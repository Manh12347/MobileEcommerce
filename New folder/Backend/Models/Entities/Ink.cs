using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Danh sách cuộn mực trong hệ thống
/// </summary>
public partial class Ink
{
    public int InkId { get; set; }

    public string InkCode { get; set; } = null!;

    public string InkType { get; set; } = null!; // Toner, Inkjet

    public string Color { get; set; } = null!; // Black, Cyan, Magenta, Yellow

    public int CapacityPages { get; set; } // Số trang in tối đa theo hãng

    public int CurrentPages { get; set; } // Số trang còn lại

    public string Status { get; set; } = null!; // Available, Offline

    public string? Brand { get; set; } // Hãng cuộn mực
    
    // Note: inks table no longer stores current printer reference (id or name).

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }
}

