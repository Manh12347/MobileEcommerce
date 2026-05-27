namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho cấu hình khả năng in (capability)
/// </summary>
public class PrinterCapabilityDto
{
    public int? PrinterCapabilityId { get; set; }
    public int PaperSizeId { get; set; }
    public bool IsColorSupported { get; set; }
    public bool IsBwSupported { get; set; }
}

 
/// <summary>
/// DTO cho response cấu hình khả năng in (capability)
/// </summary>
public class PrinterCapabilityResponseDto
{
    public int PrinterCapabilityId { get; set; }
    public int PaperSizeId { get; set; }
    public string? PaperSizeCode { get; set; }
    public string? PaperSizeDescription { get; set; }
    public bool IsColorSupported { get; set; }
    public bool IsBwSupported { get; set; }
}

/// <summary>
/// DTO cho tạo/cập nhật máy in
/// </summary>
public class PrinterUpsertDto
{
    public string PrinterCode { get; set; } = string.Empty;
    public string? Location { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string? Status { get; set; }
    public int? PaperCapacity { get; set; }
    public List<PrinterCapabilityDto>? Capabilities { get; set; }
    // Optional: assign an ink to the printer directly
    public int? InkId { get; set; }
}

/// <summary>
/// DTO cho response máy in
/// </summary>
public class PrinterResponseDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string? Location { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string? Status { get; set; }
    public int? PaperCapacity { get; set; }
    public int? AdditionalPaper { get; set; }
    // Optional ink currently installed in the printer
    public int? InkId { get; set; }
    public string? InkCode { get; set; }
    public DateTime? CreatedOn { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime? ModifiedOn { get; set; }
    public string? ModifiedBy { get; set; }
    public List<PrinterCapabilityResponseDto>? Capabilities { get; set; }
}

/// <summary>
/// DTO cho danh sách máy in để chọn khi in
/// </summary>
public class PrinterSelectDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string? Location { get; set; }
    public string? Status { get; set; }
}

/// <summary>
/// DTO cho số trang còn lại của cuộn mực
/// </summary>
public class InkRemainingPagesDto
{
    public int InkId { get; set; }
    public string InkCode { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public int RemainingPages { get; set; }
}

/// <summary>
/// DTO cho số trang còn lại của giấy và mực trong máy in
/// </summary>
public class PrinterRemainingPagesDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string? Location { get; set; }
    public int RemainingPaperPages { get; set; }
    public List<InkRemainingPagesDto> Inks { get; set; } = new List<InkRemainingPagesDto>();
}

/// <summary>
/// DTO cho cập nhật sau khi in
/// </summary>
public class UpdateAfterPrintDto
{
    public int PrintJobId { get; set; }
    public int PrinterId { get; set; }
    public int TotalPages { get; set; }
    public bool IsColor { get; set; }
}

/// <summary>
/// DTO for assigning/unassigning Ink to a Printer
/// </summary>
public class AssignInkDto
{
    public int PrinterId { get; set; }
    // null => unassign
    public int? InkId { get; set; }
}

