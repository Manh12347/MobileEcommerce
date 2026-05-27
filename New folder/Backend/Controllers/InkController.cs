using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    [Produces("application/json")]
    public class InkController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<InkController> _logger;

        public InkController(WebDbContext context, ILogger<InkController> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Lấy danh sách tất cả cuộn mực
        /// </summary>
        [HttpGet("All")]
        [ProducesResponseType(typeof(List<InkResponseDto>), 200)]
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

                var inks = await _context.Inks
                    .OrderBy(i => i.InkCode)
                    .Select(i => new InkResponseDto
                    {
                        InkId = i.InkId,
                        InkCode = i.InkCode,
                        InkType = i.InkType,
                        Color = i.Color,
                        CapacityPages = i.CapacityPages,
                        CurrentPages = i.CurrentPages,
                        Status = i.Status,
                        Brand = i.Brand,
                        // Resolve assigned printer (printers.ink_id == ink.ink_id)
                        AssignedPrinterName = _context.Printers
                            .Where(p => p.InkId == i.InkId)
                            .Select(p => (string?) (p.PrinterCode ?? p.Model ?? p.Location))
                            .FirstOrDefault() ?? "None",
                        CreatedOn = i.CreatedOn,
                        CreatedBy = i.CreatedBy,
                        ModifiedOn = i.ModifiedOn,
                        ModifiedBy = i.ModifiedBy
                    })
                    .ToListAsync();

                return Ok(new { success = true, data = inks });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[InkController.GetAll] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy thông tin cuộn mực theo ID
        /// </summary>
        [HttpGet("Get/{id}")]
        [ProducesResponseType(typeof(InkResponseDto), 200)]
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

                var ink = await _context.Inks.FindAsync(id);
                if (ink == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy cuộn mực." });
                }

                var response = new InkResponseDto
                {
                    InkId = ink.InkId,
                    InkCode = ink.InkCode,
                    InkType = ink.InkType,
                    Color = ink.Color,
                    CapacityPages = ink.CapacityPages,
                    CurrentPages = ink.CurrentPages,
                    Status = ink.Status,
                    Brand = ink.Brand,
                    AssignedPrinterName = _context.Printers
                        .Where(p => p.InkId == ink.InkId)
                        .Select(p => (string?) (p.PrinterCode ?? p.Model ?? p.Location))
                        .FirstOrDefault() ?? "None",
                    CreatedOn = ink.CreatedOn,
                    CreatedBy = ink.CreatedBy,
                    ModifiedOn = ink.ModifiedOn,
                    ModifiedBy = ink.ModifiedBy
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[InkController.GetById] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Tạo cuộn mực mới (chỉ SPSO)
        /// </summary>
        [HttpPost("Create")]
        [ProducesResponseType(typeof(InkResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Create([FromBody] InkUpsertDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền tạo cuộn mực." });
                }

                // Validate
                if (string.IsNullOrWhiteSpace(dto.InkCode))
                {
                    return BadRequest(new { success = false, message = "Mã cuộn mực là bắt buộc." });
                }

                // Kiểm tra InkCode đã tồn tại chưa
                var existing = await _context.Inks
                    .FirstOrDefaultAsync(i => i.InkCode.ToUpper() == dto.InkCode.ToUpper());
                if (existing != null)
                {
                    return BadRequest(new { success = false, message = "Mã cuộn mực đã tồn tại." });
                }

                // Validate InkType
                if (string.IsNullOrWhiteSpace(dto.InkType))
                {
                    return BadRequest(new { success = false, message = "Loại mực là bắt buộc." });
                }
                var validInkTypes = new[] { "TONER", "INKJET" };
                if (!validInkTypes.Contains(dto.InkType.ToUpper()))
                {
                    return BadRequest(new { success = false, message = "Loại mực không hợp lệ. Các loại hợp lệ: TONER, INKJET." });
                }

                // Validate Color
                if (string.IsNullOrWhiteSpace(dto.Color))
                {
                    return BadRequest(new { success = false, message = "Màu mực là bắt buộc." });
                }
                var validColors = new[] { "BLACK", "COLOR" };
                if (!validColors.Contains(dto.Color.ToUpper()))
                {
                    return BadRequest(new { success = false, message = "Màu mực không hợp lệ. Các màu hợp lệ: BLACK, COLOR." });
                }

                // Validate Status
                if (string.IsNullOrWhiteSpace(dto.Status))
                {
                    return BadRequest(new { success = false, message = "Trạng thái là bắt buộc." });
                }
                var validStatuses = new[] { "AVAILABLE", "MEDIUM", "LOW", "OFFLINE" };
                if (!validStatuses.Contains(dto.Status.ToUpper()))
                {
                    return BadRequest(new { success = false, message = "Trạng thái không hợp lệ. Các trạng thái hợp lệ: AVAILABLE, MEDIUM, LOW, OFFLINE." });
                }

                // Validate CapacityPages và CurrentPages
                if (dto.CapacityPages < 0)
                {
                    return BadRequest(new { success = false, message = "Số trang tối đa không được âm." });
                }
                if (dto.CurrentPages < 0)
                {
                    return BadRequest(new { success = false, message = "Số trang còn lại không được âm." });
                }
                if (dto.CurrentPages > dto.CapacityPages)
                {
                    return BadRequest(new { success = false, message = "Số trang còn lại không được lớn hơn số trang tối đa." });
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                var ink = new Ink
                {
                    InkCode = dto.InkCode.ToUpper(),
                    InkType = dto.InkType.ToUpper(),
                    Color = dto.Color.ToUpper(),
                    CapacityPages = dto.CapacityPages,
                    CurrentPages = dto.CurrentPages,
                    Status = dto.Status.ToUpper(),
                    Brand = dto.Brand,
                    CreatedOn = now,
                    CreatedBy = email ?? userId?.ToString()
                };

                _context.Inks.Add(ink);
                await _context.SaveChangesAsync();

                var response = new InkResponseDto
                {
                    InkId = ink.InkId,
                    InkCode = ink.InkCode,
                    InkType = ink.InkType,
                    Color = ink.Color,
                    CapacityPages = ink.CapacityPages,
                    CurrentPages = ink.CurrentPages,
                    Status = ink.Status,
                    Brand = ink.Brand,
                    AssignedPrinterName = _context.Printers
                        .Where(p => p.InkId == ink.InkId)
                        .Select(p => (string?) (p.PrinterCode ?? p.Model ?? p.Location))
                        .FirstOrDefault() ?? "None",
                    CreatedOn = ink.CreatedOn,
                    CreatedBy = ink.CreatedBy,
                    ModifiedOn = ink.ModifiedOn,
                    ModifiedBy = ink.ModifiedBy
                };

                return Ok(new { success = true, message = "Tạo cuộn mực thành công.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[InkController.Create] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Cập nhật cuộn mực (chỉ SPSO)
        /// </summary>
        [HttpPut("Update/{id}")]
        [ProducesResponseType(typeof(InkResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Update(int id, [FromBody] InkUpsertDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền cập nhật cuộn mực." });
                }

                var ink = await _context.Inks.FindAsync(id);
                if (ink == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy cuộn mực." });
                }

                // Validate
                if (string.IsNullOrWhiteSpace(dto.InkCode))
                {
                    return BadRequest(new { success = false, message = "Mã cuộn mực là bắt buộc." });
                }

                // Kiểm tra InkCode đã tồn tại chưa (trừ chính nó)
                if (ink.InkCode.ToUpper() != dto.InkCode.ToUpper())
                {
                    var existing = await _context.Inks
                        .FirstOrDefaultAsync(i => i.InkId != id && i.InkCode.ToUpper() == dto.InkCode.ToUpper());
                    if (existing != null)
                    {
                        return BadRequest(new { success = false, message = "Mã cuộn mực đã tồn tại." });
                    }
                }

                // Validate InkType
                if (string.IsNullOrWhiteSpace(dto.InkType))
                {
                    return BadRequest(new { success = false, message = "Loại mực là bắt buộc." });
                }
                var validInkTypes = new[] { "TONER", "INKJET" };
                if (!validInkTypes.Contains(dto.InkType.ToUpper()))
                {
                    return BadRequest(new { success = false, message = "Loại mực không hợp lệ. Các loại hợp lệ: TONER, INKJET." });
                }

                // Validate Color
                if (string.IsNullOrWhiteSpace(dto.Color))
                {
                    return BadRequest(new { success = false, message = "Màu mực là bắt buộc." });
                }
                var validColors = new[] { "BLACK", "COLOR" };
                if (!validColors.Contains(dto.Color.ToUpper()))
                {
                    return BadRequest(new { success = false, message = "Màu mực không hợp lệ. Các màu hợp lệ: BLACK, COLOR." });
                }

                // Validate Status
                if (string.IsNullOrWhiteSpace(dto.Status))
                {
                    return BadRequest(new { success = false, message = "Trạng thái là bắt buộc." });
                }
                var validStatuses = new[] { "AVAILABLE", "MEDIUM", "LOW", "OFFLINE" };
                if (!validStatuses.Contains(dto.Status.ToUpper()))
                {
                    return BadRequest(new { success = false, message = "Trạng thái không hợp lệ. Các trạng thái hợp lệ: AVAILABLE, MEDIUM, LOW, OFFLINE." });
                }

                // Validate CapacityPages và CurrentPages
                if (dto.CapacityPages < 0)
                {
                    return BadRequest(new { success = false, message = "Số trang tối đa không được âm." });
                }
                if (dto.CurrentPages < 0)
                {
                    return BadRequest(new { success = false, message = "Số trang còn lại không được âm." });
                }
                if (dto.CurrentPages > dto.CapacityPages)
                {
                    return BadRequest(new { success = false, message = "Số trang còn lại không được lớn hơn số trang tối đa." });
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                // Cập nhật
                ink.InkCode = dto.InkCode.ToUpper();
                ink.InkType = dto.InkType.ToUpper();
                ink.Color = dto.Color.ToUpper();
                ink.CapacityPages = dto.CapacityPages;
                ink.CurrentPages = dto.CurrentPages;
                ink.Status = dto.Status.ToUpper();
                ink.Brand = dto.Brand;
                ink.ModifiedOn = now;
                ink.ModifiedBy = email ?? userId?.ToString();

                await _context.SaveChangesAsync();

                var response = new InkResponseDto
                {
                    InkId = ink.InkId,
                    InkCode = ink.InkCode,
                    InkType = ink.InkType,
                    Color = ink.Color,
                    CapacityPages = ink.CapacityPages,
                    CurrentPages = ink.CurrentPages,
                    Status = ink.Status,
                    Brand = ink.Brand,
                    CreatedOn = ink.CreatedOn,
                    CreatedBy = ink.CreatedBy,
                    ModifiedOn = ink.ModifiedOn,
                    ModifiedBy = ink.ModifiedBy
                };

                return Ok(new { success = true, message = "Cập nhật cuộn mực thành công.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[InkController.Update] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Xóa cuộn mực (chỉ SPSO)
        /// </summary>
        [HttpDelete("Delete/{id}")]
        [ProducesResponseType(200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xóa cuộn mực." });
                }

                var ink = await _context.Inks.FindAsync(id);
                if (ink == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy cuộn mực." });
                }

                _context.Inks.Remove(ink);
                await _context.SaveChangesAsync();

                return Ok(new { success = true, message = "Xóa cuộn mực thành công." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[InkController.Delete] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách cuộn mực (cho user)
        /// </summary>
        [HttpGet("GetList")]
        [ProducesResponseType(typeof(List<InkListDto>), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetList()
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                var inks = await _context.Inks
                    .OrderBy(i => i.InkCode)
                    .Select(i => new InkListDto
                    {
                        InkId = i.InkId,
                        InkCode = i.InkCode,
                        InkType = i.InkType,
                        Color = i.Color,
                        CapacityPages = i.CapacityPages,
                        CurrentPages = i.CurrentPages,
                        Status = i.Status,
                        Brand = i.Brand,
                    })
                    .ToListAsync();

                return Ok(new { success = true, data = inks });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[InkController.GetList] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Generate mã cuộn mực tự động (chỉ SPSO)
        /// </summary>
        [HttpGet("GenerateInkCode")]
        [ProducesResponseType(typeof(object), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GenerateInkCode()
        {
            try
            {
                _logger.LogInformation("[InkController.GenerateInkCode] Starting ink code generation");

                // TEMPORARILY DISABLED FOR DEBUGGING
                // if (!AuthHelper.IsLoggedIn(HttpContext))
                // {
                //     _logger.LogWarning("[InkController.GenerateInkCode] User not logged in");
                //     return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                // }

                // if (!AuthHelper.IsSPSO(HttpContext))
                // {
                //     _logger.LogWarning("[InkController.GenerateInkCode] User is not SPSO");
                //     return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền generate mã cuộn mực." });
                // }

                // Lấy số lượng ink hiện tại để tạo mã tiếp theo
                var currentCount = await _context.Inks.CountAsync();
                var nextNumber = currentCount + 1;
                _logger.LogInformation($"[InkController.GenerateInkCode] Current ink count: {currentCount}, Next number: {nextNumber}");

                // Generate mã theo pattern INK + số (3 chữ số)
                var inkCode = $"INK{nextNumber:D3}";
                _logger.LogInformation($"[InkController.GenerateInkCode] Generated ink code: {inkCode}");

                // Đảm bảo mã chưa tồn tại (double check)
                var existing = await _context.Inks
                    .FirstOrDefaultAsync(i => i.InkCode.ToUpper() == inkCode.ToUpper());

                if (existing != null)
                {
                    _logger.LogInformation($"[InkController.GenerateInkCode] Code {inkCode} already exists, finding max number");

                    // Nếu đã tồn tại, tìm số lớn nhất và +1
                    var inkCodes = await _context.Inks
                        .Where(i => i.InkCode.StartsWith("INK"))
                        .Select(i => i.InkCode)
                        .ToListAsync();

                    var maxNumber = 0;
                    var hasInkCodes = false;
                    foreach (var code in inkCodes)
                    {
                        if (code.Length >= 6 && code.StartsWith("INK")) // INK + 3 digits minimum
                        {
                            var numPart = code.Substring(3);
                            if (int.TryParse(numPart, out int num))
                            {
                                maxNumber = Math.Max(maxNumber, num);
                                hasInkCodes = true;
                            }
                        }
                    }

                    if (hasInkCodes)
                    {
                        inkCode = $"INK{(maxNumber + 1):D3}";
                    }
                    else
                    {
                        // Fallback if no INK codes found
                        inkCode = $"INK{nextNumber:D3}";
                    }
                    _logger.LogInformation($"[InkController.GenerateInkCode] New ink code after conflict resolution: {inkCode}");
                }

                _logger.LogInformation($"[InkController.GenerateInkCode] Final ink code: {inkCode}");

                return Ok(new
                {
                    success = true,
                    data = new
                    {
                        inkCode = inkCode,
                        generated = true
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[InkController.GenerateInkCode] Error occurred: {Message}", ex.Message);
                _logger.LogError(ex, "[InkController.GenerateInkCode] Stack trace: {StackTrace}", ex.StackTrace);
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }
    }
}

