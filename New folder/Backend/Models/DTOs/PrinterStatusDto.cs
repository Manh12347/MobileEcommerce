namespace PTVBTPM.Models.DTOs;

public class PrinterStatusDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string? PrinterName { get; set; }
    public string? Location { get; set; }
    public string? Status { get; set; }
    public int QueueCount { get; set; }
    public int? PaperCapacity { get; set; }
    /// <summary>
    /// Thông tin print job đang in (nếu có)
    /// </summary>
    public CurrentPrintJobDto? CurrentPrintJob { get; set; }
}

/// <summary>
/// Thông tin print job đang in của máy in
/// </summary>
public class CurrentPrintJobDto
{
    public int PrintJobId { get; set; }
    public int? TotalPages { get; set; }
    public int? PagesPrinted { get; set; }
    public int? ProgressPercentage { get; set; }
    public string? Status { get; set; }
}

