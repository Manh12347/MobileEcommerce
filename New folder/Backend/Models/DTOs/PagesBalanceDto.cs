namespace PTVBTPM.Models.DTOs;

public sealed class PagesBalanceDto
{
    public int UserId { get; set; }
    public int DefaultBalance { get; set; }
    public int PurchaseBalance { get; set; }
    public int Total { get; set; }
}


