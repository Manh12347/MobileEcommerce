using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Danh mục khổ giấy in (A0–A4)
/// </summary>
public partial class PaperSize
{
    public int PaperSizeId { get; set; }

    public string Code { get; set; } = null!;

    public string? Description { get; set; }

    /// <summary>
    /// Giá in (VNĐ/trang) - chỉ hỗ trợ in đen trắng
    /// </summary>
    public decimal? Price { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }

    public virtual ICollection<PrintJob> PrintJobs { get; set; } = new List<PrintJob>();

    public virtual ICollection<PrinterCapability> PrinterCapabilities { get; set; } = new List<PrinterCapability>();
}
