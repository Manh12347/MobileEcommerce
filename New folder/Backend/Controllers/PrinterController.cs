using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using PTVBTPM.Hubs;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    [Produces("application/json")]
    public class PrinterController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<PrinterController> _logger;
        private readonly IHubContext<PrintHub> _hubContext;

        public PrinterController(WebDbContext context, ILogger<PrinterController> logger, IHubContext<PrintHub> hubContext)
        {
            _context = context;
            _logger = logger;
            _hubContext = hubContext;
        }

        /// <summary>
        /// Lấy danh sách tất cả máy in
        /// </summary>
        [HttpGet("All")]
        [ProducesResponseType(typeof(List<PrinterResponseDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                // Load printers and inks first (simple query)
                var printers = await _context.Printers
                    .Include(p => p.Ink)
                    .OrderBy(p => p.PrinterCode)
                    .ToListAsync();

                // Load capabilities separately to avoid complex multi-join SQL
                var printerIds = printers.Select(p => p.PrinterId).ToList();
                var capabilities = await _context.PrinterCapabilities
                    .Where(c => printerIds.Contains(c.PrinterId ?? 0))
                    .Include(c => c.PaperSize)
                    .ToListAsync();

                var capabilitiesByPrinter = capabilities
                    .GroupBy(c => c.PrinterId)
                    .ToDictionary(g => g.Key ?? 0, g => g.ToList());

                var response = printers.Select(p =>
                {
                    var caps = capabilitiesByPrinter.ContainsKey(p.PrinterId) ? capabilitiesByPrinter[p.PrinterId] : new List<PrinterCapability>();
                    return new PrinterResponseDto
                    {
                        PrinterId = p.PrinterId,
                        PrinterCode = p.PrinterCode,
                        Location = p.Location,
                        Brand = p.Brand,
                        Model = p.Model,
                        Status = p.Status,
                        PaperCapacity = p.PaperCapacity,
                        AdditionalPaper = p.AdditionalPaper,
                        // IsDisabled column removed
                        CreatedOn = p.CreatedOn,
                        CreatedBy = p.CreatedBy,
                        ModifiedOn = p.ModifiedOn,
                        ModifiedBy = p.ModifiedBy,
                        InkId = p.InkId,
                        InkCode = p.Ink != null ? p.Ink.InkCode : null,
                        Capabilities = caps.Select(c => new PrinterCapabilityResponseDto
                        {
                            PrinterCapabilityId = c.PrinterCapabilityId,
                            PaperSizeId = c.PaperSizeId ?? 0,
                            PaperSizeCode = c.PaperSize != null ? c.PaperSize.Code : null,
                            PaperSizeDescription = c.PaperSize != null ? c.PaperSize.Description : null,
                            IsColorSupported = c.IsColorSupported,
                            IsBwSupported = c.IsBwSupported
                        }).ToList()
                    };
                }).ToList();

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.GetAll] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy thông tin máy in theo ID
        /// </summary>
        [HttpGet("Get/{id}")]
        [ProducesResponseType(typeof(PrinterResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetById(int id)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                var printer = await _context.Printers
                    .Include(p => p.PrinterCapabilities)
                        .ThenInclude(c => c.PaperSize)
                    .Include(p => p.Ink)
                    .FirstOrDefaultAsync(p => p.PrinterId == id);
                
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                var response = new PrinterResponseDto
                {
                    PrinterId = printer.PrinterId,
                    PrinterCode = printer.PrinterCode,
                    Location = printer.Location,
                    Brand = printer.Brand,
                    Model = printer.Model,
                    Status = printer.Status,
                    PaperCapacity = printer.PaperCapacity,
                    AdditionalPaper = printer.AdditionalPaper,
                    CreatedOn = printer.CreatedOn,
                    CreatedBy = printer.CreatedBy,
                    ModifiedOn = printer.ModifiedOn,
                    ModifiedBy = printer.ModifiedBy,
                    InkId = printer.InkId,
                    InkCode = printer.Ink != null ? printer.Ink.InkCode : null,
                    Capabilities = printer.PrinterCapabilities.Select(c => new PrinterCapabilityResponseDto
                    {
                        PrinterCapabilityId = c.PrinterCapabilityId,
                        PaperSizeId = c.PaperSizeId ?? 0,
                        PaperSizeCode = c.PaperSize != null ? c.PaperSize.Code : null,
                        PaperSizeDescription = c.PaperSize != null ? c.PaperSize.Description : null,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported
                    }).ToList()
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.GetById] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Tạo máy in mới (chỉ SPSO)
        /// </summary>
        [HttpPost("Create")]
        [ProducesResponseType(typeof(PrinterResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Create([FromBody] PrinterUpsertDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền tạo máy in." });
                }

                // Validate
                if (string.IsNullOrWhiteSpace(dto.PrinterCode))
                {
                    return BadRequest(new { success = false, message = "Mã máy in là bắt buộc." });
                }

                // Kiểm tra PrinterCode đã tồn tại chưa
                var existing = await _context.Printers
                    .FirstOrDefaultAsync(p => p.PrinterCode.ToUpper() == dto.PrinterCode.ToUpper());
                if (existing != null)
                {
                    return BadRequest(new { success = false, message = "Mã máy in đã tồn tại." });
                }

                // Validate Status
                if (!string.IsNullOrWhiteSpace(dto.Status))
                {
                    var validStatuses = new[] { "AVAILABLE", "OFFLINE", "MAINTENANCE", "ERROR" };
                    if (!validStatuses.Contains(dto.Status.ToUpper()))
                    {
                        return BadRequest(new { success = false, message = "Trạng thái không hợp lệ. Các trạng thái hợp lệ: AVAILABLE, OFFLINE, MAINTENANCE, ERROR." });
                    }
                }

                // Validate PaperCapacity
                if (dto.PaperCapacity.HasValue && dto.PaperCapacity.Value < 0)
                {
                    return BadRequest(new { success = false, message = "Dung lượng giấy không được âm." });
                }
                
                // Validate InkId if provided: must exist and not already assigned to another printer
                if (dto.InkId.HasValue)
                {
                    var inkExists = await _context.Inks.AnyAsync(i => i.InkId == dto.InkId.Value);
                    if (!inkExists)
                    {
                        return BadRequest(new { success = false, message = "Cuộn mực chọn không tồn tại." });
                    }
                    var alreadyAssigned = await _context.Printers.AnyAsync(p => p.InkId == dto.InkId.Value);
                    if (alreadyAssigned)
                    {
                        return BadRequest(new { success = false, message = "Cuộn mực đã được gắn cho máy khác." });
                    }
                }

                // Validate Capabilities
                if (dto.Capabilities != null && dto.Capabilities.Any())
                {
                    // Kiểm tra PaperSizeId hợp lệ
                    var paperSizeIds = dto.Capabilities.Select(c => c.PaperSizeId).Distinct().ToList();
                    var validPaperSizes = await _context.PaperSizes
                        .Where(ps => paperSizeIds.Contains(ps.PaperSizeId))
                        .Select(ps => ps.PaperSizeId)
                        .ToListAsync();
                    
                    var invalidPaperSizes = paperSizeIds.Except(validPaperSizes).ToList();
                    if (invalidPaperSizes.Any())
                    {
                        return BadRequest(new { success = false, message = $"Khổ giấy không hợp lệ: {string.Join(", ", invalidPaperSizes)}" });
                    }

                    // Kiểm tra trùng lặp PaperSizeId
                    var duplicatePaperSizes = paperSizeIds.GroupBy(id => id).Where(g => g.Count() > 1).Select(g => g.Key).ToList();
                    if (duplicatePaperSizes.Any())
                    {
                        return BadRequest(new { success = false, message = $"Không thể có nhiều cấu hình cho cùng một khổ giấy: {string.Join(", ", duplicatePaperSizes)}" });
                    }

                    // Kiểm tra ít nhất một loại in (màu hoặc đen trắng) được hỗ trợ
                    var invalidCapabilities = dto.Capabilities.Where(c => !c.IsColorSupported && !c.IsBwSupported).ToList();
                    if (invalidCapabilities.Any())
                    {
                        return BadRequest(new { success = false, message = "Mỗi cấu hình phải hỗ trợ ít nhất một loại in (màu hoặc đen trắng)." });
                    }
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                var printer = new Printer
                {
                    PrinterCode = dto.PrinterCode.ToUpper(),
                    Location = dto.Location,
                    Brand = dto.Brand,
                    Model = dto.Model,
                    Status = !string.IsNullOrWhiteSpace(dto.Status) ? dto.Status.ToUpper() : "AVAILABLE",
                    PaperCapacity = dto.PaperCapacity,
                    InkId = dto.InkId,
                    CreatedOn = now,
                    CreatedBy = email ?? userId?.ToString()
                };

                _context.Printers.Add(printer);
                await _context.SaveChangesAsync();

                // Tạo capabilities nếu có
                if (dto.Capabilities != null && dto.Capabilities.Any())
                {
                    var capabilities = dto.Capabilities.Select(c => new PrinterCapability
                    {
                        PrinterId = printer.PrinterId,
                        PaperSizeId = c.PaperSizeId,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported,
                        CreatedOn = now,
                        CreatedBy = email ?? userId?.ToString()
                    }).ToList();

                    _context.PrinterCapabilities.AddRange(capabilities);
                    await _context.SaveChangesAsync();
                }

                // Load lại với capabilities để trả về
                var printerWithCapabilities = await _context.Printers
                    .Include(p => p.PrinterCapabilities)
                        .ThenInclude(c => c.PaperSize)
                    .FirstOrDefaultAsync(p => p.PrinterId == printer.PrinterId);

                var response = new PrinterResponseDto
                {
                    PrinterId = printerWithCapabilities!.PrinterId,
                    PrinterCode = printerWithCapabilities.PrinterCode,
                    Location = printerWithCapabilities.Location,
                    Brand = printerWithCapabilities.Brand,
                    Model = printerWithCapabilities.Model,
                    Status = printerWithCapabilities.Status,
                    PaperCapacity = printerWithCapabilities.PaperCapacity,
                    CreatedOn = printerWithCapabilities.CreatedOn,
                    CreatedBy = printerWithCapabilities.CreatedBy,
                    ModifiedOn = printerWithCapabilities.ModifiedOn,
                    ModifiedBy = printerWithCapabilities.ModifiedBy,
                    InkId = printerWithCapabilities.InkId,
                    InkCode = printerWithCapabilities.Ink != null ? printerWithCapabilities.Ink.InkCode : null,
                    Capabilities = printerWithCapabilities.PrinterCapabilities.Select(c => new PrinterCapabilityResponseDto
                    {
                        PrinterCapabilityId = c.PrinterCapabilityId,
                        PaperSizeId = c.PaperSizeId ?? 0,
                        PaperSizeCode = c.PaperSize != null ? c.PaperSize.Code : null,
                        PaperSizeDescription = c.PaperSize != null ? c.PaperSize.Description : null,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported
                    }).ToList()
                };

                return Ok(new { success = true, message = "Tạo máy in thành công.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.Create] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Cập nhật máy in (chỉ SPSO)
        /// </summary>
        [HttpPut("Update/{id}")]
        [ProducesResponseType(typeof(PrinterResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Update(int id, [FromBody] PrinterUpsertDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền cập nhật máy in." });
                }

                var printer = await _context.Printers.FindAsync(id);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                // Validate
                if (string.IsNullOrWhiteSpace(dto.PrinterCode))
                {
                    return BadRequest(new { success = false, message = "Mã máy in là bắt buộc." });
                }

                // Validate Status
                if (!string.IsNullOrWhiteSpace(dto.Status))
                {
                    var validStatuses = new[] { "AVAILABLE", "OFFLINE", "MAINTENANCE", "ERROR" };
                    if (!validStatuses.Contains(dto.Status.ToUpper()))
                    {
                        return BadRequest(new { success = false, message = "Trạng thái không hợp lệ. Các trạng thái hợp lệ: AVAILABLE, OFFLINE, MAINTENANCE, ERROR." });
                    }
                }

                // Validate PaperCapacity
                if (dto.PaperCapacity.HasValue && dto.PaperCapacity.Value < 0)
                {
                    return BadRequest(new { success = false, message = "Dung lượng giấy không được âm." });
                }

                // Validate Capabilities
                if (dto.Capabilities != null && dto.Capabilities.Any())
                {
                    // Kiểm tra PaperSizeId hợp lệ
                    var paperSizeIds = dto.Capabilities.Select(c => c.PaperSizeId).Distinct().ToList();
                    var validPaperSizes = await _context.PaperSizes
                        .Where(ps => paperSizeIds.Contains(ps.PaperSizeId))
                        .Select(ps => ps.PaperSizeId)
                        .ToListAsync();
                    
                    var invalidPaperSizes = paperSizeIds.Except(validPaperSizes).ToList();
                    if (invalidPaperSizes.Any())
                    {
                        return BadRequest(new { success = false, message = $"Khổ giấy không hợp lệ: {string.Join(", ", invalidPaperSizes)}" });
                    }

                    // Kiểm tra trùng lặp PaperSizeId
                    var duplicatePaperSizes = paperSizeIds.GroupBy(id => id).Where(g => g.Count() > 1).Select(g => g.Key).ToList();
                    if (duplicatePaperSizes.Any())
                    {
                        return BadRequest(new { success = false, message = $"Không thể có nhiều cấu hình cho cùng một khổ giấy: {string.Join(", ", duplicatePaperSizes)}" });
                    }

                    // Kiểm tra ít nhất một loại in (màu hoặc đen trắng) được hỗ trợ
                    var invalidCapabilities = dto.Capabilities.Where(c => !c.IsColorSupported && !c.IsBwSupported).ToList();
                    if (invalidCapabilities.Any())
                    {
                        return BadRequest(new { success = false, message = "Mỗi cấu hình phải hỗ trợ ít nhất một loại in (màu hoặc đen trắng)." });
                    }
                }

                // Kiểm tra PrinterCode đã tồn tại chưa (trừ chính nó)
                if (printer.PrinterCode.ToUpper() != dto.PrinterCode.ToUpper())
                {
                    var existing = await _context.Printers
                        .FirstOrDefaultAsync(p => p.PrinterId != id && p.PrinterCode.ToUpper() == dto.PrinterCode.ToUpper());
                    if (existing != null)
                    {
                        return BadRequest(new { success = false, message = "Mã máy in đã tồn tại." });
                    }
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                // Cập nhật printer
                printer.PrinterCode = dto.PrinterCode.ToUpper();
                printer.Location = dto.Location;
                printer.Brand = dto.Brand;
                printer.Model = dto.Model;
                if (!string.IsNullOrWhiteSpace(dto.Status))
                {
                    printer.Status = dto.Status.ToUpper();
                }
                // Validate InkId if provided: must exist and not assigned to another printer (excluding current)
                if (dto.InkId.HasValue)
                {
                    var inkExists = await _context.Inks.AnyAsync(i => i.InkId == dto.InkId.Value);
                    if (!inkExists)
                    {
                        return BadRequest(new { success = false, message = "Cuộn mực chọn không tồn tại." });
                    }
                    var assignedElsewhere = await _context.Printers.AnyAsync(p => p.PrinterId != id && p.InkId == dto.InkId.Value);
                    if (assignedElsewhere)
                    {
                        return BadRequest(new { success = false, message = "Cuộn mực đã được gắn cho máy khác." });
                    }
                }
                printer.InkId = dto.InkId;
                printer.PaperCapacity = dto.PaperCapacity;
                // 'is_disable' column removed from DB; no longer set here.
                printer.ModifiedOn = now;
                printer.ModifiedBy = email ?? userId?.ToString();

                // Xóa capabilities cũ và tạo lại nếu có
                var oldCapabilities = await _context.PrinterCapabilities
                    .Where(c => c.PrinterId == id)
                    .ToListAsync();
                
                if (oldCapabilities.Any())
                {
                    _context.PrinterCapabilities.RemoveRange(oldCapabilities);
                }

                // Tạo capabilities mới nếu có
                if (dto.Capabilities != null && dto.Capabilities.Any())
                {
                    var newCapabilities = dto.Capabilities.Select(c => new PrinterCapability
                    {
                        PrinterId = id,
                        PaperSizeId = c.PaperSizeId,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported,
                        CreatedOn = now,
                        CreatedBy = email ?? userId?.ToString()
                    }).ToList();

                    _context.PrinterCapabilities.AddRange(newCapabilities);
                }

                await _context.SaveChangesAsync();

                // Load lại với capabilities để trả về
                var printerWithCapabilities = await _context.Printers
                    .Include(p => p.PrinterCapabilities)
                        .ThenInclude(c => c.PaperSize)
                    .FirstOrDefaultAsync(p => p.PrinterId == id);

                var response = new PrinterResponseDto
                {
                    PrinterId = printerWithCapabilities!.PrinterId,
                    PrinterCode = printerWithCapabilities.PrinterCode,
                    Location = printerWithCapabilities.Location,
                    Brand = printerWithCapabilities.Brand,
                    Model = printerWithCapabilities.Model,
                    Status = printerWithCapabilities.Status,
                    PaperCapacity = printerWithCapabilities.PaperCapacity,
                    // IsDisabled removed
                    CreatedOn = printerWithCapabilities.CreatedOn,
                    CreatedBy = printerWithCapabilities.CreatedBy,
                    ModifiedOn = printerWithCapabilities.ModifiedOn,
                    ModifiedBy = printerWithCapabilities.ModifiedBy,
                    Capabilities = printerWithCapabilities.PrinterCapabilities.Select(c => new PrinterCapabilityResponseDto
                    {
                        PrinterCapabilityId = c.PrinterCapabilityId,
                        PaperSizeId = c.PaperSizeId ?? 0,
                        PaperSizeCode = c.PaperSize != null ? c.PaperSize.Code : null,
                        PaperSizeDescription = c.PaperSize != null ? c.PaperSize.Description : null,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported
                    }).ToList()
                };

                return Ok(new { success = true, message = "Cập nhật máy in thành công.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.Update] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        // NOTE: Delete endpoint removed — deletion of printers is no longer supported.

        /// <summary>
        /// DEBUG: Kiểm tra tất cả printer capabilities
        /// </summary>
        [HttpGet("DebugCapabilities")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> DebugCapabilities()
        {
            try
            {
                var capabilities = await _context.PrinterCapabilities
                    .Include(c => c.Printer)
                    .Include(c => c.PaperSize)
                    .ToListAsync();

                var result = capabilities.Select(c => new {
                    PrinterId = c.PrinterId,
                    PrinterCode = c.Printer?.PrinterCode,
                    PaperSizeId = c.PaperSizeId,
                    PaperSizeCode = c.PaperSize?.Code,
                    IsColorSupported = c.IsColorSupported,
                    IsBwSupported = c.IsBwSupported
                });

                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách máy in để chọn khi in (cho user - chỉ lấy máy in không bị disable và có đủ giấy/mực cho hàng chờ)
        /// </summary>
        [HttpGet("GetList")]
        [ProducesResponseType(typeof(List<PrinterSelectDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetList(string? paperSizeCode = null, bool? isColor = null)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                // Cho user: bỏ lọc is_disable (đã xóa cột); chỉ loại trừ máy OFFLINE
                var printers = await _context.Printers
                    .Where(p => p.Status == null || p.Status != "OFFLINE")
                    .Include(p => p.PrintJobs)
                        .ThenInclude(j => j.PaperSize)
                    .Include(p => p.PrinterCapabilities)
                        .ThenInclude(c => c.PaperSize)
                    .OrderBy(p => p.PrinterCode)
                    .ToListAsync();

                // Filter by paper size capability if specified
                if (!string.IsNullOrWhiteSpace(paperSizeCode))
                {
                    var paperSizeCodeUpper = paperSizeCode.ToUpper();
                    printers = printers.Where(p =>
                        p.PrinterCapabilities.Any(c =>
                            c.PaperSize != null &&
                            c.PaperSize.Code != null &&
                            c.PaperSize.Code.ToUpper() == paperSizeCodeUpper &&
                            ((isColor == true && c.IsColorSupported) ||
                             (isColor == false && c.IsBwSupported) ||
                             (isColor == null && (c.IsColorSupported || c.IsBwSupported)))
                        )
                    ).ToList();
                }

                var availablePrinters = new List<PrinterSelectDto>();

                // Lấy tất cả mực có sẵn
                var availableInks = await _context.Inks
                    .Where(i => i.Status == "AVAILABLE")
                    .ToListAsync();

                foreach (var printer in printers)
                {
                    // Lấy tất cả print jobs đang chờ (PENDING + PRINTING)
                    var queueJobs = printer.PrintJobs
                        .Where(j => j.Status == "PENDING" || j.Status == "PRINTING")
                        .ToList();

                    // Tính tổng giấy và mực cần thiết cho hàng chờ
                    int totalPapersNeeded = 0;
                    int totalInkNeeded = 0; // Mực đen trắng (tính worst case)

                    foreach (var job in queueJobs)
                    {
                        var (actualPagesPerCopy, _, isDoubleSided) = CalculateActualPagesFromPrintJob(job);
                        var papersForThisJob = actualPagesPerCopy * (job.Copies ?? 1);
                        totalPapersNeeded += papersForThisJob;

                        // Mực tiêu hao: 1 mặt = 1 mực/giấy, 2 mặt = 2 mực/giấy
                        var inkPerPaper = isDoubleSided ? 2 : 1;
                        totalInkNeeded += papersForThisJob * inkPerPaper;
                    }

                    // Kiểm tra đủ giấy
                    // Nếu CurrentPaper = null, coi như có đủ (chưa cấu hình)
                    bool hasEnoughPaper = !printer.CurrentPaper.HasValue || printer.CurrentPaper.Value >= totalPapersNeeded;

                    // Kiểm tra đủ mực đen (worst case: in đen trắng)
                    // Nếu không có mực BLACK, vẫn hiển thị máy in (có thể chưa cấu hình mực)
                    var blackInk = availableInks.FirstOrDefault(i => i.Color.ToUpper() == "BLACK");
                    bool hasEnoughInk = blackInk == null || blackInk.CurrentPages >= totalInkNeeded;

                    // Chỉ hiển thị máy in nếu có đủ giấy và mực cho hàng chờ
                    // Hoặc nếu chưa cấu hình (CurrentPaper = null hoặc không có mực BLACK)
                    if (hasEnoughPaper && hasEnoughInk)
                    {
                        availablePrinters.Add(new PrinterSelectDto
                        {
                            PrinterId = printer.PrinterId,
                            PrinterCode = printer.PrinterCode,
                            Location = printer.Location,
                            Status = printer.Status ?? "UNKNOWN"
                        });
                    }
                }

                return Ok(new { success = true, data = availablePrinters });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.GetList] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách tất cả máy in (cho admin/SPSO - bao gồm cả máy in bị disable)
        /// </summary>
        [HttpGet("GetListAll")]
        [ProducesResponseType(typeof(List<PrinterResponseDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetListAll()
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xem tất cả máy in." });
                }

                // Cho admin/SPSO: lấy tất cả máy in (bao gồm cả máy in bị disable)
                var printers = await _context.Printers
                    .Include(p => p.Ink)
                    .OrderBy(p => p.PrinterCode)
                    .ToListAsync();

                var printerIds = printers.Select(p => p.PrinterId).ToList();
                var capabilities = await _context.PrinterCapabilities
                    .Where(c => c.PrinterId.HasValue && printerIds.Contains(c.PrinterId.Value))
                    .Include(c => c.PaperSize)
                    .ToListAsync();

                var capsByPrinter = capabilities.GroupBy(c => c.PrinterId).ToDictionary(g => g.Key ?? 0, g => g.ToList());

                var response = printers.Select(p => new PrinterResponseDto
                {
                    PrinterId = p.PrinterId,
                    PrinterCode = p.PrinterCode,
                    Location = p.Location,
                    Brand = p.Brand,
                    Model = p.Model,
                    Status = p.Status,
                    PaperCapacity = p.PaperCapacity,
                    CreatedOn = p.CreatedOn,
                    CreatedBy = p.CreatedBy,
                    ModifiedOn = p.ModifiedOn,
                    ModifiedBy = p.ModifiedBy,
                    InkId = p.InkId,
                    InkCode = p.Ink != null ? p.Ink.InkCode : null,
                    Capabilities = (capsByPrinter.ContainsKey(p.PrinterId) ? capsByPrinter[p.PrinterId] : new List<PrinterCapability>()).Select(c => new PrinterCapabilityResponseDto
                    {
                        PrinterCapabilityId = c.PrinterCapabilityId,
                        PaperSizeId = c.PaperSizeId ?? 0,
                        PaperSizeCode = c.PaperSize != null ? c.PaperSize.Code : null,
                        PaperSizeDescription = c.PaperSize != null ? c.PaperSize.Description : null,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported
                    }).ToList()
                }).ToList();

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.GetListAll] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Gán hoặc hủy gán cuộn mực cho máy in (chỉ SPSO)
        /// </summary>
        [HttpPost("AssignInk")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> AssignInk([FromBody] AssignInkDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền gán cuộn mực." });
                }

                var printer = await _context.Printers.FindAsync(dto.PrinterId);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                if (dto.InkId.HasValue)
                {
                    // validate ink exists
                    var inkExists = await _context.Inks.AnyAsync(i => i.InkId == dto.InkId.Value);
                    if (!inkExists)
                    {
                        return BadRequest(new { success = false, message = "Cuộn mực không tồn tại." });
                    }
                    // ensure not assigned to another printer
                    var assigned = await _context.Printers.AnyAsync(p => p.PrinterId != dto.PrinterId && p.InkId == dto.InkId.Value);
                    if (assigned)
                    {
                        return BadRequest(new { success = false, message = "Cuộn mực đã được gắn cho máy khác." });
                    }
                }

                // assign or unassign
                printer.InkId = dto.InkId;
                printer.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                _context.Printers.Update(printer);
                await _context.SaveChangesAsync();

                // reload for response
                var printerWithCapabilities = await _context.Printers
                    .Include(p => p.PrinterCapabilities)
                        .ThenInclude(c => c.PaperSize)
                    .Include(p => p.Ink)
                    .FirstOrDefaultAsync(p => p.PrinterId == printer.PrinterId);

                var response = new PrinterResponseDto
                {
                    PrinterId = printerWithCapabilities!.PrinterId,
                    PrinterCode = printerWithCapabilities.PrinterCode,
                    Location = printerWithCapabilities.Location,
                    Brand = printerWithCapabilities.Brand,
                    Model = printerWithCapabilities.Model,
                    Status = printerWithCapabilities.Status,
                    PaperCapacity = printerWithCapabilities.PaperCapacity,
                    // IsDisabled removed
                    CreatedOn = printerWithCapabilities.CreatedOn,
                    CreatedBy = printerWithCapabilities.CreatedBy,
                    ModifiedOn = printerWithCapabilities.ModifiedOn,
                    ModifiedBy = printerWithCapabilities.ModifiedBy,
                    InkId = printerWithCapabilities.InkId,
                    InkCode = printerWithCapabilities.Ink != null ? printerWithCapabilities.Ink.InkCode : null,
                    Capabilities = printerWithCapabilities.PrinterCapabilities.Select(c => new PrinterCapabilityResponseDto
                    {
                        PrinterCapabilityId = c.PrinterCapabilityId,
                        PaperSizeId = c.PaperSizeId ?? 0,
                        PaperSizeCode = c.PaperSize != null ? c.PaperSize.Code : null,
                        PaperSizeDescription = c.PaperSize != null ? c.PaperSize.Description : null,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported
                    }).ToList()
                };

                return Ok(new { success = true, message = "Cập nhật cuộn mực cho máy in thành công.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.AssignInk] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Toggle power status of a printer (OFFLINE <-> AVAILABLE) (SPSO only)
        /// </summary>
        [HttpPost("TogglePower/{id}")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> TogglePower(int id)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }
                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền thao tác." });
                }

                var printer = await _context.Printers.FindAsync(id);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);

                var current = (printer.Status ?? "UNKNOWN").ToUpper();
                if (current == "OFFLINE")
                {
                    printer.Status = "AVAILABLE";
                }
                else
                {
                    // Chỉ cho phép tắt máy in khi trạng thái là AVAILABLE và không có job in đang chờ
                    if (current != "AVAILABLE")
                    {
                        return BadRequest(new { success = false, message = "Chỉ có thể tắt máy in khi đang ở trạng thái AVAILABLE." });
                    }

                    // Kiểm tra có job in đang chờ không (PENDING hoặc PRINTING)
                    var hasPendingJobs = await _context.PrintJobs.AnyAsync(p => p.PrinterId == id && (p.Status == "PENDING" || p.Status == "PRINTING"));
                    if (hasPendingJobs)
                    {
                        return BadRequest(new { success = false, message = "Không thể tắt máy in khi còn job in đang chờ hoặc đang thực hiện." });
                    }

                    printer.Status = "OFFLINE";
                }
                printer.ModifiedOn = now;
                printer.ModifiedBy = email ?? userId?.ToString();

                _context.Printers.Update(printer);
                await _context.SaveChangesAsync();

                // return updated printer
                var updated = await _context.Printers
                    .Include(p => p.PrinterCapabilities)
                        .ThenInclude(c => c.PaperSize)
                    .Include(p => p.Ink)
                    .FirstOrDefaultAsync(p => p.PrinterId == id);

                var response = new PrinterResponseDto
                {
                    PrinterId = updated!.PrinterId,
                    PrinterCode = updated.PrinterCode,
                    Location = updated.Location,
                    Brand = updated.Brand,
                    Model = updated.Model,
                    Status = updated.Status,
                    PaperCapacity = updated.PaperCapacity,
                    CreatedOn = updated.CreatedOn,
                    CreatedBy = updated.CreatedBy,
                    ModifiedOn = updated.ModifiedOn,
                    ModifiedBy = updated.ModifiedBy,
                    InkId = updated.InkId,
                    InkCode = updated.Ink != null ? updated.Ink.InkCode : null,
                    Capabilities = updated.PrinterCapabilities.Select(c => new PrinterCapabilityResponseDto
                    {
                        PrinterCapabilityId = c.PrinterCapabilityId,
                        PaperSizeId = c.PaperSizeId ?? 0,
                        PaperSizeCode = c.PaperSize != null ? c.PaperSize.Code : null,
                        PaperSizeDescription = c.PaperSize != null ? c.PaperSize.Description : null,
                        IsColorSupported = c.IsColorSupported,
                        IsBwSupported = c.IsBwSupported
                    }).ToList()
                };

                // Send SignalR update for status change
                await SendPrinterStatusUpdateAsync(updated!, now);

                return Ok(new { success = true, message = "Đã chuyển trạng thái máy in.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.TogglePower] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy số trang còn lại của giấy và mực trong máy in
        /// </summary>
        [HttpGet("RemainingPages/{id}")]
        [ProducesResponseType(typeof(PrinterRemainingPagesDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetRemainingPages(int id)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                var printer = await _context.Printers.FindAsync(id);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                // Lấy tất cả cuộn mực có sẵn (AVAILABLE)
                var inks = await _context.Inks
                    .Where(i => i.Status == "AVAILABLE")
                    .OrderBy(i => i.Color)
                    .ToListAsync();

                var response = new PrinterRemainingPagesDto
                {
                    PrinterId = printer.PrinterId,
                    PrinterCode = printer.PrinterCode,
                    Location = printer.Location,
                    RemainingPaperPages = printer.CurrentPaper ?? 0,
                    Inks = inks.Select(i => new InkRemainingPagesDto
                    {
                        InkId = i.InkId,
                        InkCode = i.InkCode,
                        Color = i.Color,
                        RemainingPages = i.CurrentPages
                    }).ToList()
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.GetRemainingPages] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy hàng đợi in (queue) của một máy in với thời gian chờ ước tính
        /// Tính toán thời gian: A4 = 0.5s/tờ, A3 = 0.7s/tờ + 60s (làm lạnh)
        /// </summary>
        [HttpGet("Queue/{printerId}")]
        [ProducesResponseType(typeof(PrinterQueueResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetQueue(int printerId)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                // Kiểm tra máy in tồn tại
                var printer = await _context.Printers.FindAsync(printerId);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                // Lấy tất cả print jobs đang chờ hoặc đang in (PENDING hoặc PRINTING)
                // Sắp xếp theo CreatedOn (FIFO - First In First Out)
                var queueJobs = await _context.PrintJobs
                    .Where(j => j.PrinterId == printerId && (j.Status == "PENDING" || j.Status == "PRINTING"))
                    .Include(j => j.User)
                    .Include(j => j.Document)
                    .Include(j => j.PaperSize)
                    .OrderBy(j => j.CreatedOn)
                    .ToListAsync();

                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                var queueItems = new List<PrintQueueItemDto>();
                double cumulativeWaitTime = 0; // Tổng thời gian chờ tích lũy

                for (int i = 0; i < queueJobs.Count; i++)
                {
                    var job = queueJobs[i];
                    
                    // Tính số giấy thực tế cần in
                    var (actualPagesPerCopy, paperSizeCode, isDoubleSided) = CalculateActualPagesFromPrintJob(job);
                    var totalPapersNeeded = actualPagesPerCopy * (job.Copies ?? 1); // Số tờ giấy thực tế
                    
                    // Tính thời gian in: A4 = 0.5s/tờ, A3 = 0.7s/tờ + 60s (làm lạnh)
                    const double secondsPerPaperA4 = 0.5;
                    const double secondsPerPaperA3 = 0.7;
                    const double coolingTimeSeconds = 60.0; // 1 phút làm lạnh
                    double secondsPerPaper = secondsPerPaperA4; // Default A4
                    if (paperSizeCode == "A3")
                    {
                        secondsPerPaper = secondsPerPaperA3;
                    }
                    var jobDurationSeconds = (totalPapersNeeded * secondsPerPaper) + coolingTimeSeconds;

                    // Thời gian chờ ước tính = tổng thời gian của các job phía trước
                    var estimatedWaitTime = cumulativeWaitTime;
                    var estimatedStartTime = now.AddSeconds(estimatedWaitTime);
                    var estimatedCompleteTime = estimatedStartTime.AddSeconds(jobDurationSeconds);

                    queueItems.Add(new PrintQueueItemDto
                    {
                        PrintJobId = job.PrintJobId,
                        UserId = job.UserId,
                        UserName = job.User?.FullName,
                        StudentCode = job.User?.StudentCode,
                        DocumentName = job.Document?.FileName,
                        TotalPages = job.TotalPages ?? 0,
                        Copies = job.Copies ?? 1,
                        IsColor = job.IsColor,
                        PaperSizeCode = paperSizeCode,
                        Status = job.Status ?? "UNKNOWN",
                        CreatedOn = job.CreatedOn,
                        QueuePosition = i + 1, // Vị trí trong hàng (bắt đầu từ 1)
                        EstimatedWaitTimeSeconds = Math.Round(estimatedWaitTime, 1),
                        EstimatedPrintTimeSeconds = Math.Round(jobDurationSeconds, 1),
                        EstimatedStartTime = estimatedStartTime,
                        EstimatedCompleteTime = estimatedCompleteTime
                    });

                    // Cộng dồn thời gian cho job tiếp theo
                    // Nếu job đang PRINTING, chỉ tính thời gian còn lại (ước tính một nửa)
                    if (job.Status == "PRINTING")
                    {
                        cumulativeWaitTime += jobDurationSeconds / 2; // Giả sử đã in được một nửa
                    }
                    else
                    {
                        cumulativeWaitTime += jobDurationSeconds;
                    }
                }

                var response = new PrinterQueueResponseDto
                {
                    PrinterId = printer.PrinterId,
                    PrinterCode = printer.PrinterCode,
                    Location = printer.Location,
                    TotalJobsInQueue = queueJobs.Count,
                    QueueItems = queueItems
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.GetQueue] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Thực thi in: Lấy print job PENDING đầu tiên từ queue, chuyển sang PRINTING
        /// Sinh viên cũng có thể gọi API này. Giấy và mực sẽ được trừ sau khi in xong (UpdateAfterPrint)
        /// </summary>
        [HttpPost("ExecutePrint/{printerId}")]
        [ProducesResponseType(typeof(ExecutePrintResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> ExecutePrint(int printerId)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                // Kiểm tra máy in tồn tại
                var printer = await _context.Printers.FindAsync(printerId);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                // Lấy print job PENDING đầu tiên (FIFO)
                var printJob = await _context.PrintJobs
                    .Where(j => j.PrinterId == printerId && j.Status == "PENDING")
                    .Include(j => j.User)
                    .Include(j => j.Document)
                    .Include(j => j.PaperSize)
                    .OrderBy(j => j.CreatedOn)
                    .FirstOrDefaultAsync();

                if (printJob == null)
                {
                    return BadRequest(new { success = false, message = "Không có print job nào đang chờ in." });
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                // Tính số giấy thực tế cần in
                var (actualPagesPerCopy, paperSizeCode, isDoubleSided) = CalculateActualPagesFromPrintJob(printJob);
                var totalPapersNeeded = actualPagesPerCopy * (printJob.Copies ?? 1); // Số tờ giấy thực tế

                // Tính thời gian in: A4 = 0.5s/tờ, A3 = 0.7s/tờ + 60s (làm lạnh)
                const double secondsPerPaperA4 = 0.5;
                const double secondsPerPaperA3 = 0.7;
                const double coolingTimeSeconds = 60.0; // 1 phút làm lạnh
                double secondsPerPaper = secondsPerPaperA4; // Default A4
                if (paperSizeCode == "A3")
                {
                    secondsPerPaper = secondsPerPaperA3;
                }
                var estimatedPrintTimeSeconds = (totalPapersNeeded * secondsPerPaper) + coolingTimeSeconds;
                var estimatedCompleteTime = now.AddSeconds(estimatedPrintTimeSeconds);

                // Chỉ cập nhật PrintJob status: PENDING → PRINTING
                // KHÔNG trừ giấy/mực ở đây - sẽ trừ sau khi in xong (UpdateAfterPrint)
                printJob.Status = "PRINTING";
                printJob.ModifiedOn = now;
                printJob.ModifiedBy = email ?? userId?.ToString();

                await _context.SaveChangesAsync();

                // Gửi SignalR notifications
                await SendPrintJobStatusUpdateAsync(printJob, now);
                await SendPrinterStatusUpdateAsync(printer, now);

                var response = new ExecutePrintResponseDto
                {
                    PrintJobId = printJob.PrintJobId,
                    UserId = printJob.UserId,
                    UserName = printJob.User?.FullName,
                    StudentCode = printJob.User?.StudentCode,
                    DocumentName = printJob.Document?.FileName,
                    TotalPages = printJob.TotalPages ?? 0,
                    Copies = printJob.Copies ?? 1,
                    IsColor = printJob.IsColor,
                    PaperSizeCode = paperSizeCode,
                    Status = printJob.Status,
                    EstimatedPrintTimeSeconds = Math.Round(estimatedPrintTimeSeconds, 1),
                    EstimatedCompleteTime = estimatedCompleteTime,
                    RemainingPaperAfterPrint = printer.CurrentPaper ?? 0, // Giữ nguyên, chưa trừ
                    InksAfterPrint = new List<InkAfterPrintDto>() // Chưa trừ mực
                };

                return Ok(new { 
                    success = true, 
                    message = "Bắt đầu in thành công. Giấy và mực sẽ được trừ sau khi in xong.",
                    data = response
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.ExecutePrint] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Cập nhật trạng thái sau khi in xong (trừ giấy và mực)
        /// </summary>
        [HttpPost("UpdateAfterPrint")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> UpdateAfterPrint([FromBody] UpdateAfterPrintDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                // Cho phép sinh viên gọi API này sau khi in xong để trừ giấy và mực
                // Không cần kiểm tra SPSO role

                // Kiểm tra PrintJob (cần Include PaperSize để tính toán)
                var printJob = await _context.PrintJobs
                    .Include(j => j.PaperSize)
                    .FirstOrDefaultAsync(j => j.PrintJobId == dto.PrintJobId);
                if (printJob == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy print job." });
                }

                // Kiểm tra status phải là PRINTING
                if (printJob.Status != "PRINTING")
                {
                    return BadRequest(new { 
                        success = false, 
                        message = $"Print job không ở trạng thái PRINTING. Trạng thái hiện tại: {printJob.Status ?? "UNKNOWN"}" 
                    });
                }

                // Kiểm tra Printer
                var printer = await _context.Printers.FindAsync(dto.PrinterId);
                if (printer == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                // Tính số giấy thực tế cần in
                var (actualPagesPerCopy, paperSizeCode, isDoubleSided) = CalculateActualPagesFromPrintJob(printJob);
                var totalPapersNeeded = actualPagesPerCopy * (printJob.Copies ?? 1); // Số tờ giấy thực tế

                // 1. Trừ giấy trong máy in
                if (printer.CurrentPaper.HasValue)
                {
                    if (printer.CurrentPaper.Value < totalPapersNeeded)
                    {
                        return BadRequest(new { 
                            success = false, 
                            message = $"Không đủ giấy. Máy in còn {printer.CurrentPaper.Value} tờ, cần {totalPapersNeeded} tờ." 
                        });
                    }
                    
                    var newCurrentPaper = printer.CurrentPaper.Value - totalPapersNeeded;
                    printer.CurrentPaper = newCurrentPaper;
                    printer.ModifiedOn = now;
                    printer.ModifiedBy = email ?? userId?.ToString();
                }

                // 2. Trừ mực (tìm cuộn mực phù hợp)
                // Mực tiêu hao: 1 mặt = 1 mực/giấy, 2 mặt = 2 mực/giấy
                var inkConsumptionPerPaper = isDoubleSided ? 2 : 1;
                var totalInkNeeded = totalPapersNeeded * inkConsumptionPerPaper;
                
                // Nếu in màu, cần trừ các cuộn mực màu (CYAN, MAGENTA, YELLOW)
                // Nếu in đen trắng, chỉ trừ cuộn mực đen (BLACK)
                var inkColorsToUpdate = printJob.IsColor 
                    ? new[] { "BLACK", "COLOR" }
                    : new[] { "BLACK" };

                var inksToUpdate = await _context.Inks
                    .Where(i => i.Status == "AVAILABLE" && inkColorsToUpdate.Contains(i.Color.ToUpper()))
                    .ToListAsync();

                if (!inksToUpdate.Any())
                {
                    return BadRequest(new { 
                        success = false, 
                        message = "Không tìm thấy cuộn mực phù hợp." 
                    });
                }

                // Kiểm tra đủ mực
                foreach (var ink in inksToUpdate)
                {
                    if (ink.CurrentPages < totalInkNeeded)
                    {
                        return BadRequest(new { 
                            success = false, 
                            message = $"Không đủ mực {ink.Color}. Cuộn mực còn {ink.CurrentPages} trang, cần {totalInkNeeded} trang." 
                        });
                    }
                }

                // Trừ mực
                foreach (var ink in inksToUpdate)
                {
                    var newCurrentPages = ink.CurrentPages - totalInkNeeded;
                    ink.CurrentPages = newCurrentPages;
                    
                    // Cập nhật status nếu hết mực
                    if (newCurrentPages == 0)
                    {
                        ink.Status = "OFFLINE";
                    }
                    else if (newCurrentPages <= (ink.CapacityPages * 0.2)) // Nếu còn ≤ 20% thì chuyển LOW
                    {
                        ink.Status = "LOW";
                    }
                    else if (newCurrentPages <= (ink.CapacityPages * 0.5)) // Nếu còn ≤ 50% thì chuyển MEDIUM
                    {
                        ink.Status = "MEDIUM";
                    }
                    
                    ink.ModifiedOn = now;
                    ink.ModifiedBy = email ?? userId?.ToString();
                }

                // 3. Cập nhật PrintJob status nếu chưa DONE
                if (printJob.Status != "DONE")
                {
                    printJob.Status = "DONE";
                    printJob.CompletedAt = now;
                    printJob.ModifiedOn = now;
                    printJob.ModifiedBy = email ?? userId?.ToString();
                }

                await _context.SaveChangesAsync();

                return Ok(new { 
                    success = true, 
                    message = "Cập nhật trạng thái sau khi in thành công.",
                    data = new {
                        PrinterId = printer.PrinterId,
                        NewCurrentPaper = printer.CurrentPaper,
                        UpdatedInks = inksToUpdate.Select(i => new {
                            InkId = i.InkId,
                            InkCode = i.InkCode,
                            Color = i.Color,
                            NewCurrentPages = i.CurrentPages,
                            Status = i.Status
                        }).ToList()
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterController.UpdateAfterPrint] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Helper: Tính số giấy thực tế từ PrintJob và parse double-sided
        /// </summary>
        private (int actualPagesPerCopy, string? paperSizeCode, bool isDoubleSided) CalculateActualPagesFromPrintJob(PrintJob job)
        {
            var paperSizeCode = job.PaperSize?.Code?.ToUpper();
            int actualPagesPerCopy = job.TotalPages ?? 0;
            
            // Nếu là A3, TotalPages đã được nhân 2 (A3 = 2x A4), nên chia lại
            if (paperSizeCode == "A3")
            {
                actualPagesPerCopy = actualPagesPerCopy / 2;
            }
            
            // Parse double-sided từ PagesToPrint (format: "PAGES|DOUBLE_SIDED" hoặc "ALL|DOUBLE_SIDED")
            bool isDoubleSided = false;
            if (!string.IsNullOrWhiteSpace(job.PagesToPrint) && job.PagesToPrint.Contains("|DOUBLE_SIDED", StringComparison.OrdinalIgnoreCase))
            {
                isDoubleSided = true;
            }
            
            return (actualPagesPerCopy, paperSizeCode, isDoubleSided);
        }

        /// <summary>
        /// Gửi SignalR notification về trạng thái print job
        /// </summary>
        private async Task SendPrintJobStatusUpdateAsync(PrintJob job, DateTime now)
        {
            try
            {
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

