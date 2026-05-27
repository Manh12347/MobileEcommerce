using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Bảng lưu giao dịch ngân hàng từ webhook
/// </summary>
public partial class BankTransaction
{
    public long Id { get; set; }

    public string Gateway { get; set; } = null!;

    public DateTime Transactiondate { get; set; }

    public string Accountnumber { get; set; } = null!;

    public string? Code { get; set; }

    public string? Content { get; set; }

    public string Transfertype { get; set; } = null!;

    public decimal Transferamount { get; set; }

    public decimal Accumulated { get; set; }

    public string? Subaccount { get; set; }

    public string? Referencecode { get; set; }

    public string? Description { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }
}
