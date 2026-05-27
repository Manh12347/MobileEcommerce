namespace PTVBTPM.Models.DTOs;

public sealed class LoginLogCreateDto
{
    public int? UserId { get; set; }
    public string EventType { get; set; } = string.Empty; // SUCCESS | FAILED_PASSWORD | LOCKED
    public string? IpAddress { get; set; }
    public string? Device { get; set; }
    public string? Message { get; set; }
}


