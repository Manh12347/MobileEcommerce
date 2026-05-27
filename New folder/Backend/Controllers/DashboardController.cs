using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using System.Text;
using System.Text.Json;
using PdfSharpCore.Pdf;
using PdfSharpCore.Drawing;
using System.IO;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    public class DashboardController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<DashboardController> _logger;

        public DashboardController(WebDbContext context, ILogger<DashboardController> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Debug: Kiểm tra purchase transactions của user hiện tại
        /// </summary>
        [HttpGet("DebugPurchases")]
        public async Task<IActionResult> DebugPurchases()
        {
            var userId = AuthHelper.GetCurrentUserId(HttpContext);
            if (userId == null)
                return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

            var purchases = await _context.PurchaseTransactions
                .Where(pt => pt.UserId == userId)
                .OrderByDescending(pt => pt.CreatedAt)
                .Take(10)
                .Select(pt => new
                {
                    pt.Id,
                    pt.TransactionType,
                    pt.Quantity,
                    pt.PricePerUnit,
                    pt.TotalAmount,
                    pt.TransactionCode,
                    pt.Status,
                    pt.CreatedAt
                })
                .ToListAsync();

            var totalPagesSpent = purchases
                .Where(pt => pt.TransactionType == "PAGE_PURCHASE" && pt.Status == "SUCCESS")
                .Sum(pt => pt.TotalAmount);

            var totalStorageSpent = purchases
                .Where(pt => pt.TransactionType == "STORAGE_PURCHASE" && pt.Status == "SUCCESS")
                .Sum(pt => pt.TotalAmount);

            return Ok(new
            {
                success = true,
                data = new
                {
                    purchases,
                    summary = new
                    {
                        totalPagesSpent,
                        totalStorageSpent,
                        totalSpent = totalPagesSpent + totalStorageSpent,
                        count = purchases.Count
                    }
                }
            });
        }

        /// <summary>
        /// Lấy thống kê in ấn của sinh viên
        /// </summary>
        [HttpGet("Stats")]
        public async Task<ActionResult<DashboardStatsDto>> GetStats()
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

                // Lấy thông tin user để lấy số trang còn lại
                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                    return NotFound(new { message = "Không tìm thấy người dùng." });

                // Đếm tổng số file (documents) của user
                var totalFiles = await _context.Documents
                    .Where(d => d.UserId == userId)
                    .CountAsync();

                // Đếm số job theo status
                var completedJobs = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.Status == "DONE")
                    .CountAsync();

                var pendingJobs = await _context.PrintJobs
                    .Where(j => j.UserId == userId && (j.Status == "PENDING" || j.Status == "PRINTING"))
                    .CountAsync();

                var errorJobs = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.Status == "FAILED")
                    .CountAsync();

                // Tính tổng số trang đã in
                var totalPagesPrinted = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.Status == "DONE")
                    .SumAsync(j => (j.TotalPages ?? 0) * (j.Copies ?? 1));

                // Debug: Kiểm tra số đơn in
                var allJobsCount = await _context.PrintJobs
                    .Where(j => j.UserId == userId)
                    .CountAsync();
                var doneJobsCount = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.Status == "DONE")
                    .CountAsync();
                
                _logger.LogInformation($"[GetStats] UserId: {userId}, AllJobs: {allJobsCount}, DoneJobs: {doneJobsCount}, TotalPagesPrinted: {totalPagesPrinted}");
                // Số dư trang = tổng trang sở hữu (PageDefaultBalance + PagePurchasedBalance)
                var pageBalance = (decimal)(user.PageDefaultBalance + user.PagePurchasedBalance);

                // Đếm tổng số đơn in đã hoàn thành
                var totalOrders = doneJobsCount;

                // Tính tổng chi phí (chỉ tính các đơn đã hoàn thành)
                var totalCostJobs = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.Status == "DONE")
                    .Include(j => j.PaperSize)
                    .ToListAsync();

                decimal totalCost = 0;
                foreach (var job in totalCostJobs)
                {
                    if (job.PaperSize?.Price != null && job.TotalPages != null && job.Copies != null)
                    {
                        totalCost += job.PaperSize.Price.Value * job.TotalPages.Value * job.Copies.Value;
                    }
                }

                // Tính tổng tiền đã mua giấy từ bảng purchase_transactions
                var totalMoneySpentOnPages = await _context.PurchaseTransactions
                    .Where(pt => pt.UserId == userId &&
                                 pt.TransactionType == "PAGE_PURCHASE" &&
                                 pt.Status == "SUCCESS")
                    .SumAsync(pt => pt.TotalAmount);

                // Tính tổng tiền đã mua dung lượng từ bảng purchase_transactions
                var totalMoneySpentOnStorage = await _context.PurchaseTransactions
                    .Where(pt => pt.UserId == userId &&
                                 pt.TransactionType == "STORAGE_PURCHASE" &&
                                 pt.Status == "SUCCESS")
                    .SumAsync(pt => pt.TotalAmount);

                var stats = new DashboardStatsDto
                {
                    TotalFiles = totalFiles,
                    CompletedJobs = completedJobs,
                    PendingJobs = pendingJobs,
                    ErrorJobs = errorJobs,
                    TotalPagesPrinted = (int)totalPagesPrinted,
                    PageBalance = pageBalance,
                    PageDefaultBalance = user.PageDefaultBalance,
                    PagePurchasedBalance = user.PagePurchasedBalance,
                    TotalCost = totalCost,
                    TotalOrders = totalOrders,
                    TotalMoneySpentOnPages = totalMoneySpentOnPages,
                    TotalMoneySpent = totalMoneySpentOnPages + totalMoneySpentOnStorage, // Tổng tiền đã chi cho mua giấy + mua dung lượng
                    TotalMoneySpentOnStorage = totalMoneySpentOnStorage
                };

                _logger.LogInformation($"[GetStats] Final stats - TotalOrders: {stats.TotalOrders}, TotalPagesPrinted: {stats.TotalPagesPrinted}, TotalCost: {stats.TotalCost}, PageBalance: {stats.PageBalance}");

                return Ok(new { success = true, data = stats });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting dashboard stats");
                return StatusCode(500, new { message = "Lỗi hệ thống khi lấy thống kê.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy báo cáo chi tiết sử dụng của người dùng (giấy, tiền, tài liệu)
        /// </summary>
        [HttpGet("UserReport")]
        [ProducesResponseType(typeof(UserReportResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<UserReportResponseDto>> GetUserReport([FromQuery] string? period = "week", [FromQuery] string? startDate = null, [FromQuery] string? endDate = null)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                DateTime start;
                DateTime end;
                var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);
                bool isCustomDateRange = !string.IsNullOrWhiteSpace(startDate) && !string.IsNullOrWhiteSpace(endDate);

                // Xử lý custom date range
                if (isCustomDateRange && DateTime.TryParse(startDate, out var parsedStart) && DateTime.TryParse(endDate, out var parsedEnd))
                {
                    start = DateTime.SpecifyKind(parsedStart.Date, DateTimeKind.Unspecified);
                    end = DateTime.SpecifyKind(parsedEnd.Date, DateTimeKind.Unspecified);
                    period = "custom";
                }
                else
                {
                    // Xử lý các period định sẵn
                    period = period ?? "week";
                    switch (period.ToLower())
                    {
                        case "week":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                            break;
                        case "month":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-29), DateTimeKind.Unspecified);
                            break;
                        case "quarter":
                            end = now;
                            start = end.AddMonths(-11);
                            start = DateTime.SpecifyKind(new DateTime(start.Year, start.Month, 1), DateTimeKind.Unspecified);
                            break;
                        case "year":
                            end = now;
                            start = DateTime.SpecifyKind(new DateTime(end.Year - 4, 1, 1), DateTimeKind.Unspecified);
                            break;
                        default:
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                            period = "week";
                            break;
                    }
                }

                List<UserReportByPeriodDto> reportsByPeriod;

                if (period.ToLower() == "quarter")
                {
                    // Group theo quý (4 quý gần nhất)
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.UserId == userId && 
                                   j.Status == "DONE" &&
                                   j.CreatedOn.HasValue && 
                                   j.CreatedOn.Value >= start && 
                                   j.CreatedOn.Value <= end.AddDays(1))
                        .Include(j => j.PaperSize)
                        .ToListAsync();

                    var reportsByQuarter = printJobsInRange
                        .GroupBy(j => new { 
                            Year = j.CreatedOn!.Value.Year, 
                            Quarter = (j.CreatedOn!.Value.Month - 1) / 3 + 1
                        })
                        .Select(g => new
                        {
                            Year = g.Key.Year,
                            Quarter = g.Key.Quarter,
                            PagesUsed = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                            MoneySpent = g.Sum(j => 
                                (j.PaperSize?.Price ?? 0) * (j.TotalPages ?? 0) * (j.Copies ?? 1)
                            ),
                            DocumentsPrinted = g.Where(j => j.DocumentId.HasValue).Select(j => j.DocumentId!.Value).Distinct().Count()
                        })
                        .ToList();

                    reportsByPeriod = new List<UserReportByPeriodDto>();
                    var currentDate = now;
                    for (int i = 0; i < 4; i++)
                    {
                        var quarterDate = currentDate.AddMonths(-3 * i);
                        var year = quarterDate.Year;
                        var quarter = (quarterDate.Month - 1) / 3 + 1;
                        
                        var report = reportsByQuarter.FirstOrDefault(r => r.Year == year && r.Quarter == quarter);
                        var quarterStartDate = new DateTime(year, (quarter - 1) * 3 + 1, 1);
                        
                        reportsByPeriod.Insert(0, new UserReportByPeriodDto
                        {
                            PeriodLabel = $"Q{quarter}/{year}",
                            Date = quarterStartDate.ToString("yyyy-MM-dd"),
                            PagesUsed = report?.PagesUsed ?? 0,
                            MoneySpent = report?.MoneySpent ?? 0,
                            DocumentsPrinted = report?.DocumentsPrinted ?? 0
                        });
                    }
                }
                else if (period.ToLower() == "year")
                {
                    // Group theo năm (5 năm gần nhất)
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.UserId == userId && 
                                   j.Status == "DONE" &&
                                   j.CreatedOn.HasValue && 
                                   j.CreatedOn.Value >= start && 
                                   j.CreatedOn.Value <= end.AddDays(1))
                        .Include(j => j.PaperSize)
                        .ToListAsync();

                    var reportsByYear = printJobsInRange
                        .GroupBy(j => j.CreatedOn!.Value.Year)
                        .Select(g => new
                        {
                            Year = g.Key,
                            PagesUsed = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                            MoneySpent = g.Sum(j => 
                                (j.PaperSize?.Price ?? 0) * (j.TotalPages ?? 0) * (j.Copies ?? 1)
                            ),
                            DocumentsPrinted = g.Where(j => j.DocumentId.HasValue).Select(j => j.DocumentId!.Value).Distinct().Count()
                        })
                        .ToList();

                    reportsByPeriod = new List<UserReportByPeriodDto>();
                    var currentYear = now.Year;
                    for (int i = 0; i < 5; i++)
                    {
                        var year = currentYear - i;
                        var report = reportsByYear.FirstOrDefault(r => r.Year == year);
                        
                        reportsByPeriod.Insert(0, new UserReportByPeriodDto
                        {
                            PeriodLabel = year.ToString(),
                            Date = DateTime.SpecifyKind(new DateTime(year, 1, 1), DateTimeKind.Unspecified).ToString("yyyy-MM-dd"),
                            PagesUsed = report?.PagesUsed ?? 0,
                            MoneySpent = report?.MoneySpent ?? 0,
                            DocumentsPrinted = report?.DocumentsPrinted ?? 0
                        });
                    }
                }
                else
                {
                    // Group theo ngày
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.UserId == userId && 
                                   j.Status == "DONE" &&
                                   j.CreatedOn.HasValue && 
                                   j.CreatedOn.Value >= start && 
                                   j.CreatedOn.Value <= end.AddDays(1))
                        .Include(j => j.PaperSize)
                        .ToListAsync();

                    var reportsByDate = printJobsInRange
                        .GroupBy(j => j.CreatedOn!.Value.Date)
                        .Select(g => new
                        {
                            Date = g.Key,
                            PagesUsed = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                            MoneySpent = g.Sum(j => 
                                (j.PaperSize?.Price ?? 0) * (j.TotalPages ?? 0) * (j.Copies ?? 1)
                            ),
                            DocumentsPrinted = g.Where(j => j.DocumentId.HasValue).Select(j => j.DocumentId!.Value).Distinct().Count()
                        })
                        .ToList();

                    reportsByPeriod = new List<UserReportByPeriodDto>();
                    
                    var dayLabels = new Dictionary<DayOfWeek, string>
                    {
                        { DayOfWeek.Monday, "T2" },
                        { DayOfWeek.Tuesday, "T3" },
                        { DayOfWeek.Wednesday, "T4" },
                        { DayOfWeek.Thursday, "T5" },
                        { DayOfWeek.Friday, "T6" },
                        { DayOfWeek.Saturday, "T7" },
                        { DayOfWeek.Sunday, "CN" }
                    };

                    for (var date = start; date <= end; date = date.AddDays(1))
                    {
                        var dateOnly = date.Date;
                        var report = reportsByDate.FirstOrDefault(r => r.Date == dateOnly);
                        var dayLabel = dayLabels.ContainsKey(date.DayOfWeek) ? dayLabels[date.DayOfWeek] : date.DayOfWeek.ToString();

                        reportsByPeriod.Add(new UserReportByPeriodDto
                        {
                            PeriodLabel = dayLabel,
                            Date = date.ToString("yyyy-MM-dd"),
                            PagesUsed = report?.PagesUsed ?? 0,
                            MoneySpent = report?.MoneySpent ?? 0,
                            DocumentsPrinted = report?.DocumentsPrinted ?? 0
                        });
                    }
                }

                var highestPagesUsed = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.PagesUsed) : 0;
                var highestMoneySpent = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.MoneySpent) : 0;
                var highestDocumentsPrinted = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.DocumentsPrinted) : 0;

                var response = new UserReportResponseDto
                {
                    ReportsByPeriod = reportsByPeriod,
                    HighestPagesUsed = highestPagesUsed,
                    HighestMoneySpent = highestMoneySpent,
                    HighestDocumentsPrinted = highestDocumentsPrinted,
                    Period = period.ToLower()
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting user report");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy báo cáo sử dụng.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách in ấn gần đây
        /// </summary>
        [HttpGet("RecentPrints")]
        public async Task<ActionResult<List<RecentPrintDto>>> GetRecentPrints([FromQuery] int limit = 10)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

                var recentPrints = await _context.PrintJobs
                    .Where(j => j.UserId == userId)
                    .Include(j => j.Document)
                    .Include(j => j.Printer)
                    .OrderByDescending(j => j.CreatedOn)
                    .Take(limit)
                    .Select(j => new RecentPrintDto
                    {
                        PrintJobId = j.PrintJobId,
                        FileName = j.Document != null ? j.Document.FileName : "Unknown",
                        Pages = j.TotalPages ?? 0,
                        Copies = j.Copies ?? 1,
                        Status = j.Status ?? "UNKNOWN",
                        CreatedOn = j.CreatedOn,
                        CompletedAt = j.CompletedAt,
                        PrinterName = j.Printer != null ? (string.IsNullOrWhiteSpace(j.Printer.Brand) && string.IsNullOrWhiteSpace(j.Printer.Model) 
                            ? j.Printer.PrinterCode 
                            : $"{j.Printer.Brand} {j.Printer.Model}".Trim()) : null,
                        PrinterLocation = j.Printer != null ? j.Printer.Location : null
                    })
                    .ToListAsync();

                return Ok(new { success = true, data = recentPrints });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting recent prints");
                return StatusCode(500, new { message = "Lỗi hệ thống khi lấy lịch sử in.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách máy in và trạng thái
        /// </summary>
        [HttpGet("Printers")]
        public async Task<ActionResult<List<PrinterStatusDto>>> GetPrinters()
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

                var printers = await _context.Printers
                    .Include(p => p.PrintJobs)
                    .Select(p => new PrinterStatusDto
                    {
                        PrinterId = p.PrinterId,
                        PrinterCode = p.PrinterCode,
                        PrinterName = string.IsNullOrWhiteSpace(p.Brand) && string.IsNullOrWhiteSpace(p.Model) 
                            ? p.PrinterCode 
                            : $"{p.Brand} {p.Model}".Trim(),
                        Location = p.Location,
                        Status = p.Status ?? "UNKNOWN",
                        QueueCount = p.PrintJobs.Count(j => j.Status == "PENDING" || j.Status == "PRINTING"),
                        PaperCapacity = p.PaperCapacity
                    })
                    .ToListAsync();

                return Ok(new { success = true, data = printers });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting printers");
                return StatusCode(500, new { message = "Lỗi hệ thống khi lấy danh sách máy in.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy 5 máy in gần đây nhất mà user đã sử dụng
        /// </summary>
        [HttpGet("RecentPrinters")]
        public async Task<ActionResult<List<PrinterStatusDto>>> GetRecentPrinters([FromQuery] int limit = 5)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

                // Lấy các máy in gần đây nhất từ lịch sử in của user
                var recentPrinterIds = await _context.PrintJobs
                    .Where(j => j.UserId == userId && j.PrinterId != null)
                    .GroupBy(j => j.PrinterId)
                    .Select(g => new { PrinterId = g.Key, LastUsed = g.Max(j => j.CreatedOn) })
                    .OrderByDescending(x => x.LastUsed)
                    .Take(limit)
                    .Select(x => x.PrinterId)
                    .ToListAsync();

                if (!recentPrinterIds.Any())
                {
                    return Ok(new { success = true, data = new List<PrinterStatusDto>() });
                }

                // Lấy thông tin chi tiết của các máy in
                var printers = await _context.Printers
                    .Where(p => recentPrinterIds.Contains(p.PrinterId))
                    .Include(p => p.PrintJobs)
                    .ToListAsync();

                // Sắp xếp theo thứ tự recentPrinterIds
                var result = recentPrinterIds
                    .Select(printerId => printers.FirstOrDefault(p => p.PrinterId == printerId))
                    .Where(p => p != null)
                    .Select(p => {
                        // Lấy print job đang in (nếu có)
                        var currentPrintJob = p!.PrintJobs
                            .Where(j => j.Status == "PRINTING")
                            .OrderByDescending(j => j.CreatedOn)
                            .FirstOrDefault();

                        return new PrinterStatusDto
                        {
                            PrinterId = p!.PrinterId,
                            PrinterCode = p.PrinterCode,
                            PrinterName = string.IsNullOrWhiteSpace(p.Brand) && string.IsNullOrWhiteSpace(p.Model) 
                                ? p.PrinterCode 
                                : $"{p.Brand} {p.Model}".Trim(),
                            Location = p.Location,
                            Status = p.Status ?? "UNKNOWN",
                            QueueCount = p.PrintJobs.Count(j => j.Status == "PENDING" || j.Status == "PRINTING"),
                            PaperCapacity = p.PaperCapacity,
                            CurrentPrintJob = currentPrintJob != null ? new CurrentPrintJobDto
                            {
                                PrintJobId = currentPrintJob.PrintJobId,
                                TotalPages = currentPrintJob.TotalPages,
                                PagesPrinted = null, // Sẽ được cập nhật từ SignalR
                                ProgressPercentage = null, // Sẽ được cập nhật từ SignalR
                                Status = currentPrintJob.Status
                            } : null
                        };
                    })
                    .ToList();

                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting recent printers");
                return StatusCode(500, new { message = "Lỗi hệ thống khi lấy danh sách máy in gần đây.", error = ex.Message });
            }
        }


        /// <summary>
        /// Lấy báo cáo máy in theo danh sách máy in được chọn (chỉ SPSO)
        /// </summary>
        [HttpPost("Admin/PrinterReport")]
        [ProducesResponseType(typeof(PrinterReportResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<PrinterReportResponseDto>> GetPrinterReport([FromBody] PrinterReportRequestDto request)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem báo cáo máy in." });
                }

                if (request == null || request.PrinterIds == null || !request.PrinterIds.Any())
                {
                    return BadRequest(new { success = false, message = "Vui lòng chọn ít nhất một máy in." });
                }

                // Lấy thông tin máy in được chọn
                var selectedPrinters = await _context.Printers
                    .Where(p => request.PrinterIds.Contains(p.PrinterId))
                    .Select(p => new PrinterDto
                    {
                        PrinterId = p.PrinterId,
                        PrinterCode = p.PrinterCode,
                        Location = p.Location,
                        Brand = p.Brand,
                        Model = p.Model,
                        Status = p.Status
                    })
                    .ToListAsync();

                // Lấy báo cáo print jobs theo máy in
                var printerReports = await _context.PrintJobs
                    .Where(pj => request.PrinterIds.Contains(pj.PrinterId ?? 0) &&
                                pj.Status == "DONE" &&
                                pj.CompletedAt.HasValue)
                    .Include(pj => pj.Printer)
                    .Include(pj => pj.Document)
                    .GroupBy(pj => pj.PrinterId)
                    .Select(g => new PrinterReportDto
                    {
                        PrinterId = g.Key ?? 0,
                        PrinterCode = g.First().Printer != null ? g.First().Printer.PrinterCode : "Unknown",
                        Location = g.First().Printer != null ? g.First().Printer.Location : "",
                        TotalJobs = g.Count(),
                        TotalPages = g.Sum(pj => pj.TotalPages ?? 0),
                        PrintedDocuments = g.Where(pj => pj.Document != null)
                                           .GroupBy(pj => pj.DocumentId)
                                           .Select(dg => new PrintedDocumentDto
                                           {
                                               DocumentId = dg.Key ?? 0,
                                               FileName = dg.First().Document != null ? dg.First().Document.FileName : "Unknown",
                                               PrintCount = dg.Sum(pj => pj.Copies ?? 1),
                                               TotalPages = dg.Sum(pj => pj.TotalPages ?? 0),
                                               LastPrinted = dg.Max(pj => pj.CompletedAt)
                                           })
                                           .OrderByDescending(d => d.TotalPages)
                                           .ToList()
                    })
                    .ToListAsync();

                var response = new PrinterReportResponseDto
                {
                    SelectedPrinters = selectedPrinters,
                    PrinterReports = printerReports,
                    TotalPrinters = printerReports.Count,
                    TotalJobs = printerReports.Sum(r => r.TotalJobs),
                    TotalPages = printerReports.Sum(r => r.TotalPages)
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting printer report");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy báo cáo máy in.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy Top 5 người dùng mua giấy nhiều nhất (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/TopPaperPurchasers")]
        [ProducesResponseType(typeof(List<TopPurchaserDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<List<TopPurchaserDto>>> GetTopPaperPurchasers([FromQuery] int top = 5)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem thống kê này." });
                }

                var topPaperPurchasers = await _context.PurchaseTransactions
                    .Where(pt => pt.TransactionType == "PAGE_PURCHASE" && pt.Status == "SUCCESS")
                    .GroupBy(pt => pt.UserId)
                    .Select(g => new
                    {
                        UserId = g.Key,
                        TotalPagesPurchased = g.Sum(pt => pt.Quantity),
                        TotalAmount = g.Sum(pt => pt.TotalAmount)
                    })
                    .OrderByDescending(x => x.TotalPagesPurchased)
                    .Take(top)
                    .ToListAsync();

                var userIds = topPaperPurchasers.Select(x => x.UserId).ToList();
                var users = await _context.Users
                    .Where(u => userIds.Contains(u.UserId))
                    .ToListAsync();

                var result = topPaperPurchasers.Select(x =>
                {
                    var user = users.FirstOrDefault(u => u.UserId == x.UserId);
                    return new TopPurchaserDto
                    {
                        UserId = x.UserId,
                        FullName = user?.FullName ?? "Unknown",
                        StudentCode = user?.StudentCode ?? "",
                        Email = user?.Email ?? "",
                        TotalQuantity = x.TotalPagesPurchased,
                        TotalAmount = x.TotalAmount
                    };
                }).ToList();

                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting top paper purchasers");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy top người mua giấy.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy Top 5 người dùng mua dung lượng nhiều nhất (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/TopStoragePurchasers")]
        [ProducesResponseType(typeof(List<TopPurchaserDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<List<TopPurchaserDto>>> GetTopStoragePurchasers([FromQuery] int top = 5)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem thống kê này." });
                }

                var topStoragePurchasers = await _context.PurchaseTransactions
                    .Where(pt => pt.TransactionType == "STORAGE_PURCHASE" && pt.Status == "SUCCESS")
                    .GroupBy(pt => pt.UserId)
                    .Select(g => new
                    {
                        UserId = g.Key,
                        TotalStoragePurchased = g.Sum(pt => pt.Quantity),
                        TotalAmount = g.Sum(pt => pt.TotalAmount)
                    })
                    .OrderByDescending(x => x.TotalStoragePurchased)
                    .Take(top)
                    .ToListAsync();

                var userIds = topStoragePurchasers.Select(x => x.UserId).ToList();
                var users = await _context.Users
                    .Where(u => userIds.Contains(u.UserId))
                    .ToListAsync();

                var result = topStoragePurchasers.Select(x =>
                {
                    var user = users.FirstOrDefault(u => u.UserId == x.UserId);
                    return new TopPurchaserDto
                    {
                        UserId = x.UserId,
                        FullName = user?.FullName ?? "Unknown",
                        StudentCode = user?.StudentCode ?? "",
                        Email = user?.Email ?? "",
                        TotalQuantity = x.TotalStoragePurchased,
                        TotalAmount = x.TotalAmount
                    };
                }).ToList();

                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting top storage purchasers");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy top người mua dung lượng.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy doanh thu theo ngày (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/RevenueByPeriod")]
        [ProducesResponseType(typeof(RevenueByPeriodResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<RevenueByPeriodResponseDto>> GetRevenueByPeriod([FromQuery] string? period = "week", [FromQuery] string? startDate = null, [FromQuery] string? endDate = null)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem thống kê này." });
                }

                DateTime start;
                DateTime end;
                var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);
                bool isCustomDateRange = !string.IsNullOrWhiteSpace(startDate) && !string.IsNullOrWhiteSpace(endDate);

                // Xử lý custom date range
                if (isCustomDateRange && DateTime.TryParse(startDate, out var parsedStart) && DateTime.TryParse(endDate, out var parsedEnd))
                {
                    start = DateTime.SpecifyKind(parsedStart.Date, DateTimeKind.Unspecified);
                    end = DateTime.SpecifyKind(parsedEnd.Date, DateTimeKind.Unspecified);
                    period = "custom";
                }
                else
                {
                    // Xử lý các period định sẵn
                    period = period ?? "week";
                    switch (period.ToLower())
                    {
                        case "week":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                            break;
                        case "month":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-29), DateTimeKind.Unspecified);
                            break;
                        case "quarter":
                            end = now;
                            start = end.AddMonths(-11);
                            start = DateTime.SpecifyKind(new DateTime(start.Year, start.Month, 1), DateTimeKind.Unspecified);
                            break;
                        case "year":
                            end = now;
                            start = DateTime.SpecifyKind(new DateTime(end.Year - 4, 1, 1), DateTimeKind.Unspecified);
                            break;
                        default:
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                            period = "week";
                            break;
                    }
                }

                List<RevenueByPeriodDto> revenueByPeriod;

                if (period.ToLower() == "quarter")
                {
                    // Group theo quý (4 quý gần nhất)
                    var revenueByQuarter = await _context.PurchaseTransactions
                        .Where(pt => pt.Status == "SUCCESS" &&
                                   pt.CreatedAt >= start &&
                                   pt.CreatedAt <= end.AddDays(1))
                        .GroupBy(pt => new {
                            Year = pt.CreatedAt.Year,
                            Quarter = (pt.CreatedAt.Month - 1) / 3 + 1
                        })
                        .Select(g => new
                        {
                            Year = g.Key.Year,
                            Quarter = g.Key.Quarter,
                            TotalRevenue = g.Sum(pt => pt.TotalAmount)
                        })
                        .ToListAsync();

                    revenueByPeriod = new List<RevenueByPeriodDto>();
                    var currentDate = now;
                    for (int i = 0; i < 4; i++)
                    {
                        var quarterDate = currentDate.AddMonths(-3 * i);
                        var year = quarterDate.Year;
                        var quarter = (quarterDate.Month - 1) / 3 + 1;

                        var revenue = revenueByQuarter.FirstOrDefault(r => r.Year == year && r.Quarter == quarter);
                        var quarterStartDate = new DateTime(year, (quarter - 1) * 3 + 1, 1);

                        revenueByPeriod.Insert(0, new RevenueByPeriodDto
                        {
                            PeriodLabel = $"Q{quarter}/{year}",
                            Date = quarterStartDate.ToString("yyyy-MM-dd"),
                            TotalRevenue = revenue?.TotalRevenue ?? 0
                        });
                    }
                }
                else if (period.ToLower() == "year")
                {
                    // Group theo năm (5 năm gần nhất)
                    var revenueByYear = await _context.PurchaseTransactions
                        .Where(pt => pt.Status == "SUCCESS" &&
                                   pt.CreatedAt >= start &&
                                   pt.CreatedAt <= end.AddDays(1))
                        .GroupBy(pt => pt.CreatedAt.Year)
                        .Select(g => new
                        {
                            Year = g.Key,
                            TotalRevenue = g.Sum(pt => pt.TotalAmount)
                        })
                        .ToListAsync();

                    revenueByPeriod = new List<RevenueByPeriodDto>();
                    var currentYear = now.Year;
                    for (int i = 0; i < 5; i++)
                    {
                        var year = currentYear - i;
                        var revenue = revenueByYear.FirstOrDefault(r => r.Year == year);

                        revenueByPeriod.Insert(0, new RevenueByPeriodDto
                        {
                            PeriodLabel = year.ToString(),
                            Date = DateTime.SpecifyKind(new DateTime(year, 1, 1), DateTimeKind.Unspecified).ToString("yyyy-MM-dd"),
                            TotalRevenue = revenue?.TotalRevenue ?? 0
                        });
                    }
                }
                else
                {
                    // Group theo ngày
                    var revenueByDate = await _context.PurchaseTransactions
                        .Where(pt => pt.Status == "SUCCESS" &&
                                   pt.CreatedAt >= start &&
                                   pt.CreatedAt <= end.AddDays(1))
                        .GroupBy(pt => pt.CreatedAt.Date)
                        .Select(g => new
                        {
                            Date = g.Key,
                            TotalRevenue = g.Sum(pt => pt.TotalAmount)
                        })
                        .ToListAsync();

                    revenueByPeriod = new List<RevenueByPeriodDto>();

                    var dayLabels = new Dictionary<DayOfWeek, string>
                    {
                        { DayOfWeek.Monday, "T2" },
                        { DayOfWeek.Tuesday, "T3" },
                        { DayOfWeek.Wednesday, "T4" },
                        { DayOfWeek.Thursday, "T5" },
                        { DayOfWeek.Friday, "T6" },
                        { DayOfWeek.Saturday, "T7" },
                        { DayOfWeek.Sunday, "CN" }
                    };

                    for (var date = start; date <= end; date = date.AddDays(1))
                    {
                        var dateOnly = date.Date;
                        var revenue = revenueByDate.FirstOrDefault(r => r.Date == dateOnly);
                        var dayLabel = dayLabels.ContainsKey(date.DayOfWeek) ? dayLabels[date.DayOfWeek] : date.DayOfWeek.ToString();

                        revenueByPeriod.Add(new RevenueByPeriodDto
                        {
                            PeriodLabel = dayLabel,
                            Date = date.ToString("yyyy-MM-dd"),
                            TotalRevenue = revenue?.TotalRevenue ?? 0
                        });
                    }
                }

                var data = await GetRevenueDataAsync(period, startDate, endDate);
                return Ok(data);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting revenue by period");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy thống kê doanh thu.", error = ex.Message });
            }
        }

        private async Task<RevenueByPeriodResponseDto> GetRevenueDataAsync(string? period, string? startDate, string? endDate)
        {
            DateTime start;
            DateTime end;
            var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);
            bool isCustomDateRange = !string.IsNullOrWhiteSpace(startDate) && !string.IsNullOrWhiteSpace(endDate);

            // Xử lý custom date range
            if (isCustomDateRange && DateTime.TryParse(startDate, out var parsedStart) && DateTime.TryParse(endDate, out var parsedEnd))
            {
                start = DateTime.SpecifyKind(parsedStart.Date, DateTimeKind.Unspecified);
                end = DateTime.SpecifyKind(parsedEnd.Date, DateTimeKind.Unspecified);
                period = "custom";
            }
            else
            {
                // Xử lý các period định sẵn
                period = period ?? "week";
                switch (period.ToLower())
                {
                    case "week":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                        break;
                    case "month":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-29), DateTimeKind.Unspecified);
                        break;
                    case "quarter":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddMonths(-3).AddDays(1), DateTimeKind.Unspecified);
                        break;
                    case "year":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddYears(-1).AddDays(1), DateTimeKind.Unspecified);
                        break;
                    default:
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                        period = "week";
                        break;
                }
            }

            List<RevenueByPeriodDto> revenueByPeriod;

            if (period.ToLower() == "quarter")
            {
                // Group theo quý (4 quý gần nhất)
                var revenueByQuarter = await _context.PurchaseTransactions
                    .Where(pt => pt.Status == "SUCCESS" &&
                               pt.CreatedAt >= start &&
                               pt.CreatedAt <= end.AddDays(1))
                    .GroupBy(pt => new {
                        Year = pt.CreatedAt.Year,
                        Quarter = (pt.CreatedAt.Month - 1) / 3 + 1
                    })
                    .Select(g => new
                    {
                        Year = g.Key.Year,
                        Quarter = g.Key.Quarter,
                        TotalRevenue = g.Sum(pt => pt.TotalAmount)
                    })
                    .ToListAsync();

                revenueByPeriod = new List<RevenueByPeriodDto>();
                var currentDate = now;
                for (int i = 0; i < 4; i++)
                {
                    var quarterDate = currentDate.AddMonths(-3 * i);
                    var year = quarterDate.Year;
                    var quarter = (quarterDate.Month - 1) / 3 + 1;

                    var revenue = revenueByQuarter.FirstOrDefault(r => r.Year == year && r.Quarter == quarter);
                    var quarterStartDate = new DateTime(year, (quarter - 1) * 3 + 1, 1);

                    revenueByPeriod.Insert(0, new RevenueByPeriodDto
                    {
                        PeriodLabel = $"Q{quarter}/{year}",
                        Date = quarterStartDate.ToString("yyyy-MM-dd"),
                        TotalRevenue = revenue?.TotalRevenue ?? 0
                    });
                }
            }
            else if (period.ToLower() == "year")
            {
                // Group theo năm (5 năm gần nhất)
                var revenueByYear = await _context.PurchaseTransactions
                    .Where(pt => pt.Status == "SUCCESS" &&
                               pt.CreatedAt >= start &&
                               pt.CreatedAt <= end.AddDays(1))
                    .GroupBy(pt => pt.CreatedAt.Year)
                    .Select(g => new
                    {
                        Year = g.Key,
                        TotalRevenue = g.Sum(pt => pt.TotalAmount)
                    })
                    .ToListAsync();

                revenueByPeriod = new List<RevenueByPeriodDto>();
                var currentYear = now.Year;
                for (int i = 0; i < 5; i++)
                {
                    var year = currentYear - i;
                    var revenue = revenueByYear.FirstOrDefault(r => r.Year == year);

                    revenueByPeriod.Insert(0, new RevenueByPeriodDto
                    {
                        PeriodLabel = year.ToString(),
                        Date = DateTime.SpecifyKind(new DateTime(year, 1, 1), DateTimeKind.Unspecified).ToString("yyyy-MM-dd"),
                        TotalRevenue = revenue?.TotalRevenue ?? 0
                    });
                }
            }
            else
            {
                // Group theo ngày
                var revenueByDate = await _context.PurchaseTransactions
                    .Where(pt => pt.Status == "SUCCESS" &&
                               pt.CreatedAt >= start &&
                               pt.CreatedAt <= end.AddDays(1))
                    .GroupBy(pt => pt.CreatedAt.Date)
                    .Select(g => new
                    {
                        Date = g.Key,
                        TotalRevenue = g.Sum(pt => pt.TotalAmount)
                    })
                    .ToListAsync();

                revenueByPeriod = new List<RevenueByPeriodDto>();

                var dayLabels = new Dictionary<DayOfWeek, string>
                {
                    { DayOfWeek.Monday, "T2" },
                    { DayOfWeek.Tuesday, "T3" },
                    { DayOfWeek.Wednesday, "T4" },
                    { DayOfWeek.Thursday, "T5" },
                    { DayOfWeek.Friday, "T6" },
                    { DayOfWeek.Saturday, "T7" },
                    { DayOfWeek.Sunday, "CN" }
                };

                foreach (var revenue in revenueByDate.OrderBy(r => r.Date))
                {
                    revenueByPeriod.Add(new RevenueByPeriodDto
                    {
                        PeriodLabel = dayLabels.ContainsKey(revenue.Date.DayOfWeek)
                            ? dayLabels[revenue.Date.DayOfWeek]
                            : revenue.Date.ToString("dd/MM"),
                        Date = revenue.Date.ToString("yyyy-MM-dd"),
                        TotalRevenue = revenue.TotalRevenue
                    });
                }
            }

            var highestRevenue = revenueByPeriod.Any() ? revenueByPeriod.Max(r => r.TotalRevenue) : 0;
            var totalRevenue = revenueByPeriod.Sum(r => r.TotalRevenue);
            var totalPaperRevenue = await _context.PurchaseTransactions
                .Where(pt => pt.Status == "SUCCESS" &&
                           pt.CreatedAt >= start &&
                           pt.CreatedAt <= end.AddDays(1) &&
                           pt.TransactionType == "PAGE_PURCHASE")
                .SumAsync(pt => pt.TotalAmount);
            var totalStorageRevenue = await _context.PurchaseTransactions
                .Where(pt => pt.Status == "SUCCESS" &&
                           pt.CreatedAt >= start &&
                           pt.CreatedAt <= end.AddDays(1) &&
                           pt.TransactionType == "STORAGE_PURCHASE")
                .SumAsync(pt => pt.TotalAmount);

            var response = new RevenueByPeriodResponseDto
            {
                ReportsByPeriod = revenueByPeriod,
                HighestRevenue = highestRevenue,
                HighestPaperRevenue = totalPaperRevenue,
                HighestStorageRevenue = totalStorageRevenue,
                Period = period.ToLower(),
                TotalRevenue = totalRevenue,
                TotalPaperRevenue = totalPaperRevenue,
                TotalStorageRevenue = totalStorageRevenue
            };

            return response;
        }

        /// <summary>
        /// Lấy số đơn in theo ngày (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/PrintOrdersByDay")]
        [ProducesResponseType(typeof(PrintOrdersByDayResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<PrintOrdersByDayResponseDto>> GetPrintOrdersByDay([FromQuery] string period = "week")
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem thống kê này." });
                }

                DateTime startDate;
                DateTime endDate;

                // Sử dụng DateTime với DateTimeKind.Unspecified để khớp với database (timestamp without time zone)
                var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);
                
                // Đảm bảo startDate và endDate cũng có DateTimeKind.Unspecified

                switch (period.ToLower())
                {
                    case "week":
                        // Tuần: 7 ngày gần nhất
                        endDate = now;
                        startDate = DateTime.SpecifyKind(endDate.AddDays(-6), DateTimeKind.Unspecified);
                        break;
                    case "month":
                        // Tháng: 30 ngày gần nhất
                        endDate = now;
                        startDate = DateTime.SpecifyKind(endDate.AddDays(-29), DateTimeKind.Unspecified);
                        break;
                    case "quarter":
                        // Quý: 4 quý gần nhất (mỗi quý = 3 tháng)
                        endDate = now;
                        startDate = endDate.AddMonths(-11); // 4 quý = 12 tháng = 4 * 3 tháng
                        startDate = DateTime.SpecifyKind(new DateTime(startDate.Year, startDate.Month, 1), DateTimeKind.Unspecified);
                        break;
                    case "year":
                        // Năm: 5 năm gần nhất
                        endDate = now;
                        startDate = DateTime.SpecifyKind(new DateTime(endDate.Year - 4, 1, 1), DateTimeKind.Unspecified); // 5 năm gần nhất
                        break;
                    default:
                        endDate = now;
                        startDate = DateTime.SpecifyKind(endDate.AddDays(-6), DateTimeKind.Unspecified);
                        break;
                }

                List<PrintOrdersByDayDto> ordersByDay;

                if (period.ToLower() == "quarter")
                {
                    // Group theo quý (4 quý gần nhất)
                    // First, filter and select only CreatedOn to minimize data transfer
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.CreatedOn.HasValue && 
                                   j.CreatedOn.Value >= startDate && 
                                   j.CreatedOn.Value <= endDate.AddDays(1))
                        .Select(j => j.CreatedOn!.Value)
                        .ToListAsync();

                    var ordersByQuarter = printJobsInRange
                        .GroupBy(date => new { 
                            Year = date.Year, 
                            Quarter = (date.Month - 1) / 3 + 1
                        })
                        .Select(g => new
                        {
                            Year = g.Key.Year,
                            Quarter = g.Key.Quarter,
                            Count = g.Count()
                        })
                        .OrderBy(x => x.Year)
                        .ThenBy(x => x.Quarter)
                        .ToList();

                    // Tạo danh sách đầy đủ 4 quý gần nhất
                    ordersByDay = new List<PrintOrdersByDayDto>();
                    var currentDate = now;
                    for (int i = 0; i < 4; i++)
                    {
                        var quarterDate = currentDate.AddMonths(-3 * i);
                        var year = quarterDate.Year;
                        var quarter = (quarterDate.Month - 1) / 3 + 1;
                        
                        var order = ordersByQuarter.FirstOrDefault(o => o.Year == year && o.Quarter == quarter);
                        var quarterStartDate = new DateTime(year, (quarter - 1) * 3 + 1, 1);
                        
                        ordersByDay.Insert(0, new PrintOrdersByDayDto
                        {
                            DayLabel = $"Q{quarter}/{year}",
                            Date = quarterStartDate.ToString("yyyy-MM-dd"),
                            OrderCount = order?.Count ?? 0
                        });
                    }
                }
                else if (period.ToLower() == "year")
                {
                    // Group theo năm (5 năm gần nhất)
                    // First, filter and select only CreatedOn to minimize data transfer
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.CreatedOn.HasValue && 
                                   j.CreatedOn.Value >= startDate && 
                                   j.CreatedOn.Value <= endDate.AddDays(1))
                        .Select(j => j.CreatedOn!.Value)
                        .ToListAsync();

                    var ordersByYear = printJobsInRange
                        .GroupBy(date => date.Year)
                        .Select(g => new
                        {
                            Year = g.Key,
                            Count = g.Count()
                        })
                        .OrderBy(x => x.Year)
                        .ToList();

                    // Tạo danh sách đầy đủ 5 năm gần nhất
                    ordersByDay = new List<PrintOrdersByDayDto>();
                    var currentYear = now.Year;
                    for (int i = 0; i < 5; i++)
                    {
                        var year = currentYear - i;
                        var order = ordersByYear.FirstOrDefault(o => o.Year == year);
                        
                        ordersByDay.Insert(0, new PrintOrdersByDayDto
                        {
                            DayLabel = year.ToString(),
                            Date = DateTime.SpecifyKind(new DateTime(year, 1, 1), DateTimeKind.Unspecified).ToString("yyyy-MM-dd"),
                            OrderCount = order?.Count ?? 0
                        });
                    }
                }
                else
                {
                    // Group theo ngày
                    // First, filter and select only CreatedOn to minimize data transfer
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.CreatedOn.HasValue && 
                                   j.CreatedOn.Value >= startDate && 
                                   j.CreatedOn.Value <= endDate.AddDays(1))
                        .Select(j => j.CreatedOn!.Value)
                        .ToListAsync();

                    var orders = printJobsInRange
                        .GroupBy(date => date.Date)
                        .Select(g => new
                        {
                            Date = g.Key,
                            Count = g.Count()
                        })
                        .OrderBy(x => x.Date)
                        .ToList();

                    // Tạo danh sách đầy đủ các ngày (bao gồm cả ngày không có đơn)
                    ordersByDay = new List<PrintOrdersByDayDto>();
                    
                    // Map day of week sang T2, T3, T4, T5, T6, T7, CN
                    var dayLabels = new Dictionary<DayOfWeek, string>
                    {
                        { DayOfWeek.Monday, "T2" },
                        { DayOfWeek.Tuesday, "T3" },
                        { DayOfWeek.Wednesday, "T4" },
                        { DayOfWeek.Thursday, "T5" },
                        { DayOfWeek.Friday, "T6" },
                        { DayOfWeek.Saturday, "T7" },
                        { DayOfWeek.Sunday, "CN" }
                    };

                    for (var date = startDate; date <= endDate; date = date.AddDays(1))
                    {
                        var dateOnly = date.Date;
                        var order = orders.FirstOrDefault(o => o.Date == dateOnly);
                        var dayLabel = dayLabels.ContainsKey(date.DayOfWeek) ? dayLabels[date.DayOfWeek] : date.DayOfWeek.ToString();

                        ordersByDay.Add(new PrintOrdersByDayDto
                        {
                            DayLabel = dayLabel,
                            Date = date.ToString("yyyy-MM-dd"),
                            OrderCount = order?.Count ?? 0
                        });
                    }
                }

                var highestOrderCount = ordersByDay.Any() ? ordersByDay.Max(o => o.OrderCount) : 0;

                var response = new PrintOrdersByDayResponseDto
                {
                    OrdersByDay = ordersByDay,
                    HighestOrderCount = highestOrderCount,
                    Period = period.ToLower()
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting print orders by day. Period: {Period}, Exception: {ExceptionType}, Message: {Message}, StackTrace: {StackTrace}", 
                    period, ex.GetType().Name, ex.Message, ex.StackTrace);
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy thống kê số đơn in theo ngày.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy Top 5 người dùng in nhiều nhất (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/TopUsers")]
        [ProducesResponseType(typeof(List<TopUserDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<List<TopUserDto>>> GetTopUsers([FromQuery] int top = 5)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem thống kê này." });
                }

                var topUsers = await _context.PrintJobs
                    .Where(j => j.UserId.HasValue && j.Status == "DONE")
                    .GroupBy(j => j.UserId)
                    .Select(g => new
                    {
                        UserId = g.Key!.Value,
                        TotalPages = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                        OrderCount = g.Count()
                    })
                    .OrderByDescending(x => x.TotalPages)
                    .Take(top)
                    .ToListAsync();

                var userIds = topUsers.Select(x => x.UserId).ToList();
                var users = await _context.Users
                    .Where(u => userIds.Contains(u.UserId))
                    .ToListAsync();

                var result = topUsers.Select(x =>
                {
                    var user = users.FirstOrDefault(u => u.UserId == x.UserId);
                    return new TopUserDto
                    {
                        UserId = x.UserId,
                        FullName = user?.FullName ?? "Unknown",
                        StudentCode = user?.StudentCode ?? "",
                        Email = user?.Email ?? "",
                        TotalPages = x.TotalPages,
                        OrderCount = x.OrderCount
                    };
                }).ToList();

                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting top users");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy top người dùng.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy Top 5 máy in sử dụng nhiều nhất (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/TopPrinters")]
        [ProducesResponseType(typeof(List<TopPrinterDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<List<TopPrinterDto>>> GetTopPrinters([FromQuery] int top = 5)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem thống kê này." });
                }

                var topPrinters = await _context.PrintJobs
                    .Where(j => j.PrinterId.HasValue && j.Status == "DONE")
                    .GroupBy(j => j.PrinterId)
                    .Select(g => new
                    {
                        PrinterId = g.Key!.Value,
                        OrderCount = g.Count()
                    })
                    .OrderByDescending(x => x.OrderCount)
                    .Take(top)
                    .ToListAsync();

                var printerIds = topPrinters.Select(x => x.PrinterId).ToList();
                var printers = await _context.Printers
                    .Where(p => printerIds.Contains(p.PrinterId))
                    .ToListAsync();

                var result = topPrinters.Select(x =>
                {
                    var printer = printers.FirstOrDefault(p => p.PrinterId == x.PrinterId);
                    return new TopPrinterDto
                    {
                        PrinterId = x.PrinterId,
                        PrinterCode = printer?.PrinterCode ?? "Unknown",
                        PrinterName = printer != null ? (string.IsNullOrWhiteSpace(printer.Brand) && string.IsNullOrWhiteSpace(printer.Model) 
                            ? printer.PrinterCode 
                            : $"{printer.Brand} {printer.Model}".Trim()) : "Unknown",
                        Location = printer?.Location,
                        Brand = printer?.Brand,
                        Model = printer?.Model,
                        OrderCount = x.OrderCount
                    };
                }).ToList();

                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting top printers");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy top máy in.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy tổng quan thống kê cho admin dashboard (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/SummaryStats")]
        [ProducesResponseType(typeof(AdminSummaryStatsDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<AdminSummaryStatsDto>> GetSummaryStats()
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem thống kê này." });
                }

                var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);
                var todayStart = now;
                var todayEnd = now.AddDays(1);

                // Tuần này: 7 ngày gần nhất (từ 7 ngày trước đến hôm nay)
                var thisWeekStart = DateTime.SpecifyKind(now.AddDays(-6), DateTimeKind.Unspecified);
                var thisWeekEnd = now.AddDays(1);

                // Tuần trước: 7 ngày trước đó (từ 14 ngày trước đến 7 ngày trước)
                var lastWeekStart = DateTime.SpecifyKind(now.AddDays(-13), DateTimeKind.Unspecified);
                var lastWeekEnd = DateTime.SpecifyKind(now.AddDays(-6), DateTimeKind.Unspecified);

                // Cùng ngày tuần trước (1 tuần trước)
                var sameDayLastWeekStart = DateTime.SpecifyKind(now.AddDays(-7), DateTimeKind.Unspecified);
                var sameDayLastWeekEnd = DateTime.SpecifyKind(now.AddDays(-6), DateTimeKind.Unspecified);

                // 1. Tổng số người dùng
                var totalUsersNow = await _context.Users.CountAsync();
                var totalUsersLastWeek = await _context.Users
                    .Where(u => u.CreatedOn.HasValue && u.CreatedOn.Value < lastWeekEnd)
                    .CountAsync();
                
                var usersChangePercent = totalUsersLastWeek > 0 
                    ? Math.Round(((double)(totalUsersNow - totalUsersLastWeek) / totalUsersLastWeek) * 100, 1)
                    : 0;

                // 2. Máy in hoạt động
                var totalPrinters = await _context.Printers.CountAsync();
                // Count active printers as those explicitly in AVAILABLE state
                var activePrintersNow = await _context.Printers
                    .Where(p => (p.Status != null && p.Status.ToUpper() == "AVAILABLE"))
                    .CountAsync();
                // For last week snapshot we currently reuse same query (could be improved later)
                var activePrintersLastWeek = await _context.Printers
                    .Where(p => (p.Status != null && p.Status.ToUpper() == "AVAILABLE"))
                    .CountAsync();

                var printersPercentage = totalPrinters > 0
                    ? Math.Round((double)activePrintersNow / totalPrinters * 100, 1)
                    : 0;
                var printersChangePercent = activePrintersLastWeek > 0
                    ? Math.Round(((double)(activePrintersNow - activePrintersLastWeek) / activePrintersLastWeek) * 100, 1)
                    : 0;

                // 3. Đơn in hôm nay
                var ordersToday = await _context.PrintJobs
                    .Where(j => j.CreatedOn.HasValue && 
                                j.CreatedOn.Value >= todayStart && 
                                j.CreatedOn.Value < todayEnd)
                    .CountAsync();

                var ordersSameDayLastWeek = await _context.PrintJobs
                    .Where(j => j.CreatedOn.HasValue && 
                                j.CreatedOn.Value >= sameDayLastWeekStart && 
                                j.CreatedOn.Value < sameDayLastWeekEnd)
                    .CountAsync();

                var ordersChangePercent = ordersSameDayLastWeek > 0
                    ? Math.Round(((double)(ordersToday - ordersSameDayLastWeek) / ordersSameDayLastWeek) * 100, 1)
                    : (ordersToday > 0 ? 100 : 0);

                // 4. Tổng trang in tuần này
                var totalPagesThisWeek = await _context.PrintJobs
                    .Where(j => j.CreatedOn.HasValue && 
                                j.CreatedOn.Value >= thisWeekStart && 
                                j.CreatedOn.Value < thisWeekEnd &&
                                j.Status == "DONE")
                    .SumAsync(j => (j.TotalPages ?? 0) * (j.Copies ?? 1));

                var totalPagesLastWeek = await _context.PrintJobs
                    .Where(j => j.CreatedOn.HasValue && 
                                j.CreatedOn.Value >= lastWeekStart && 
                                j.CreatedOn.Value < lastWeekEnd &&
                                j.Status == "DONE")
                    .SumAsync(j => (j.TotalPages ?? 0) * (j.Copies ?? 1));

                var pagesChangePercent = totalPagesLastWeek > 0
                    ? Math.Round(((double)(totalPagesThisWeek - totalPagesLastWeek) / totalPagesLastWeek) * 100, 1)
                    : (totalPagesThisWeek > 0 ? 100 : 0);

                var response = new AdminSummaryStatsDto
                {
                    TotalUsers = new StatWithChangeDto
                    {
                        Value = totalUsersNow,
                        ChangePercent = usersChangePercent,
                        IsIncrease = usersChangePercent >= 0
                    },
                    ActivePrinters = new ActivePrintersStatDto
                    {
                        Active = activePrintersNow,
                        Total = totalPrinters,
                        Percentage = printersPercentage,
                        ChangePercent = printersChangePercent,
                        IsIncrease = printersChangePercent >= 0
                    },
                    PrintOrdersToday = new StatWithChangeDto
                    {
                        Value = ordersToday,
                        ChangePercent = ordersChangePercent,
                        IsIncrease = ordersChangePercent >= 0
                    },
                    TotalPagesThisWeek = new StatWithChangeDto
                    {
                        Value = (int)totalPagesThisWeek,
                        ChangePercent = pagesChangePercent,
                        IsIncrease = pagesChangePercent >= 0
                    }
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting summary stats");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy thống kê tổng quan.", error = ex.Message });
            }
        }

        /// <summary>
        /// Xuất báo cáo thống kê (chỉ SPSO)
        /// </summary>
        [HttpGet("Admin/ExportReport")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> ExportReport(
            [FromQuery] string reportType = "orders", 
            [FromQuery] string? period = null,
            [FromQuery] string? startDate = null,
            [FromQuery] string? endDate = null,
            [FromQuery] int top = 5, 
            [FromQuery] string format = "excel",
            [FromQuery] int[]? printerIds = null)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập trước." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xuất báo cáo này." });
                }

                // Validate date range nếu có
                DateTime? start = null;
                DateTime? end = null;
                
                if (!string.IsNullOrWhiteSpace(startDate) && !string.IsNullOrWhiteSpace(endDate))
                {
                    if (!DateTime.TryParse(startDate, out var parsedStart))
                    {
                        return BadRequest(new { success = false, message = "startDate không hợp lệ. Format: yyyy-MM-dd" });
                    }
                    if (!DateTime.TryParse(endDate, out var parsedEnd))
                    {
                        return BadRequest(new { success = false, message = "endDate không hợp lệ. Format: yyyy-MM-dd" });
                    }
                    
                    start = DateTime.SpecifyKind(parsedStart.Date, DateTimeKind.Unspecified);
                    end = DateTime.SpecifyKind(parsedEnd.Date, DateTimeKind.Unspecified);
                    
                    if (start > end)
                    {
                        return BadRequest(new { success = false, message = "startDate phải nhỏ hơn hoặc bằng endDate" });
                    }
                    
                    // Validate date range không quá lớn (tối đa 5 năm)
                    if ((end.Value - start.Value).TotalDays > 1825)
                    {
                        return BadRequest(new { success = false, message = "Khoảng thời gian không được vượt quá 5 năm" });
                    }
                }
                else if (string.IsNullOrWhiteSpace(period))
                {
                    // Nếu không có cả period và date range, dùng default
                    period = "week";
                }

                byte[] fileBytes;
                string fileName;
                string contentType;

                switch (reportType.ToLower())
                {
                    case "orders":
                        (fileBytes, fileName) = await ExportOrdersByDayReport(period, start, end, format);
                        contentType = format.ToLower() switch
                        {
                            "csv" => "text/csv; charset=utf-8",
                            "json" => "application/json; charset=utf-8",
                            "pdf" => "application/pdf",
                            _ => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                        };
                        break;
                    case "revenue":
                        (fileBytes, fileName) = await ExportRevenueReport(period, start, end, format);
                        contentType = format.ToLower() switch
                        {
                            "csv" => "text/csv; charset=utf-8",
                            "json" => "application/json; charset=utf-8",
                            "pdf" => "application/pdf",
                            _ => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                        };
                        break;
                    case "transactions":
                        (fileBytes, fileName) = await ExportTransactionsReport(period, start, end, format);
                        contentType = format.ToLower() switch
                        {
                            "csv" => "text/csv; charset=utf-8",
                            "json" => "application/json; charset=utf-8",
                            "pdf" => "application/pdf",
                            _ => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                        };
                        break;
                    case "topusers":
                        (fileBytes, fileName) = await ExportTopUsersReport(start, end, top, format);
                        contentType = format.ToLower() switch
                        {
                            "csv" => "text/csv; charset=utf-8",
                            "json" => "application/json; charset=utf-8",
                            "pdf" => "application/pdf",
                            _ => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                        };
                        break;
                    case "topprinters":
                        if (printerIds == null || printerIds.Length == 0)
                        {
                            return BadRequest(new { success = false, message = "Vui lòng chọn ít nhất một máy in để xuất báo cáo." });
                        }
                        (fileBytes, fileName) = await ExportPrinterReport(period, start, end, printerIds, format);
                        contentType = format.ToLower() switch
                        {
                            "csv" => "text/csv; charset=utf-8",
                            "json" => "application/json; charset=utf-8",
                            "pdf" => "application/pdf",
                            _ => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                        };
                        break;
                    default:
                        return BadRequest(new { success = false, message = "Loại báo cáo không hợp lệ. Các loại hợp lệ: orders, revenue, topusers, topprinters" });
                }

                // Nếu format là JSON, trả về JSON response thay vì file download
                if (format.ToLower() == "json")
                {
                    var jsonString = Encoding.UTF8.GetString(fileBytes);
                    return Content(jsonString, contentType, Encoding.UTF8);
                }

                return File(fileBytes, contentType, fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting report. ReportType: {ReportType}, Period: {Period}, StartDate: {StartDate}, EndDate: {EndDate}, Format: {Format}", 
                    reportType, period, startDate, endDate, format);
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi xuất báo cáo.", error = ex.Message });
            }
        }

        private async Task<(byte[] fileBytes, string fileName)> ExportOrdersByDayReport(string? period, DateTime? customStartDate, DateTime? customEndDate, string format)
        {
            DateTime startDate;
            DateTime endDate;
            var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);
            bool isCustomDateRange = customStartDate.HasValue && customEndDate.HasValue;

            // Nếu có custom date range, dùng chúng
            if (isCustomDateRange && customStartDate.HasValue && customEndDate.HasValue)
            {
                startDate = customStartDate.Value;
                endDate = customEndDate.Value;
            }
            else
            {
                // Nếu không, dùng period (logic hiện tại)
                period = period ?? "week";
                switch (period.ToLower())
                {
                    case "week":
                        endDate = now;
                        startDate = DateTime.SpecifyKind(endDate.AddDays(-6), DateTimeKind.Unspecified);
                        break;
                    case "month":
                        endDate = now;
                        startDate = DateTime.SpecifyKind(endDate.AddDays(-29), DateTimeKind.Unspecified);
                        break;
                    case "quarter":
                        endDate = now;
                        startDate = endDate.AddMonths(-11);
                        startDate = DateTime.SpecifyKind(new DateTime(startDate.Year, startDate.Month, 1), DateTimeKind.Unspecified);
                        break;
                    case "year":
                        endDate = now;
                        startDate = DateTime.SpecifyKind(new DateTime(endDate.Year - 4, 1, 1), DateTimeKind.Unspecified);
                        break;
                    default:
                        endDate = now;
                        startDate = DateTime.SpecifyKind(endDate.AddDays(-6), DateTimeKind.Unspecified);
                        break;
                }
            }

            List<PrintOrdersByDayDto> ordersByDay;

            // Chỉ dùng quarter logic khi period là "quarter" và không có custom date range
            if (!isCustomDateRange && period != null && period.ToLower() == "quarter")
            {
                var printJobsInRange = await _context.PrintJobs
                    .Where(j => j.CreatedOn.HasValue && 
                               j.CreatedOn.Value >= startDate && 
                               j.CreatedOn.Value <= endDate.AddDays(1))
                    .Select(j => j.CreatedOn!.Value)
                    .ToListAsync();

                var ordersByQuarter = printJobsInRange
                    .GroupBy(date => new { 
                        Year = date.Year, 
                        Quarter = (date.Month - 1) / 3 + 1
                    })
                    .Select(g => new
                    {
                        Year = g.Key.Year,
                        Quarter = g.Key.Quarter,
                        Count = g.Count()
                    })
                    .OrderBy(x => x.Year)
                    .ThenBy(x => x.Quarter)
                    .ToList();

                ordersByDay = new List<PrintOrdersByDayDto>();
                var currentDate = now;
                for (int i = 0; i < 4; i++)
                {
                    var quarterDate = currentDate.AddMonths(-3 * i);
                    var year = quarterDate.Year;
                    var quarter = (quarterDate.Month - 1) / 3 + 1;
                    
                    var order = ordersByQuarter.FirstOrDefault(o => o.Year == year && o.Quarter == quarter);
                    var quarterStartDate = new DateTime(year, (quarter - 1) * 3 + 1, 1);
                    
                    ordersByDay.Insert(0, new PrintOrdersByDayDto
                    {
                        DayLabel = $"Q{quarter}/{year}",
                        Date = quarterStartDate.ToString("yyyy-MM-dd"),
                        OrderCount = order?.Count ?? 0
                    });
                }
            }
            // Chỉ dùng year logic khi period là "year" và không có custom date range
            else if (!isCustomDateRange && period != null && period.ToLower() == "year")
            {
                var printJobsInRange = await _context.PrintJobs
                    .Where(j => j.CreatedOn.HasValue && 
                               j.CreatedOn.Value >= startDate && 
                               j.CreatedOn.Value <= endDate.AddDays(1))
                    .Select(j => j.CreatedOn!.Value)
                    .ToListAsync();

                var ordersByYear = printJobsInRange
                    .GroupBy(date => date.Year)
                    .Select(g => new
                    {
                        Year = g.Key,
                        Count = g.Count()
                    })
                    .OrderBy(x => x.Year)
                    .ToList();

                ordersByDay = new List<PrintOrdersByDayDto>();
                var currentYear = now.Year;
                for (int i = 0; i < 5; i++)
                {
                    var year = currentYear - i;
                    var order = ordersByYear.FirstOrDefault(o => o.Year == year);
                    
                    ordersByDay.Insert(0, new PrintOrdersByDayDto
                    {
                        DayLabel = year.ToString(),
                        Date = new DateTime(year, 1, 1).ToString("yyyy-MM-dd"),
                        OrderCount = order?.Count ?? 0
                    });
                }
            }
            else
            {
                var printJobsInRange = await _context.PrintJobs
                    .Where(j => j.CreatedOn.HasValue && 
                               j.CreatedOn.Value >= startDate && 
                               j.CreatedOn.Value <= endDate.AddDays(1))
                    .Select(j => j.CreatedOn!.Value)
                    .ToListAsync();

                var orders = printJobsInRange
                    .GroupBy(date => date.Date)
                    .Select(g => new
                    {
                        Date = g.Key,
                        Count = g.Count()
                    })
                    .OrderBy(x => x.Date)
                    .ToList();

                ordersByDay = new List<PrintOrdersByDayDto>();
                var dayLabels = new Dictionary<DayOfWeek, string>
                {
                    { DayOfWeek.Monday, "T2" },
                    { DayOfWeek.Tuesday, "T3" },
                    { DayOfWeek.Wednesday, "T4" },
                    { DayOfWeek.Thursday, "T5" },
                    { DayOfWeek.Friday, "T6" },
                    { DayOfWeek.Saturday, "T7" },
                    { DayOfWeek.Sunday, "CN" }
                };

                for (var date = startDate; date <= endDate; date = date.AddDays(1))
                {
                    var order = orders.FirstOrDefault(o => o.Date == date);
                    var dayLabel = dayLabels.ContainsKey(date.DayOfWeek) ? dayLabels[date.DayOfWeek] : date.DayOfWeek.ToString();

                    ordersByDay.Add(new PrintOrdersByDayDto
                    {
                        DayLabel = dayLabel,
                        Date = date.ToString("yyyy-MM-dd"),
                        OrderCount = order?.Count ?? 0
                    });
                }
            }

            var periodLabel = isCustomDateRange 
                ? $"{startDate:dd/MM/yyyy} - {endDate:dd/MM/yyyy}"
                : (period?.ToLower() switch
                {
                    "week" => "7 ngày",
                    "month" => "30 ngày",
                    "quarter" => "4 quý",
                    "year" => "5 năm",
                    _ => "7 ngày"
                }) ?? "7 ngày";

            var fileName = $"BaoCao_DonInTheoNgay_{periodLabel?.Replace(" ", "_").Replace("/", "").Replace("-", "_")}_{DateTime.Now:yyyyMMdd_HHmmss}";

            if (format.ToLower() == "json")
            {
                var response = new PrintOrdersByDayResponseDto
                {
                    OrdersByDay = ordersByDay,
                    HighestOrderCount = ordersByDay.Any() ? ordersByDay.Max(o => o.OrderCount) : 0,
                    Period = periodLabel ?? "custom"
                };
                var jsonOptions = new JsonSerializerOptions 
                { 
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    WriteIndented = true
                };
                var json = JsonSerializer.Serialize(new { success = true, data = response }, jsonOptions);
                return (Encoding.UTF8.GetBytes(json), $"{fileName}.json");
            }
            else if (format.ToLower() == "csv")
            {
                var csv = GenerateOrdersByDayCsv(ordersByDay, periodLabel ?? "custom");
                var csvBytes = new List<byte>(Encoding.UTF8.GetPreamble());
                csvBytes.AddRange(Encoding.UTF8.GetBytes(csv));
                return (csvBytes.ToArray(), $"{fileName}.csv");
            }
            else if (format.ToLower() == "pdf")
            {
                var pdf = GenerateOrdersByDayPdf(ordersByDay, periodLabel ?? "custom");
                return (pdf, $"{fileName}.pdf");
            }
            else
            {
                var excel = GenerateOrdersByDayExcel(ordersByDay, periodLabel ?? "custom");
                return (excel, $"{fileName}.xlsx");
            }
        }

        private async Task<(byte[] fileBytes, string fileName)> ExportTopUsersReport(DateTime? startDate, DateTime? endDate, int top, string format)
        {
            var query = _context.PrintJobs.Where(j => j.UserId.HasValue && j.Status == "DONE");
            
            // Filter theo date range nếu có
            if (startDate.HasValue && endDate.HasValue)
            {
                query = query.Where(j => j.CreatedOn.HasValue && 
                                          j.CreatedOn.Value >= startDate.Value && 
                                          j.CreatedOn.Value < endDate.Value.AddDays(1));
            }

            var topUsers = await query
                .GroupBy(j => j.UserId)
                .Select(g => new
                {
                    UserId = g.Key!.Value,
                    TotalPages = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                    OrderCount = g.Count()
                })
                .OrderByDescending(x => x.TotalPages)
                .Take(top)
                .ToListAsync();

            var userIds = topUsers.Select(x => x.UserId).ToList();
            var users = await _context.Users
                .Where(u => userIds.Contains(u.UserId))
                .ToListAsync();

            var result = topUsers.Select(x =>
            {
                var user = users.FirstOrDefault(u => u.UserId == x.UserId);
                return new TopUserDto
                {
                    UserId = x.UserId,
                    FullName = user?.FullName ?? "Unknown",
                    StudentCode = user?.StudentCode ?? "",
                    Email = user?.Email ?? "",
                    TotalPages = x.TotalPages,
                    OrderCount = x.OrderCount
                };
            }).ToList();

            var dateRangeLabel = startDate.HasValue && endDate.HasValue 
                ? $"{startDate.Value:yyyyMMdd}_{endDate.Value:yyyyMMdd}"
                : "all";
            var fileName = $"BaoCao_Top{top}NguoiDung_{dateRangeLabel}_{DateTime.Now:yyyyMMdd_HHmmss}";

            if (format.ToLower() == "json")
            {
                var jsonOptions = new JsonSerializerOptions 
                { 
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    WriteIndented = true
                };
                var json = JsonSerializer.Serialize(new { success = true, data = result }, jsonOptions);
                return (Encoding.UTF8.GetBytes(json), $"{fileName}.json");
            }
            else if (format.ToLower() == "csv")
            {
                var csv = GenerateTopUsersCsv(result);
                var csvBytes = new List<byte>(Encoding.UTF8.GetPreamble());
                csvBytes.AddRange(Encoding.UTF8.GetBytes(csv));
                return (csvBytes.ToArray(), $"{fileName}.csv");
            }
            else if (format.ToLower() == "pdf")
            {
                var pdf = GenerateTopUsersPdf(result);
                return (pdf, $"{fileName}.pdf");
            }
            else
            {
                var excel = GenerateTopUsersExcel(result);
                return (excel, $"{fileName}.xlsx");
            }
        }

        private async Task<(byte[] fileBytes, string fileName)> ExportRevenueReport(string? period, DateTime? customStartDate, DateTime? customEndDate, string format)
        {
            // Xử lý period và date range
            DateTime start;
            DateTime end;
            var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);

            if (customStartDate.HasValue && customEndDate.HasValue)
            {
                start = DateTime.SpecifyKind(customStartDate.Value.Date, DateTimeKind.Unspecified);
                end = DateTime.SpecifyKind(customEndDate.Value.Date, DateTimeKind.Unspecified);
            }
            else
            {
                period = period ?? "week";
                switch (period.ToLower())
                {
                    case "week":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                        break;
                    case "month":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-29), DateTimeKind.Unspecified);
                        break;
                    case "quarter":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddMonths(-3).AddDays(1), DateTimeKind.Unspecified);
                        break;
                    case "year":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddYears(-1).AddDays(1), DateTimeKind.Unspecified);
                        break;
                    default:
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                        period = "week";
                        break;
                }
            }

            // Fetch revenue data
            var revenueData = await GetRevenueDataAsync(period, customStartDate?.ToString("yyyy-MM-dd"), customEndDate?.ToString("yyyy-MM-dd"));

            // Fetch top paper purchasers
            var topPaperPurchasers = await _context.PurchaseTransactions
                .Where(pt => pt.Status == "SUCCESS" &&
                           pt.CreatedAt >= start &&
                           pt.CreatedAt < end.AddDays(1) &&
                           pt.TransactionType == "PAGE_PURCHASE")
                .Include(pt => pt.User)
                .GroupBy(pt => pt.UserId)
                .Select(g => new
                {
                    UserId = g.Key,
                    UserName = g.First().User != null ? g.First().User.FullName : "Unknown",
                    TotalQuantity = g.Sum(pt => pt.Quantity),
                    TotalAmount = g.Sum(pt => pt.TotalAmount)
                })
                .OrderByDescending(x => x.TotalQuantity)
                .Take(5)
                .ToListAsync();

            // Fetch top storage purchasers
            var topStoragePurchasers = await _context.PurchaseTransactions
                .Where(pt => pt.Status == "SUCCESS" &&
                           pt.CreatedAt >= start &&
                           pt.CreatedAt < end.AddDays(1) &&
                           pt.TransactionType == "STORAGE_PURCHASE")
                .Include(pt => pt.User)
                .GroupBy(pt => pt.UserId)
                .Select(g => new
                {
                    UserId = g.Key,
                    UserName = g.First().User != null ? g.First().User.FullName : "Unknown",
                    TotalQuantity = g.Sum(pt => pt.Quantity),
                    TotalAmount = g.Sum(pt => pt.TotalAmount)
                })
                .OrderByDescending(x => x.TotalQuantity)
                .Take(5)
                .ToListAsync();

            // Fetch purchase transaction details
            var purchaseTransactionDetails = await _context.PurchaseTransactions
                .Where(pt => pt.Status == "SUCCESS" &&
                           pt.CreatedAt >= start &&
                           pt.CreatedAt < end.AddDays(1) &&
                           (pt.TransactionType == "PAGE_PURCHASE" || pt.TransactionType == "STORAGE_PURCHASE" || pt.TransactionType == "ORDER"))
                .Include(pt => pt.User)
                .OrderByDescending(pt => pt.CreatedAt)
                .Select(pt => new PurchaseTransactionDetailDto
                {
                    TransactionId = pt.Id,
                    UserFullName = pt.User != null ? pt.User.FullName : "Unknown",
                    UserStudentCode = pt.User != null ? pt.User.StudentCode : "",
                    UserEmail = pt.User != null ? pt.User.Email : "",
                    PurchaseType = pt.TransactionType,
                    ItemName = pt.TransactionType == "PAGE_PURCHASE" ? "Giấy A4" :
                              pt.TransactionType == "STORAGE_PURCHASE" ? "Dung lượng (MB)" : "Đơn in",
                    Quantity = pt.Quantity,
                    PricePerUnit = pt.PricePerUnit,
                    TotalAmount = pt.TotalAmount,
                    PurchaseDate = pt.CreatedAt
                })
                .ToListAsync();

            var periodLabel = customStartDate.HasValue && customEndDate.HasValue
                ? $"{customStartDate.Value:yyyyMMdd}_{customEndDate.Value:yyyyMMdd}"
                : $"{period}_{DateTime.Now:yyyyMMdd_HHmmss}";
            var fileName = $"BaoCao_DoanhThu_{periodLabel}";

            var exportData = new
            {
                RevenueData = revenueData,
                TopPaperPurchasers = topPaperPurchasers.Select(x => new
                {
                    UserName = x.UserName,
                    TotalQuantity = x.TotalQuantity,
                    TotalAmount = x.TotalAmount
                }).ToList(),
                TopStoragePurchasers = topStoragePurchasers.Select(x => new
                {
                    UserName = x.UserName,
                    TotalQuantity = x.TotalQuantity,
                    TotalAmount = x.TotalAmount
                }).ToList(),
                PurchaseTransactionDetails = purchaseTransactionDetails
            };

            return format.ToLower() switch
            {
                "csv" => (GenerateRevenueCsv(exportData), $"{fileName}.csv"),
                "json" => (GenerateRevenueJson(exportData), $"{fileName}.json"),
                "pdf" => (GenerateRevenuePdf(exportData), $"{fileName}.pdf"),
                _ => (GenerateRevenueExcel(exportData), $"{fileName}.xlsx")
            };
        }

        private async Task<(byte[] fileBytes, string fileName)> ExportTransactionsReport(string? period, DateTime? customStartDate, DateTime? customEndDate, string format)
        {
            // Xử lý period và date range
            DateTime start;
            DateTime end;
            var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);

            if (customStartDate.HasValue && customEndDate.HasValue)
            {
                start = DateTime.SpecifyKind(customStartDate.Value.Date, DateTimeKind.Unspecified);
                end = DateTime.SpecifyKind(customEndDate.Value.Date, DateTimeKind.Unspecified);
            }
            else
            {
                period = period ?? "week";
                switch (period.ToLower())
                {
                    case "week":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                        break;
                    case "month":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-29), DateTimeKind.Unspecified);
                        break;
                    case "quarter":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddMonths(-3).AddDays(1), DateTimeKind.Unspecified);
                        break;
                    case "year":
                        end = now;
                        start = DateTime.SpecifyKind(end.AddYears(-1).AddDays(1), DateTimeKind.Unspecified);
                        break;
                    default:
                        end = now;
                        start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                        period = "week";
                        break;
                }
            }

            // Fetch transaction data
            var transactions = await _context.PurchaseTransactions
                .Where(pt => pt.CreatedAt >= start &&
                           pt.CreatedAt < end.AddDays(1))
                .Include(pt => pt.User)
                .OrderByDescending(pt => pt.CreatedAt)
                .Select(pt => new
                {
                    TransactionId = pt.Id,
                    OrderCode = pt.TransactionCode,
                    UserId = pt.UserId,
                    UserName = pt.User != null ? pt.User.FullName : "Unknown",
                    UserEmail = pt.User != null ? pt.User.Email : "",
                    TransactionType = pt.TransactionType,
                    Quantity = pt.Quantity,
                    PricePerUnit = pt.PricePerUnit,
                    TotalAmount = pt.TotalAmount,
                    Status = pt.Status,
                    CreatedAt = pt.CreatedAt
                })
                .ToListAsync();

            var periodLabel = customStartDate.HasValue && customEndDate.HasValue
                ? $"{customStartDate.Value:yyyyMMdd}_{customEndDate.Value:yyyyMMdd}"
                : $"{period}_{DateTime.Now:yyyyMMdd_HHmmss}";
            var fileName = $"BaoCao_GiaoDich_ChiTiet_{periodLabel}";

            var exportData = transactions.Select(t => new
            {
                t.TransactionId,
                t.OrderCode,
                t.UserName,
                t.UserEmail,
                TransactionType = t.TransactionType switch
                {
                    "PAGE_PURCHASE" => "Mua giấy",
                    "STORAGE_PURCHASE" => "Mua dung lượng",
                    "ORDER" => "Đơn in",
                    _ => t.TransactionType
                },
                t.Quantity,
                t.PricePerUnit,
                t.TotalAmount,
                Status = t.Status switch
                {
                    "SUCCESS" => "Thành công",
                    "PENDING" => "Chờ xử lý",
                    "FAILED" => "Thất bại",
                    _ => t.Status
                },
                CreatedAt = t.CreatedAt.ToString("dd/MM/yyyy HH:mm:ss")
            }).ToList();

            return format.ToLower() switch
            {
                "csv" => (GenerateTransactionsCsv(exportData), $"{fileName}.csv"),
                "json" => (GenerateTransactionsJson(exportData), $"{fileName}.json"),
                "pdf" => (GenerateTransactionsPdf(exportData), $"{fileName}.pdf"),
                _ => (GenerateTransactionsExcel(exportData), $"{fileName}.xlsx")
            };
        }

        private async Task<(byte[] fileBytes, string fileName)> ExportTopPrintersReport(DateTime? startDate, DateTime? endDate, int top, string format)
        {
            var query = _context.PrintJobs.Where(j => j.PrinterId.HasValue && j.Status == "DONE");
            
            // Filter theo date range nếu có
            if (startDate.HasValue && endDate.HasValue)
            {
                query = query.Where(j => j.CreatedOn.HasValue && 
                                          j.CreatedOn.Value >= startDate.Value && 
                                          j.CreatedOn.Value < endDate.Value.AddDays(1));
            }

            var topPrinters = await query
                .GroupBy(j => j.PrinterId)
                .Select(g => new
                {
                    PrinterId = g.Key!.Value,
                    OrderCount = g.Count()
                })
                .OrderByDescending(x => x.OrderCount)
                .Take(top)
                .ToListAsync();

            var printerIds = topPrinters.Select(x => x.PrinterId).ToList();
            var printers = await _context.Printers
                .Where(p => printerIds.Contains(p.PrinterId))
                .ToListAsync();

            var result = topPrinters.Select(x =>
            {
                var printer = printers.FirstOrDefault(p => p.PrinterId == x.PrinterId);
                return new TopPrinterDto
                {
                    PrinterId = x.PrinterId,
                    PrinterCode = printer?.PrinterCode ?? "Unknown",
                    PrinterName = printer != null ? $"{printer.PrinterCode} - {printer.Location}" : "Unknown",
                    Location = printer?.Location,
                    Brand = printer?.Brand,
                    Model = printer?.Model,
                    OrderCount = x.OrderCount
                };
            }).ToList();

            var dateRangeLabel = startDate.HasValue && endDate.HasValue 
                ? $"{startDate.Value:yyyyMMdd}_{endDate.Value:yyyyMMdd}"
                : "all";
            var fileName = $"BaoCao_Top{top}MayIn_{dateRangeLabel}_{DateTime.Now:yyyyMMdd_HHmmss}";

            if (format.ToLower() == "json")
            {
                var jsonOptions = new JsonSerializerOptions 
                { 
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    WriteIndented = true
                };
                var json = JsonSerializer.Serialize(new { success = true, data = result }, jsonOptions);
                return (Encoding.UTF8.GetBytes(json), $"{fileName}.json");
            }
            else if (format.ToLower() == "csv")
            {
                var csv = GenerateTopPrintersCsv(result);
                var csvBytes = new List<byte>(Encoding.UTF8.GetPreamble());
                csvBytes.AddRange(Encoding.UTF8.GetBytes(csv));
                return (csvBytes.ToArray(), $"{fileName}.csv");
            }
            else if (format.ToLower() == "pdf")
            {
                var pdf = GenerateTopPrintersPdf(result);
                return (pdf, $"{fileName}.pdf");
            }
            else
            {
                var excel = GenerateTopPrintersExcel(result);
                return (excel, $"{fileName}.xlsx");
            }
        }

        private string GenerateOrdersByDayCsv(List<PrintOrdersByDayDto> data, string periodLabel)
        {
            var sb = new StringBuilder();
            sb.AppendLine("BÁO CÁO SỐ ĐƠN IN THEO NGÀY");
            sb.AppendLine($"Kỳ: {periodLabel}");
            sb.AppendLine($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}");
            sb.AppendLine();
            sb.AppendLine("Thời gian,Ngày,Số đơn");
            
            foreach (var item in data)
            {
                sb.AppendLine($"{item.DayLabel},{item.Date},{item.OrderCount}");
            }
            
            return sb.ToString();
        }

        private byte[] GenerateOrdersByDayExcel(List<PrintOrdersByDayDto> data, string periodLabel)
        {
            using (var stream = new MemoryStream())
            {
                using (var document = SpreadsheetDocument.Create(stream, SpreadsheetDocumentType.Workbook))
                {
                    var workbookPart = document.AddWorkbookPart();
                    workbookPart.Workbook = new Workbook();
                    
                    var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
                    worksheetPart.Worksheet = new Worksheet(new SheetData());
                    
                    var sheets = workbookPart.Workbook.AppendChild(new Sheets());
                    var sheet = new Sheet { Id = workbookPart.GetIdOfPart(worksheetPart), SheetId = 1, Name = "Báo cáo" };
                    sheets.Append(sheet);
                    
                    var sheetData = worksheetPart.Worksheet.GetFirstChild<SheetData>();
                    if (sheetData == null) throw new InvalidOperationException("SheetData is null");
                    
                    // Header
                    var headerRow = new Row();
                    headerRow.Append(new Cell { CellValue = new CellValue("BÁO CÁO SỐ ĐƠN IN THEO NGÀY"), DataType = CellValues.String });
                    sheetData.AppendChild(headerRow);
                    
                    var periodRow = new Row();
                    periodRow.Append(new Cell { CellValue = new CellValue($"Kỳ: {periodLabel}"), DataType = CellValues.String });
                    sheetData.AppendChild(periodRow);
                    
                    var dateRow = new Row();
                    dateRow.Append(new Cell { CellValue = new CellValue($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}"), DataType = CellValues.String });
                    sheetData.AppendChild(dateRow);
                    
                    var emptyRow = new Row();
                    sheetData.AppendChild(emptyRow);
                    
                    // Column headers
                    var columnHeaderRow = new Row();
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Thời gian"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Ngày"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Số đơn"), DataType = CellValues.String });
                    sheetData.AppendChild(columnHeaderRow);
                    
                    // Data rows
                    foreach (var item in data)
                    {
                        var row = new Row();
                        row.Append(new Cell { CellValue = new CellValue(item.DayLabel), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.Date), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.OrderCount.ToString()), DataType = CellValues.Number });
                        sheetData.AppendChild(row);
                    }
                }
                
                return stream.ToArray();
            }
        }

        private string GenerateTopUsersCsv(List<TopUserDto> data)
        {
            var sb = new StringBuilder();
            sb.AppendLine("BÁO CÁO TOP NGƯỜI DÙNG IN NHIỀU NHẤT");
            sb.AppendLine($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}");
            sb.AppendLine();
            sb.AppendLine("STT,Họ tên,Mã sinh viên,Email,Tổng trang,Số đơn");
            
            for (int i = 0; i < data.Count; i++)
            {
                var item = data[i];
                sb.AppendLine($"{i + 1},{item.FullName},{item.StudentCode},{item.Email},{item.TotalPages},{item.OrderCount}");
            }
            
            return sb.ToString();
        }

        private byte[] GenerateTopUsersExcel(List<TopUserDto> data)
        {
            using (var stream = new MemoryStream())
            {
                using (var document = SpreadsheetDocument.Create(stream, SpreadsheetDocumentType.Workbook))
                {
                    var workbookPart = document.AddWorkbookPart();
                    workbookPart.Workbook = new Workbook();
                    
                    var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
                    worksheetPart.Worksheet = new Worksheet(new SheetData());
                    
                    var sheets = workbookPart.Workbook.AppendChild(new Sheets());
                    var sheet = new Sheet { Id = workbookPart.GetIdOfPart(worksheetPart), SheetId = 1, Name = "Top người dùng" };
                    sheets.Append(sheet);
                    
                    var sheetData = worksheetPart.Worksheet.GetFirstChild<SheetData>();
                    if (sheetData == null) throw new InvalidOperationException("SheetData is null");
                    
                    // Header
                    var headerRow = new Row();
                    headerRow.Append(new Cell { CellValue = new CellValue("BÁO CÁO TOP NGƯỜI DÙNG IN NHIỀU NHẤT"), DataType = CellValues.String });
                    sheetData.AppendChild(headerRow);
                    
                    var dateRow = new Row();
                    dateRow.Append(new Cell { CellValue = new CellValue($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}"), DataType = CellValues.String });
                    sheetData.AppendChild(dateRow);
                    
                    var emptyRow = new Row();
                    sheetData.AppendChild(emptyRow);
                    
                    // Column headers
                    var columnHeaderRow = new Row();
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("STT"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Họ tên"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Mã sinh viên"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Email"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Tổng trang"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Số đơn"), DataType = CellValues.String });
                    sheetData.AppendChild(columnHeaderRow);
                    
                    // Data rows
                    for (int i = 0; i < data.Count; i++)
                    {
                        var item = data[i];
                        var row = new Row();
                        row.Append(new Cell { CellValue = new CellValue((i + 1).ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(item.FullName), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.StudentCode), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.Email), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.TotalPages.ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(item.OrderCount.ToString()), DataType = CellValues.Number });
                        sheetData.AppendChild(row);
                    }
                }
                
                return stream.ToArray();
            }
        }

        private string GenerateTopPrintersCsv(List<TopPrinterDto> data)
        {
            var sb = new StringBuilder();
            sb.AppendLine("BÁO CÁO TOP MÁY IN SỬ DỤNG NHIỀU NHẤT");
            sb.AppendLine($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}");
            sb.AppendLine();
            sb.AppendLine("STT,Mã máy in,Tên máy in,Vị trí,Hãng,Model,Số đơn");
            
            for (int i = 0; i < data.Count; i++)
            {
                var item = data[i];
                sb.AppendLine($"{i + 1},{item.PrinterCode},{item.PrinterName},{item.Location ?? ""},{item.Brand ?? ""},{item.Model ?? ""},{item.OrderCount}");
            }
            
            return sb.ToString();
        }

        private byte[] GenerateTopPrintersExcel(List<TopPrinterDto> data)
        {
            using (var stream = new MemoryStream())
            {
                using (var document = SpreadsheetDocument.Create(stream, SpreadsheetDocumentType.Workbook))
                {
                    var workbookPart = document.AddWorkbookPart();
                    workbookPart.Workbook = new Workbook();
                    
                    var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
                    worksheetPart.Worksheet = new Worksheet(new SheetData());
                    
                    var sheets = workbookPart.Workbook.AppendChild(new Sheets());
                    var sheet = new Sheet { Id = workbookPart.GetIdOfPart(worksheetPart), SheetId = 1, Name = "Top máy in" };
                    sheets.Append(sheet);
                    
                    var sheetData = worksheetPart.Worksheet.GetFirstChild<SheetData>();
                    if (sheetData == null) throw new InvalidOperationException("SheetData is null");
                    
                    // Header
                    var headerRow = new Row();
                    headerRow.Append(new Cell { CellValue = new CellValue("BÁO CÁO TOP MÁY IN SỬ DỤNG NHIỀU NHẤT"), DataType = CellValues.String });
                    sheetData.AppendChild(headerRow);
                    
                    var dateRow = new Row();
                    dateRow.Append(new Cell { CellValue = new CellValue($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}"), DataType = CellValues.String });
                    sheetData.AppendChild(dateRow);
                    
                    var emptyRow = new Row();
                    sheetData.AppendChild(emptyRow);
                    
                    // Column headers
                    var columnHeaderRow = new Row();
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("STT"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Mã máy in"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Tên máy in"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Vị trí"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Hãng"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Model"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Số đơn"), DataType = CellValues.String });
                    sheetData.AppendChild(columnHeaderRow);
                    
                    // Data rows
                    for (int i = 0; i < data.Count; i++)
                    {
                        var item = data[i];
                        var row = new Row();
                        row.Append(new Cell { CellValue = new CellValue((i + 1).ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(item.PrinterCode), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.PrinterName), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.Location ?? ""), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.Brand ?? ""), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.Model ?? ""), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(item.OrderCount.ToString()), DataType = CellValues.Number });
                        sheetData.AppendChild(row);
                    }
                }
                
                return stream.ToArray();
            }
        }

        private byte[] GenerateOrdersByDayPdf(List<PrintOrdersByDayDto> data, string periodLabel)
        {
            var document = new PdfDocument();
            var page = document.AddPage();
            var gfx = XGraphics.FromPdfPage(page);
            
            var fontTitle = new XFont("Arial", 16, XFontStyle.Bold);
            var fontHeader = new XFont("Arial", 10, XFontStyle.Bold);
            var fontNormal = new XFont("Arial", 9, XFontStyle.Regular);
            
            var yPos = 50;
            var margin = 50;
            var pageWidth = page.Width;
            var pageHeight = page.Height;
            var columnWidth = (pageWidth - 2 * margin) / 3;
            
            // Title
            gfx.DrawString("BÁO CÁO SỐ ĐƠN IN THEO NGÀY", fontTitle, XBrushes.Black, 
                new XRect(margin, yPos, pageWidth - 2 * margin, 30), XStringFormats.TopCenter);
            yPos += 30;
            
            // Period and date
            gfx.DrawString($"Kỳ: {periodLabel}", fontNormal, XBrushes.Black, 
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 20;
            gfx.DrawString($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}", fontNormal, XBrushes.Black, 
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 30;
            
            // Table header
            var headerRect = new XRect(margin, yPos, pageWidth - 2 * margin, 25);
            gfx.DrawRectangle(XPens.Black, XBrushes.LightGray, headerRect);
            gfx.DrawString("Thời gian", fontHeader, XBrushes.Black, 
                new XRect(margin, yPos + 5, columnWidth, 20), XStringFormats.TopLeft);
            gfx.DrawString("Ngày", fontHeader, XBrushes.Black, 
                new XRect(margin + columnWidth, yPos + 5, columnWidth, 20), XStringFormats.TopLeft);
            gfx.DrawString("Số đơn", fontHeader, XBrushes.Black, 
                new XRect(margin + 2 * columnWidth, yPos + 5, columnWidth, 20), XStringFormats.TopLeft);
            yPos += 25;
            
            // Data rows
            foreach (var item in data)
            {
                if (yPos > pageHeight - 50)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPos = 50;
                }
                
                var rowRect = new XRect(margin, yPos, pageWidth - 2 * margin, 20);
                gfx.DrawRectangle(XPens.Black, XBrushes.White, rowRect);
                gfx.DrawString(item.DayLabel, fontNormal, XBrushes.Black, 
                    new XRect(margin + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.Date, fontNormal, XBrushes.Black, 
                    new XRect(margin + columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.OrderCount.ToString(), fontNormal, XBrushes.Black, 
                    new XRect(margin + 2 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                yPos += 20;
            }
            
            using (var stream = new MemoryStream())
            {
                document.Save(stream);
                return stream.ToArray();
            }
        }

        private byte[] GenerateTopUsersPdf(List<TopUserDto> data)
        {
            var document = new PdfDocument();
            var page = document.AddPage();
            var gfx = XGraphics.FromPdfPage(page);
            
            var fontTitle = new XFont("Arial", 16, XFontStyle.Bold);
            var fontHeader = new XFont("Arial", 9, XFontStyle.Bold);
            var fontNormal = new XFont("Arial", 8, XFontStyle.Regular);
            
            var yPos = 50;
            var margin = 50;
            var pageWidth = page.Width;
            var pageHeight = page.Height;
            var columnWidth = (pageWidth - 2 * margin) / 6;
            
            // Title
            gfx.DrawString("BÁO CÁO TOP NGƯỜI DÙNG IN NHIỀU NHẤT", fontTitle, XBrushes.Black, 
                new XRect(margin, yPos, pageWidth - 2 * margin, 30), XStringFormats.TopCenter);
            yPos += 30;
            
            // Date
            gfx.DrawString($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}", fontNormal, XBrushes.Black, 
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 30;
            
            // Table header
            var headerRect = new XRect(margin, yPos, pageWidth - 2 * margin, 25);
            gfx.DrawRectangle(XPens.Black, XBrushes.LightGray, headerRect);
            gfx.DrawString("STT", fontHeader, XBrushes.Black, 
                new XRect(margin + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Họ tên", fontHeader, XBrushes.Black, 
                new XRect(margin + columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Mã SV", fontHeader, XBrushes.Black, 
                new XRect(margin + 2 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Email", fontHeader, XBrushes.Black, 
                new XRect(margin + 3 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Tổng trang", fontHeader, XBrushes.Black, 
                new XRect(margin + 4 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Số đơn", fontHeader, XBrushes.Black, 
                new XRect(margin + 5 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            yPos += 25;
            
            // Data rows
            for (int i = 0; i < data.Count; i++)
            {
                if (yPos > pageHeight - 50)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPos = 50;
                }
                
                var item = data[i];
                var rowRect = new XRect(margin, yPos, pageWidth - 2 * margin, 20);
                gfx.DrawRectangle(XPens.Black, XBrushes.White, rowRect);
                gfx.DrawString((i + 1).ToString(), fontNormal, XBrushes.Black, 
                    new XRect(margin + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.FullName, fontNormal, XBrushes.Black, 
                    new XRect(margin + columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.StudentCode, fontNormal, XBrushes.Black, 
                    new XRect(margin + 2 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.Email, fontNormal, XBrushes.Black, 
                    new XRect(margin + 3 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.TotalPages.ToString("N0"), fontNormal, XBrushes.Black, 
                    new XRect(margin + 4 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopRight);
                gfx.DrawString(item.OrderCount.ToString(), fontNormal, XBrushes.Black, 
                    new XRect(margin + 5 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopRight);
                yPos += 20;
            }
            
            using (var stream = new MemoryStream())
            {
                document.Save(stream);
                return stream.ToArray();
            }
        }

        private byte[] GenerateTopPrintersPdf(List<TopPrinterDto> data)
        {
            var document = new PdfDocument();
            var page = document.AddPage();
            var gfx = XGraphics.FromPdfPage(page);
            
            var fontTitle = new XFont("Arial", 16, XFontStyle.Bold);
            var fontHeader = new XFont("Arial", 9, XFontStyle.Bold);
            var fontNormal = new XFont("Arial", 8, XFontStyle.Regular);
            
            var yPos = 50;
            var margin = 50;
            var pageWidth = page.Width;
            var pageHeight = page.Height;
            var columnWidth = (pageWidth - 2 * margin) / 7;
            
            // Title
            gfx.DrawString("BÁO CÁO TOP MÁY IN SỬ DỤNG NHIỀU NHẤT", fontTitle, XBrushes.Black, 
                new XRect(margin, yPos, pageWidth - 2 * margin, 30), XStringFormats.TopCenter);
            yPos += 30;
            
            // Date
            gfx.DrawString($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}", fontNormal, XBrushes.Black, 
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 30;
            
            // Table header
            var headerRect = new XRect(margin, yPos, pageWidth - 2 * margin, 25);
            gfx.DrawRectangle(XPens.Black, XBrushes.LightGray, headerRect);
            gfx.DrawString("STT", fontHeader, XBrushes.Black, 
                new XRect(margin + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Mã máy", fontHeader, XBrushes.Black, 
                new XRect(margin + columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Tên máy", fontHeader, XBrushes.Black, 
                new XRect(margin + 2 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Vị trí", fontHeader, XBrushes.Black, 
                new XRect(margin + 3 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Hãng", fontHeader, XBrushes.Black, 
                new XRect(margin + 4 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Model", fontHeader, XBrushes.Black, 
                new XRect(margin + 5 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            gfx.DrawString("Số đơn", fontHeader, XBrushes.Black, 
                new XRect(margin + 6 * columnWidth + 5, yPos + 5, columnWidth - 10, 20), XStringFormats.TopLeft);
            yPos += 25;
            
            // Data rows
            for (int i = 0; i < data.Count; i++)
            {
                if (yPos > pageHeight - 50)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPos = 50;
                }
                
                var item = data[i];
                var rowRect = new XRect(margin, yPos, pageWidth - 2 * margin, 20);
                gfx.DrawRectangle(XPens.Black, XBrushes.White, rowRect);
                gfx.DrawString((i + 1).ToString(), fontNormal, XBrushes.Black, 
                    new XRect(margin + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.PrinterCode, fontNormal, XBrushes.Black, 
                    new XRect(margin + columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.PrinterName.Length > 20 ? item.PrinterName.Substring(0, 17) + "..." : item.PrinterName, fontNormal, XBrushes.Black, 
                    new XRect(margin + 2 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.Location ?? "", fontNormal, XBrushes.Black, 
                    new XRect(margin + 3 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.Brand ?? "", fontNormal, XBrushes.Black, 
                    new XRect(margin + 4 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.Model ?? "", fontNormal, XBrushes.Black, 
                    new XRect(margin + 5 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopLeft);
                gfx.DrawString(item.OrderCount.ToString(), fontNormal, XBrushes.Black, 
                    new XRect(margin + 6 * columnWidth + 5, yPos + 3, columnWidth - 10, 20), XStringFormats.TopRight);
                yPos += 20;
            }
            
            using (var stream = new MemoryStream())
            {
                document.Save(stream);
                return stream.ToArray();
            }
        }

        private byte[] GenerateRevenueCsv(dynamic data)
        {
            var sb = new StringBuilder();
            sb.AppendLine("BÁO CÁO DOANH THU");
            sb.AppendLine($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}");
            sb.AppendLine();

            // Revenue summary
            sb.AppendLine($"Tổng doanh thu: {data.RevenueData?.TotalRevenue:N0} VND");
            sb.AppendLine($"Doanh thu bán giấy: {data.RevenueData?.TotalPaperRevenue:N0} VND");
            sb.AppendLine($"Doanh thu bán dung lượng: {data.RevenueData?.TotalStorageRevenue:N0} VND");
            sb.AppendLine();

            sb.AppendLine("TOP NGƯỜI DÙNG MUA GIẤY NHIỀU NHẤT");
            sb.AppendLine("STT,Họ tên,Số trang mua,Doanh thu");
            for (int i = 0; i < data.TopPaperPurchasers.Count; i++)
            {
                var user = data.TopPaperPurchasers[i];
                sb.AppendLine($"{i + 1},{user.UserName},{user.TotalQuantity},{user.TotalAmount:N0} VND");
            }
            sb.AppendLine();

            sb.AppendLine("TOP NGƯỜI DÙNG MUA DUNG LƯỢNG NHIỀU NHẤT");
            sb.AppendLine("STT,Họ tên,Dung lượng mua,Doanh thu");
            for (int i = 0; i < data.TopStoragePurchasers.Count; i++)
            {
                var user = data.TopStoragePurchasers[i];
                sb.AppendLine($"{i + 1},{user.UserName},{user.TotalQuantity} MB,{user.TotalAmount:N0} VND");
            }
            sb.AppendLine();

            sb.AppendLine("CHI TIẾT GIAO DỊCH MUA");
            sb.AppendLine("Họ tên,MSSV,Email,Mua gì,Số lượng,Giá đơn vị,Tổng tiền,Ngày mua");
            foreach (var transaction in data.PurchaseTransactionDetails)
            {
                sb.AppendLine($"\"{transaction.UserFullName}\",\"{transaction.UserStudentCode}\",\"{transaction.UserEmail}\",\"{transaction.ItemName}\",{transaction.Quantity},{transaction.PricePerUnit},{transaction.TotalAmount},\"{transaction.PurchaseDate:yyyy-MM-dd HH:mm:ss}\"");
            }

            var csvBytes = new List<byte>(Encoding.UTF8.GetPreamble());
            csvBytes.AddRange(Encoding.UTF8.GetBytes(sb.ToString()));
            return csvBytes.ToArray();
        }

        private byte[] GenerateRevenueJson(dynamic data)
        {
            var result = new
            {
                title = "Báo cáo doanh thu",
                exportDate = DateTime.UtcNow,
                revenueData = data.RevenueData,
                topPaperPurchasers = data.TopPaperPurchasers,
                topStoragePurchasers = data.TopStoragePurchasers,
                purchaseTransactionDetails = data.PurchaseTransactionDetails
            };

            var jsonOptions = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = true,
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            };

            var json = JsonSerializer.Serialize(result, jsonOptions);
            return Encoding.UTF8.GetBytes(json);
        }

        private byte[] GenerateRevenueExcel(dynamic data)
        {
            using (var stream = new MemoryStream())
            {
                using (var document = SpreadsheetDocument.Create(stream, SpreadsheetDocumentType.Workbook))
                {
                    var workbookPart = document.AddWorkbookPart();
                    workbookPart.Workbook = new Workbook();

                    var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
                    worksheetPart.Worksheet = new Worksheet(new SheetData());

                    var sheets = workbookPart.Workbook.AppendChild(new Sheets());
                    var sheet = new Sheet { Id = workbookPart.GetIdOfPart(worksheetPart), SheetId = 1, Name = "Doanh thu" };
                    sheets.Append(sheet);

                    var sheetData = worksheetPart.Worksheet.GetFirstChild<SheetData>();
                    if (sheetData == null) throw new InvalidOperationException("SheetData is null");

                    // Header
                    var headerRow = new Row();
                    headerRow.Append(new Cell { CellValue = new CellValue("BÁO CÁO DOANH THU"), DataType = CellValues.String });
                    sheetData.AppendChild(headerRow);

                    var dateRow = new Row();
                    dateRow.Append(new Cell { CellValue = new CellValue($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}"), DataType = CellValues.String });
                    sheetData.AppendChild(dateRow);

                    sheetData.AppendChild(new Row()); // Empty row

                    // Summary
                    var summaryRow1 = new Row();
                    summaryRow1.Append(new Cell { CellValue = new CellValue($"Tổng doanh thu: {data.RevenueData?.TotalRevenue:N0} VND"), DataType = CellValues.String });
                    sheetData.AppendChild(summaryRow1);

                    var summaryRow2 = new Row();
                    summaryRow2.Append(new Cell { CellValue = new CellValue($"Doanh thu bán giấy: {data.RevenueData?.TotalPaperRevenue:N0} VND"), DataType = CellValues.String });
                    sheetData.AppendChild(summaryRow2);

                    var summaryRow3 = new Row();
                    summaryRow3.Append(new Cell { CellValue = new CellValue($"Doanh thu bán dung lượng: {data.RevenueData?.TotalStorageRevenue:N0} VND"), DataType = CellValues.String });
                    sheetData.AppendChild(summaryRow3);

                    sheetData.AppendChild(new Row()); // Empty row

                    // Top Paper Users Header
                    var paperHeaderRow = new Row();
                    paperHeaderRow.Append(new Cell { CellValue = new CellValue("TOP NGƯỜI DÙNG MUA GIẤY NHIỀU NHẤT"), DataType = CellValues.String });
                    sheetData.AppendChild(paperHeaderRow);

                    var paperColumnHeaderRow = new Row();
                    paperColumnHeaderRow.Append(new Cell { CellValue = new CellValue("STT"), DataType = CellValues.String });
                    paperColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Họ tên"), DataType = CellValues.String });
                    paperColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Số trang mua"), DataType = CellValues.String });
                    paperColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Doanh thu"), DataType = CellValues.String });
                    sheetData.AppendChild(paperColumnHeaderRow);

                    for (int i = 0; i < data.TopPaperPurchasers.Count; i++)
                    {
                        var user = data.TopPaperPurchasers[i];
                        var row = new Row();
                        row.Append(new Cell { CellValue = new CellValue((i + 1).ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(user.UserName), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(user.TotalQuantity.ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue($"{user.TotalAmount:N0} VND"), DataType = CellValues.String });
                        sheetData.AppendChild(row);
                    }

                    sheetData.AppendChild(new Row()); // Empty row

                    // Top Storage Users Header
                    var storageHeaderRow = new Row();
                    storageHeaderRow.Append(new Cell { CellValue = new CellValue("TOP NGƯỜI DÙNG MUA DUNG LƯỢNG NHIỀU NHẤT"), DataType = CellValues.String });
                    sheetData.AppendChild(storageHeaderRow);

                    var storageColumnHeaderRow = new Row();
                    storageColumnHeaderRow.Append(new Cell { CellValue = new CellValue("STT"), DataType = CellValues.String });
                    storageColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Họ tên"), DataType = CellValues.String });
                    storageColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Dung lượng mua"), DataType = CellValues.String });
                    storageColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Doanh thu"), DataType = CellValues.String });
                    sheetData.AppendChild(storageColumnHeaderRow);

                    for (int i = 0; i < data.TopStoragePurchasers.Count; i++)
                    {
                        var user = data.TopStoragePurchasers[i];
                        var row = new Row();
                        row.Append(new Cell { CellValue = new CellValue((i + 1).ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(user.UserName), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue($"{user.TotalQuantity} MB"), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue($"{user.TotalAmount:N0} VND"), DataType = CellValues.String });
                        sheetData.AppendChild(row);
                    }

                    sheetData.AppendChild(new Row()); // Empty row
                    sheetData.AppendChild(new Row()); // Empty row

                    // Purchase Transaction Details Header
                    var detailsHeaderRow = new Row();
                    detailsHeaderRow.Append(new Cell { CellValue = new CellValue("CHI TIẾT GIAO DỊCH MUA"), DataType = CellValues.String });
                    sheetData.AppendChild(detailsHeaderRow);

                    var detailsColumnHeaderRow = new Row();
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Họ tên"), DataType = CellValues.String });
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("MSSV"), DataType = CellValues.String });
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Email"), DataType = CellValues.String });
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Mua gì"), DataType = CellValues.String });
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Số lượng"), DataType = CellValues.String });
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Giá đơn vị"), DataType = CellValues.String });
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Tổng tiền"), DataType = CellValues.String });
                    detailsColumnHeaderRow.Append(new Cell { CellValue = new CellValue("Ngày mua"), DataType = CellValues.String });
                    sheetData.AppendChild(detailsColumnHeaderRow);

                    // Transaction details
                    foreach (var transaction in data.PurchaseTransactionDetails)
                    {
                        var row = new Row();
                        row.Append(new Cell { CellValue = new CellValue(transaction.UserFullName), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(transaction.UserStudentCode), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(transaction.UserEmail), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(transaction.ItemName), DataType = CellValues.String });
                        row.Append(new Cell { CellValue = new CellValue(transaction.Quantity.ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(transaction.PricePerUnit.ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(transaction.TotalAmount.ToString()), DataType = CellValues.Number });
                        row.Append(new Cell { CellValue = new CellValue(transaction.PurchaseDate.ToString("yyyy-MM-dd HH:mm:ss")), DataType = CellValues.String });
                        sheetData.AppendChild(row);
                    }

                    workbookPart.Workbook.Save();
                }

                return stream.ToArray();
            }
        }

        private byte[] GenerateRevenuePdf(dynamic data)
        {
            var document = new PdfDocument();
            var page = document.AddPage();
            var gfx = XGraphics.FromPdfPage(page);

            var fontTitle = new XFont("Arial", 16, XFontStyle.Bold);
            var fontHeader = new XFont("Arial", 12, XFontStyle.Bold);
            var fontNormal = new XFont("Arial", 10, XFontStyle.Regular);
            var fontSmall = new XFont("Arial", 8, XFontStyle.Regular);

            var yPos = 50;
            var margin = 50;
            var pageWidth = page.Width;
            var pageHeight = page.Height;

            // Title
            gfx.DrawString("BÁO CÁO DOANH THU", fontTitle, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 30), XStringFormats.TopCenter);
            yPos += 40;

            // Date
            gfx.DrawString($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}", fontNormal, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 30;

            // Summary
            gfx.DrawString($"Tổng doanh thu: {data.RevenueData?.TotalRevenue:N0} VND", fontHeader, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 20;
            gfx.DrawString($"Doanh thu bán giấy: {data.RevenueData?.TotalPaperRevenue:N0} VND", fontNormal, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 20;
            gfx.DrawString($"Doanh thu bán dung lượng: {data.RevenueData?.TotalStorageRevenue:N0} VND", fontNormal, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 40;

            // Top Paper Users
            if (yPos > pageHeight - 100)
            {
                page = document.AddPage();
                gfx = XGraphics.FromPdfPage(page);
                yPos = 50;
            }

            gfx.DrawString("TOP NGƯỜI DÙNG MUA GIẤY NHIỀU NHẤT", fontHeader, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 25;

            for (int i = 0; i < data.TopPaperPurchasers.Count; i++)
            {
                if (yPos > pageHeight - 50)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPos = 50;
                }

                var user = data.TopPaperPurchasers[i];
                gfx.DrawString($"{i + 1}. {user.UserName} - {user.TotalQuantity} trang - {user.TotalAmount:N0} VND", fontSmall, XBrushes.Black,
                    new XRect(margin, yPos, pageWidth - 2 * margin, 15), XStringFormats.TopLeft);
                yPos += 15;
            }

            yPos += 20;

            // Top Storage Users
            if (yPos > pageHeight - 100)
            {
                page = document.AddPage();
                gfx = XGraphics.FromPdfPage(page);
                yPos = 50;
            }

            gfx.DrawString("TOP NGƯỜI DÙNG MUA DUNG LƯỢNG NHIỀU NHẤT", fontHeader, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 25;

            for (int i = 0; i < data.TopStoragePurchasers.Count; i++)
            {
                if (yPos > pageHeight - 50)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPos = 50;
                }

                var user = data.TopStoragePurchasers[i];
                gfx.DrawString($"{i + 1}. {user.UserName} - {user.TotalQuantity} MB - {user.TotalAmount:N0} VND", fontSmall, XBrushes.Black,
                    new XRect(margin, yPos, pageWidth - 2 * margin, 15), XStringFormats.TopLeft);
                yPos += 15;
            }

            yPos += 40;

            // Purchase Transaction Details
            if (yPos > pageHeight - 150)
            {
                page = document.AddPage();
                gfx = XGraphics.FromPdfPage(page);
                yPos = 50;
            }

            gfx.DrawString("CHI TIẾT GIAO DỊCH MUA", fontHeader, XBrushes.Black,
                new XRect(margin, yPos, pageWidth - 2 * margin, 20), XStringFormats.TopLeft);
            yPos += 25;

            // Table header
            var colWidths = new[] { 60, 40, 80, 40, 35, 45, 45, 65 };
            var colPositions = new[] { margin, margin + 60, margin + 100, margin + 180, margin + 220, margin + 255, margin + 300, margin + 345 };

            var headers = new[] { "Họ tên", "MSSV", "Email", "Mua gì", "SL", "Đơn giá", "Tổng", "Ngày mua" };
            for (int i = 0; i < headers.Length; i++)
            {
                gfx.DrawString(headers[i], fontNormal, XBrushes.Black, new XPoint(colPositions[i], yPos));
            }
            yPos += 20;

            // Table data
            foreach (var transaction in data.PurchaseTransactionDetails)
            {
                if (yPos > pageHeight - 50)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPos = 50;

                    // Re-draw header
                    for (int i = 0; i < headers.Length; i++)
                    {
                        gfx.DrawString(headers[i], fontNormal, XBrushes.Black, new XPoint(colPositions[i], yPos));
                    }
                    yPos += 20;
                }

                var values = new[]
                {
                    transaction.UserFullName.Length > 12 ? transaction.UserFullName.Substring(0, 12) + "..." : transaction.UserFullName,
                    transaction.UserStudentCode,
                    transaction.UserEmail.Length > 15 ? transaction.UserEmail.Substring(0, 15) + "..." : transaction.UserEmail,
                    transaction.ItemName,
                    transaction.Quantity.ToString(),
                    transaction.PricePerUnit.ToString("N0"),
                    transaction.TotalAmount.ToString("N0"),
                    transaction.PurchaseDate.ToString("dd/MM/yyyy HH:mm")
                };

                for (int i = 0; i < values.Length; i++)
                {
                    gfx.DrawString(values[i], fontSmall, XBrushes.Black, new XPoint(colPositions[i], yPos));
                }
                yPos += 15;
            }

            using (var stream = new MemoryStream())
            {
                document.Save(stream);
                return stream.ToArray();
            }
        }

        private async Task<(byte[] fileBytes, string fileName)> ExportPrinterReport(string? period, DateTime? startDate, DateTime? endDate, int[] printerIds, string format)
        {
            try
            {
                // Xử lý period và date range tương tự GetUserReport
                DateTime start;
                DateTime end;
                var now = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Unspecified);

                if (startDate.HasValue && endDate.HasValue)
                {
                    start = DateTime.SpecifyKind(startDate.Value.Date, DateTimeKind.Unspecified);
                    end = DateTime.SpecifyKind(endDate.Value.Date, DateTimeKind.Unspecified);
                }
                else
                {
                    period = period ?? "week";
                    switch (period.ToLower())
                    {
                        case "week":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                            break;
                        case "month":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-29), DateTimeKind.Unspecified);
                            break;
                        case "quarter":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddMonths(-3).AddDays(1), DateTimeKind.Unspecified);
                            break;
                        case "year":
                            end = now;
                            start = DateTime.SpecifyKind(end.AddYears(-1).AddDays(1), DateTimeKind.Unspecified);
                            break;
                        default:
                            end = now;
                            start = DateTime.SpecifyKind(end.AddDays(-6), DateTimeKind.Unspecified);
                            period = "week";
                            break;
                    }
                }

                _logger.LogInformation($"[PrinterReport] Period: {period}, Start: {start:yyyy-MM-dd}, End: {end:yyyy-MM-dd}");

                // Lấy data trực tiếp từ database thay vì gọi API method
                var selectedPrinters = await _context.Printers
                    .Where(p => printerIds.Contains(p.PrinterId))
                    .Select(p => new PrinterDto
                    {
                        PrinterId = p.PrinterId,
                        PrinterCode = p.PrinterCode,
                        Location = p.Location,
                        Brand = p.Brand,
                        Model = p.Model,
                        Status = p.Status
                    })
                    .ToListAsync();

                // Lấy tất cả print jobs chi tiết theo máy in được chọn và filter theo thời gian
                var printJobs = await _context.PrintJobs
                    .Where(pj => printerIds.Contains(pj.PrinterId ?? 0) &&
                                pj.Status == "DONE" && // Status là DONE, không phải COMPLETED
                                pj.CreatedOn.HasValue &&
                                pj.CreatedOn.Value >= start &&
                                pj.CreatedOn.Value < end.AddDays(1)) // Bao gồm cả ngày cuối
                    .Include(pj => pj.Printer)
                    .Include(pj => pj.Document)
                    .OrderByDescending(pj => pj.CreatedOn)
                    .ToListAsync();

                _logger.LogInformation($"[PrinterReport] Found {printJobs.Count} print jobs for printerIds: {string.Join(",", printerIds)} in period {period} ({start:yyyy-MM-dd} to {end:yyyy-MM-dd})");
                _logger.LogInformation($"[PrinterReport] Sample job: PrinterId={printJobs.FirstOrDefault()?.PrinterId}, DocumentId={printJobs.FirstOrDefault()?.DocumentId}, Status={printJobs.FirstOrDefault()?.Status}, CreatedOn={printJobs.FirstOrDefault()?.CreatedOn}");

                // Tạo danh sách chi tiết từng job in
                var printerReports = printJobs.Select(pj => new PrinterReportDto
                {
                    PrinterId = pj.PrinterId ?? 0,
                    PrinterCode = pj.Printer?.PrinterCode ?? "Unknown",
                    Location = pj.Printer?.Location ?? "",
                    TotalJobs = 1, // Mỗi record là 1 job
                    TotalPages = pj.TotalPages ?? 0,
                    PrintedDocuments = new List<PrintedDocumentDto>
                    {
                        new PrintedDocumentDto
                        {
                            DocumentId = pj.DocumentId ?? 0,
                            FileName = pj.Document?.FileName ?? "Unknown",
                            PrintCount = pj.Copies ?? 1,
                            TotalPages = pj.TotalPages ?? 0,
                            LastPrinted = pj.CompletedAt
                        }
                    }
                }).ToList();

                var reportData = new PrinterReportResponseDto
                {
                    SelectedPrinters = selectedPrinters,
                    PrinterReports = printerReports,
                    TotalPrinters = selectedPrinters.Count,
                    TotalJobs = printJobs.Count,
                    TotalPages = printJobs.Sum(pj => pj.TotalPages ?? 0)
                };

                var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
                var periodLabel = startDate.HasValue && endDate.HasValue
                    ? $"{startDate.Value:yyyyMMdd}_{endDate.Value:yyyyMMdd}"
                    : $"{period}_{timestamp}";
                var fileName = $"BaoCao_MayIn_{periodLabel}_{timestamp}";

                return format.ToLower() switch
                {
                    "csv" => (ExportPrinterReportToCsv(reportData), $"{fileName}.csv"),
                    "json" => (ExportPrinterReportToJson(reportData), $"{fileName}.json"),
                    "pdf" => (ExportPrinterReportToPdf(reportData), $"{fileName}.pdf"),
                    _ => (GeneratePrinterReportExcel(reportData), $"{fileName}.xlsx")
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting printer report");
                throw;
            }
        }


        private byte[] ExportPrinterReportToCsv(PrinterReportResponseDto data)
        {
            var csv = new StringBuilder();

            // Header
            csv.AppendLine("BÁO CÁO MÁY IN CHI TIẾT");
            csv.AppendLine();
            csv.AppendLine($"Tổng máy in: {data.TotalPrinters}");
            csv.AppendLine($"Tổng công việc: {data.TotalJobs}");
            csv.AppendLine($"Tổng trang in: {data.TotalPages}");
            csv.AppendLine();

            // Table header
            csv.AppendLine("Tên máy in,Tên tài liệu,Ngày in,Số lượng");

            // Detail for each print job
            foreach (var printerReport in data.PrinterReports)
            {
                var printerName = $"{printerReport.PrinterCode} - {printerReport.Location}";
                var document = printerReport.PrintedDocuments.FirstOrDefault();

                if (document != null)
                {
                    var printDate = document.LastPrinted?.ToString("yyyy-MM-dd HH:mm:ss") ?? "N/A";
                    csv.AppendLine($"\"{printerName}\",\"{document.FileName}\",\"{printDate}\",{document.PrintCount}");
                }
            }

            return Encoding.UTF8.GetBytes(csv.ToString());
        }

        private byte[] ExportPrinterReportToJson(PrinterReportResponseDto data)
        {
            var json = System.Text.Json.JsonSerializer.Serialize(data, new JsonSerializerOptions
            {
                WriteIndented = true,
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            });

            return Encoding.UTF8.GetBytes(json);
        }

        private byte[] GeneratePrinterReportExcel(PrinterReportResponseDto data)
        {
            using (var stream = new MemoryStream())
            {
                using (var document = SpreadsheetDocument.Create(stream, SpreadsheetDocumentType.Workbook))
                {
                    var workbookPart = document.AddWorkbookPart();
                    workbookPart.Workbook = new Workbook();

                    var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
                    worksheetPart.Worksheet = new Worksheet(new SheetData());

                    var sheets = workbookPart.Workbook.AppendChild(new Sheets());
                    var sheet = new Sheet { Id = workbookPart.GetIdOfPart(worksheetPart), SheetId = 1, Name = "Báo cáo máy in" };
                    sheets.Append(sheet);

                    var sheetData = worksheetPart.Worksheet.GetFirstChild<SheetData>();
                    if (sheetData == null) throw new InvalidOperationException("SheetData is null");

                    // Header
                    var headerRow = new Row();
                    headerRow.Append(new Cell { CellValue = new CellValue("BÁO CÁO MÁY IN CHI TIẾT"), DataType = CellValues.String });
                    sheetData.AppendChild(headerRow);

                    var dateRow = new Row();
                    dateRow.Append(new Cell { CellValue = new CellValue($"Xuất ngày: {DateTime.Now:dd/MM/yyyy HH:mm:ss}"), DataType = CellValues.String });
                    sheetData.AppendChild(dateRow);

                    var emptyRow = new Row();
                    sheetData.AppendChild(emptyRow);

                    // Summary
                    var summaryRow1 = new Row();
                    summaryRow1.Append(new Cell { CellValue = new CellValue($"Tổng máy in: {data.TotalPrinters}"), DataType = CellValues.String });
                    sheetData.AppendChild(summaryRow1);

                    var summaryRow2 = new Row();
                    summaryRow2.Append(new Cell { CellValue = new CellValue($"Tổng công việc: {data.TotalJobs}"), DataType = CellValues.String });
                    sheetData.AppendChild(summaryRow2);

                    var summaryRow3 = new Row();
                    summaryRow3.Append(new Cell { CellValue = new CellValue($"Tổng trang in: {data.TotalPages}"), DataType = CellValues.String });
                    sheetData.AppendChild(summaryRow3);

                    var emptyRow2 = new Row();
                    sheetData.AppendChild(emptyRow2);

                    // Column headers
                    var columnHeaderRow = new Row();
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Tên máy in"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Tên tài liệu"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Ngày in"), DataType = CellValues.String });
                    columnHeaderRow.Append(new Cell { CellValue = new CellValue("Số lượng"), DataType = CellValues.String });
                    sheetData.AppendChild(columnHeaderRow);

                    // Data rows
                    foreach (var printerReport in data.PrinterReports)
                    {
                        var printerName = $"{printerReport.PrinterCode} - {printerReport.Location}";
                        var printedDocument = printerReport.PrintedDocuments.FirstOrDefault();

                        if (printedDocument != null)
                        {
                            var row = new Row();
                            row.Append(new Cell { CellValue = new CellValue(printerName), DataType = CellValues.String });
                            row.Append(new Cell { CellValue = new CellValue(printedDocument.FileName), DataType = CellValues.String });
                            row.Append(new Cell { CellValue = new CellValue(printedDocument.LastPrinted?.ToString("yyyy-MM-dd HH:mm:ss") ?? "N/A"), DataType = CellValues.String });
                            row.Append(new Cell { CellValue = new CellValue(printedDocument.PrintCount.ToString()), DataType = CellValues.Number });
                            sheetData.AppendChild(row);
                        }
                    }

                    workbookPart.Workbook.Save();
                }

                return stream.ToArray();
            }
        }

        private byte[] ExportPrinterReportToPdf(PrinterReportResponseDto data)
        {
            using var stream = new MemoryStream();
            var document = new PdfDocument();
            var page = document.AddPage();
            var gfx = XGraphics.FromPdfPage(page);
            var font = new XFont("Arial", 12, XFontStyle.Regular);
            var boldFont = new XFont("Arial", 12, XFontStyle.Bold);
            var titleFont = new XFont("Arial", 16, XFontStyle.Bold);

            var yPos = 50;

            // Title
            gfx.DrawString("BÁO CÁO MÁY IN CHI TIẾT", titleFont, XBrushes.Black, new XPoint(50, yPos));
            yPos += 40;

            // Summary
            gfx.DrawString($"Tổng máy in: {data.TotalPrinters}", boldFont, XBrushes.Black, new XPoint(50, yPos));
            yPos += 20;
            gfx.DrawString($"Tổng công việc: {data.TotalJobs}", boldFont, XBrushes.Black, new XPoint(50, yPos));
            yPos += 20;
            gfx.DrawString($"Tổng trang in: {data.TotalPages}", boldFont, XBrushes.Black, new XPoint(50, yPos));
            yPos += 40;

            // Table header
            if (yPos > page.Height - 100)
            {
                page = document.AddPage();
                gfx = XGraphics.FromPdfPage(page);
                yPos = 50;
            }

            gfx.DrawString("Tên máy in", boldFont, XBrushes.Black, new XPoint(50, yPos));
            gfx.DrawString("Tên tài liệu", boldFont, XBrushes.Black, new XPoint(200, yPos));
            gfx.DrawString("Ngày in", boldFont, XBrushes.Black, new XPoint(350, yPos));
            gfx.DrawString("Số lượng", boldFont, XBrushes.Black, new XPoint(450, yPos));
            yPos += 25;

            // Detail for each print job
            foreach (var printerReport in data.PrinterReports)
            {
                if (yPos > page.Height - 50)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPos = 50;

                    // Re-draw header on new page
                    gfx.DrawString("Tên máy in", boldFont, XBrushes.Black, new XPoint(50, yPos));
                    gfx.DrawString("Tên tài liệu", boldFont, XBrushes.Black, new XPoint(200, yPos));
                    gfx.DrawString("Ngày in", boldFont, XBrushes.Black, new XPoint(350, yPos));
                    gfx.DrawString("Số lượng", boldFont, XBrushes.Black, new XPoint(450, yPos));
                    yPos += 25;
                }

                var printerName = $"{printerReport.PrinterCode} - {printerReport.Location}";
                var printedDoc = printerReport.PrintedDocuments.FirstOrDefault();

                if (printedDoc != null)
                {
                    var printDate = printedDoc.LastPrinted?.ToString("yyyy-MM-dd HH:mm") ?? "N/A";

                    gfx.DrawString(printerName, font, XBrushes.Black, new XPoint(50, yPos));
                    gfx.DrawString(printedDoc.FileName, font, XBrushes.Black, new XPoint(200, yPos));
                    gfx.DrawString(printDate, font, XBrushes.Black, new XPoint(350, yPos));
                    gfx.DrawString(printedDoc.PrintCount.ToString(), font, XBrushes.Black, new XPoint(450, yPos));
                    yPos += 20;
                }
            }

            document.Save(stream);
            return stream.ToArray();
        }

        /// <summary>
        /// Test endpoint to check transaction count
        /// </summary>
        [HttpGet("Test/TransactionCount")]
        [ProducesResponseType(typeof(object), 200)]
        public async Task<IActionResult> GetTransactionCount()
        {
            try
            {
                var count = await _context.PurchaseTransactions.CountAsync();
                return Ok(new { success = true, count = count });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy lịch sử giao dịch cho admin
        /// </summary>
        [HttpGet("Admin/TransactionHistory")]
        [ProducesResponseType(typeof(List<TransactionHistoryDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetTransactionHistory()
        {
            try
            {
                // Kiểm tra quyền Admin/SPSO
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });
                }

                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền xem lịch sử giao dịch." });
                }

                // Lấy tất cả purchase transactions với thông tin user và order
                var transactions = await _context.PurchaseTransactions
                    .Include(pt => pt.User)
                    .OrderByDescending(pt => pt.CreatedAt)
                    .Select(pt => new TransactionHistoryDto
                    {
                        Id = pt.Id,
                        OrderCode = pt.TransactionCode, // Use TransactionCode as OrderCode
                        UserId = pt.UserId,
                        UserName = pt.User != null ? pt.User.FullName : "Unknown",
                        UserEmail = pt.User != null ? pt.User.Email : "Unknown",
                        TransactionType = pt.TransactionType,
                        Quantity = pt.Quantity,
                        PricePerUnit = pt.PricePerUnit,
                        TotalAmount = pt.TotalAmount,
                        Status = pt.Status,
                        CreatedAt = pt.CreatedAt
                    })
                    .ToListAsync();

                return Ok(new { success = true, data = transactions });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting transaction history");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy lịch sử giao dịch.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy lịch sử giao dịch của user hiện tại
        /// </summary>
        [HttpGet("TransactionHistory")]
        [ProducesResponseType(typeof(List<TransactionHistoryDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetUserTransactionHistory()
        {
            try
            {
                // Kiểm tra đăng nhập
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });
                }

                // Lấy lịch sử giao dịch của user hiện tại
                var transactions = await _context.PurchaseTransactions
                    .Include(pt => pt.User)
                    .Where(pt => pt.UserId == userId)
                    .OrderByDescending(pt => pt.CreatedAt)
                    .Select(pt => new TransactionHistoryDto
                    {
                        Id = pt.Id,
                        OrderCode = pt.TransactionCode, // Use TransactionCode as OrderCode
                        UserId = pt.UserId,
                        UserName = pt.User != null ? pt.User.FullName : "Unknown",
                        UserEmail = pt.User != null ? pt.User.Email : "Unknown",
                        TransactionType = pt.TransactionType,
                        Quantity = pt.Quantity,
                        PricePerUnit = pt.PricePerUnit,
                        TotalAmount = pt.TotalAmount,
                        Status = pt.Status,
                        CreatedAt = pt.CreatedAt
                    })
                    .ToListAsync();

                return Ok(new { success = true, data = transactions });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting user transaction history");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy lịch sử giao dịch.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy thống kê giao dịch của user hiện tại
        /// </summary>
        [HttpGet("Student/TransactionSummary")]
        [ProducesResponseType(typeof(object), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetUserTransactionSummary()
        {
            try
            {
                // Kiểm tra đăng nhập
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });
                }

                // Lấy thống kê giao dịch của user hiện tại
                var summary = await _context.PurchaseTransactions
                    .Where(pt => pt.UserId == userId)
                    .GroupBy(pt => 1)
                    .Select(g => new
                    {
                        TotalTransactions = g.Count(),
                        TotalAmount = g.Sum(pt => pt.TotalAmount)
                    })
                    .FirstOrDefaultAsync();

                if (summary == null)
                {
                    return Ok(new
                    {
                        success = true,
                        data = new
                        {
                            TotalTransactions = 0,
                            TotalAmount = 0
                        }
                    });
                }

                return Ok(new
                {
                    success = true,
                    data = summary
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting user transaction summary");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy thống kê giao dịch.", error = ex.Message });
            }
        }

        private byte[] GenerateTransactionsCsv(IEnumerable<dynamic> data)
        {
            var csv = new StringBuilder();
            csv.AppendLine("Mã giao dịch,Mã đơn hàng,Tên người dùng,Email,Loại giao dịch,Số lượng,Đơn giá,Tổng tiền,Trạng thái,Thời gian tạo");

            foreach (var item in data)
            {
                csv.AppendLine($"{item.TransactionId},{item.OrderCode ?? ""},{item.UserName},{item.UserEmail},{item.TransactionType},{item.Quantity},{item.PricePerUnit},{item.TotalAmount},{item.Status},{item.CreatedAt}");
            }

            return Encoding.UTF8.GetBytes(csv.ToString());
        }

        private byte[] GenerateTransactionsJson(IEnumerable<dynamic> data)
        {
            var json = System.Text.Json.JsonSerializer.Serialize(data, new JsonSerializerOptions
            {
                WriteIndented = true,
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            });
            return Encoding.UTF8.GetBytes(json);
        }

        private byte[] GenerateTransactionsPdf(IEnumerable<dynamic> data)
        {
            using var stream = new MemoryStream();
            var document = new PdfDocument();
            var page = document.AddPage();
            var gfx = XGraphics.FromPdfPage(page);
            var font = new XFont("Arial", 10);

            var y = 50;
            gfx.DrawString("BÁO CÁO CHI TIẾT GIAO DỊCH", new XFont("Arial", 16, XFontStyle.Bold), XBrushes.Black, new XPoint(50, y));
            y += 30;

            // Headers
            var headers = new[] { "Mã GD", "Người dùng", "Loại", "SL", "Đơn giá", "Tổng", "Trạng thái", "Thời gian" };
            var x = 50;
            foreach (var header in headers)
            {
                gfx.DrawString(header, font, XBrushes.Black, new XPoint(x, y));
                x += 80;
            }
            y += 20;

            // Data
            foreach (var item in data.Take(50)) // Limit to 50 rows for PDF
            {
                x = 50;
                var values = new[]
                {
                    item.TransactionId.ToString(),
                    item.UserName.ToString(),
                    item.TransactionType.ToString(),
                    item.Quantity.ToString(),
                    item.PricePerUnit.ToString("N0"),
                    item.TotalAmount.ToString("N0"),
                    item.Status.ToString(),
                    item.CreatedAt.ToString()
                };

                foreach (var value in values)
                {
                    gfx.DrawString(value, font, XBrushes.Black, new XPoint(x, y));
                    x += 80;
                }
                y += 15;

                if (y > page.Height - 50) break; // Prevent overflow
            }

            document.Save(stream);
            return stream.ToArray();
        }

        private byte[] GenerateTransactionsExcel(IEnumerable<dynamic> data)
        {
            try
            {
                using (var stream = new MemoryStream())
                {
                    using (var document = SpreadsheetDocument.Create(stream, SpreadsheetDocumentType.Workbook))
                    {
                        var workbookPart = document.AddWorkbookPart();
                        workbookPart.Workbook = new Workbook();

                        var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
                        var sheetData = new SheetData();
                        worksheetPart.Worksheet = new Worksheet(sheetData);

                        var sheets = workbookPart.Workbook.AppendChild(new Sheets());
                        var sheet = new Sheet { Id = workbookPart.GetIdOfPart(worksheetPart), SheetId = 1, Name = "GiaoDich" };
                        sheets.Append(sheet);

                        // Headers
                        var headerRow = new Row();
                        var headers = new[] { "Mã giao dịch", "Mã đơn hàng", "Tên người dùng", "Email", "Loại giao dịch", "Số lượng", "Đơn giá", "Tổng tiền", "Trạng thái", "Thời gian tạo" };

                        foreach (var header in headers)
                        {
                            headerRow.Append(new Cell { CellValue = new CellValue(header), DataType = CellValues.String });
                        }
                        sheetData.Append(headerRow);

                        // Data rows
                        if (data != null)
                        {
                            foreach (var item in data)
                            {
                                try
                                {
                                    var dataRow = new Row();

                                    // Safely extract values from dynamic object
                                    var transactionId = GetDynamicValue(item, "TransactionId", "0");
                                    var orderCode = GetDynamicValue(item, "OrderCode", "");
                                    var userName = GetDynamicValue(item, "UserName", "Unknown");
                                    var userEmail = GetDynamicValue(item, "UserEmail", "");
                                    var transactionType = GetDynamicValue(item, "TransactionType", "");
                                    var quantity = GetDynamicValue(item, "Quantity", "0");
                                    var pricePerUnit = GetDynamicValue(item, "PricePerUnit", "0");
                                    var totalAmount = GetDynamicValue(item, "TotalAmount", "0");
                                    var status = GetDynamicValue(item, "Status", "");
                                    var createdAt = GetDynamicValue(item, "CreatedAt", "");

                                    var values = new[] { transactionId, orderCode, userName, userEmail, transactionType, quantity, pricePerUnit, totalAmount, status, createdAt };

                                    foreach (var value in values)
                                    {
                                        dataRow.Append(new Cell { CellValue = new CellValue(value), DataType = CellValues.String });
                                    }
                                    sheetData.Append(dataRow);
                                }
                                catch (Exception ex)
                                {
                                    _logger.LogWarning(ex, "Error processing transaction item in Excel export");
                                    // Skip this item and continue
                                }
                            }
                        }

                        workbookPart.Workbook.Save();
                    }

                    var result = stream.ToArray();
                    _logger.LogInformation($"Generated transactions Excel file with {result.Length} bytes");
                    return result;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating transactions Excel file");
                // Create a fallback Excel file with error message
                using (var errorStream = new MemoryStream())
                {
                    using (var errorDoc = SpreadsheetDocument.Create(errorStream, SpreadsheetDocumentType.Workbook))
                    {
                        var errorWorkbookPart = errorDoc.AddWorkbookPart();
                        errorWorkbookPart.Workbook = new Workbook();

                        var errorWorksheetPart = errorWorkbookPart.AddNewPart<WorksheetPart>();
                        var errorSheetData = new SheetData();
                        errorWorksheetPart.Worksheet = new Worksheet(errorSheetData);

                        var errorSheets = errorWorkbookPart.Workbook.AppendChild(new Sheets());
                        var errorSheet = new Sheet { Id = errorWorkbookPart.GetIdOfPart(errorWorksheetPart), SheetId = 1, Name = "Error" };
                        errorSheets.Append(errorSheet);

                        var errorRow = new Row();
                        errorRow.Append(new Cell { CellValue = new CellValue($"Lỗi tạo file Excel: {ex.Message}"), DataType = CellValues.String });
                        errorSheetData.Append(errorRow);

                        errorWorkbookPart.Workbook.Save();
                    }
                    return errorStream.ToArray();
                }
            }
        }

        private string GetDynamicValue(dynamic obj, string propertyName, string defaultValue)
        {
            try
            {
                var value = obj.GetType().GetProperty(propertyName)?.GetValue(obj, null);
                return value?.ToString() ?? defaultValue;
            }
            catch
            {
                return defaultValue;
            }
        }

    }
}

