using Microsoft.AspNetCore.Http;

namespace PTVBTPM.Models.DTOs;

public class UpdateProfileRequestDto
{
    public string? FullName { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? Address { get; set; }
    public string? PhoneNumber { get; set; }
    public IFormFile? Avatar { get; set; }
}

public class Update2FARequestDto
{
    public bool Enable { get; set; }
    public string? Method { get; set; } // "authenticator", "email", "both"
}

