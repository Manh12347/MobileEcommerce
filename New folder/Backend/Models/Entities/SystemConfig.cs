using System;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Bảng cấu hình hệ thống - chỉ có 1 record duy nhất (singleton)
/// </summary>
public partial class SystemConfig
{
    public int ConfigId { get; set; }

    /// <summary>
    /// Tên hệ thống
    /// </summary>
    public string SystemName { get; set; } = null!;

    /// <summary>
    /// Chế độ bảo trì (true/false)
    /// </summary>
    public bool MaintenanceMode { get; set; }

    /// <summary>
    /// Kích thước file tối đa (bytes)
    /// </summary>
    public long MaxFileSize { get; set; }

    /// <summary>
    /// Định dạng file cho phép, ngăn cách bằng dấu phẩy (.pdf,.docx,.pptx)
    /// </summary>
    public string AllowedFileFormats { get; set; } = null!;

    /// <summary>
    /// Số trang mặc định cấp cho sinh viên
    /// </summary>
    public int DefaultPagesForStudent { get; set; }

    /// <summary>
    /// Giá giấy mặc định (VNĐ/trang)
    /// </summary>
    public decimal PaperPrice { get; set; }

    /// <summary>
    /// Hệ số phân trang
    /// </summary>
    // Now stored as integer per requirement
    public int PageFactor { get; set; }

    /// <summary>
    /// Tự động cấp giấy cho sinh viên (true/false)
    /// </summary>
    public bool AutoAssignPages { get; set; }

    /// <summary>
    /// Các mốc ngày cấp giấy, định dạng: "ngày/tháng;ngày/tháng" (ví dụ: "7/10;20/12;1/1")
    /// </summary>
    public string AutoAssignDays { get; set; } = null!;

    /// <summary>
    /// Ngày trong tháng để tự động tạo báo cáo tổng quát (1-31)
    /// </summary>
    public int AutoAssignDayOfMonth { get; set; }

    /// <summary>
    /// Thời gian hết phiên (phút)
    /// </summary>
    public int SessionTimeoutMinutes { get; set; }

    /// <summary>
    /// Số lần nhập sai tối đa
    /// </summary>
    public int MaxLoginAttempts { get; set; }

    /// <summary>
    /// Yêu cầu độ dài tối thiểu mật khẩu
    /// </summary>
    public int MinPasswordLength { get; set; }

    /// <summary>
    /// Yêu cầu định dạng mật khẩu (true/false)
    /// </summary>
    public bool RequirePasswordFormat { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }
    
    /// <summary>
    /// Giới hạn lưu trữ cho hệ thống (MB)
    /// </summary>
    public long StorageLimitMb { get; set; }

    /// <summary>
    /// Giá mỗi MB dung lượng lưu trữ (VNĐ/MB)
    /// </summary>
    public decimal StoragePricePerMb { get; set; }

    /// <summary>
    /// Số giấy mặc định để thêm vào máy in khi nạp (sheets)
    /// </summary>
    public int DefaultAdditionalPaper { get; set; }

    /// <summary>
    /// URL ảnh background của hệ thống
    /// </summary>
    public string? PictureUrl { get; set; }

    /// <summary>
    /// Số trang giấy mặc định cấp cho tài khoản mới khi tạo (VNĐ)
    /// </summary>
    public int PageDefaultCreate { get; set; }
}

