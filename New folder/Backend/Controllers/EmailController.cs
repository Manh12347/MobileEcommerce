using Microsoft.AspNetCore.Mvc;
using PTVBTPM.Services;

namespace PTVBTPM.Controllers;

[ApiController]
[Route("v1/api/[controller]")]
public class EmailController : ControllerBase
{
    private readonly IEmailService _emailService;
    private readonly ILogger<EmailController> _logger;

    public EmailController(IEmailService emailService, ILogger<EmailController> logger)
    {
        _emailService = emailService;
        _logger = logger;
    }

    [HttpPost("send")]
    public async Task<IActionResult> SendEmail([FromBody] SendEmailRequest request)
    {
        try
        {
            await _emailService.SendEmailAsync(
                request.To,
                request.ToName ?? request.To,
                request.Subject,
                request.Body,
                request.IsHtml
            );

            return Ok(new { message = "Email sent successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending email");
            return StatusCode(500, new { message = "Error sending email", error = ex.Message });
        }
    }
}

public class SendEmailRequest
{
    public string To { get; set; } = string.Empty;
    public string? ToName { get; set; }
    public string Subject { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public bool IsHtml { get; set; } = false;
}

