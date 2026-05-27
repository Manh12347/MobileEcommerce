namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO để lưu thông tin user đang chờ xác nhận email trong cache
/// </summary>
public class PendingUserRegistrationDto
{
    public string StudentCode { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Role { get; set; } = "STUDENT";
    public string? AvatarUrl { get; set; }
    public DateTime CreatedOn { get; set; }
}

