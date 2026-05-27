using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Bảng lưu lịch sử giao dịch mua giấy và dung lượng của user
/// </summary>
public partial class PurchaseTransaction
{
    public int Id { get; set; }

    public int UserId { get; set; }

    /// <summary>
    /// Loại giao dịch: PAGE_PURCHASE, STORAGE_PURCHASE, ORDER
    /// </summary>
    public string TransactionType { get; set; } = null!;

    /// <summary>
    /// Số lượng: số trang hoặc số MB
    /// </summary>
    public int Quantity { get; set; }

    /// <summary>
    /// Giá mỗi đơn vị (VND/trang hoặc VND/MB)
    /// </summary>
    public decimal PricePerUnit { get; set; }

    /// <summary>
    /// Tổng tiền thanh toán
    /// </summary>
    public decimal TotalAmount { get; set; }

    /// <summary>
    /// Mã giao dịch từ ngân hàng
    /// </summary>
    public string? TransactionCode { get; set; }

    /// <summary>
    /// Trạng thái: PENDING, SUCCESS, FAILED, CANCELLED
    /// </summary>
    public string Status { get; set; } = "PENDING";

    public DateTime CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual User User { get; set; } = null!;
}
