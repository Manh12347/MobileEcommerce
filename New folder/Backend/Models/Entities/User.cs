using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Bảng người dùng hệ thống in ấn (Student &amp; SPSO)
/// </summary>
public partial class User
{
    public int UserId { get; set; }

    public string StudentCode { get; set; } = null!;

    public string FullName { get; set; } = null!;

    public string Email { get; set; } = null!;

    /// <summary>
    /// Trạng thái xác nhận email đã được xác thực chưa
    /// </summary>
    public bool EmailConfirmed { get; set; }

    public string PasswordHash { get; set; } = null!;

    public string Role { get; set; } = null!;

    /// <summary>
    /// Số trang in mặc định được hệ thống cấp (ví dụ theo học kỳ)
    /// </summary>
    public int PageDefaultBalance { get; set; }

    /// <summary>
    /// Số trang in do người dùng mua thêm
    /// </summary>
    public int PagePurchasedBalance { get; set; }

    /// <summary>
    /// Dung lượng lưu trữ do người dùng mua thêm (MB)
    /// </summary>
    [Column("storage_purchased_mb")]
    public long StoragePurchasedBalance { get; set; }

    public string? Status { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }

    /// <summary>
    /// Trạng thái bật/tắt 2FA
    /// </summary>
    public bool TwoFactorEnabled { get; set; }

    /// <summary>
    /// Phương thức 2FA: authenticator, email, both
    /// </summary>
    public string? TwoFactorMethod { get; set; }

    /// <summary>
    /// Secret key đã mã hóa cho TOTP
    /// </summary>
    public string? TwoFactorSecret { get; set; }

    /// <summary>
    /// Chuỗi JSON chứa mã khôi phục 2FA
    /// </summary>
    public string? TwoFactorRecoveryCodes { get; set; }

    /// <summary>
    /// URL ảnh đại diện (avatar)
    /// </summary>
    public string? AvatarUrl { get; set; }

    /// <summary>
    /// Ngày sinh
    /// </summary>
    public DateTime? DateOfBirth { get; set; }

    /// <summary>
    /// Địa chỉ
    /// </summary>
    public string? Address { get; set; }

    /// <summary>
    /// Số điện thoại
    /// </summary>
    public string? PhoneNumber { get; set; }

    public virtual ICollection<Document> Documents { get; set; } = new List<Document>();

    public virtual ICollection<LoginHistory> LoginHistories { get; set; } = new List<LoginHistory>();

    public virtual ICollection<PrintJob> PrintJobs { get; set; } = new List<PrintJob>();

    public virtual ICollection<PurchaseTransaction> PurchaseTransactions { get; set; } = new List<PurchaseTransaction>();
}
