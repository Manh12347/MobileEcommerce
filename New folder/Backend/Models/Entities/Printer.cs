using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Danh sách máy in trong hệ thống
/// </summary>
public partial class Printer
{
    public int PrinterId { get; set; }

    public string PrinterCode { get; set; } = null!;

    public string? Location { get; set; }

    public string? Brand { get; set; }

    public string? Model { get; set; }

    public string? Status { get; set; }

    public int? PaperCapacity { get; set; }

    /// <summary>
    /// Số trang giấy còn lại trong máy in
    /// </summary>
    public int? CurrentPaper { get; set; }

    
    /// <summary>
    /// Optional: reference to an Ink currently installed in this printer
    /// </summary>
    public int? InkId { get; set; }
    
    /// <summary>
    /// Số giấy được thêm vào máy in (lần nạp gần nhất hoặc mặc định)
    /// </summary>
    public int? AdditionalPaper { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }

    public virtual ICollection<PrintJob> PrintJobs { get; set; } = new List<PrintJob>();

    public virtual ICollection<PrinterCapability> PrinterCapabilities { get; set; } = new List<PrinterCapability>();
    
    /// <summary>
    /// Navigation to an Ink currently installed in this printer
    /// </summary>
    public virtual Ink? Ink { get; set; }
}
