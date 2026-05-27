namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho số đơn in theo ngày
/// </summary>
public class PrintOrdersByDayDto
{
    public string DayLabel { get; set; } = string.Empty; // T2, T3, T4, T5, T6, T7, CN
    public string Date { get; set; } = string.Empty; // yyyy-MM-dd
    public int OrderCount { get; set; }
}

/// <summary>
/// DTO cho top người dùng in nhiều nhất
/// </summary>
public class TopUserDto
{
    public int UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string StudentCode { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public int TotalPages { get; set; }
    public int OrderCount { get; set; }
}

/// <summary>
/// DTO cho top máy in sử dụng nhiều nhất
/// </summary>
public class TopPrinterDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string PrinterName { get; set; } = string.Empty; // Code - Location
    public string? Location { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public int OrderCount { get; set; }
}

/// <summary>
/// DTO cho top người dùng mua giấy/dung lượng nhiều nhất
/// </summary>
public class TopPurchaserDto
{
    public int UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string StudentCode { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public int TotalQuantity { get; set; } // Số trang hoặc dung lượng (MB)
    public decimal TotalAmount { get; set; } // Tổng tiền đã chi
}

/// <summary>
/// DTO cho doanh thu theo thời gian
/// </summary>
public class RevenueByPeriodDto
{
    public string PeriodLabel { get; set; } = string.Empty; // T2, T3, Q1/2024, 2024, hoặc dd/MM/yyyy
    public string Date { get; set; } = string.Empty; // yyyy-MM-dd
    public decimal TotalRevenue { get; set; }
}

/// <summary>
/// DTO cho response doanh thu theo thời gian
/// </summary>
public class RevenueByPeriodResponseDto
{
    public List<RevenueByPeriodDto> ReportsByPeriod { get; set; } = new List<RevenueByPeriodDto>();
    public decimal HighestRevenue { get; set; }
    public decimal HighestPaperRevenue { get; set; }
    public decimal HighestStorageRevenue { get; set; }
    public string Period { get; set; } = string.Empty; // week, month, quarter, year, custom
    public decimal TotalRevenue { get; set; }
    public decimal TotalPaperRevenue { get; set; }
    public decimal TotalStorageRevenue { get; set; }
}

/// <summary>
/// DTO cho lịch sử giao dịch
/// </summary>
public class TransactionHistoryDto
{
    public int Id { get; set; }
    public string? OrderCode { get; set; }
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public string TransactionType { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal PricePerUnit { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

/// <summary>
/// DTO cho máy in (đơn giản hóa cho báo cáo)
/// </summary>
public class PrinterDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string? Location { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string? Status { get; set; }
}

/// <summary>
/// DTO cho tài liệu đã in
/// </summary>
public class PrintedDocumentDto
{
    public int DocumentId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public int PrintCount { get; set; } // Số lần in tài liệu này
    public int TotalPages { get; set; } // Tổng số trang đã in của tài liệu này
    public DateTime? LastPrinted { get; set; }
}

/// <summary>
/// DTO cho báo cáo máy in
/// </summary>
public class PrinterReportDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public int TotalJobs { get; set; } // Tổng số job đã hoàn thành
    public int TotalPages { get; set; } // Tổng số trang đã in
    public List<PrintedDocumentDto> PrintedDocuments { get; set; } = new List<PrintedDocumentDto>();
}

/// <summary>
/// DTO cho request báo cáo máy in
/// </summary>
public class PrinterReportRequestDto
{
    public List<int> PrinterIds { get; set; } = new List<int>();
}

/// <summary>
/// DTO cho response báo cáo máy in
/// </summary>
public class PrinterReportResponseDto
{
    public List<PrinterDto> SelectedPrinters { get; set; } = new List<PrinterDto>();
    public List<PrinterReportDto> PrinterReports { get; set; } = new List<PrinterReportDto>();
    public int TotalPrinters { get; set; }
    public int TotalJobs { get; set; }
    public int TotalPages { get; set; }
}

/// <summary>
/// DTO cho response số đơn in theo ngày
/// </summary>
public class PrintOrdersByDayResponseDto
{
    public List<PrintOrdersByDayDto> OrdersByDay { get; set; } = new List<PrintOrdersByDayDto>();
    public int HighestOrderCount { get; set; }
    public string Period { get; set; } = string.Empty; // week, month, year
}

/// <summary>
/// DTO cho thống kê với phần trăm thay đổi
/// </summary>
public class StatWithChangeDto
{
    public int Value { get; set; }
    public double ChangePercent { get; set; }
    public bool IsIncrease { get; set; }
}

/// <summary>
/// DTO cho máy in hoạt động
/// </summary>
public class ActivePrintersStatDto
{
    public int Active { get; set; }
    public int Total { get; set; }
    public double Percentage { get; set; }
    public double ChangePercent { get; set; }
    public bool IsIncrease { get; set; }
}

/// <summary>
/// DTO cho summary stats của admin dashboard
/// </summary>
public class AdminSummaryStatsDto
{
    public StatWithChangeDto TotalUsers { get; set; } = new StatWithChangeDto();
    public ActivePrintersStatDto ActivePrinters { get; set; } = new ActivePrintersStatDto();
    public StatWithChangeDto PrintOrdersToday { get; set; } = new StatWithChangeDto();
    public StatWithChangeDto TotalPagesThisWeek { get; set; } = new StatWithChangeDto();
}

/// <summary>
/// DTO cho chi tiết giao dịch mua giấy/dung lượng/đơn in
/// </summary>
public class PurchaseTransactionDetailDto
{
    public int TransactionId { get; set; }
    public string UserFullName { get; set; } = string.Empty;
    public string UserStudentCode { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public string PurchaseType { get; set; } = string.Empty; // "PAGE_PURCHASE", "STORAGE_PURCHASE", hoặc "ORDER"
    public string ItemName { get; set; } = string.Empty; // "Giấy A4", "Dung lượng (MB)", hoặc "Đơn in"
    public int Quantity { get; set; } // Số trang giấy, số MB dung lượng, hoặc số items trong đơn in
    public decimal PricePerUnit { get; set; } // Giá mỗi đơn vị
    public decimal TotalAmount { get; set; } // Tổng tiền
    public DateTime PurchaseDate { get; set; }
}


