using Microsoft.AspNetCore.Mvc;
using PTVBTPM.Models.Entities;

namespace PTVBTPM.Services
{
    public interface IHooksService
    {
        Task AddTransactionAsync(BankTransaction transaction);
        Task<TransactionProcessResult> ProcessTransactionAsync(BankTransaction transaction);
    }

    public class TransactionProcessResult
    {
        public string Message { get; set; } = string.Empty;
        public bool OrderUpdated { get; set; }
        public int? OrderId { get; set; }
    }
}

