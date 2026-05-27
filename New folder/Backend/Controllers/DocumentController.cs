using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using PTVBTPM.Hubs;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Hosting;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using DocumentFormat.OpenXml.Presentation;
using DocumentFormat.OpenXml.Spreadsheet;
using PdfSharpCore.Pdf.IO;
using PdfSharpCore.Pdf;
using Microsoft.Extensions.Caching.Memory;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    [Produces("application/json")]
    public class DocumentController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<DocumentController> _logger;
        private readonly IWebHostEnvironment _environment;
        private readonly IMemoryCache _cache;
        private readonly IHubContext<PrintHub> _hubContext;

        public DocumentController(
            WebDbContext context, 
            ILogger<DocumentController> logger,
            IWebHostEnvironment environment,
            IMemoryCache cache,
            IHubContext<PrintHub> hubContext)
        {
            _context = context;
            _logger = logger;
            _environment = environment;
            _cache = cache;
            _hubContext = hubContext;
        }

        /// <summary>
        /// Upload tài liệu để in
        /// </summary>
        [HttpPost("Upload")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> UploadDocument(IFormFile file)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                if (file == null || file.Length == 0)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Vui lòng chọn file để upload."
                    });
                }

                // Lấy system config để kiểm tra file type và size
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                // Nếu không có config, sử dụng giá trị mặc định
                var maxFileSize = systemConfig?.MaxFileSize ?? 52428800; // 50MB
                var allowedFormats = systemConfig?.AllowedFileFormats ?? ".pdf,.docx,.pptx";

                // Kiểm tra file type từ config
                var allowedExtensions = allowedFormats
                    .Split(',', StringSplitOptions.RemoveEmptyEntries)
                    .Select(e => e.Trim().ToLowerInvariant())
                    .ToArray();
                var fileExtension = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(fileExtension))
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = $"File type không được hỗ trợ. Chỉ chấp nhận: {allowedFormats}"
                    });
                }

                // Kiểm tra file size từ config
                if (file.Length > maxFileSize)
                {
                    var maxFileSizeMB = Math.Round(maxFileSize / (1024.0 * 1024.0), 2);
                    return BadRequest(new
                    {
                        success = false,
                        message = $"File quá lớn. Kích thước tối đa là {maxFileSizeMB}MB."
                    });
                }

                // Tạo tên file unique và lưu vào DocumentUploads (lưu DB ngay)
                var fileName = $"{Guid.NewGuid()}_{file.FileName}";
                var documentUploadsFolder = Path.Combine(_environment.WebRootPath, "DocumentUploads");
                
                // Đảm bảo thư mục DocumentUploads tồn tại
                if (!Directory.Exists(documentUploadsFolder))
                {
                    Directory.CreateDirectory(documentUploadsFolder);
                }

                var filePath = Path.Combine(documentUploadsFolder, fileName);

                // Lưu file vào DocumentUploads
                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                // Tính số trang (convert nếu cần)
                int? pageCount = null;
                string? convertedPdfPath = null;
                
                if (fileExtension == ".pdf")
                {
                    pageCount = CountPdfPages(filePath);
                }
                else if (fileExtension == ".docx")
                {
                    pageCount = CountDocxPages(filePath);
                    // PDF đã được convert trong CountDocxPages, lấy path
                    convertedPdfPath = Path.ChangeExtension(filePath, ".pdf");
                    if (!System.IO.File.Exists(convertedPdfPath))
                    {
                        convertedPdfPath = null;
                    }
                }
                else if (fileExtension == ".pptx")
                {
                    // Convert PPTX sang PDF ngay khi upload (giống DOCX)
                    // PDF cơ bản với 1 slide per page để preview nhanh
                    ConvertPptxToPdfUsingLibreOffice(filePath);
                    pageCount = CountPptxSlides(filePath);
                }

                // Di chuyển PDF đã convert (nếu có) - cho DOCX và PPTX
                if (fileExtension == ".docx" || fileExtension == ".pptx")
                {
                    var tempPdfPath = Path.ChangeExtension(filePath, ".pdf");
                    if (System.IO.File.Exists(tempPdfPath))
                    {
                        // PDF đã ở đúng vị trí, không cần move
                        _logger.LogInformation($"Converted PDF ready: {Path.GetFileName(tempPdfPath)}");
                    }
                }

                // Lưu vào database ngay
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                var document = new PTVBTPM.Models.Entities.Document
                {
                    UserId = userId.Value,
                    FileName = file.FileName,
                    FileType = fileExtension,
                    FileSize = file.Length,
                    PageCount = pageCount,
                    UploadPath = $"DocumentUploads/{fileName}",
                    Status = "UPLOADED",
                    CreatedOn = now,
                    ModifiedOn = now
                };

                _context.Documents.Add(document);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Saved document to DB: DocumentId={document.DocumentId}, FileName={file.FileName}");

                var response = new UploadDocumentResponseDto
                {
                    DocumentId = document.DocumentId, // Trả về DocumentId đã lưu DB
                    FileName = file.FileName,
                    FileType = fileExtension,
                    FileSize = file.Length,
                    FileSizeMB = Math.Round(file.Length / (1024.0 * 1024.0), 2),
                    PageCount = pageCount,
                    FileUrl = $"DocumentUploads/{fileName}",
                    CreatedOn = document.CreatedOn,
                    TempFileName = null // Không cần temp file nữa
                };

                return Ok(new
                {
                    success = true,
                    message = "Upload file thành công.",
                    data = response
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error uploading document");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi upload file.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Kiểm tra trạng thái conversion của document (cho DOCX -> PDF)
        /// </summary>
        [HttpGet("Status")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        public async Task<IActionResult> GetDocumentStatus([FromQuery] int documentId)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                if (documentId <= 0)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "documentId là bắt buộc và phải lớn hơn 0."
                    });
                }

                // Lấy document từ database
                var document = await _context.Documents
                    .FirstOrDefaultAsync(d => d.DocumentId == documentId && d.UserId == userId);
                
                if (document == null)
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "Không tìm thấy tài liệu."
                    });
                }

                // Lấy file path từ UploadPath hoặc tạo từ FileName
                string filePath;
                if (!string.IsNullOrWhiteSpace(document.UploadPath))
                {
                    filePath = document.UploadPath;
                }
                else
                {
                    // Fallback: tìm file trong upload folder
                    var uploadFolder = Path.Combine(_environment.WebRootPath, "uploads", userId.ToString() ?? "0");
                    filePath = Path.Combine(uploadFolder, document.FileName);
                }

                // Kiểm tra file có tồn tại không
                if (!System.IO.File.Exists(filePath))
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "File không tồn tại trên server."
                    });
                }

                var fileExtension = Path.GetExtension(document.FileName).ToLowerInvariant();

                // Nếu là PDF thì luôn ready
                if (fileExtension == ".pdf")
                {
                    // Đếm số trang thực tế
                    int? pageCount = null;
                    try
                    {
                        pageCount = CountPdfPages(filePath);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Error counting pages for PDF: {filePath}");
                    }
                    
                    return Ok(new
                    {
                        success = true,
                        status = "ready",
                        totalPages = pageCount,
                        message = "PDF file đã sẵn sàng để preview."
                    });
                }

                // Nếu là DOCX, kiểm tra PDF đã được convert chưa
                if (fileExtension == ".docx")
                {
                    var pdfPath = Path.ChangeExtension(filePath, ".pdf");
                    if (System.IO.File.Exists(pdfPath))
                    {
                        // Kiểm tra file PDF có hợp lệ không (size > 0)
                        var pdfInfo = new FileInfo(pdfPath);
                        if (pdfInfo.Length > 0)
                        {
                            // Đếm số trang thực tế
                            int? pageCount = null;
                            try
                            {
                                pageCount = CountPdfPages(pdfPath);
                            }
                            catch (Exception ex)
                            {
                                _logger.LogWarning(ex, $"Error counting pages for PDF: {pdfPath}");
                            }
                            
                            return Ok(new
                            {
                                success = true,
                                status = "ready",
                                totalPages = pageCount,
                                message = "PDF đã được convert thành công."
                            });
                        }
                        else
                        {
                            // PDF file rỗng hoặc đang được tạo
                            return Ok(new
                            {
                                success = true,
                                status = "processing",
                                message = "PDF đang được tạo..."
                            });
                        }
                    }
                    else
                    {
                        // PDF chưa được tạo - đang convert hoặc chưa bắt đầu
                        return Ok(new
                        {
                            success = true,
                            status = "processing",
                            message = "Đang xử lý conversion DOCX sang PDF..."
                        });
                    }
                }

                // Các file type khác (PPTX) không cần conversion
                return Ok(new
                {
                    success = true,
                    status = "ready",
                    message = "File đã sẵn sàng."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking document status");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi kiểm tra trạng thái.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Lấy danh sách khổ giấy có sẵn
        /// </summary>
        [HttpGet("PaperSizes")]
        [ProducesResponseType(200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetPaperSizes()
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                var paperSizes = await _context.PaperSizes
                    .Select(p => new PaperSizeDto
                    {
                        PaperSizeId = p.PaperSizeId,
                        Code = p.Code,
                        Description = p.Description,
                        Price = p.Price
                    })
                    .OrderBy(p => p.Code)
                    .ToListAsync();

                return Ok(new
                {
                    success = true,
                    data = paperSizes
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting paper sizes");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi lấy danh sách khổ giấy.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Lấy danh sách tài liệu đã upload của user
        /// </summary>
        [HttpGet("MyDocuments")]
        [ProducesResponseType(200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetMyDocuments()
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                var documents = await _context.Documents
                    .Where(d => d.UserId == userId)
                    .OrderByDescending(d => d.CreatedOn)
                    .Select(d => new UploadDocumentResponseDto
                    {
                        DocumentId = d.DocumentId,
                        FileName = d.FileName,
                        FileType = d.FileType,
                        FileSize = d.FileSize,
                        PageCount = d.PageCount,
                        FileUrl = !string.IsNullOrEmpty(d.UploadPath) ? UrlHelper.GetFileUrl(d.UploadPath) : null,
                        CreatedOn = d.CreatedOn
                    })
                    .ToListAsync();

                return Ok(new
                {
                    success = true,
                    data = documents
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting my documents");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi lấy danh sách tài liệu.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Xóa tài liệu đã upload của user
        /// </summary>
        [HttpDelete("MyDocuments/{documentId}")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> DeleteMyDocument(int documentId)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                // Tìm document
                var document = await _context.Documents
                    .FirstOrDefaultAsync(d => d.DocumentId == documentId && d.UserId == userId);

                if (document == null)
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "Không tìm thấy tài liệu hoặc bạn không có quyền xóa tài liệu này."
                    });
                }

                // Kiểm tra xem có PrintJob nào đang sử dụng document này không
                var hasPrintJobs = await _context.PrintJobs
                    .AnyAsync(j => j.DocumentId == documentId);

                if (hasPrintJobs)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Không thể xóa tài liệu này vì đã có đơn in sử dụng tài liệu này."
                    });
                }

                // Xóa file vật lý
                if (!string.IsNullOrEmpty(document.UploadPath))
                {
                    try
                    {
                        var uploadsFolder = Path.Combine(_environment.WebRootPath ?? _environment.ContentRootPath, "DocumentUploads");
                        var filePath = Path.Combine(uploadsFolder, Path.GetFileName(document.UploadPath.Replace("DocumentUploads/", "")));
                        
                        if (System.IO.File.Exists(filePath))
                        {
                            System.IO.File.Delete(filePath);
                            _logger.LogInformation($"Deleted physical file: {filePath}");
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Failed to delete physical file: {document.UploadPath}");
                        // Tiếp tục xóa record trong DB dù file vật lý không xóa được
                    }
                }

                // Xóa record trong database
                _context.Documents.Remove(document);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Deleted document: DocumentId={documentId}, FileName={document.FileName}");

                return Ok(new
                {
                    success = true,
                    message = "Đã xóa tài liệu thành công."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting document");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi xóa tài liệu.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Tạo print job với các tùy chọn in
        /// </summary>
        [HttpPost("CreatePrintJob")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> CreatePrintJob([FromBody] CreatePrintJobRequestDto request)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                // Validate request
                if (request.Copies < 1 || request.Copies > 100)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Số bản in phải từ 1 đến 100."
                    });
                }

                // Lấy document từ DB (file đã được lưu khi upload)
                if (request.DocumentId <= 0)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "DocumentId không hợp lệ."
                    });
                }

                var document = await _context.Documents
                    .FirstOrDefaultAsync(d => d.DocumentId == request.DocumentId && d.UserId == userId);
                
                if (document == null)
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "Không tìm thấy tài liệu hoặc bạn không có quyền truy cập."
                    });
                }

                int? pageCount = document.PageCount;

                // Kiểm tra printer tồn tại và status AVAILABLE
                var printer = await _context.Printers.FindAsync(request.PrinterId);
                if (printer == null)
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "Không tìm thấy máy in."
                    });
                }

                // Kiểm tra số job đang chờ in cho máy in này (tối đa 5)
                var pendingJobsCount = await _context.PrintJobs
                    .Where(j => j.PrinterId == request.PrinterId && j.Status == "PENDING")
                    .CountAsync();

                if (pendingJobsCount >= 5)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = $"Máy in đang có quá nhiều job trong hàng chờ (tối đa 5). Vui lòng chọn máy in khác hoặc thử lại sau."
                    });
                }

                // Kiểm tra paper size tồn tại
                var paperSize = await _context.PaperSizes.FindAsync(request.PaperSizeId);
                if (paperSize == null)
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "Không tìm thấy khổ giấy."
                    });
                }

                // Tính số trang sẽ in
                int totalPages = 0;
                if (string.IsNullOrWhiteSpace(request.PagesToPrint) || request.PagesToPrint.ToLower() == "all")
                {
                    // In tất cả các trang
                    totalPages = pageCount ?? 0;
                }
                else
                {
                    // Parse pages to print (ví dụ: "1-5,10,15-20")
                    totalPages = ParsePagesToPrint(request.PagesToPrint, pageCount ?? 0);
                }

                if (totalPages <= 0)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Số trang in không hợp lệ."
                    });
                }

                // Tính số trang thực tế (tính cả double-sided)
                int actualPages = totalPages;
                if (request.IsDoubleSided)
                {
                    // Double-sided: số trang thực tế = ceil(totalPages / 2)
                    actualPages = (int)Math.Ceiling(totalPages / 2.0);
                }

                // Quy đổi khổ giấy: A3 = 2x A4
                var paperSizeCode = paperSize.Code.ToUpper();
                int pageMultiplier = 1;
                if (paperSizeCode == "A3")
                {
                    pageMultiplier = 2; // 1 trang A3 = 2 trang A4
                }
                // A4 và các khổ khác = 1

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
                    return NotFound(new
                    {
                        success = false,
                        message = "Không tìm thấy người dùng."
                    });
                }

                // Tính số trang cần thiết (đã quy đổi về A4) * số bản
                var totalPagesNeeded = equivalentA4Pages * request.Copies;

                // Kiểm tra tổng trang sở hữu
                var pageBalance = user.PageDefaultBalance + user.PagePurchasedBalance;
                if (totalPagesNeeded > pageBalance)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = $"Số trang còn lại không đủ. Bạn còn {pageBalance} trang, cần {totalPagesNeeded} trang."
                    });
                }

                // Tạo print job
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                
                // Lưu thông tin double-sided vào PagesToPrint với format: "PAGES|DOUBLE_SIDED" hoặc "DOUBLE_SIDED"
                string? pagesToPrintValue = request.PagesToPrint;
                if (request.IsDoubleSided)
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

                // Nếu là file mới upload (DocumentId = 0), dùng DocumentId từ document đã lưu DB
                int finalDocumentId = request.DocumentId;
                if (request.DocumentId == 0 && document != null)
                {
                    finalDocumentId = document.DocumentId;
                }

                var printJob = new PrintJob
                {
                    UserId = userId,
                    DocumentId = finalDocumentId,
                    PrinterId = request.PrinterId,
                    PaperSizeId = request.PaperSizeId,
                    Copies = request.Copies,
                    IsColor = request.IsColor,
                    PagesToPrint = pagesToPrintValue,
                    TotalPages = equivalentA4Pages, // Lưu số trang A4 tương đương để trừ page balance
                    Status = "PENDING",
                    CreatedOn = now,
                    ModifiedOn = now
                };

                _context.PrintJobs.Add(printJob);
                await _context.SaveChangesAsync();

                // Tự động execute print job nếu máy in AVAILABLE và không có job nào đang PRINTING
                // Và không có job DONE trong 1 phút gần đây (để tránh race condition với làm lạnh)
                var currentPrinter = await _context.Printers.FindAsync(request.PrinterId);
                var hasPrintingJob = await _context.PrintJobs
                    .AnyAsync(j => j.PrinterId == request.PrinterId && j.Status == "PRINTING" && j.PrintJobId != printJob.PrintJobId);

                // Kiểm tra có job DONE trong 1 phút gần đây không (để đảm bảo máy in đã làm lạnh xong)
                var recentDoneJob = await _context.PrintJobs
                    .Where(j => j.PrinterId == request.PrinterId && j.Status == "DONE" && j.CompletedAt.HasValue)
                    .OrderByDescending(j => j.CompletedAt)
                    .FirstOrDefaultAsync();

                var hasRecentDoneJob = recentDoneJob != null &&
                    (DateTime.UtcNow - recentDoneJob.CompletedAt.Value).TotalSeconds < 60;

                Console.WriteLine($"[CreatePrintJob] Printer {request.PrinterId} status: {currentPrinter?.Status}, hasPrintingJob: {hasPrintingJob}, hasRecentDoneJob: {hasRecentDoneJob}");

                if (currentPrinter?.Status == "AVAILABLE" && !hasPrintingJob && !hasRecentDoneJob)
                {
                    // Máy in sẵn sàng và không có job đang in, tự động execute
                    try
                    {
                        // Reload printJob với PaperSize để tính toán
                        await _context.Entry(printJob)
                            .Reference(p => p.PaperSize)
                            .LoadAsync();
                        
                        printJob.Status = "PRINTING";
                        printJob.ModifiedOn = now;
                        printJob.ModifiedBy = userId?.ToString();
                        
                        // Cập nhật máy in status → BUSY (đang in và sẽ làm lạnh)
                        if (printer != null)
                        {
                            printer.Status = "BUSY";
                            printer.ModifiedOn = now;
                        }
                        
                        await _context.SaveChangesAsync();
                        
                        _logger.LogInformation($"Auto-executed print job {printJob.PrintJobId} on printer {request.PrinterId} - printer was idle");

                        // Gửi SignalR notifications
                        await SendPrintJobStatusUpdateAsync(printJob, now);
                        if (printer != null)
                        {
                            await SendPrinterStatusUpdateAsync(printer, now);
                        }
                    }
                    catch (Exception ex)
                    {
                        // Nếu auto-execute fail, vẫn giữ status PENDING
                        _logger.LogWarning(ex, $"Failed to auto-execute print job {printJob.PrintJobId}, keeping status PENDING");
                        // Reload printJob để có status đúng
                        await _context.Entry(printJob).ReloadAsync();
                    }
                }
                else
                {
                    Console.WriteLine($"[CreatePrintJob] Job {printJob.PrintJobId} stays PENDING - printer status: {currentPrinter?.Status}, hasPrintingJob: {hasPrintingJob}");
                }

                // Parse lại PagesToPrint để loại bỏ |DOUBLE_SIDED
                string? cleanPagesToPrint = request.PagesToPrint;
                if (string.IsNullOrWhiteSpace(cleanPagesToPrint) || cleanPagesToPrint.ToLower() == "all")
                {
                    cleanPagesToPrint = "all";
                }

                // Reload để có status mới nhất
                await _context.Entry(printJob).ReloadAsync();

                var response = new CreatePrintJobResponseDto
                {
                    PrintJobId = printJob.PrintJobId,
                    DocumentId = printJob.DocumentId ?? 0,
                    PrinterId = printJob.PrinterId ?? 0,
                    Status = printJob.Status,
                    TotalPages = printJob.TotalPages,
                    Copies = printJob.Copies ?? 1,
                    IsColor = printJob.IsColor,
                    IsDoubleSided = request.IsDoubleSided,
                    PagesToPrint = cleanPagesToPrint,
                    CreatedOn = printJob.CreatedOn
                };

                return Ok(new
                {
                    success = true,
                    message = printJob.Status == "PRINTING" 
                        ? "Tạo job in thành công và đã tự động bắt đầu in." 
                        : "Tạo job in thành công.",
                    data = response
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating print job");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi tạo job in.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Xóa file tạm nếu user không tạo print job
        /// </summary>
        [HttpPost("CleanupTempFile")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> CleanupTempFile([FromBody] CleanupTempFileRequest request)
        {
            try
            {
                // Method này có thể mở rộng để làm async trong tương lai
                await Task.CompletedTask;
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                if (string.IsNullOrEmpty(request.TempFileName))
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Tên file không hợp lệ."
                    });
                }

                // File tạm được lưu trong system temp folder
                var tempFolder = Path.Combine(Path.GetTempPath(), "PTVBTPM", "Uploads");
                var tempFilePath = Path.Combine(tempFolder, request.TempFileName);

                // Xóa file gốc
                bool deleted = false;
                if (System.IO.File.Exists(tempFilePath))
                {
                    try
                    {
                        System.IO.File.Delete(tempFilePath);
                        deleted = true;
                        _logger.LogInformation($"Deleted temp file: {request.TempFileName}");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Failed to delete temp file: {request.TempFileName}");
                    }
                }

                // Xóa PDF đã convert (nếu có)
                var fileExtension = Path.GetExtension(request.TempFileName).ToLowerInvariant();
                if (fileExtension == ".docx" || fileExtension == ".pptx")
                {
                    var tempPdfPath = Path.ChangeExtension(tempFilePath, ".pdf");
                    if (System.IO.File.Exists(tempPdfPath))
                    {
                        try
                        {
                            System.IO.File.Delete(tempPdfPath);
                            _logger.LogInformation($"Deleted temp PDF: {Path.GetFileName(tempPdfPath)}");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, $"Failed to delete temp PDF: {tempPdfPath}");
                        }
                    }
                }

                return Ok(new
                {
                    success = true,
                    message = "Đã xóa file tạm.",
                    deleted = deleted
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error cleaning up temp file");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi xóa file tạm.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Xem preview một trang cụ thể của document (trả về image PNG)
        /// </summary>
        [HttpGet("Preview")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> PreviewDocumentPage(
            [FromQuery] int? documentId = null,
            [FromQuery] string? tempFileName = null,
            [FromQuery] int page = 1,
            [FromQuery] int? slidesPerPage = null) // Cho PPTX: 1, 2, 4, 6, 8 slide per page
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = "Vui lòng đăng nhập trước."
                    });
                }

                if (page < 1)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Số trang phải lớn hơn 0."
                    });
                }

                string? filePath = null;
                string? pdfPath = null;
                int? totalPages = null;

                // Lấy file path từ DocumentId hoặc TempFileName
                if (documentId.HasValue && documentId > 0)
                {
                    var document = await _context.Documents
                        .FirstOrDefaultAsync(d => d.DocumentId == documentId.Value && d.UserId == userId);
                    
                    if (document == null)
                    {
                        return NotFound(new
                        {
                            success = false,
                            message = "Không tìm thấy tài liệu hoặc bạn không có quyền truy cập."
                        });
                    }

                    filePath = Path.Combine(_environment.WebRootPath, document.UploadPath ?? "");
                    totalPages = document.PageCount;
                    
                    if (!System.IO.File.Exists(filePath))
                    {
                        return NotFound(new
                        {
                            success = false,
                            message = "File không tồn tại trên server."
                        });
                    }
                }
                else if (!string.IsNullOrEmpty(tempFileName))
                {
                    // File tạm được lưu trong system temp folder
                    var tempFolder = Path.Combine(Path.GetTempPath(), "PTVBTPM", "Uploads");
                    filePath = Path.Combine(tempFolder, tempFileName);
                    
                    if (!System.IO.File.Exists(filePath))
                    {
                        return NotFound(new
                        {
                            success = false,
                            message = "File tạm không tồn tại."
                        });
                    }
                }
                else
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Cần cung cấp documentId hoặc tempFileName."
                    });
                }

                // Kiểm tra số trang
                var fileExtension = Path.GetExtension(filePath).ToLowerInvariant();
                
                // Lấy PDF path (nếu là DOCX thì cần convert hoặc lấy PDF đã convert)
                if (fileExtension == ".pdf")
                {
                    pdfPath = filePath;
                    if (totalPages == null)
                    {
                        totalPages = CountPdfPages(pdfPath);
                    }
                }
                else if (fileExtension == ".docx")
                {
                    // Tìm PDF đã convert (cùng thư mục, cùng tên, extension .pdf)
                    pdfPath = Path.ChangeExtension(filePath, ".pdf");
                    
                    if (!System.IO.File.Exists(pdfPath))
                    {
                        // FIX: Không convert ngay trong Preview API - trả 202 Accepted với status "processing"
                        // Frontend sẽ gọi Status API để check và retry
                        _logger.LogInformation($"PDF not found for DOCX, returning processing status. File: {filePath}");
                        
                        return StatusCode(202, new
                        {
                            success = false,
                            status = "processing",
                            message = "File đang được xử lý (convert sang PDF). Vui lòng thử lại sau hoặc kiểm tra trạng thái qua API Status."
                        });
                    }
                    
                    if (totalPages == null)
                    {
                        totalPages = CountPdfPages(pdfPath);
                    }
                }
                else if (fileExtension == ".pptx")
                {
                    // PPTX: Sử dụng PDF cơ bản đã convert khi upload (1 slide per page)
                    // Nếu slidesPerPage = 1, dùng PDF đã có. Nếu khác, vẫn dùng PDF cơ bản (LibreOffice không hỗ trợ slides per page trong command line)
                    pdfPath = Path.ChangeExtension(filePath, ".pdf");
                    
                    if (!System.IO.File.Exists(pdfPath))
                    {
                        // PDF chưa được convert - có thể đang xử lý
                        _logger.LogInformation($"PDF not found for PPTX, returning processing status. File: {filePath}");
                        
                        return StatusCode(202, new
                        {
                            success = false,
                            status = "processing",
                            message = "File đang được xử lý (convert PPTX sang PDF). Vui lòng thử lại sau."
                        });
                    }
                    
                    // PPTX với slides per page: tổng số trang = số slide / slidesPerPage
                    int totalSlides = CountPptxSlides(filePath);
                    int slidesPerPageValue = slidesPerPage ?? 1;
                    totalPages = (int)Math.Ceiling((double)totalSlides / slidesPerPageValue);
                }
                else
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Chỉ hỗ trợ preview file PDF, DOCX và PPTX."
                    });
                }

                // FIX: Kiểm tra page có hợp lệ không - nhưng nếu > totalPages thì vẫn thử render
                // (vì có thể có trang ảo, số trang thực tế có thể ít hơn totalPages)

                // Extract trang cụ thể từ PDF và convert sang PNG
                var previewImage = await ExtractPdfPageAsImageAsync(pdfPath, page);
                if (previewImage == null || previewImage.Length == 0)
                {
                    // FIX: Trang không có nội dung hoặc không tồn tại (trang ảo)
                    string libreOfficePath = FindLibreOfficePath();
                    if (string.IsNullOrEmpty(libreOfficePath))
                    {
                        return NotFound(new
                        {
                            success = false,
                            message = $"Trang {page} không tồn tại hoặc không có nội dung. LibreOffice không được cài đặt trên server."
                        });
                    }
                    
                    // Kiểm tra xem có phải do trang không tồn tại không
                    if (totalPages.HasValue && page > totalPages.Value)
                    {
                        return NotFound(new
                        {
                            success = false,
                            message = $"Trang {page} không tồn tại hoặc không có nội dung (tổng số trang: {totalPages.Value})."
                        });
                    }
                    
                    return NotFound(new
                    {
                        success = false,
                        message = $"Trang {page} không tồn tại hoặc không có nội dung."
                    });
                }

                return File(previewImage, "image/png", $"page_{page}.png");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating document preview");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi tạo preview.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Extract một trang từ PDF và convert sang PNG image
        /// </summary>
        private async Task<byte[]?> ExtractPdfPageAsImageAsync(string pdfPath, int pageNumber)
        {
            try
            {
                // Sử dụng LibreOffice để convert PDF page sang PNG
                // LibreOffice có thể export một trang cụ thể từ PDF sang image
                string libreOfficePath = FindLibreOfficePath();
                if (string.IsNullOrEmpty(libreOfficePath))
                {
                    _logger.LogWarning($"LibreOffice not found, cannot extract PDF page as image. PDF: {pdfPath}, Page: {pageNumber}");
                    _logger.LogWarning("Please install LibreOffice to enable PDF preview functionality.");
                    _logger.LogWarning("Windows: Download from https://www.libreoffice.org/download/");
                    _logger.LogWarning("Linux: sudo apt-get install libreoffice");
                    return null;
                }

                // Tạo temp output file cho image
                var tempOutputDir = Path.Combine(Path.GetTempPath(), "Preview", Guid.NewGuid().ToString());
                Directory.CreateDirectory(tempOutputDir);
                
                var outputImagePath = Path.Combine(tempOutputDir, $"page_{pageNumber}.png");

                // LibreOffice command để export PDF page sang PNG
                // Format: --headless --convert-to png --outdir <output> <pdf_file>
                // Note: LibreOffice không hỗ trợ extract một trang cụ thể trực tiếp,
                // nên ta cần extract tất cả trang rồi lấy trang cần thiết
                // Hoặc dùng thư viện PDF khác để extract page trước, rồi convert sang PNG

                // Cách 1: Extract page từ PDF bằng PdfSharpCore trước, rồi convert sang PNG
                var singlePagePdfPath = ExtractSinglePageFromPdf(pdfPath, pageNumber, tempOutputDir);
                if (string.IsNullOrEmpty(singlePagePdfPath) || !System.IO.File.Exists(singlePagePdfPath))
                {
                    _logger.LogError($"Failed to extract page {pageNumber} from PDF: {pdfPath}");
                    return null;
                }
                
                _logger.LogDebug($"Extracted single page PDF: {singlePagePdfPath}");

                // Convert PDF page sang PNG bằng LibreOffice
                var processStartInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = libreOfficePath,
                    Arguments = $"--headless --nodefault --nolockcheck --convert-to png \"{singlePagePdfPath}\" --outdir \"{tempOutputDir}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = tempOutputDir
                };

                // Set environment variables như trong ConvertDocxToPdfUsingLibreOffice
                if (!System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
                {
                    string? homeDir = Environment.GetEnvironmentVariable("HOME");
                    if (!string.IsNullOrEmpty(homeDir) && !processStartInfo.EnvironmentVariables.ContainsKey("HOME"))
                    {
                        processStartInfo.EnvironmentVariables["HOME"] = homeDir;
                    }

                    string? currentPath = Environment.GetEnvironmentVariable("PATH");
                    if (!string.IsNullOrEmpty(currentPath) && !processStartInfo.EnvironmentVariables.ContainsKey("PATH"))
                    {
                        processStartInfo.EnvironmentVariables["PATH"] = currentPath;
                    }

                    if (processStartInfo.EnvironmentVariables.ContainsKey("DISPLAY"))
                    {
                        processStartInfo.EnvironmentVariables.Remove("DISPLAY");
                    }
                }

                using (var process = System.Diagnostics.Process.Start(processStartInfo))
                {
                    if (process != null)
                    {
                        // Đọc output và error để debug
                        string? stdOutput = null;
                        string? stdError = null;
                        
                        try
                        {
                            stdOutput = await process.StandardOutput.ReadToEndAsync();
                            stdError = await process.StandardError.ReadToEndAsync();
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Error reading LibreOffice process output");
                        }

                        bool exited = process.WaitForExit(60000); // Timeout 60 giây cho PDF lớn
                        
                        if (!exited)
                        {
                            process.Kill();
                            _logger.LogError($"LibreOffice conversion to PNG timeout. PDF: {pdfPath}, Page: {pageNumber}");
                            if (!string.IsNullOrEmpty(stdError))
                            {
                                _logger.LogError($"LibreOffice stderr: {stdError}");
                            }
                            return null;
                        }

                        if (process.ExitCode != 0)
                        {
                            _logger.LogError($"LibreOffice conversion failed with exit code {process.ExitCode}. PDF: {pdfPath}, Page: {pageNumber}");
                            if (!string.IsNullOrEmpty(stdError))
                            {
                                _logger.LogError($"LibreOffice stderr: {stdError}");
                            }
                            if (!string.IsNullOrEmpty(stdOutput))
                            {
                                _logger.LogError($"LibreOffice stdout: {stdOutput}");
                            }
                            return null;
                        }

                        // LibreOffice sẽ tạo file PNG với tên giống PDF (không có extension)
                        var generatedPngPath = Path.ChangeExtension(singlePagePdfPath, ".png");
                        if (!System.IO.File.Exists(generatedPngPath))
                        {
                            // Thử tìm file PNG với các pattern khác
                            var baseName = Path.GetFileNameWithoutExtension(singlePagePdfPath);
                            generatedPngPath = Path.Combine(tempOutputDir, $"{baseName}.png");
                            if (!System.IO.File.Exists(generatedPngPath))
                            {
                                // Thử tìm tất cả file PNG trong thư mục
                                var pngFiles = Directory.GetFiles(tempOutputDir, "*.png");
                                if (pngFiles.Length > 0)
                                {
                                    generatedPngPath = pngFiles[0];
                                    _logger.LogDebug($"Found PNG file: {generatedPngPath}");
                                }
                                else
                                {
                                    _logger.LogError($"Generated PNG file not found in {tempOutputDir}. LibreOffice may have failed to convert.");
                                    if (!string.IsNullOrEmpty(stdError))
                                    {
                                        _logger.LogError($"LibreOffice stderr: {stdError}");
                                    }
                                    return null;
                                }
                            }
                        }

                        // Kiểm tra file PNG có hợp lệ không
                        var fileInfo = new FileInfo(generatedPngPath);
                        if (fileInfo.Length == 0)
                        {
                            _logger.LogError($"Generated PNG file is empty: {generatedPngPath}");
                            return null;
                        }

                        // Đọc image data
                        var imageData = await System.IO.File.ReadAllBytesAsync(generatedPngPath);
                        
                        _logger.LogDebug($"Successfully converted PDF page {pageNumber} to PNG. Size: {imageData.Length} bytes");
                        
                        // Cleanup temp files
                        try
                        {
                            if (System.IO.File.Exists(singlePagePdfPath))
                                System.IO.File.Delete(singlePagePdfPath);
                            if (System.IO.File.Exists(generatedPngPath))
                                System.IO.File.Delete(generatedPngPath);
                            if (Directory.Exists(tempOutputDir))
                                Directory.Delete(tempOutputDir, true);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Error cleaning up temp files");
                        }

                        return imageData;
                    }
                    else
                    {
                        _logger.LogError("Failed to start LibreOffice process");
                        return null;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error extracting PDF page as image");
                return null;
            }
        }

        /// <summary>
        /// Extract một trang cụ thể từ PDF bằng PdfSharpCore
        /// </summary>
        private string? ExtractSinglePageFromPdf(string pdfPath, int pageNumber, string outputDir)
        {
            try
            {
                // Kiểm tra file PDF tồn tại
                if (!System.IO.File.Exists(pdfPath))
                {
                    _logger.LogError($"PDF file not found: {pdfPath}");
                    return null;
                }

                using (var sourceDocument = PdfReader.Open(pdfPath, PdfDocumentOpenMode.Import))
                {
                    if (pageNumber < 1 || pageNumber > sourceDocument.PageCount)
                    {
                        _logger.LogWarning($"Page number {pageNumber} out of range (total: {sourceDocument.PageCount})");
                        return null;
                    }

                    // Tạo PDF mới chỉ chứa 1 trang
                    var newDocument = new PdfDocument();
                    try
                    {
                        newDocument.AddPage(sourceDocument.Pages[pageNumber - 1]);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Error adding page {pageNumber} to new document");
                        newDocument.Close();
                        return null;
                    }

                    var outputPath = Path.Combine(outputDir, $"page_{pageNumber}_extracted.pdf");
                    
                    // Đảm bảo output directory tồn tại
                    if (!Directory.Exists(outputDir))
                    {
                        Directory.CreateDirectory(outputDir);
                    }

                    try
                    {
                        newDocument.Save(outputPath);
                        newDocument.Close();

                        // Kiểm tra file đã được tạo thành công
                        if (System.IO.File.Exists(outputPath) && new FileInfo(outputPath).Length > 0)
                        {
                            _logger.LogDebug($"Successfully extracted page {pageNumber} to {outputPath}");
                            return outputPath;
                        }
                        else
                        {
                            _logger.LogError($"Extracted PDF file is empty or not created: {outputPath}");
                            return null;
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Error saving extracted PDF page: {outputPath}");
                        newDocument.Close();
                        return null;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error extracting single page from PDF: {pdfPath}, Page: {pageNumber}");
                return null;
            }
        }

        /// <summary>
        /// Di chuyển file từ system temp folder sang DocumentUploads và lưu vào DB
        /// </summary>
        private async Task<PTVBTPM.Models.Entities.Document?> MoveTempFileToUploadsAndSaveToDb(string tempFileName, int userId)
        {
            try
            {
                // File tạm được lưu trong system temp folder
                var tempFolder = Path.Combine(Path.GetTempPath(), "PTVBTPM", "Uploads");
                var documentUploadsFolder = Path.Combine(_environment.WebRootPath, "DocumentUploads");
                
                // Đảm bảo thư mục DocumentUploads tồn tại
                if (!Directory.Exists(documentUploadsFolder))
                {
                    Directory.CreateDirectory(documentUploadsFolder);
                }

                var tempFilePath = Path.Combine(tempFolder, tempFileName);
                
                // Kiểm tra file tạm tồn tại
                if (!System.IO.File.Exists(tempFilePath))
                {
                    _logger.LogWarning($"Temp file not found: {tempFilePath}");
                    return null;
                }

                // Lấy thông tin file
                var fileInfo = new System.IO.FileInfo(tempFilePath);
                var fileExtension = Path.GetExtension(tempFileName).ToLowerInvariant();
                
                // Lấy original filename (bỏ Guid_ prefix)
                var originalFileName = tempFileName;
                if (tempFileName.Contains('_'))
                {
                    var parts = tempFileName.Split('_', 2);
                    if (parts.Length > 1)
                    {
                        originalFileName = parts[1];
                    }
                }

                // Đếm số trang trước khi di chuyển
                int? pageCount = null;
                if (fileExtension == ".pdf")
                {
                    pageCount = CountPdfPages(tempFilePath);
                }
                else if (fileExtension == ".docx")
                {
                    pageCount = CountDocxPages(tempFilePath);
                }
                else if (fileExtension == ".pptx")
                {
                    // Convert PPTX sang PDF ngay khi upload (giống DOCX)
                    // PDF cơ bản với 1 slide per page để preview nhanh
                    ConvertPptxToPdfUsingLibreOffice(tempFilePath);
                    pageCount = CountPptxSlides(tempFilePath);
                }

                // COPY file từ system temp folder sang DocumentUploads (không MOVE để tránh mất file nếu có lỗi)
                var finalFilePath = Path.Combine(documentUploadsFolder, tempFileName);
                System.IO.File.Copy(tempFilePath, finalFilePath, overwrite: true);
                _logger.LogInformation($"Copied file from system temp folder to DocumentUploads: {tempFileName}");

                // COPY PDF đã convert (nếu có) - cho DOCX và PPTX
                if (fileExtension == ".docx" || fileExtension == ".pptx")
                {
                    var tempPdfPath = Path.ChangeExtension(tempFilePath, ".pdf");
                    if (System.IO.File.Exists(tempPdfPath))
                    {
                        var finalPdfPath = Path.ChangeExtension(finalFilePath, ".pdf");
                        System.IO.File.Copy(tempPdfPath, finalPdfPath, overwrite: true);
                        _logger.LogInformation($"Copied converted PDF: {Path.GetFileName(finalPdfPath)}");
                    }
                }

                // Lưu vào database
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                var document = new PTVBTPM.Models.Entities.Document
                {
                    UserId = userId,
                    FileName = originalFileName,
                    FileType = fileExtension,
                    FileSize = fileInfo.Length,
                    PageCount = pageCount,
                    UploadPath = $"DocumentUploads/{tempFileName}",
                    Status = "UPLOADED",
                    CreatedOn = now,
                    ModifiedOn = now
                };

                _context.Documents.Add(document);
                await _context.SaveChangesAsync();

                _logger.LogInformation($"Saved document to DB: DocumentId={document.DocumentId}, FileName={originalFileName}");
                
                // Sau khi lưu DB thành công, mới xóa file temp
                try
                {
                    System.IO.File.Delete(tempFilePath);
                    _logger.LogInformation($"Deleted temp file after successful save: {tempFileName}");
                    
                    // Xóa PDF temp nếu có
                    if (fileExtension == ".docx" || fileExtension == ".pptx")
                    {
                        var tempPdfPath = Path.ChangeExtension(tempFilePath, ".pdf");
                        if (System.IO.File.Exists(tempPdfPath))
                        {
                            System.IO.File.Delete(tempPdfPath);
                            _logger.LogInformation($"Deleted temp PDF after successful save: {Path.GetFileName(tempPdfPath)}");
                        }
                    }
                }
                catch (Exception deleteEx)
                {
                    // Log warning nhưng không throw - file đã được copy và lưu DB thành công
                    _logger.LogWarning(deleteEx, $"Failed to delete temp file after save: {tempFileName}");
                }
                
                return document;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error moving temp file to uploads: {tempFileName}");
                return null;
            }
        }

        /// <summary>
        /// Đếm số trang trong file DOCX bằng cách convert sang PDF rồi đếm (sử dụng LibreOffice)
        /// </summary>
        private int CountDocxPages(string filePath)
        {
            try
            {
                // Cách 1: Sử dụng LibreOffice để convert DOCX → PDF (chính xác nhất)
                string? pdfPath = ConvertDocxToPdfUsingLibreOffice(filePath);
                if (!string.IsNullOrEmpty(pdfPath) && System.IO.File.Exists(pdfPath))
                {
                    try
                    {
                        int pageCount = CountPdfPages(pdfPath);
                        
                            // KHÔNG xóa file PDF tạm - sẽ được di chuyển cùng file gốc khi tạo print job
                            // File PDF sẽ được di chuyển từ system temp folder sang DocumentUploads khi user xác nhận in
                        
                        return pageCount;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Error counting pages from converted PDF, falling back to estimation");
                    }
                }
                
                // Cách 2: Fallback - ước tính dựa trên nội dung (nếu LibreOffice không có)
                return EstimateDocxPages(filePath);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error counting DOCX pages, using estimation");
                return EstimateDocxPages(filePath);
            }
        }

        /// <summary>
        /// Convert DOCX sang PDF bằng LibreOffice
        /// </summary>
        private string? ConvertDocxToPdfUsingLibreOffice(string docxPath)
        {
            try
            {
                // Tìm đường dẫn LibreOffice
                string libreOfficePath = FindLibreOfficePath();
                if (string.IsNullOrEmpty(libreOfficePath))
                {
                    _logger.LogWarning("LibreOffice not found, skipping PDF conversion");
                    return null;
                }

                // Output PDF vào cùng thư mục với file gốc (như user đã test thành công)
                string outputDir = Path.GetDirectoryName(docxPath) ?? Path.GetTempPath();
                
                // Đảm bảo thư mục tồn tại và có quyền ghi
                if (!Directory.Exists(outputDir))
                {
                    Directory.CreateDirectory(outputDir);
                }

                // Tên file PDF output (LibreOffice tự động tạo cùng tên với extension .pdf)
                string pdfPath = Path.Combine(outputDir, Path.GetFileNameWithoutExtension(docxPath) + ".pdf");

                // Chạy LibreOffice command (format như user đã test thành công)
                var processStartInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = libreOfficePath,
                    Arguments = $"--headless --convert-to pdf \"{docxPath}\" --outdir \"{outputDir}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = outputDir
                };

                // Cấu hình environment variables để LibreOffice có thể nhận diện nhiều loại font
                // Font đã được cài vào /usr/share/fonts/truetype/custom-fonts/ trên server
                // LibreOffice sẽ tự động scan system font directories, nhưng đảm bảo environment được set đúng
                if (!System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
                {
                    // Đảm bảo HOME được set để LibreOffice có thể tìm font ở ~/.fonts (nếu có)
                    string? homeDir = Environment.GetEnvironmentVariable("HOME");
                    if (!string.IsNullOrEmpty(homeDir) && !processStartInfo.EnvironmentVariables.ContainsKey("HOME"))
                    {
                        processStartInfo.EnvironmentVariables["HOME"] = homeDir;
                        _logger.LogDebug($"Set HOME environment variable: {homeDir}");
                    }

                    // Đảm bảo PATH có các thư mục cần thiết cho fontconfig và LibreOffice
                    string? currentPath = Environment.GetEnvironmentVariable("PATH");
                    if (!string.IsNullOrEmpty(currentPath) && !processStartInfo.EnvironmentVariables.ContainsKey("PATH"))
                    {
                        processStartInfo.EnvironmentVariables["PATH"] = currentPath;
                    }

                    // Đảm bảo FONTCONFIG_PATH được set (nếu cần thiết)
                    // Font system sẽ tự động được scan từ /usr/share/fonts/, nhưng set để chắc chắn
                    if (!processStartInfo.EnvironmentVariables.ContainsKey("FONTCONFIG_PATH"))
                    {
                        // LibreOffice sử dụng fontconfig của system, không cần set FONTCONFIG_PATH
                        // Vì font đã được cài vào /usr/share/fonts/ và fc-cache đã được chạy
                    }

                    // Unset DISPLAY để đảm bảo chạy headless mode (tránh lỗi GUI)
                    if (processStartInfo.EnvironmentVariables.ContainsKey("DISPLAY"))
                    {
                        processStartInfo.EnvironmentVariables.Remove("DISPLAY");
                    }
                }

                _logger.LogInformation($"Converting DOCX to PDF: {docxPath} -> {pdfPath}");

                using (var process = System.Diagnostics.Process.Start(processStartInfo))
                {
                    if (process != null)
                    {
                        // Đọc output để debug
                        string? stdOutput = null;
                        string? stdError = null;
                        
                        process.OutputDataReceived += (sender, e) => {
                            if (!string.IsNullOrEmpty(e.Data))
                            {
                                stdOutput = e.Data;
                                _logger.LogInformation($"LibreOffice output: {e.Data}");
                            }
                        };
                        
                        process.ErrorDataReceived += (sender, e) => {
                            if (!string.IsNullOrEmpty(e.Data))
                            {
                                stdError = e.Data;
                                _logger.LogWarning($"LibreOffice error: {e.Data}");
                            }
                        };
                        
                        process.BeginOutputReadLine();
                        process.BeginErrorReadLine();
                        
                        bool exited = process.WaitForExit(60000); // Timeout 60 giây
                        
                        if (!exited)
                        {
                            process.Kill();
                            _logger.LogError("LibreOffice conversion timeout after 60 seconds");
                            return null;
                        }
                        
                        if (process.ExitCode == 0 && System.IO.File.Exists(pdfPath))
                        {
                            _logger.LogInformation($"PDF conversion successful: {pdfPath}");
                            return pdfPath;
                        }
                        else
                        {
                            _logger.LogWarning($"LibreOffice conversion failed. Exit code: {process.ExitCode}, Output: {stdOutput}, Error: {stdError}");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error converting DOCX to PDF using LibreOffice");
            }

            return null;
        }

        /// <summary>
        /// Tìm đường dẫn LibreOffice trên hệ thống (ưu tiên Linux server)
        /// </summary>
        private string FindLibreOfficePath()
        {
            // Linux/Mac (ưu tiên vì server production là Linux)
            if (!System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
            {
                var commonPaths = new[]
                {
                    "/usr/bin/libreoffice",  // Debian/Ubuntu standard path (như server của bạn)
                    "/usr/local/bin/libreoffice",
                    "/opt/libreoffice/program/soffice"
                };

                foreach (var path in commonPaths)
                {
                    if (System.IO.File.Exists(path))
                    {
                        _logger.LogInformation($"Found LibreOffice at: {path}");
                        return path;
                    }
                }

                // Tìm trong PATH
                string pathResult = FindExecutableInPath("libreoffice");
                if (!string.IsNullOrEmpty(pathResult))
                {
                    _logger.LogInformation($"Found LibreOffice in PATH: {pathResult}");
                    return pathResult;
                }
            }
            // Windows (cho development)
            else
            {
                var commonPaths = new[]
                {
                    @"C:\Program Files\LibreOffice\program\soffice.exe",
                    @"C:\Program Files (x86)\LibreOffice\program\soffice.exe",
                    @"C:\Program Files\LibreOffice 7\program\soffice.exe",
                    @"C:\Program Files\LibreOffice 6\program\soffice.exe",
                    @"C:\Program Files\LibreOffice 5\program\soffice.exe",
                    Environment.ExpandEnvironmentVariables(@"%ProgramFiles%\LibreOffice\program\soffice.exe"),
                    Environment.ExpandEnvironmentVariables(@"%ProgramFiles(x86)%\LibreOffice\program\soffice.exe")
                };

                foreach (var path in commonPaths)
                {
                    if (System.IO.File.Exists(path))
                    {
                        _logger.LogInformation($"Found LibreOffice at: {path}");
                        return path;
                    }
                }

                // Tìm trong PATH
                string pathResult = FindExecutableInPath("soffice.exe");
                if (!string.IsNullOrEmpty(pathResult))
                {
                    _logger.LogInformation($"Found LibreOffice in PATH: {pathResult}");
                    return pathResult;
                }
                
                // Tìm trong các thư mục Program Files
                try
                {
                    var programFilesPaths = new[]
                    {
                        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)
                    };

                    foreach (var programFilesPath in programFilesPaths)
                    {
                        if (Directory.Exists(programFilesPath))
                        {
                            var libreOfficeDirs = Directory.GetDirectories(programFilesPath, "LibreOffice*", SearchOption.TopDirectoryOnly);
                            foreach (var dir in libreOfficeDirs)
                            {
                                var sofficePath = Path.Combine(dir, "program", "soffice.exe");
                                if (System.IO.File.Exists(sofficePath))
                                {
                                    _logger.LogInformation($"Found LibreOffice at: {sofficePath}");
                                    return sofficePath;
                                }
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error searching for LibreOffice in Program Files");
                }
            }

            _logger.LogWarning("LibreOffice not found on system. Please install LibreOffice to enable document preview.");
            return string.Empty;
        }

        /// <summary>
        /// Track temp file trong cache để cleanup khi logout hoặc session timeout
        /// </summary>
        private void TrackTempFile(int userId, string tempFileName)
        {
            try
            {
                var cacheKey = $"TempFiles_{userId}";
                
                // Lấy danh sách temp files hiện tại từ cache
                if (!_cache.TryGetValue(cacheKey, out List<string>? tempFiles))
                {
                    tempFiles = new List<string>();
                }
                
                // Thêm file mới vào danh sách
                if (!tempFiles!.Contains(tempFileName))
                {
                    tempFiles.Add(tempFileName);
                }
                
                // Lưu lại vào cache với expiration 30 phút (matching session timeout)
                var cacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(30),
                    SlidingExpiration = TimeSpan.FromMinutes(30)
                };
                
                _cache.Set(cacheKey, tempFiles, cacheOptions);
                _logger.LogDebug($"Tracked temp file for user {userId}: {tempFileName}");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, $"Error tracking temp file: {tempFileName}");
            }
        }

        /// <summary>
        /// Kiểm tra file temp có trong cache không
        /// </summary>
        private bool IsTempFileInCache(int userId, string tempFileName)
        {
            try
            {
                var cacheKey = $"TempFiles_{userId}";
                
                if (_cache.TryGetValue(cacheKey, out List<string>? tempFiles) && tempFiles != null)
                {
                    bool exists = tempFiles.Contains(tempFileName);
                    _logger.LogDebug($"Temp file {tempFileName} {(exists ? "exists" : "not found")} in cache for user {userId}");
                    return exists;
                }
                
                _logger.LogDebug($"Temp file cache not found for user {userId}");
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, $"Error checking temp file in cache: {tempFileName}");
                return false;
            }
        }

        /// <summary>
        /// Remove temp file khỏi cache (khi file đã được move sang DocumentUploads)
        /// </summary>
        private void RemoveTempFileFromCache(int userId, string tempFileName)
        {
            try
            {
                var cacheKey = $"TempFiles_{userId}";
                
                if (_cache.TryGetValue(cacheKey, out List<string>? tempFiles) && tempFiles != null)
                {
                    tempFiles.Remove(tempFileName);
                    
                    if (tempFiles.Count > 0)
                    {
                        // Còn file khác, update cache
                        var cacheOptions = new MemoryCacheEntryOptions
                        {
                            AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(30),
                            SlidingExpiration = TimeSpan.FromMinutes(30)
                        };
                        _cache.Set(cacheKey, tempFiles, cacheOptions);
                    }
                    else
                    {
                        // Không còn file nào, remove cache entry
                        _cache.Remove(cacheKey);
                    }
                    
                    _logger.LogDebug($"Removed temp file from cache for user {userId}: {tempFileName}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, $"Error removing temp file from cache: {tempFileName}");
            }
        }

        /// <summary>
        /// Cleanup tất cả temp files của user (khi logout hoặc session timeout)
        /// Helper method - không phải API endpoint
        /// </summary>
        private void CleanupUserTempFiles(int userId)
        {
            try
            {
                var cacheKey = $"TempFiles_{userId}";
                var tempFolder = Path.Combine(Path.GetTempPath(), "PTVBTPM", "Uploads");
                
                if (_cache.TryGetValue(cacheKey, out List<string>? tempFiles) && tempFiles != null)
                {
                    int deletedCount = 0;
                    
                    foreach (var tempFileName in tempFiles)
                    {
                        try
                        {
                            var tempFilePath = Path.Combine(tempFolder, tempFileName);
                            
                            // Xóa file gốc
                            if (System.IO.File.Exists(tempFilePath))
                            {
                                System.IO.File.Delete(tempFilePath);
                                deletedCount++;
                                _logger.LogInformation($"Deleted temp file on logout: {tempFileName}");
                            }
                            
                            // Xóa PDF đã convert (nếu có) - cho DOCX
                            var fileExtension = Path.GetExtension(tempFileName).ToLowerInvariant();
                            if (fileExtension == ".docx")
                            {
                                var tempPdfPath = Path.ChangeExtension(tempFilePath, ".pdf");
                                if (System.IO.File.Exists(tempPdfPath))
                                {
                                    System.IO.File.Delete(tempPdfPath);
                                    _logger.LogInformation($"Deleted temp PDF on logout: {Path.GetFileName(tempPdfPath)}");
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, $"Failed to delete temp file on logout: {tempFileName}");
                        }
                    }
                    
                    // Remove cache entry
                    _cache.Remove(cacheKey);
                    
                    _logger.LogInformation($"Cleaned up {deletedCount} temp files for user {userId} on logout");
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, $"Error cleaning up temp files for user {userId}");
            }
        }

        /// <summary>
        /// Tìm executable trong PATH environment variable
        /// </summary>
        private string FindExecutableInPath(string executableName)
        {
            string? pathEnv = Environment.GetEnvironmentVariable("PATH");
            if (string.IsNullOrEmpty(pathEnv))
                return string.Empty;

            var paths = pathEnv.Split(Path.PathSeparator);
            foreach (var path in paths)
            {
                try
                {
                    string fullPath = Path.Combine(path, executableName);
                    if (System.IO.File.Exists(fullPath))
                        return fullPath;
                }
                catch { }
            }

            return string.Empty;
        }

        /// <summary>
        /// Ước tính số trang DOCX dựa trên nội dung (fallback method)
        /// </summary>
        private int EstimateDocxPages(string filePath)
        {
            try
            {
                using (WordprocessingDocument doc = WordprocessingDocument.Open(filePath, false))
                {
                    var body = doc.MainDocumentPart?.Document?.Body;
                    if (body == null) return 1;

                    // Đếm số page breaks explicit
                    int pageBreakCount = body.Descendants<DocumentFormat.OpenXml.Wordprocessing.Break>()?.Count(b => b.Type?.Value == BreakValues.Page) ?? 0;
                    
                    // Đếm số paragraph
                    int paragraphCount = body.Descendants<Paragraph>().Count();
                    
                    // Đếm tổng số ký tự
                    int totalChars = body.Descendants<DocumentFormat.OpenXml.Wordprocessing.Text>()
                        .Sum(t => t.Text?.Length ?? 0);
                    
                    // Tính số trang dựa trên nội dung
                    int estimatedPages = 1;
                    
                    if (paragraphCount > 0 || totalChars > 0)
                    {
                        int pagesByChars = Math.Max(1, (int)Math.Ceiling(totalChars / 2200.0));
                        int pagesByParagraphs = Math.Max(1, (int)Math.Ceiling(paragraphCount / 28.0));
                        estimatedPages = Math.Max(pagesByChars, pagesByParagraphs);
                    }
                    
                    if (pageBreakCount > 0)
                    {
                        int pagesByBreaks = pageBreakCount + 1;
                        estimatedPages = Math.Max(estimatedPages, pagesByBreaks);
                    }
                    
                    return estimatedPages;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error estimating DOCX pages");
                return 1;
            }
        }

        /// <summary>
        /// Đếm số slide trong file PPTX
        /// </summary>
        private int CountPptxSlides(string filePath)
        {
            try
            {
                using (PresentationDocument doc = PresentationDocument.Open(filePath, false))
                {
                    var presentationPart = doc.PresentationPart;
                    if (presentationPart?.Presentation == null) return 0;

                    // Đếm số slide ID trong presentation
                    var slideIds = presentationPart.Presentation.SlideIdList?.Elements<SlideId>();
                    return slideIds?.Count() ?? 0;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error counting PPTX slides");
                return 0;
            }
        }

        /// <summary>
        /// Convert PPTX sang PDF cơ bản (1 slide per page) - dùng khi upload
        /// </summary>
        private string? ConvertPptxToPdfUsingLibreOffice(string pptxPath)
        {
            try
            {
                string libreOfficePath = FindLibreOfficePath();
                if (string.IsNullOrEmpty(libreOfficePath))
                {
                    _logger.LogWarning("LibreOffice not found, cannot convert PPTX to PDF");
                    return null;
                }

                var outputDir = Path.GetDirectoryName(pptxPath) ?? Path.GetTempPath();
                var pdfPath = Path.ChangeExtension(pptxPath, ".pdf");

                // Kiểm tra xem PDF đã được tạo chưa (cache)
                if (System.IO.File.Exists(pdfPath))
                {
                    var pdfInfo = new FileInfo(pdfPath);
                    if (pdfInfo.Length > 0)
                    {
                        _logger.LogDebug($"Using existing PDF for PPTX: {pdfPath}");
                        return pdfPath;
                    }
                }

                // Tạo user profile directory riêng cho LibreOffice
                string userProfileDir = Path.Combine(Path.GetTempPath(), "LibreOffice_Profile", Guid.NewGuid().ToString());
                Directory.CreateDirectory(userProfileDir);

                // Convert path cho LibreOffice
                string profilePath = userProfileDir.Replace("\\", "/");
                if (!profilePath.StartsWith("/"))
                {
                    profilePath = "/" + profilePath;
                }

                // LibreOffice command để convert PPTX sang PDF
                var processStartInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = libreOfficePath,
                    Arguments = $"--headless --nodefault --nolockcheck -env:UserInstallation=file://{profilePath} --convert-to pdf \"{pptxPath}\" --outdir \"{outputDir}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = outputDir
                };

                // Set environment variables
                if (!System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
                {
                    string? homeDir = Environment.GetEnvironmentVariable("HOME");
                    if (!string.IsNullOrEmpty(homeDir) && !processStartInfo.EnvironmentVariables.ContainsKey("HOME"))
                    {
                        processStartInfo.EnvironmentVariables["HOME"] = homeDir;
                    }

                    string? currentPath = Environment.GetEnvironmentVariable("PATH");
                    if (!string.IsNullOrEmpty(currentPath) && !processStartInfo.EnvironmentVariables.ContainsKey("PATH"))
                    {
                        processStartInfo.EnvironmentVariables["PATH"] = currentPath;
                    }

                    if (processStartInfo.EnvironmentVariables.ContainsKey("DISPLAY"))
                    {
                        processStartInfo.EnvironmentVariables.Remove("DISPLAY");
                    }
                }

                using (var process = System.Diagnostics.Process.Start(processStartInfo))
                {
                    if (process != null)
                    {
                        bool exited = process.WaitForExit(120000); // Timeout 2 phút cho PPTX lớn
                        
                        if (!exited)
                        {
                            process.Kill();
                            _logger.LogError($"LibreOffice conversion timeout for PPTX: {pptxPath}");
                            try { Directory.Delete(userProfileDir, true); } catch { }
                            return null;
                        }

                        if (process.ExitCode != 0)
                        {
                            _logger.LogError($"LibreOffice conversion failed with exit code {process.ExitCode} for PPTX: {pptxPath}");
                            try { Directory.Delete(userProfileDir, true); } catch { }
                            return null;
                        }
                    }
                }

                // Cleanup user profile
                try
                {
                    Directory.Delete(userProfileDir, true);
                }
                catch { }

                // LibreOffice sẽ tạo PDF với tên giống file gốc
                if (System.IO.File.Exists(pdfPath))
                {
                    var pdfInfo = new FileInfo(pdfPath);
                    if (pdfInfo.Length > 0)
                    {
                        _logger.LogInformation($"Successfully converted PPTX to PDF: {pdfPath}");
                        return pdfPath;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error converting PPTX to PDF: {pptxPath}");
            }

            return null;
        }

        /// <summary>
        /// Convert PPTX sang PDF với slides per page option cho preview
        /// </summary>
        private Task<string?> ConvertPptxToPdfForPreview(string pptxPath, int slidesPerPage, int requestedPage)
        {
            return Task.Run(() =>
            {
                try
                {
                    string libreOfficePath = FindLibreOfficePath();
                    if (string.IsNullOrEmpty(libreOfficePath))
                    {
                        _logger.LogWarning("LibreOffice not found, cannot convert PPTX to PDF");
                        return null;
                    }

                    // Tạo temp output directory
                    var outputDir = Path.GetDirectoryName(pptxPath) ?? Path.GetTempPath();
                    
                    // Tạo tên file PDF với slidesPerPage và page để cache
                    var baseName = Path.GetFileNameWithoutExtension(pptxPath);
                    var pdfFileName = $"{baseName}_spp{slidesPerPage}_p{requestedPage}.pdf";
                    var pdfPath = Path.Combine(outputDir, pdfFileName);

                    // Kiểm tra xem PDF đã được tạo chưa (cache)
                    if (System.IO.File.Exists(pdfPath))
                    {
                        _logger.LogDebug($"Using cached PDF for PPTX: {pdfPath}");
                        return pdfPath;
                    }

                // Tạo user profile directory riêng cho LibreOffice
                string userProfileDir = Path.Combine(Path.GetTempPath(), "LibreOffice_Profile", Guid.NewGuid().ToString());
                Directory.CreateDirectory(userProfileDir);

                // Convert path cho LibreOffice
                string profilePath = userProfileDir.Replace("\\", "/");
                if (!profilePath.StartsWith("/"))
                {
                    profilePath = "/" + profilePath;
                }

                // LibreOffice command để convert PPTX sang PDF
                // Note: LibreOffice không hỗ trợ trực tiếp slides per page trong command line
                // Nên ta sẽ convert toàn bộ và để frontend xử lý layout, hoặc convert từng slide riêng
                var processStartInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = libreOfficePath,
                    Arguments = $"--headless --nodefault --nolockcheck -env:UserInstallation=file://{profilePath} --convert-to pdf \"{pptxPath}\" --outdir \"{outputDir}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = outputDir
                };

                // Set environment variables
                if (!System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
                {
                    string? homeDir = Environment.GetEnvironmentVariable("HOME");
                    if (!string.IsNullOrEmpty(homeDir) && !processStartInfo.EnvironmentVariables.ContainsKey("HOME"))
                    {
                        processStartInfo.EnvironmentVariables["HOME"] = homeDir;
                    }

                    string? currentPath = Environment.GetEnvironmentVariable("PATH");
                    if (!string.IsNullOrEmpty(currentPath) && !processStartInfo.EnvironmentVariables.ContainsKey("PATH"))
                    {
                        processStartInfo.EnvironmentVariables["PATH"] = currentPath;
                    }

                    if (processStartInfo.EnvironmentVariables.ContainsKey("DISPLAY"))
                    {
                        processStartInfo.EnvironmentVariables.Remove("DISPLAY");
                    }
                }

                using (var process = System.Diagnostics.Process.Start(processStartInfo))
                {
                    if (process != null)
                    {
                        bool exited = process.WaitForExit(120000); // Timeout 2 phút cho PPTX lớn
                        
                        if (!exited)
                        {
                            process.Kill();
                            _logger.LogError($"LibreOffice conversion timeout for PPTX: {pptxPath}");
                            // Cleanup
                            try { Directory.Delete(userProfileDir, true); } catch { }
                            return null;
                        }

                        if (process.ExitCode != 0)
                        {
                            _logger.LogError($"LibreOffice conversion failed with exit code {process.ExitCode} for PPTX: {pptxPath}");
                            // Cleanup
                            try { Directory.Delete(userProfileDir, true); } catch { }
                            return null;
                        }
                    }
                }

                // Cleanup user profile
                try
                {
                    Directory.Delete(userProfileDir, true);
                }
                catch { }

                // LibreOffice sẽ tạo PDF với tên giống file gốc
                var defaultPdfPath = Path.ChangeExtension(pptxPath, ".pdf");
                if (System.IO.File.Exists(defaultPdfPath))
                {
                    // Rename hoặc copy để cache với tên có slidesPerPage
                    try
                    {
                        if (defaultPdfPath != pdfPath)
                        {
                            System.IO.File.Copy(defaultPdfPath, pdfPath, overwrite: true);
                        }
                        _logger.LogInformation($"Successfully converted PPTX to PDF: {pdfPath}");
                        return pdfPath;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Error copying PDF file, using default path");
                        return defaultPdfPath;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error converting PPTX to PDF: {pptxPath}");
            }

                return null;
            });
        }

        /// <summary>
        /// Đếm số trang PDF dựa trên engine (có thể có trang ảo)
        /// </summary>
        private int CountPdfPagesEngine(string filePath)
        {
            try
            {
                // Đọc file PDF dưới dạng bytes
                byte[] pdfBytes = System.IO.File.ReadAllBytes(filePath);
                string pdfText = System.Text.Encoding.ASCII.GetString(pdfBytes);
                
                // Tìm pattern /Count trong file PDF
                // PDF thường có /Count trong Pages dictionary hoặc trong trailer
                var match = Regex.Match(
                    pdfText, 
                    @"/Count\s+(\d+)",
                    RegexOptions.IgnoreCase
                );
                
                if (match.Success && int.TryParse(match.Groups[1].Value, out int count))
                {
                    return count;
                }
                
                // Fallback: đếm số lần xuất hiện "/Type /Page" (ít chính xác hơn)
                var pageMatches = Regex.Matches(
                    pdfText,
                    @"/Type\s*/Page[^s]"
                );
                
                if (pageMatches.Count > 0)
                {
                    return pageMatches.Count;
                }
                
                return 0;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error counting PDF pages from engine");
                return 0;
            }
        }

        /// <summary>
        /// Đếm số trang PDF thực tế dựa trên nội dung render được (không tính trang rỗng)
        /// FIX: Chỉ tính những trang có thể render được và có nội dung
        /// </summary>
        private int CountPdfPages(string filePath)
        {
            try
            {
                // Lấy số trang từ engine trước (để biết giới hạn)
                int enginePageCount = CountPdfPagesEngine(filePath);
                
                if (enginePageCount <= 0)
                {
                    return 0;
                }

                // Sử dụng PdfSharpCore để đếm trang thực tế
                using (var document = PdfReader.Open(filePath, PdfDocumentOpenMode.Import))
                {
                    int realPageCount = 0;
                    
                    // Lặp qua từng trang và kiểm tra có thể render được không
                    for (int pageNum = 1; pageNum <= document.PageCount && pageNum <= enginePageCount; pageNum++)
                    {
                        try
                        {
                            var page = document.Pages[pageNum - 1];
                            
                            // Kiểm tra trang có nội dung không bằng cách thử extract
                            // Nếu trang có thể extract được và không throw exception thì có nội dung
                            bool hasContent = HasPdfPageContent(document, pageNum);
                            
                            if (hasContent)
                            {
                                realPageCount++;
                            }
                            else
                            {
                                // Gặp trang rỗng đầu tiên → dừng lại (các trang sau cũng sẽ rỗng)
                                _logger.LogDebug($"Found empty page at {pageNum}, stopping count. Real page count: {realPageCount}");
                                break;
                            }
                        }
                        catch (Exception ex)
                        {
                            // Nếu không thể đọc trang → dừng lại
                            _logger.LogDebug($"Cannot read page {pageNum}, stopping count. Real page count: {realPageCount}. Error: {ex.Message}");
                            break;
                        }
                    }
                    
                    _logger.LogInformation($"PDF page count: Engine={enginePageCount}, Real={realPageCount} (file: {Path.GetFileName(filePath)})");
                    return realPageCount > 0 ? realPageCount : enginePageCount; // Fallback về engine count nếu không đếm được
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, $"Error counting real PDF pages, falling back to engine count. File: {filePath}");
                // Fallback về engine count
                return CountPdfPagesEngine(filePath);
            }
        }

        /// <summary>
        /// Kiểm tra trang PDF có nội dung hay không bằng cách thử extract và kiểm tra
        /// FIX: Chỉ return true nếu trang có thể extract được và không throw exception
        /// </summary>
        private bool HasPdfPageContent(PdfDocument document, int pageNumber)
        {
            try
            {
                if (pageNumber < 1 || pageNumber > document.PageCount)
                {
                    return false;
                }

                var page = document.Pages[pageNumber - 1];
                
                // Kiểm tra xem có thể extract được không bằng cách tạo PDF 1 trang
                using (var testDocument = new PdfDocument())
                {
                    try
                    {
                        // Thử add page vào document mới - nếu thành công thì page có nội dung
                        testDocument.AddPage(page);
                        
                        // Lưu vào memory stream để kiểm tra
                        using (var stream = new MemoryStream())
                        {
                            testDocument.Save(stream);
                            
                            // Kiểm tra size: PDF header + metadata thường ~ 1-2KB
                            // Trang có nội dung sẽ có size lớn hơn nhiều
                            // Trang rỗng thường chỉ có structure, size nhỏ
                            if (stream.Length < 1024)
                            {
                                return false;
                            }
                            
                            // Thử đọc lại để đảm bảo PDF hợp lệ
                            stream.Position = 0;
                            try
                            {
                                using (var testRead = PdfReader.Open(stream, PdfDocumentOpenMode.ReadOnly))
                                {
                                    return testRead.PageCount > 0;
                                }
                            }
                            catch
                            {
                                return false;
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogDebug($"Page {pageNumber} cannot be extracted: {ex.Message}");
                        return false;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogDebug($"Error checking page {pageNumber} content: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Parse chuỗi pages to print (ví dụ: "1-5,10,15-20")
        /// </summary>
        private int ParsePagesToPrint(string pagesToPrint, int maxPages)
        {
            if (string.IsNullOrWhiteSpace(pagesToPrint))
                return 0;

            var pages = new HashSet<int>();
            var parts = pagesToPrint.Split(',', StringSplitOptions.RemoveEmptyEntries);

            foreach (var part in parts)
            {
                var trimmed = part.Trim();
                
                if (trimmed.Contains('-'))
                {
                    // Range: "1-5"
                    var rangeParts = trimmed.Split('-');
                    if (rangeParts.Length == 2 && 
                        int.TryParse(rangeParts[0].Trim(), out int start) &&
                        int.TryParse(rangeParts[1].Trim(), out int end))
                    {
                        for (int i = Math.Max(1, start); i <= Math.Min(maxPages, end); i++)
                        {
                            pages.Add(i);
                        }
                    }
                }
                else
                {
                    // Single page: "10"
                    if (int.TryParse(trimmed, out int page) && page >= 1 && page <= maxPages)
                    {
                        pages.Add(page);
                    }
                }
            }

            return pages.Count;
        }

        /// <summary>
        /// Gửi SignalR notification về trạng thái print job
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
        /// Download document cho admin (không cần check userId)
        /// </summary>
        [HttpGet("Admin/Download/{documentId}")]
        [ProducesResponseType(200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> DownloadDocumentForAdmin(int documentId)
        {
            try
            {
                // Kiểm tra quyền Admin/SPSO
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền tải xuống tài liệu." });

                // Lấy document (không filter theo userId cho admin)
                var document = await _context.Documents
                    .FirstOrDefaultAsync(d => d.DocumentId == documentId);

                if (document == null)
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "Không tìm thấy tài liệu."
                    });
                }

                // Lấy file path
                string filePath;
                if (!string.IsNullOrWhiteSpace(document.UploadPath))
                {
                    filePath = Path.Combine(_environment.WebRootPath, document.UploadPath);
                }
                else
                {
                    // Fallback: tìm file trong upload folder
                    var uploadFolder = Path.Combine(_environment.WebRootPath, "uploads", document.UserId?.ToString() ?? "0");
                    filePath = Path.Combine(uploadFolder, document.FileName);
                }

                if (!System.IO.File.Exists(filePath))
                {
                    return NotFound(new
                    {
                        success = false,
                        message = "File không tồn tại trên server."
                    });
                }

                // Trả về file
                var fileBytes = await System.IO.File.ReadAllBytesAsync(filePath);
                var contentType = GetContentType(document.FileType);
                return File(fileBytes, contentType, document.FileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error downloading document for admin");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Lỗi hệ thống khi tải xuống tài liệu.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Lấy content type từ file extension
        /// </summary>
        private string GetContentType(string fileExtension)
        {
            return fileExtension?.ToLowerInvariant() switch
            {
                ".pdf" => "application/pdf",
                ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                _ => "application/octet-stream"
            };
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
    }
}

