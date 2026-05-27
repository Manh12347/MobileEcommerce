namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho tạo/cập nhật cuộn mực
/// </summary>
public class InkUpsertDto
{
    public string InkCode { get; set; } = string.Empty;
    public string InkType { get; set; } = string.Empty; // Toner, Inkjet
    public string Color { get; set; } = string.Empty; // Black, Cyan, Magenta, Yellow
    public int CapacityPages { get; set; } // Số trang in tối đa
    public int CurrentPages { get; set; } // Số trang còn lại
    public string Status { get; set; } = string.Empty; // Available, Offline
    public string? Brand { get; set; } // Hãng cuộn mực
}

/// <summary>
/// DTO cho response cuộn mực
/// </summary>
public class InkResponseDto
{
    public int InkId { get; set; }
    public string InkCode { get; set; } = string.Empty;
    public string InkType { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public int CapacityPages { get; set; }
    public int CurrentPages { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Brand { get; set; }
    public string? AssignedPrinterName { get; set; }
    public DateTime? CreatedOn { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime? ModifiedOn { get; set; }
    public string? ModifiedBy { get; set; }
}

/// <summary>
/// DTO cho danh sách cuộn mực (đơn giản)
/// </summary>
public class InkListDto
{
    public int InkId { get; set; }
    public string InkCode { get; set; } = string.Empty;
    public string InkType { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public int CapacityPages { get; set; }
    public int CurrentPages { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Brand { get; set; }
    public string? AssignedPrinterName { get; set; }
}

