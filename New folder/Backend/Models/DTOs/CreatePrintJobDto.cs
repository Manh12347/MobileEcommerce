namespace PTVBTPM.Models.DTOs;

public class CreatePrintJobRequestDto
{
    public int DocumentId { get; set; } // 0 nếu dùng TempFileName
    public string? TempFileName { get; set; } // Tên file tạm từ upload (nếu DocumentId = 0)
    public int PrinterId { get; set; }
    public int PaperSizeId { get; set; }
    public int Copies { get; set; } = 1;
    public bool IsColor { get; set; } = false;
    public bool IsDoubleSided { get; set; } = false; // One-sided (false) hoặc Double-sided (true)
    public string? PagesToPrint { get; set; } // Ví dụ: "1-5,10,15-20" hoặc "all"
}

public class CreatePrintJobResponseDto
{
    public int PrintJobId { get; set; }
    public int DocumentId { get; set; }
    public int PrinterId { get; set; }
    public string? Status { get; set; }
    public int? TotalPages { get; set; } // Số trang A4 tương đương (đã tính quy đổi)
    public int Copies { get; set; }
    public bool IsColor { get; set; }
    public bool IsDoubleSided { get; set; }
    public string? PagesToPrint { get; set; } // Trang in gốc (không có |DOUBLE_SIDED)
    public DateTime? CreatedOn { get; set; }
}

