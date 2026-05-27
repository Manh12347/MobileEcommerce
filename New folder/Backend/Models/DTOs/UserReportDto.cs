namespace PTVBTPM.Models.DTOs;

/// <summary>
/// DTO cho báo cáo chi tiết sử dụng của người dùng theo từng khoảng thời gian
/// </summary>
public class UserReportByPeriodDto
{
    public string PeriodLabel { get; set; } = string.Empty; // T2, T3, Q1/2024, 2024, hoặc dd/MM/yyyy
    public string Date { get; set; } = string.Empty; // yyyy-MM-dd
    public int PagesUsed { get; set; } // Số giấy đã sử dụng
    public decimal MoneySpent { get; set; } // Tiền đã mua giấy (tiền đã chi để in)
    public int DocumentsPrinted { get; set; } // Số tài liệu đã in
    // Additional metrics
    public decimal MoneySpentOnPages { get; set; }
    public decimal MoneySpentOnStorage { get; set; }
    public int PagesPurchased { get; set; }
    public long StoragePurchased { get; set; }
}

/// <summary>
/// DTO cho response báo cáo user
/// </summary>
public class UserReportResponseDto
{
    public List<UserReportByPeriodDto> ReportsByPeriod { get; set; } = new List<UserReportByPeriodDto>();
    public int HighestPagesUsed { get; set; }
    public decimal HighestMoneySpent { get; set; }
    public int HighestDocumentsPrinted { get; set; }
    public string Period { get; set; } = string.Empty; // week, month, quarter, year, custom
    // Aggregated metrics across periods
    public decimal HighestMoneySpentOnPages { get; set; }
    public decimal HighestMoneySpentOnStorage { get; set; }
    public decimal TotalMoneySpentOnPages { get; set; }
    public decimal TotalMoneySpentOnStorage { get; set; }
    public int TotalPagesPurchased { get; set; }
    public long TotalStoragePurchased { get; set; }
}

