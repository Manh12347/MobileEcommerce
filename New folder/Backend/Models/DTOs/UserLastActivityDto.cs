namespace PTVBTPM.Models.DTOs;

public sealed class UserLastActivityDto
{
    public int UserId { get; set; }
    public DateTime? LastLogin { get; set; }
    public string? LastActive { get; set; }
}


