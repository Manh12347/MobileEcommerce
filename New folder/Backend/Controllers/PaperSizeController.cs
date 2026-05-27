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
    public class PaperSizeController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<PaperSizeController> _logger;

        public PaperSizeController(WebDbContext context, ILogger<PaperSizeController> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Lấy danh sách tất cả loại giấy
        /// </summary>
        [HttpGet("All")]
        [ProducesResponseType(typeof(List<PaperSizeResponseDto>), 200)]
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

                var paperSizes = await _context.PaperSizes
                    .OrderBy(p => p.Code)
                    .Select(p => new PaperSizeResponseDto
                    {
                        PaperSizeId = p.PaperSizeId,
                        Code = p.Code,
                        Description = p.Description,
                        Price = p.Price,
                        CreatedOn = p.CreatedOn,
                        CreatedBy = p.CreatedBy,
                        ModifiedOn = p.ModifiedOn,
                        ModifiedBy = p.ModifiedBy
                    })
                    .ToListAsync();

                return Ok(new { success = true, data = paperSizes });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PaperSizeController.GetAll] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy thông tin loại giấy theo ID
        /// </summary>
        [HttpGet("Get/{id}")]
        [ProducesResponseType(typeof(PaperSizeResponseDto), 200)]
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

                var paperSize = await _context.PaperSizes.FindAsync(id);
                if (paperSize == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy loại giấy." });
                }

                var response = new PaperSizeResponseDto
                {
                    PaperSizeId = paperSize.PaperSizeId,
                    Code = paperSize.Code,
                    Description = paperSize.Description,
                    Price = paperSize.Price,
                    CreatedOn = paperSize.CreatedOn,
                    CreatedBy = paperSize.CreatedBy,
                    ModifiedOn = paperSize.ModifiedOn,
                    ModifiedBy = paperSize.ModifiedBy
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PaperSizeController.GetById] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Tạo loại giấy mới (chỉ SPSO)
        /// </summary>
        [HttpPost("Create")]
        [ProducesResponseType(typeof(PaperSizeResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Create([FromBody] PaperSizeUpsertDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền tạo loại giấy." });
                }

                // Validate
                if (string.IsNullOrWhiteSpace(dto.Code))
                {
                    return BadRequest(new { success = false, message = "Code là bắt buộc." });
                }

                // Kiểm tra Code đã tồn tại chưa
                var existing = await _context.PaperSizes
                    .FirstOrDefaultAsync(p => p.Code.ToUpper() == dto.Code.ToUpper());
                if (existing != null)
                {
                    return BadRequest(new { success = false, message = "Code đã tồn tại." });
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                // Validate giá
                if (dto.Price.HasValue && dto.Price.Value <= 0)
                {
                    return BadRequest(new { success = false, message = "Giá in phải lớn hơn 0." });
                }

                var paperSize = new PaperSize
                {
                    Code = dto.Code.ToUpper(),
                    Description = dto.Description,
                    Price = dto.Price,
                    CreatedOn = now,
                    CreatedBy = email ?? userId?.ToString()
                };

                _context.PaperSizes.Add(paperSize);
                await _context.SaveChangesAsync();

                var response = new PaperSizeResponseDto
                {
                    PaperSizeId = paperSize.PaperSizeId,
                    Code = paperSize.Code,
                    Description = paperSize.Description,
                    Price = paperSize.Price,
                    CreatedOn = paperSize.CreatedOn,
                    CreatedBy = paperSize.CreatedBy,
                    ModifiedOn = paperSize.ModifiedOn,
                    ModifiedBy = paperSize.ModifiedBy
                };

                return Ok(new { success = true, message = "Tạo loại giấy thành công.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PaperSizeController.Create] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Cập nhật loại giấy (chỉ SPSO)
        /// </summary>
        [HttpPut("Update/{id}")]
        [ProducesResponseType(typeof(PaperSizeResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(404)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> Update(int id, [FromBody] PaperSizeUpsertDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });
                }

                if (!AuthHelper.IsSPSO(HttpContext))
                {
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền cập nhật loại giấy." });
                }

                var paperSize = await _context.PaperSizes.FindAsync(id);
                if (paperSize == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy loại giấy." });
                }

                // Validate
                if (string.IsNullOrWhiteSpace(dto.Code))
                {
                    return BadRequest(new { success = false, message = "Code là bắt buộc." });
                }

                // Validate giá
                if (dto.Price.HasValue && dto.Price.Value <= 0)
                {
                    return BadRequest(new { success = false, message = "Giá in phải lớn hơn 0." });
                }

                // Kiểm tra Code đã tồn tại chưa (trừ chính nó)
                if (paperSize.Code.ToUpper() != dto.Code.ToUpper())
                {
                    var existing = await _context.PaperSizes
                        .FirstOrDefaultAsync(p => p.PaperSizeId != id && p.Code.ToUpper() == dto.Code.ToUpper());
                    if (existing != null)
                    {
                        return BadRequest(new { success = false, message = "Code đã tồn tại." });
                    }
                }

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                // Cập nhật
                paperSize.Code = dto.Code.ToUpper();
                paperSize.Description = dto.Description;
                paperSize.Price = dto.Price;
                paperSize.ModifiedOn = now;
                paperSize.ModifiedBy = email ?? userId?.ToString();

                await _context.SaveChangesAsync();

                var response = new PaperSizeResponseDto
                {
                    PaperSizeId = paperSize.PaperSizeId,
                    Code = paperSize.Code,
                    Description = paperSize.Description,
                    Price = paperSize.Price,
                    CreatedOn = paperSize.CreatedOn,
                    CreatedBy = paperSize.CreatedBy,
                    ModifiedOn = paperSize.ModifiedOn,
                    ModifiedBy = paperSize.ModifiedBy
                };

                return Ok(new { success = true, message = "Cập nhật loại giấy thành công.", data = response });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PaperSizeController.Update] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }

        /// <summary>
        /// Xóa loại giấy (chỉ SPSO)
        /// </summary>
        [HttpDelete("Delete/{id}")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
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
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền xóa loại giấy." });
                }

                var paperSize = await _context.PaperSizes.FindAsync(id);
                if (paperSize == null)
                {
                    return NotFound(new { success = false, message = "Không tìm thấy loại giấy." });
                }

                // Kiểm tra xem có đang được sử dụng trong PrintJobs không
                var hasJobs = await _context.PrintJobs.AnyAsync(p => p.PaperSizeId == id);
                if (hasJobs)
                {
                    return BadRequest(new { success = false, message = "Không thể xóa loại giấy đang được sử dụng trong job in." });
                }

                _context.PaperSizes.Remove(paperSize);
                await _context.SaveChangesAsync();

                return Ok(new { success = true, message = "Xóa loại giấy thành công." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PaperSizeController.Delete] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }
    }
}

