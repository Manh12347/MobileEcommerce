namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho tạo/cập nhật loại giấy
/// </summary>
public class PaperSizeUpsertDto
{
    public string Code { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal? Price { get; set; }
}

/// <summary>
/// DTO cho response loại giấy
/// </summary>
public class PaperSizeResponseDto
{
    public int PaperSizeId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal? Price { get; set; }
    public DateTime? CreatedOn { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime? ModifiedOn { get; set; }
    public string? ModifiedBy { get; set; }
}

