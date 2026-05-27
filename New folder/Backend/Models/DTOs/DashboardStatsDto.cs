namespace PTVBTPM.Models.DTOs;

public class DashboardStatsDto
{
    public int TotalFiles { get; set; }
    public int CompletedJobs { get; set; }
    public int PendingJobs { get; set; }
    public int ErrorJobs { get; set; }
    public int TotalPagesPrinted { get; set; }
    public decimal? PageBalance { get; set; }
    public int PageDefaultBalance { get; set; } // Tổng số trang được cấp
    public int PagePurchasedBalance { get; set; } // Tổng số trang mua thêm
    public decimal TotalCost { get; set; } // Tổng chi phí đã chi
    public int TotalOrders { get; set; } // Tổng số đơn in
    public decimal TotalMoneySpentOnPages { get; set; } // Tổng tiền đã mua giấy
    public decimal TotalMoneySpent { get; set; } // Tổng tiền đã chi (tổng tất cả)
    public decimal TotalMoneySpentOnStorage { get; set; } // Tổng tiền đã mua dung lượng
}

