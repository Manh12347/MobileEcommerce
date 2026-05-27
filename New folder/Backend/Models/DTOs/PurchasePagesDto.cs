namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho request mua thêm giấy
/// </summary>
public class PurchasePagesRequestDto
{
    /// <summary>
    /// Số lượng trang muốn mua
    /// </summary>
    public int Pages { get; set; }
}

/// <summary>
/// DTO cho response mua thêm giấy
/// </summary>
public class PurchasePagesResponseDto
{
    public int OrderId { get; set; }
    public string Gencode { get; set; } = string.Empty;
    public int Pages { get; set; }
    public decimal Amount { get; set; }
    public string QrUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

/// <summary>
/// DTO cho giá mua thêm giấy
/// </summary>
public class PagePurchasePriceDto
{
    public decimal PricePerPage { get; set; }
    public string Currency { get; set; } = "VND";
    public string? Description { get; set; }
}

/// <summary>
/// DTO cho request mua thêm dung lượng lưu trữ
/// </summary>
public class PurchaseStorageRequestDto
{
    /// <summary>
    /// Dung lượng muốn mua (MB)
    /// </summary>
    public long StorageMb { get; set; }

    /// <summary>
    /// Giá mỗi MB (VNĐ)
    /// </summary>
    public decimal PricePerMb { get; set; }
}

/// <summary>
/// DTO cho response mua thêm dung lượng lưu trữ
/// </summary>
public class PurchaseStorageResponseDto
{
    public int OrderId { get; set; }
    public string Gencode { get; set; } = string.Empty;
    public long StorageMb { get; set; }
    public decimal Amount { get; set; }
    public string QrUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

/// <summary>
/// DTO cho giá mua thêm dung lượng lưu trữ
/// </summary>
public class StoragePurchasePriceDto
{
    public decimal PricePerMb { get; set; }
    public string Currency { get; set; } = "VND";
    public string? Description { get; set; }
}

