namespace PTVBTPM.Models.DTOs
{
    public class BankTransactionDto
    {
        public string Gateway { get; set; } = string.Empty;
        public string Transactiondate { get; set; } = string.Empty;
        public string Accountnumber { get; set; } = string.Empty;
        public string? Subaccount { get; set; }
        public string? Code { get; set; }
        public string Content { get; set; } = string.Empty;
        public string Transfertype { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal Transferamount { get; set; }
        public string Referencecode { get; set; } = string.Empty;
        public decimal Accumulated { get; set; }
    }
}

