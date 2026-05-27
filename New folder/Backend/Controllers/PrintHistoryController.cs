using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Caching.Memory;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using PTVBTPM.Hubs;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    [Produces("application/json")]
    public class PrintHistoryController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<PrintHistoryController> _logger;
        private readonly IHubContext<PrintHub> _hubContext;
        private readonly IMemoryCache _cache;

        public PrintHistoryController(WebDbContext context, ILogger<PrintHistoryController> logger, IHubContext<PrintHub> hubContext, IMemoryCache cache)
        {
            _context = context;
            _logger = logger;
            _hubContext = hubContext;
            _cache = cache;
        }

        /// <summary>
        /// Lấy thống kê tổng quan lịch sử in (Tổng số đơn, Tổng số trang, Tổng chi phí)
        /// </summary>
        [HttpGet("Summary")]
        [ProducesResponseType(typeof(PrintHistorySummaryDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetSummary()
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                // Đếm tổng số đơn in
                var totalOrders = await _context.PrintJobs
                    .Where(j => j.UserId == userId)
                    .CountAsync();

                // Tính tổng số trang đã in (chỉ tính các đơn đã hoàn thành)
                var totalPagesPrinted = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.Status == "DONE")
                    .SumAsync(j => (j.TotalPages ?? 0) * (j.Copies ?? 1));

                // Tính tổng chi phí (chỉ tính các đơn đã hoàn thành)
                var totalCost = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.Status == "DONE")
                    .Include(j => j.PaperSize)
                    .ToListAsync();

                decimal totalCostValue = 0;
                foreach (var job in totalCost)
                {
                    if (job.PaperSize?.Price != null && job.TotalPages != null && job.Copies != null)
                    {
                        totalCostValue += job.PaperSize.Price.Value * job.TotalPages.Value * job.Copies.Value;
                    }
                }

                var summary = new PrintHistorySummaryDto
                {
                    TotalOrders = totalOrders,
                    TotalPagesPrinted = totalPagesPrinted,
                    TotalCost = totalCostValue
                };

                return Ok(new { success = true, data = summary });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting print history summary");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy thống kê lịch sử in.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách lịch sử in với tìm kiếm, lọc và phân trang
        /// </summary>
        /// <param name="page">Số trang (mặc định: 1)</param>
        /// <param name="pageSize">Số item mỗi trang (mặc định: 10)</param>
        /// <param name="search">Tìm kiếm theo tên file, mã đơn, máy in</param>
        /// <param name="status">Lọc theo trạng thái (DONE, PENDING, PRINTING, FAILED, CANCELLED). Để trống để lấy tất cả</param>
        [HttpGet]
        [ProducesResponseType(typeof(PrintHistoryListResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetPrintHistory(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string? search = null,
            [FromQuery] string? status = null)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                // Query cơ bản
                var query = _context.PrintJobs
                    .Where(j => j.UserId == userId)
                    .Include(j => j.Document)
                    .Include(j => j.Printer)
                    .Include(j => j.PaperSize)
                    .AsQueryable();

                // Lọc theo trạng thái
                if (!string.IsNullOrWhiteSpace(status))
                {
                    query = query.Where(j => j.Status == status.ToUpper());
                }

                // Tìm kiếm
                if (!string.IsNullOrWhiteSpace(search))
                {
                    var searchLower = search.ToLower();
                    var searchUpper = search.ToUpper();
                    
                    // Thử parse PrintJobId nếu search là số hoặc chứa pattern mã đơn
                    int? searchJobId = null;
                    if (int.TryParse(search, out var jobId))
                    {
                        searchJobId = jobId;
                    }
                    else if (searchUpper.StartsWith("PJ-") && search.Length > 3)
                    {
                        // Tìm kiếm theo format PJ-YYYY-XXX hoặc PJ-XXX
                        var parts = searchUpper.Substring(3).Split('-');
                        if (parts.Length > 0 && int.TryParse(parts[parts.Length - 1], out var lastPart))
                        {
                            searchJobId = lastPart;
                        }
                    }

                    var finalSearchJobId = searchJobId;
                    query = query.Where(j =>
                        (j.Document != null && j.Document.FileName.ToLower().Contains(searchLower)) ||
                        (finalSearchJobId.HasValue && j.PrintJobId == finalSearchJobId.Value) ||
                        (j.Printer != null && j.Printer.PrinterCode.ToLower().Contains(searchLower)) ||
                        (j.Printer != null && j.Printer.Brand != null && j.Printer.Brand.ToLower().Contains(searchLower)) ||
                        (j.Printer != null && j.Printer.Model != null && j.Printer.Model.ToLower().Contains(searchLower)) ||
                        (j.Printer != null && j.Printer.Location != null && j.Printer.Location.ToLower().Contains(searchLower))
                    );
                }

                // Đếm tổng số
                var totalCount = await query.CountAsync();

                // Phân trang và sắp xếp (mới nhất trước)
                var printJobs = await query
                    .OrderByDescending(j => j.CreatedOn)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                // Map sang DTO
                var items = printJobs.Select(j => new PrintHistoryItemDto
                {
                    OrderCode = FormatOrderCode(j.PrintJobId, j.CreatedOn),
                    PrintJobId = j.PrintJobId,
                    FileName = j.Document?.FileName ?? "Unknown",
                    PrintDate = j.CreatedOn,
                    NumberOfPages = j.TotalPages ?? 0,
                    Copies = j.Copies ?? 1,
                    PrinterName = FormatPrinterName(j.Printer, includeLocation: false),
                    PrinterLocation = j.Printer != null ? j.Printer.Location : null,
                    Status = MapStatus(j.Status ?? "UNKNOWN"),
                    Cost = CalculateCost(j)
                }).ToList();

                var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);

                var response = new PrintHistoryListResponseDto
                {
                    Items = items,
                    TotalCount = totalCount,
                    Page = page,
                    PageSize = pageSize,
                    TotalPages = totalPages
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting print history");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy lịch sử in.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy chi tiết một đơn in (bao gồm đầy đủ thông tin để in lại)
        /// </summary>
        /// <param name="id">ID của print job</param>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(PrintHistoryDetailDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetPrintHistoryDetail(int id)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                var printJob = await _context.PrintJobs
                    .Where(j => j.PrintJobId == id && j.UserId == userId)
                    .Include(j => j.Document)
                    .Include(j => j.Printer)
                    .Include(j => j.PaperSize)
                    .FirstOrDefaultAsync();

                if (printJob == null)
                    return NotFound(new { success = false, message = "Không tìm thấy đơn in." });

                // Parse PagesToPrint để lấy trang in gốc và kiểm tra double-sided
                var (pagesToPrint, isDoubleSided) = ParsePagesToPrint(printJob.PagesToPrint);

                var detail = new PrintHistoryDetailDto
                {
                    OrderCode = FormatOrderCode(printJob.PrintJobId, printJob.CreatedOn),
                    PrintJobId = printJob.PrintJobId,
                    Status = MapStatus(printJob.Status ?? "UNKNOWN"),
                    FileName = printJob.Document?.FileName ?? "Unknown",
                    DocumentId = printJob.DocumentId,
                    PrintTime = printJob.CreatedOn,
                    PrinterId = printJob.PrinterId,
                    PrinterName = FormatPrinterName(printJob.Printer, includeLocation: false),
                    PrinterLocation = printJob.Printer != null ? printJob.Printer.Location : null,
                    NumberOfPages = printJob.TotalPages ?? 0,
                    Copies = printJob.Copies ?? 1,
                    PaperSizeId = printJob.PaperSizeId,
                    PaperSize = printJob.PaperSize?.Code ?? "Unknown",
                    PrintMode = printJob.IsColor ? "Màu" : "Đen trắng",
                    IsColor = printJob.IsColor,
                    IsDoubleSided = isDoubleSided,
                    PagesToPrint = pagesToPrint,
                    Cost = CalculateCost(printJob)
                };

                return Ok(new { success = true, data = detail });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting print history detail");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy chi tiết đơn in.", error = ex.Message });
            }
        }

        /// <summary>
        /// In lại một đơn in dựa trên print job cũ (cho user)
        /// </summary>
        /// <param name="request">Request chứa printJobId và các tùy chọn (printerId, copies) nếu muốn thay đổi</param>
        [HttpPost("Reprint")]
        [ProducesResponseType(typeof(CreatePrintJobResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Reprint([FromBody] ReprintRequestDto request)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                // Lấy print job cũ
                var oldPrintJob = await _context.PrintJobs
                    .Where(j => j.PrintJobId == request.PrintJobId && j.UserId == userId)
                    .Include(j => j.Document)
                    .Include(j => j.Printer)
                    .Include(j => j.PaperSize)
                    .FirstOrDefaultAsync();

                if (oldPrintJob == null)
                    return NotFound(new { success = false, message = "Không tìm thấy đơn in cũ." });

                // Kiểm tra document còn tồn tại
                if (oldPrintJob.DocumentId == null || oldPrintJob.Document == null)
                {
                    return BadRequest(new { success = false, message = "Tài liệu gốc không còn tồn tại. Không thể in lại." });
                }

                // Xác định máy in (dùng máy in mới nếu có, không thì dùng máy in cũ)
                int printerId = request.PrinterId ?? oldPrintJob.PrinterId ?? 0;
                if (printerId == 0)
                {
                    return BadRequest(new { success = false, message = "Không xác định được máy in." });
                }

                // Kiểm tra máy in tồn tại và khả dụng
                var printer = await _context.Printers.FindAsync(printerId);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                if (printer.Status != "AVAILABLE")
                {
                    return BadRequest(new { success = false, message = $"Máy in không khả dụng. Trạng thái hiện tại: {printer.Status ?? "UNKNOWN"}" });
                }

                // Xác định số bản in (dùng số bản mới nếu có, không thì dùng số bản cũ)
                int copies = request.Copies ?? oldPrintJob.Copies ?? 1;
                if (copies < 1 || copies > 100)
                {
                    return BadRequest(new { success = false, message = "Số bản in phải từ 1 đến 100." });
                }

                // Kiểm tra paper size
                if (oldPrintJob.PaperSizeId == null)
                {
                    return BadRequest(new { success = false, message = "Không xác định được khổ giấy." });
                }

                var paperSize = await _context.PaperSizes.FindAsync(oldPrintJob.PaperSizeId);
                if (paperSize == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy khổ giấy." });
                }

                // Parse PagesToPrint để lấy trang in gốc
                var (pagesToPrint, isDoubleSided) = ParsePagesToPrint(oldPrintJob.PagesToPrint);

                // Tính số trang sẽ in
                int totalPages = 0;
                var document = oldPrintJob.Document;
                int? pageCount = document.PageCount;

                if (string.IsNullOrWhiteSpace(pagesToPrint) || pagesToPrint.ToLower() == "all")
                {
                    totalPages = pageCount ?? 0;
                }
                else
                {
                    // Parse pages to print (ví dụ: "1-5,10,15-20")
                    totalPages = ParsePagesToPrintCount(pagesToPrint, pageCount ?? 0);
                }

                if (totalPages <= 0)
                {
                    return BadRequest(new { success = false, message = "Số trang in không hợp lệ." });
                }

                // Tính số trang thực tế (tính cả double-sided)
                int actualPages = totalPages;
                if (isDoubleSided)
                {
                    actualPages = (int)Math.Ceiling(totalPages / 2.0);
                }

                // Quy đổi khổ giấy: A3 = 2x A4
                var paperSizeCode = paperSize.Code.ToUpper();
                int pageMultiplier = 1;
                if (paperSizeCode == "A3")
                {
                    pageMultiplier = 2;
                }

                // Lấy hệ số phân trang từ system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                // Nếu không có config, sử dụng giá trị mặc định
                var pageFactor = systemConfig?.PageFactor ?? 1;

                // Tính số trang A4 tương đương
                int equivalentA4Pages = (int)Math.Ceiling((double)(actualPages * pageMultiplier));

                // Kiểm tra số trang còn lại của user
                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy người dùng." });
                }

                var totalPagesNeeded = equivalentA4Pages * copies;

                // Kiểm tra tổng trang sở hữu
                var pageBalance = user.PageDefaultBalance + user.PagePurchasedBalance;
                if (totalPagesNeeded > pageBalance)
                {
                    return BadRequest(new { success = false, message = $"Số trang còn lại không đủ. Bạn còn {pageBalance} trang, cần {totalPagesNeeded} trang." });
                }

                // Tạo print job mới
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                
                // Format PagesToPrint với double-sided nếu cần
                string? pagesToPrintValue = pagesToPrint;
                if (isDoubleSided)
                {
                    if (string.IsNullOrWhiteSpace(pagesToPrintValue) || pagesToPrintValue.ToLower() == "all")
                    {
                        pagesToPrintValue = "ALL|DOUBLE_SIDED";
                    }
                    else
                    {
                        pagesToPrintValue = $"{pagesToPrintValue}|DOUBLE_SIDED";
                    }
                }

                var newPrintJob = new PrintJob
                {
                    UserId = userId,
                    DocumentId = oldPrintJob.DocumentId,
                    PrinterId = printerId,
                    PaperSizeId = oldPrintJob.PaperSizeId,
                    Copies = copies,
                    IsColor = oldPrintJob.IsColor,
                    PagesToPrint = pagesToPrintValue,
                    TotalPages = equivalentA4Pages,
                    Status = "PENDING",
                    CreatedOn = now,
                    ModifiedOn = now
                };

                _context.PrintJobs.Add(newPrintJob);
                await _context.SaveChangesAsync();

                // Tự động execute print job nếu máy in đang rảnh
                var hasPrintingJob = await _context.PrintJobs
                    .AnyAsync(j => j.PrinterId == printerId && j.Status == "PRINTING" && j.PrintJobId != newPrintJob.PrintJobId);
                
                if (!hasPrintingJob)
                {
                    try
                    {
                        await _context.Entry(newPrintJob)
                            .Reference(p => p.PaperSize)
                            .LoadAsync();
                        
                        newPrintJob.Status = "PRINTING";
                        newPrintJob.ModifiedOn = now;
                        newPrintJob.ModifiedBy = userId?.ToString();
                        
                        if (printer != null)
                        {
                            printer.Status = "BUSY";
                            printer.ModifiedOn = now;
                        }
                        
                        await _context.SaveChangesAsync();
                        
                        _logger.LogInformation($"Auto-executed reprint job {newPrintJob.PrintJobId} from old job {request.PrintJobId} on printer {printerId}");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Failed to auto-execute reprint job {newPrintJob.PrintJobId}, keeping status PENDING");
                        await _context.Entry(newPrintJob).ReloadAsync();
                    }
                }

                // Clean PagesToPrint để response
                string? cleanPagesToPrint = pagesToPrint;
                if (string.IsNullOrWhiteSpace(cleanPagesToPrint) || cleanPagesToPrint.ToLower() == "all")
                {
                    cleanPagesToPrint = "all";
                }

                await _context.Entry(newPrintJob).ReloadAsync();

                var response = new CreatePrintJobResponseDto
                {
                    PrintJobId = newPrintJob.PrintJobId,
                    DocumentId = newPrintJob.DocumentId ?? 0,
                    PrinterId = newPrintJob.PrinterId ?? 0,
                    Status = newPrintJob.Status,
                    TotalPages = newPrintJob.TotalPages,
                    Copies = newPrintJob.Copies ?? 1,
                    IsColor = newPrintJob.IsColor,
                    IsDoubleSided = isDoubleSided,
                    PagesToPrint = cleanPagesToPrint,
                    CreatedOn = newPrintJob.CreatedOn
                };

                return Ok(new
                {
                    success = true,
                    message = newPrintJob.Status == "PRINTING"
                        ? "In lại thành công và đã tự động bắt đầu in."
                        : "In lại thành công.",
                    data = response
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reprinting");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi in lại.", error = ex.Message });
            }
        }

        /// <summary>
        /// Map trạng thái máy in sang tiếng Việt
        /// </summary>
        private string MapPrinterStatusToVietnamese(string? status)
        {
            return (status ?? "UNKNOWN").ToUpper() switch
            {
                "AVAILABLE" => "Khả dụng",
                "BUSY" => "Bận",
                "PRINTING" => "Đang in",
                "OFFLINE" => "Offline",
                _ => status ?? "Không xác định"
            };
        }

        /// <summary>
        /// Map trạng thái print job sang tiếng Việt
        /// </summary>
        private string MapPrintJobStatusToVietnamese(string? status)
        {
            return (status ?? "UNKNOWN").ToUpper() switch
            {
                "PENDING" => "Đang chờ",
                "PRINTING" => "Đang in",
                "DONE" => "Hoàn thành",
                "COMPLETED" => "Hoàn thành",
                "SUCCESS" => "Hoàn thành",
                "FAILED" => "Thất bại",
                "ERROR" => "Thất bại",
                "CANCELLED" => "Đã hủy",
                _ => status ?? "Không xác định"
            };
        }

        /// <summary>
        /// Map status từ database sang tiếng Việt (deprecated - use MapPrintJobStatusToVietnamese)
        /// </summary>
        private string MapStatus(string status)
        {
            return MapPrintJobStatusToVietnamese(status);
        }

        /// <summary>
        /// Gửi SignalR notification về trạng thái print job
        /// </summary>
        private async Task SendPrintJobStatusUpdateAsync(PrintJob job, DateTime now)
        {
            try
            {
                await _context.Entry(job)
                    .Reference(j => j.Document)
                    .LoadAsync();
                await _context.Entry(job)
                    .Reference(j => j.Printer)
                    .LoadAsync();

                var year = job.CreatedOn?.Year ?? DateTime.Now.Year;
                var orderCode = $"PJ-{year}-{job.PrintJobId:D3}";

                var printerName = job.Printer != null
                    ? $"{job.Printer.Brand} {job.Printer.Model}".Trim()
                    : null;

                var status = job.Status ?? "UNKNOWN";
                var update = new PrintJobStatusUpdateDto
                {
                    PrintJobId = job.PrintJobId,
                    OrderCode = orderCode,
                    Status = status,
                    StatusVi = MapPrintJobStatusToVietnamese(status),
                    FileName = job.Document?.FileName,
                    PrinterId = job.PrinterId,
                    PrinterName = printerName,
                    UpdatedAt = now
                };

                // Gửi đến các groups
                if (job.UserId.HasValue)
                {
                    var userGroup = $"user_print_{job.UserId.Value}";
                    await _hubContext.Clients.Group(userGroup).SendAsync("PrintJobStatusUpdate", update);
                }

                var printJobGroup = $"printjob_{job.PrintJobId}";
                await _hubContext.Clients.Group(printJobGroup).SendAsync("PrintJobStatusUpdate", update);

                if (job.PrinterId.HasValue)
                {
                    var printerGroup = $"printer_{job.PrinterId.Value}";
                    await _hubContext.Clients.Group(printerGroup).SendAsync("PrintJobStatusUpdate", update);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending print job status update for job {job.PrintJobId}");
            }
        }

        /// <summary>
        /// Gửi SignalR notification về trạng thái máy in
        /// </summary>
        private async Task SendPrinterStatusUpdateAsync(Printer printer, DateTime now)
        {
            try
            {
                var status = printer.Status ?? "UNKNOWN";
                var update = new PrinterStatusUpdateDto
                {
                    PrinterId = printer.PrinterId,
                    PrinterCode = printer.PrinterCode,
                    Status = status,
                    StatusVi = MapPrinterStatusToVietnamese(status),
                    CurrentPaper = printer.CurrentPaper,
                    UpdatedAt = now
                };

                var printerGroup = $"printer_{printer.PrinterId}";
                await _hubContext.Clients.Group(printerGroup).SendAsync("PrinterStatusUpdate", update);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending printer status update for printer {printer.PrinterId}");
            }
        }

        /// <summary>
        /// Tính chi phí cho một print job
        /// </summary>
        private decimal? CalculateCost(PrintJob job)
        {
            // Chỉ tính chi phí cho các đơn đã hoàn thành
            if (job.Status != "DONE")
                return null;

            if (job.PaperSize?.Price != null && job.TotalPages != null && job.Copies != null)
            {
                return job.PaperSize.Price.Value * job.TotalPages.Value * job.Copies.Value;
            }

            return null;
        }

        /// <summary>
        /// Format mã đơn theo format: PJ-YYYY-XXX
        /// </summary>
        private string FormatOrderCode(int printJobId, DateTime? createdOn)
        {
            var year = createdOn?.Year ?? DateTime.Now.Year;
            return $"PJ-{year}-{printJobId:D3}";
        }

        /// <summary>
        /// Format tên máy in
        /// </summary>
        private string? FormatPrinterName(Printer? printer, bool includeLocation = true)
        {
            if (printer == null)
                return null;

            var nameParts = new List<string>();
            if (!string.IsNullOrWhiteSpace(printer.Brand))
                nameParts.Add(printer.Brand);
            if (!string.IsNullOrWhiteSpace(printer.Model))
                nameParts.Add(printer.Model);

            var printerName = nameParts.Count > 0 ? string.Join(" ", nameParts) : printer.PrinterCode;

            if (includeLocation && !string.IsNullOrWhiteSpace(printer.Location))
            {
                return $"{printerName} ({printer.Location})";
            }

            return printerName;
        }

        /// <summary>
        /// Parse PagesToPrint để lấy trang in gốc và kiểm tra double-sided
        /// </summary>
        private (string? pagesToPrint, bool isDoubleSided) ParsePagesToPrint(string? pagesToPrintValue)
        {
            if (string.IsNullOrWhiteSpace(pagesToPrintValue))
                return (null, false);

            // Kiểm tra có DOUBLE_SIDED không
            bool isDoubleSided = pagesToPrintValue.Contains("|DOUBLE_SIDED", StringComparison.OrdinalIgnoreCase);
            
            // Lấy phần trang in gốc (loại bỏ |DOUBLE_SIDED)
            string? pagesToPrint = pagesToPrintValue;
            if (isDoubleSided)
            {
                var parts = pagesToPrintValue.Split('|');
                if (parts.Length > 0 && parts[0].ToUpper() != "DOUBLE_SIDED")
                {
                    pagesToPrint = parts[0];
                }
                else
                {
                    pagesToPrint = null; // Nếu chỉ có DOUBLE_SIDED thì là in tất cả
                }
            }

            // Nếu là "ALL|DOUBLE_SIDED" hoặc chỉ "DOUBLE_SIDED" thì trả về "all"
            if (string.IsNullOrWhiteSpace(pagesToPrint) || pagesToPrint.ToUpper() == "ALL")
            {
                pagesToPrint = "all";
            }

            return (pagesToPrint, isDoubleSided);
        }

        /// <summary>
        /// Parse pages to print và đếm số trang
        /// </summary>
        private int ParsePagesToPrintCount(string pagesToPrint, int maxPages)
        {
            if (string.IsNullOrWhiteSpace(pagesToPrint) || pagesToPrint.ToLower() == "all")
                return maxPages;

            int count = 0;
            var parts = pagesToPrint.Split(',');
            
            foreach (var part in parts)
            {
                var trimmed = part.Trim();
                if (trimmed.Contains('-'))
                {
                    // Range: "1-5"
                    var rangeParts = trimmed.Split('-');
                    if (rangeParts.Length == 2 && 
                        int.TryParse(rangeParts[0].Trim(), out var start) && 
                        int.TryParse(rangeParts[1].Trim(), out var end))
                    {
                        for (int i = start; i <= end && i <= maxPages; i++)
                        {
                            count++;
                        }
                    }
                }
                else
                {
                    // Single page: "10"
                    if (int.TryParse(trimmed, out var page) && page <= maxPages)
                    {
                        count++;
                    }
                }
            }

            return count;
        }

        /// <summary>
        /// Lấy danh sách tất cả đơn in cho admin (không filter theo userId)
        /// </summary>
        /// <param name="page">Số trang (mặc định: 1)</param>
        /// <param name="pageSize">Số item mỗi trang (mặc định: 10)</param>
        /// <param name="search">Tìm kiếm theo tên file, mã đơn, máy in, tên user, email</param>
        /// <param name="status">Lọc theo trạng thái (DONE, PENDING, PRINTING, FAILED, CANCELLED). Để trống để lấy tất cả</param>
        [HttpGet("Admin")]
        [ProducesResponseType(typeof(PrintHistoryListResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetAdminPrintHistory(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string? search = null,
            [FromQuery] string? status = null)
        {
            try
            {
                // Kiểm tra quyền Admin/SPSO
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền xem danh sách đơn in." });

                // Query cơ bản - lấy tất cả print jobs (không filter theo userId)
                var query = _context.PrintJobs
                    .Include(j => j.Document)
                    .Include(j => j.Printer)
                    .Include(j => j.PaperSize)
                    .Include(j => j.User)
                    .AsQueryable();

                // Lọc theo trạng thái - chỉ filter nếu có giá trị và không phải "all"
                if (!string.IsNullOrWhiteSpace(status) && status.ToUpper() != "ALL")
                {
                    query = query.Where(j => j.Status != null && j.Status.ToUpper() == status.ToUpper());
                }
                // Nếu không có filter, lấy tất cả trạng thái (bao gồm cả null)

                // Tìm kiếm
                if (!string.IsNullOrWhiteSpace(search))
                {
                    var searchLower = search.ToLower();
                    var searchUpper = search.ToUpper();
                    
                    // Thử parse PrintJobId nếu search là số hoặc chứa pattern mã đơn
                    int? searchJobId = null;
                    if (int.TryParse(search, out var jobId))
                    {
                        searchJobId = jobId;
                    }
                    else if (searchUpper.StartsWith("PJ-") && search.Length > 3)
                    {
                        // Tìm kiếm theo format PJ-YYYY-XXX hoặc PJ-XXX
                        var parts = searchUpper.Substring(3).Split('-');
                        if (parts.Length > 0 && int.TryParse(parts[parts.Length - 1], out var lastPart))
                        {
                            searchJobId = lastPart;
                        }
                    }

                    var finalSearchJobId = searchJobId;
                    query = query.Where(j =>
                        (j.Document != null && j.Document.FileName.ToLower().Contains(searchLower)) ||
                        (finalSearchJobId.HasValue && j.PrintJobId == finalSearchJobId.Value) ||
                        (j.Printer != null && j.Printer.PrinterCode.ToLower().Contains(searchLower)) ||
                        (j.Printer != null && j.Printer.Brand != null && j.Printer.Brand.ToLower().Contains(searchLower)) ||
                        (j.Printer != null && j.Printer.Model != null && j.Printer.Model.ToLower().Contains(searchLower)) ||
                        (j.Printer != null && j.Printer.Location != null && j.Printer.Location.ToLower().Contains(searchLower)) ||
                        (j.User != null && j.User.FullName != null && j.User.FullName.ToLower().Contains(searchLower)) ||
                        (j.User != null && j.User.Email != null && j.User.Email.ToLower().Contains(searchLower))
                    );
                }

                // Đếm tổng số
                var totalCount = await query.CountAsync();

                // Phân trang và sắp xếp:
                // 1. Ưu tiên các đơn đang in (PRINTING) và đang đợi (PENDING) lên đầu
                // 2. Sau đó sắp xếp theo thời gian tạo (mới nhất trước)
                // Sử dụng OrderBy với điều kiện đơn giản hơn để EF có thể dịch được
                var printJobs = await query
                    .OrderByDescending(j => j.Status == "PRINTING" || j.Status == "PENDING") // PRINTING và PENDING = true (ưu tiên), các status khác = false
                    .ThenByDescending(j => j.CreatedOn) // Sau đó sắp xếp theo thời gian tạo
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                // Map sang DTO cho admin (có thêm thông tin user)
                var items = printJobs.Select(j => new AdminPrintHistoryItemDto
                {
                    OrderCode = FormatOrderCode(j.PrintJobId, j.CreatedOn),
                    PrintJobId = j.PrintJobId,
                    UserId = j.UserId ?? 0,
                    UserName = j.User?.FullName ?? "Unknown",
                    UserEmail = j.User?.Email ?? "Unknown",
                    FileName = j.Document?.FileName ?? "Unknown",
                    PrintDate = j.CreatedOn,
                    NumberOfPages = j.TotalPages ?? 0,
                    Copies = j.Copies ?? 1,
                    PrinterName = FormatPrinterName(j.Printer, includeLocation: false),
                    PrinterLocation = j.Printer != null ? j.Printer.Location : null,
                    Status = MapStatus(j.Status ?? "UNKNOWN"),
                    Cost = CalculateCost(j)
                }).ToList();

                var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);

                // Tạo response với AdminPrintHistoryItemDto
                var response = new
                {
                    Items = items,
                    TotalCount = totalCount,
                    Page = page,
                    PageSize = pageSize,
                    TotalPages = totalPages
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting admin print history");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy danh sách đơn in.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy chi tiết một đơn in cho admin (bao gồm đầy đủ thông tin để in lại)
        /// </summary>
        /// <param name="id">ID của print job</param>
        [HttpGet("Admin/Detail/{id}")]
        [ProducesResponseType(typeof(PrintHistoryDetailDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetAdminPrintHistoryDetail(int id)
        {
            try
            {
                // Kiểm tra quyền Admin/SPSO
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền xem chi tiết đơn in." });

                var printJob = await _context.PrintJobs
                    .Where(j => j.PrintJobId == id) // Không filter theo userId cho admin
                    .Include(j => j.Document)
                    .Include(j => j.Printer)
                    .Include(j => j.PaperSize)
                    .Include(j => j.User)
                    .FirstOrDefaultAsync();

                if (printJob == null)
                    return NotFound(new { success = false, message = "Không tìm thấy đơn in." });

                // Parse PagesToPrint để lấy trang in gốc và kiểm tra double-sided
                var (pagesToPrint, isDoubleSided) = ParsePagesToPrint(printJob.PagesToPrint);

                var detail = new PrintHistoryDetailDto
                {
                    OrderCode = FormatOrderCode(printJob.PrintJobId, printJob.CreatedOn),
                    PrintJobId = printJob.PrintJobId,
                    Status = MapStatus(printJob.Status ?? "UNKNOWN"),
                    FileName = printJob.Document?.FileName ?? "Unknown",
                    DocumentId = printJob.DocumentId,
                    PrintTime = printJob.CreatedOn,
                    PrinterId = printJob.PrinterId,
                    PrinterName = FormatPrinterName(printJob.Printer, includeLocation: false),
                    PrinterLocation = printJob.Printer != null ? printJob.Printer.Location : null,
                    NumberOfPages = printJob.TotalPages ?? 0,
                    Copies = printJob.Copies ?? 1,
                    PaperSizeId = printJob.PaperSizeId,
                    PaperSize = printJob.PaperSize?.Code ?? "Unknown",
                    PrintMode = printJob.IsColor ? "Màu" : "Đen trắng",
                    IsColor = printJob.IsColor,
                    IsDoubleSided = isDoubleSided,
                    PagesToPrint = pagesToPrint,
                    Cost = CalculateCost(printJob)
                };

                return Ok(new { success = true, data = detail });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting admin print history detail");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy chi tiết đơn in.", error = ex.Message });
            }
        }

        /// <summary>
        /// In lại một đơn in cho admin (không cần check userId của print job)
        /// </summary>
        /// <param name="request">Request chứa printJobId và các tùy chọn (printerId, copies) nếu muốn thay đổi</param>
        [HttpPost("Admin/Reprint")]
        [ProducesResponseType(typeof(CreatePrintJobResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> AdminReprint([FromBody] ReprintRequestDto request)
        {
            try
            {
                // Kiểm tra quyền Admin/SPSO
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền in lại đơn in." });

                // Lấy print job cũ (không filter theo userId cho admin)
                var oldPrintJob = await _context.PrintJobs
                    .Where(j => j.PrintJobId == request.PrintJobId)
                    .Include(j => j.Document)
                    .Include(j => j.Printer)
                    .Include(j => j.PaperSize)
                    .FirstOrDefaultAsync();

                if (oldPrintJob == null)
                    return NotFound(new { success = false, message = "Không tìm thấy đơn in cũ." });

                // Kiểm tra document còn tồn tại
                if (oldPrintJob.DocumentId == null || oldPrintJob.Document == null)
                {
                    return BadRequest(new { success = false, message = "Tài liệu gốc không còn tồn tại. Không thể in lại." });
                }

                // Xác định máy in (dùng máy in mới nếu có, không thì dùng máy in cũ)
                int printerId = request.PrinterId ?? oldPrintJob.PrinterId ?? 0;
                if (printerId == 0)
                {
                    return BadRequest(new { success = false, message = "Không xác định được máy in." });
                }

                // Kiểm tra máy in tồn tại và khả dụng
                var printer = await _context.Printers.FindAsync(printerId);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                if (printer.Status != "AVAILABLE")
                {
                    return BadRequest(new { success = false, message = $"Máy in không khả dụng. Trạng thái hiện tại: {printer.Status ?? "UNKNOWN"}" });
                }

                // Xác định số bản in (dùng số bản mới nếu có, không thì dùng số bản cũ)
                int copies = request.Copies ?? oldPrintJob.Copies ?? 1;
                if (copies < 1 || copies > 100)
                {
                    return BadRequest(new { success = false, message = "Số bản in phải từ 1 đến 100." });
                }

                // Kiểm tra paper size
                if (oldPrintJob.PaperSizeId == null)
                {
                    return BadRequest(new { success = false, message = "Không xác định được khổ giấy." });
                }

                var paperSize = await _context.PaperSizes.FindAsync(oldPrintJob.PaperSizeId);
                if (paperSize == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy khổ giấy." });
                }

                // Parse PagesToPrint để lấy trang in gốc
                var (pagesToPrint, isDoubleSided) = ParsePagesToPrint(oldPrintJob.PagesToPrint);

                // Tính số trang sẽ in
                int totalPages = 0;
                var document = oldPrintJob.Document;
                int? pageCount = document.PageCount;

                if (string.IsNullOrWhiteSpace(pagesToPrint) || pagesToPrint.ToLower() == "all")
                {
                    totalPages = pageCount ?? 0;
                }
                else
                {
                    // Parse pages to print (ví dụ: "1-5,10,15-20")
                    totalPages = ParsePagesToPrintCount(pagesToPrint, pageCount ?? 0);
                }

                if (totalPages <= 0)
                {
                    return BadRequest(new { success = false, message = "Số trang in không hợp lệ." });
                }

                // Tính số trang thực tế (tính cả double-sided)
                int actualPages = totalPages;
                if (isDoubleSided)
                {
                    actualPages = (int)Math.Ceiling(totalPages / 2.0);
                }

                // Quy đổi khổ giấy: A3 = 2x A4
                var paperSizeCode = paperSize.Code.ToUpper();
                int pageMultiplier = 1;
                if (paperSizeCode == "A3")
                {
                    pageMultiplier = 2;
                }

                // Lấy hệ số phân trang từ system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                // Nếu không có config, sử dụng giá trị mặc định
                var pageFactor = systemConfig?.PageFactor ?? 1;

                // Tính số trang A4 tương đương
                int equivalentA4Pages = (int)Math.Ceiling((double)(actualPages * pageMultiplier));

                // Kiểm tra số trang còn lại của user (user của print job cũ, không phải admin)
                var originalUserId = oldPrintJob.UserId;
                if (originalUserId.HasValue)
                {
                    var originalUser = await _context.Users.FindAsync(originalUserId.Value);
                    if (originalUser != null)
                    {
                        var totalPagesNeeded = equivalentA4Pages * copies;
                        var totalPagesPrinted = await _context.PrintJobs
                            .Where(j => j.UserId == originalUserId && j.Status == "DONE")
                            .SumAsync(j => (j.TotalPages ?? 0) * (j.Copies ?? 1));

                        var pageBalance = originalUser.PageDefaultBalance + originalUser.PagePurchasedBalance - totalPagesPrinted;
                        if (totalPagesNeeded > pageBalance)
                        {
                            return BadRequest(new { success = false, message = $"Số trang còn lại của người dùng không đủ. Còn {pageBalance} trang, cần {totalPagesNeeded} trang." });
                        }
                    }
                }

                // Tạo print job mới (với userId của user gốc)
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                
                // Format PagesToPrint với double-sided nếu cần
                string? pagesToPrintValue = pagesToPrint;
                if (isDoubleSided)
                {
                    if (string.IsNullOrWhiteSpace(pagesToPrintValue) || pagesToPrintValue.ToLower() == "all")
                    {
                        pagesToPrintValue = "ALL|DOUBLE_SIDED";
                    }
                    else
                    {
                        pagesToPrintValue = $"{pagesToPrintValue}|DOUBLE_SIDED";
                    }
                }

                var newPrintJob = new PrintJob
                {
                    UserId = originalUserId, // Giữ nguyên userId của user gốc
                    DocumentId = oldPrintJob.DocumentId,
                    PrinterId = printerId,
                    PaperSizeId = oldPrintJob.PaperSizeId,
                    Copies = copies,
                    IsColor = oldPrintJob.IsColor,
                    PagesToPrint = pagesToPrintValue,
                    TotalPages = equivalentA4Pages,
                    Status = "PENDING",
                    CreatedOn = now,
                    ModifiedOn = now
                };

                _context.PrintJobs.Add(newPrintJob);
                await _context.SaveChangesAsync();

                // Tự động execute print job nếu máy in đang rảnh
                var hasPrintingJob = await _context.PrintJobs
                    .AnyAsync(j => j.PrinterId == printerId && j.Status == "PRINTING" && j.PrintJobId != newPrintJob.PrintJobId);
                
                if (!hasPrintingJob)
                {
                    try
                    {
                        await _context.Entry(newPrintJob)
                            .Reference(p => p.PaperSize)
                            .LoadAsync();
                        
                        newPrintJob.Status = "PRINTING";
                        newPrintJob.ModifiedOn = now;
                        newPrintJob.ModifiedBy = userId?.ToString();
                        
                        if (printer != null)
                        {
                            printer.Status = "BUSY";
                            printer.ModifiedOn = now;
                        }
                        
                        await _context.SaveChangesAsync();
                        
                        _logger.LogInformation($"Auto-executed admin reprint job {newPrintJob.PrintJobId} from old job {request.PrintJobId} on printer {printerId}");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Failed to auto-execute admin reprint job {newPrintJob.PrintJobId}, keeping status PENDING");
                        await _context.Entry(newPrintJob).ReloadAsync();
                    }
                }

                // Clean PagesToPrint để response
                string? cleanPagesToPrint = pagesToPrint;
                if (string.IsNullOrWhiteSpace(cleanPagesToPrint) || cleanPagesToPrint.ToLower() == "all")
                {
                    cleanPagesToPrint = "all";
                }

                var reprintResponse = new CreatePrintJobResponseDto
                {
                    PrintJobId = newPrintJob.PrintJobId,
                    DocumentId = oldPrintJob.DocumentId ?? 0,
                    PrinterId = printerId,
                    Status = newPrintJob.Status ?? "PENDING",
                    TotalPages = equivalentA4Pages,
                    Copies = copies,
                    IsColor = oldPrintJob.IsColor,
                    IsDoubleSided = isDoubleSided,
                    PagesToPrint = cleanPagesToPrint,
                    CreatedOn = newPrintJob.CreatedOn
                };

                return Ok(new
                {
                    success = true,
                    message = newPrintJob.Status == "PRINTING"
                        ? "In lại thành công và đã tự động bắt đầu in."
                        : "In lại thành công.",
                    data = reprintResponse
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error admin reprinting");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi in lại.", error = ex.Message });
            }
        }
    }
}
