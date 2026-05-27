using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.Entities;

/// <summary>
/// Bảng lưu tài liệu in
/// </summary>
public partial class Document
{
    public int DocumentId { get; set; }

    public int? UserId { get; set; }

    public string FileName { get; set; } = null!;

    public string? FileType { get; set; }

    public long? FileSize { get; set; }

    public int? PageCount { get; set; }

    public string? UploadPath { get; set; }

    public string? Status { get; set; }

    public DateTime? CreatedOn { get; set; }

    public string? CreatedBy { get; set; }

    public DateTime? ModifiedOn { get; set; }

    public string? ModifiedBy { get; set; }

    public virtual ICollection<PrintJob> PrintJobs { get; set; } = new List<PrintJob>();

    public virtual User? User { get; set; }
}
