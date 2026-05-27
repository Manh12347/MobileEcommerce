using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using Microsoft.AspNetCore.SignalR;
using PTVBTPM.Hubs;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    [Produces("application/json")]
    public class PrinterPaperController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<PrinterPaperController> _logger;
        private readonly IHubContext<PrintHub> _hubContext;
        private readonly IServiceProvider _serviceProvider;

        public PrinterPaperController(WebDbContext context, ILogger<PrinterPaperController> logger, IHubContext<PrintHub> hubContext, IServiceProvider serviceProvider)
        {
            _context = context;
            _logger = logger;
            _hubContext = hubContext;
            _serviceProvider = serviceProvider;
        }

        [HttpPost("AddPaper/{id}")]
        public async Task<IActionResult> AddPaper(int id, [FromBody] AddPaperDto dto)
        {
            try
            {
                if (!AuthHelper.IsLoggedIn(HttpContext))
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập." });

                if (!AuthHelper.IsSPSO(HttpContext))
                    return StatusCode(403, new { success = false, message = "Chỉ SPSO mới có quyền nạp giấy." });

                // if client didn't provide AdditionalPages or provided non-positive, use system default
                int pagesToAdd = 0;
                if (dto == null || dto.AdditionalPages <= 0)
                {
                    var sys = await _context.SystemConfigs.FirstOrDefaultAsync(c => c.ConfigId == 1);
                    pagesToAdd = sys?.DefaultAdditionalPaper ?? 100;
                }
                else
                {
                    pagesToAdd = dto.AdditionalPages;
                }

                var printer = await _context.Printers.FindAsync(id);
                if (printer == null)
                    return NotFound(new { success = false, message = "Không tìm thấy máy in." });

                var email = AuthHelper.GetCurrentEmail(HttpContext);
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                // Perform aggregate add synchronously and send a single SignalR update to avoid spamming
                try
                {
                    using var scope = _serviceProvider.CreateScope();
                    var scopedContext = scope.ServiceProvider.GetRequiredService<WebDbContext>();
                    var hub = scope.ServiceProvider.GetRequiredService<IHubContext<PrintHub>>();

                    var group = $"printer_{id}";
                    var p = await scopedContext.Printers.FindAsync(id);
                    if (p == null)
                        return NotFound(new { success = false, message = "Không tìm thấy máy in." });

                    var capacity = p.PaperCapacity ?? int.MaxValue;
                    var current = p.CurrentPaper ?? 0;

                    var remainingCapacity = capacity > 0 ? capacity - current : int.MaxValue;
                    var toAdd = Math.Min(remainingCapacity, pagesToAdd);
                    if (toAdd <= 0)
                    {
                        // already full - send single full notification
                        await hub.Clients.Group(group).SendAsync("PrinterFull", new { PrinterId = id, CurrentPaper = current, Capacity = capacity });
                        return BadRequest(new { success = false, message = "Máy in đã đầy giấy." });
                    }

                    p.CurrentPaper = current + toAdd;
                    p.AdditionalPaper = toAdd;
                    p.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                    p.ModifiedBy = email ?? userId?.ToString();

                    scopedContext.Printers.Update(p);
                    await scopedContext.SaveChangesAsync();

                    // send a single status update
                    await hub.Clients.Group(group).SendAsync("PrinterStatusUpdate", new PrinterStatusUpdateDto
                    {
                        PrinterId = id,
                        Status = p.Status,
                        CurrentPaper = p.CurrentPaper ?? 0,
                        UpdatedAt = p.ModifiedOn ?? DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified)
                    });

                    // if now full, send a single full notification
                    if (p.CurrentPaper >= capacity)
                    {
                        await hub.Clients.Group(group).SendAsync("PrinterFull", new { PrinterId = id, CurrentPaper = p.CurrentPaper, Capacity = capacity });
                    }

                    // return updated printer info so client can refresh immediately
                    var updated = await scopedContext.Printers
                        .Include(pr => pr.PrinterCapabilities).ThenInclude(c => c.PaperSize)
                        .Include(pr => pr.Ink)
                        .FirstOrDefaultAsync(pr => pr.PrinterId == id);

                    var responseDto = new PrinterResponseDto
                    {
                        PrinterId = updated!.PrinterId,
                        PrinterCode = updated.PrinterCode,
                        Location = updated.Location,
                        Brand = updated.Brand,
                        Model = updated.Model,
                        Status = updated.Status,
                        PaperCapacity = updated.PaperCapacity,
                        AdditionalPaper = updated.AdditionalPaper,
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

                    return Ok(new { success = true, message = "Đã thêm giấy.", data = responseDto });
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "[PrinterPaperController.AddPaper] background add error");
                    return StatusCode(500, new { success = false, message = "Có lỗi khi thêm giấy.", error = ex.Message });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PrinterPaperController.AddPaper] Error");
                return StatusCode(500, new { success = false, message = "Có lỗi xảy ra.", error = ex.Message });
            }
        }
    }
}


