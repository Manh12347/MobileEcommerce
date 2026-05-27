namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho thống kê tổng quan lịch sử in
/// </summary>
public class PrintHistorySummaryDto
{
    /// <summary>
    /// Tổng số đơn in
    /// </summary>
    public int TotalOrders { get; set; }

    /// <summary>
    /// Tổng số trang đã in
    /// </summary>
    public int TotalPagesPrinted { get; set; }

    /// <summary>
    /// Tổng chi phí (VNĐ)
    /// </summary>
    public decimal TotalCost { get; set; }
}

/// <summary>
/// DTO cho một item trong danh sách lịch sử in
/// </summary>
public class PrintHistoryItemDto
{
    /// <summary>
    /// Mã đơn in (PrintJobId)
    /// </summary>
    public string OrderCode { get; set; } = string.Empty;

    /// <summary>
    /// ID của print job
    /// </summary>
    public int PrintJobId { get; set; }

    /// <summary>
    /// Tên file
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Ngày in
    /// </summary>
    public DateTime? PrintDate { get; set; }

    /// <summary>
    /// Số trang
    /// </summary>
    public int NumberOfPages { get; set; }

    /// <summary>
    /// Số bản in
    /// </summary>
    public int Copies { get; set; }

    /// <summary>
    /// Tên máy in
    /// </summary>
    public string? PrinterName { get; set; }

    /// <summary>
    /// Vị trí máy in
    /// </summary>
    public string? PrinterLocation { get; set; }

    /// <summary>
    /// Trạng thái: DONE, PENDING, PRINTING, FAILED, CANCELLED
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Chi phí (VNĐ). Null nếu chưa hoàn thành hoặc thất bại
    /// </summary>
    public decimal? Cost { get; set; }
}

/// <summary>
/// DTO cho chi tiết đơn in (bao gồm đầy đủ thông tin để in lại)
/// </summary>
public class PrintHistoryDetailDto
{
    /// <summary>
    /// Mã đơn in
    /// </summary>
    public string OrderCode { get; set; } = string.Empty;

    /// <summary>
    /// ID của print job
    /// </summary>
    public int PrintJobId { get; set; }

    /// <summary>
    /// Trạng thái
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Tên file
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// ID của document (cần để in lại)
    /// </summary>
    public int? DocumentId { get; set; }

    /// <summary>
    /// Thời gian in
    /// </summary>
    public DateTime? PrintTime { get; set; }

    /// <summary>
    /// ID máy in (cần để in lại)
    /// </summary>
    public int? PrinterId { get; set; }

    /// <summary>
    /// Tên máy in
    /// </summary>
    public string? PrinterName { get; set; }

    /// <summary>
    /// Vị trí máy in
    /// </summary>
    public string? PrinterLocation { get; set; }

    /// <summary>
    /// Số trang
    /// </summary>
    public int NumberOfPages { get; set; }

    /// <summary>
    /// Số bản in
    /// </summary>
    public int Copies { get; set; }

    /// <summary>
    /// ID khổ giấy (cần để in lại)
    /// </summary>
    public int? PaperSizeId { get; set; }

    /// <summary>
    /// Kích thước giấy (A4, A3, ...)
    /// </summary>
    public string? PaperSize { get; set; }

    /// <summary>
    /// Chế độ in (Đen trắng / Màu)
    /// </summary>
    public string PrintMode { get; set; } = string.Empty;

    /// <summary>
    /// Có in màu không (cần để in lại)
    /// </summary>
    public bool IsColor { get; set; }

    /// <summary>
    /// In hai mặt (cần để in lại)
    /// </summary>
    public bool IsDoubleSided { get; set; }

    /// <summary>
    /// Trang cần in gốc (không có |DOUBLE_SIDED, cần để in lại)
    /// </summary>
    public string? PagesToPrint { get; set; }

    /// <summary>
    /// Chi phí (VNĐ)
    /// </summary>
    public decimal? Cost { get; set; }
}

/// <summary>
/// DTO cho response danh sách lịch sử in với pagination
/// </summary>
public class PrintHistoryListResponseDto
{
    /// <summary>
    /// Danh sách đơn in
    /// </summary>
    public List<PrintHistoryItemDto> Items { get; set; } = new();

    /// <summary>
    /// Tổng số đơn in
    /// </summary>
    public int TotalCount { get; set; }

    /// <summary>
    /// Số trang hiện tại
    /// </summary>
    public int Page { get; set; }

    /// <summary>
    /// Số item mỗi trang
    /// </summary>
    public int PageSize { get; set; }

    /// <summary>
    /// Tổng số trang
    /// </summary>
    public int TotalPages { get; set; }
}

/// <summary>
/// DTO cho request in lại
/// </summary>
public class ReprintRequestDto
{
    /// <summary>
    /// ID của print job cũ để lấy thông tin in lại
    /// </summary>
    public int PrintJobId { get; set; }

    /// <summary>
    /// ID máy in mới (nếu muốn đổi máy in, để null sẽ dùng máy in cũ)
    /// </summary>
    public int? PrinterId { get; set; }

    /// <summary>
    /// Số bản in mới (nếu muốn đổi, để null sẽ dùng số bản cũ)
    /// </summary>
    public int? Copies { get; set; }
}

/// <summary>
/// DTO cho một item trong danh sách đơn in của admin (có thêm thông tin user)
/// </summary>
public class AdminPrintHistoryItemDto
{
    /// <summary>
    /// Mã đơn in (PrintJobId)
    /// </summary>
    public string OrderCode { get; set; } = string.Empty;

    /// <summary>
    /// ID của print job
    /// </summary>
    public int PrintJobId { get; set; }

    /// <summary>
    /// ID người dùng
    /// </summary>
    public int UserId { get; set; }

    /// <summary>
    /// Tên người dùng
    /// </summary>
    public string UserName { get; set; } = string.Empty;

    /// <summary>
    /// Email người dùng
    /// </summary>
    public string UserEmail { get; set; } = string.Empty;

    /// <summary>
    /// Tên file
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Ngày in
    /// </summary>
    public DateTime? PrintDate { get; set; }

    /// <summary>
    /// Số trang
    /// </summary>
    public int NumberOfPages { get; set; }

    /// <summary>
    /// Số bản in
    /// </summary>
    public int Copies { get; set; }

    /// <summary>
    /// Tên máy in
    /// </summary>
    public string? PrinterName { get; set; }

    /// <summary>
    /// Vị trí máy in
    /// </summary>
    public string? PrinterLocation { get; set; }

    /// <summary>
    /// Trạng thái: DONE, PENDING, PRINTING, FAILED, CANCELLED
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Chi phí (VNĐ). Null nếu chưa hoàn thành hoặc thất bại
    /// </summary>
    public decimal? Cost { get; set; }
}