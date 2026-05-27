using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Quản lý job in và lịch sử in
/// </summary>
public partial class PrintJob
{
    public int PrintJobId { get; set; }

    public int? UserId { get; set; }

    public int? DocumentId { get; set; }

    public int? PrinterId { get; set; }

    public int? PaperSizeId { get; set; }

    public int? Copies { get; set; }

    public bool IsColor { get; set; }

    public string? PagesToPrint { get; set; }

    public int? TotalPages { get; set; }

    public string? Status { get; set; }

    public DateTime? CompletedAt { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }

    public virtual Document? Document { get; set; }

    public virtual PaperSize? PaperSize { get; set; }

    public virtual Printer? Printer { get; set; }

    public virtual User? User { get; set; }
}
