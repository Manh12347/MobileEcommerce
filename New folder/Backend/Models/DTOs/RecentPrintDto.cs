namespace PTVBTPM.Models.DTOs;

public class RecentPrintDto
{
    public int PrintJobId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public int Pages { get; set; }
    public int Copies { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime? CreatedOn { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? PrinterName { get; set; }
    public string? PrinterLocation { get; set; }
}

