using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Cấu hình khả năng in của máy in (khổ giấy, màu/trắng đen)
/// </summary>
public partial class PrinterCapability
{
    public int PrinterCapabilityId { get; set; }

    public int? PrinterId { get; set; }

    public int? PaperSizeId { get; set; }

    public bool IsColorSupported { get; set; }

    public bool IsBwSupported { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public virtual PaperSize? PaperSize { get; set; }

    public virtual Printer? Printer { get; set; }
}
