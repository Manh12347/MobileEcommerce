namespace PTVBTPM.Models.DTOs;

public class AuthResponseDto
{
    public bool Success { get; set; }
    public string? Message { get; set; }
    public UserInfoDto? User { get; set; }
}

