namespace PTVBTPM.Models.DTOs;

public class ConfirmEmailRequestDto
{
    public string Email { get; set; } = string.Empty;
    public string Otp { get; set; } = string.Empty;
}

public class ResendOtpRequestDto
{
    public string Email { get; set; } = string.Empty;
}

