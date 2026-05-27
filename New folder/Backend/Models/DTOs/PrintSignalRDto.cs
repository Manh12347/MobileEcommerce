namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho SignalR notification về trạng thái máy in
/// </summary>
public class PrinterStatusUpdateDto
{
    /// <summary>
    /// ID máy in
    /// </summary>
    public int PrinterId { get; set; }

    /// <summary>
    /// Mã máy in
    /// </summary>
    public string PrinterCode { get; set; } = string.Empty;

    /// <summary>
    /// Trạng thái: AVAILABLE, BUSY, OFFLINE
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Trạng thái tiếng Việt: Khả dụng, Bận, Offline
    /// </summary>
    public string StatusVi { get; set; } = string.Empty;

    /// <summary>
    /// Số giấy còn lại
    /// </summary>
    public int? CurrentPaper { get; set; }

    /// <summary>
    /// Thời gian cập nhật
    /// </summary>
    public DateTime UpdatedAt { get; set; }
}

/// <summary>
/// DTO cho SignalR notification về tài liệu đang in
/// </summary>
public class PrintJobStatusUpdateDto
{
    /// <summary>
    /// ID print job
    /// </summary>
    public int PrintJobId { get; set; }

    /// <summary>
    /// Mã đơn in
    /// </summary>
    public string OrderCode { get; set; } = string.Empty;

    /// <summary>
    /// Trạng thái: PENDING, PRINTING, DONE, FAILED, CANCELLED
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Trạng thái tiếng Việt: Đang chờ, Đang in, Hoàn thành, Thất bại, Đã hủy
    /// </summary>
    public string StatusVi { get; set; } = string.Empty;

    /// <summary>
    /// Tên file đang in
    /// </summary>
    public string? FileName { get; set; }

    /// <summary>
    /// ID máy in
    /// </summary>
    public int? PrinterId { get; set; }

    /// <summary>
    /// Tên máy in
    /// </summary>
    public string? PrinterName { get; set; }

    /// <summary>
    /// Thời gian cập nhật
    /// </summary>
    public DateTime UpdatedAt { get; set; }
}

/// <summary>
/// DTO cho SignalR notification về tiến trình in tài liệu
/// </summary>
public class PrintJobProgressDto
{
    /// <summary>
    /// ID print job
    /// </summary>
    public int PrintJobId { get; set; }

    /// <summary>
    /// ID máy in (để map với printer trong frontend)
    /// </summary>
    public int? PrinterId { get; set; }

    /// <summary>
    /// Mã đơn in
    /// </summary>
    public string OrderCode { get; set; } = string.Empty;

    /// <summary>
    /// Trạng thái hiện tại: PENDING, PRINTING, DONE, FAILED
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Trạng thái tiếng Việt: Đang chờ, Đang in, Hoàn thành, Thất bại
    /// </summary>
    public string StatusVi { get; set; } = string.Empty;

    /// <summary>
    /// Tổng số trang cần in
    /// </summary>
    public int TotalPages { get; set; }

    /// <summary>
    /// Số bản in
    /// </summary>
    public int Copies { get; set; }

    /// <summary>
    /// Tổng số trang đã in (tính cả số bản)
    /// </summary>
    public int TotalPagesPrinted { get; set; }

    /// <summary>
    /// Số trang đã in (0-100)
    /// </summary>
    public int ProgressPercentage { get; set; }

    /// <summary>
    /// Thời gian bắt đầu in
    /// </summary>
    public DateTime? StartTime { get; set; }

    /// <summary>
    /// Thời gian dự kiến hoàn thành
    /// </summary>
    public DateTime? EstimatedEndTime { get; set; }

    /// <summary>
    /// Thời gian hoàn thành (nếu đã xong)
    /// </summary>
    public DateTime? CompletedAt { get; set; }

    /// <summary>
    /// Thời gian cập nhật
    /// </summary>
    public DateTime UpdatedAt { get; set; }
}

