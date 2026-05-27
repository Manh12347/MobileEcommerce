namespace PTVBTPM.Models.DTOs;

public class UploadDocumentResponseDto
{
    public int DocumentId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string? FileType { get; set; } // pdf, docx, pptx, xlsx
    public long? FileSize { get; set; } // bytes
    public double? FileSizeMB { get; set; } // MB (tính từ FileSize)
    public int? PageCount { get; set; } // TotalPages
    public string? FileUrl { get; set; }
    public DateTime? CreatedOn { get; set; } // UploadedAt
    public string? TempFileName { get; set; } // Tên file tạm (chưa lưu DB)
}

public class CleanupTempFileRequest
{
    public string TempFileName { get; set; } = string.Empty;
}

