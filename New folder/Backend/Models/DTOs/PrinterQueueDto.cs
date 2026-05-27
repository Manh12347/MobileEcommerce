namespace PTVBTPM.Models.DTOs;

/// <summary>
/// Thông tin một print job trong queue
/// </summary>
public class PrintQueueItemDto
{
    public int PrintJobId { get; set; }
    public int? UserId { get; set; }
    public string? UserName { get; set; }
    public string? StudentCode { get; set; }
    public string? DocumentName { get; set; }
    public int TotalPages { get; set; }
    public int Copies { get; set; }
    public bool IsColor { get; set; }
    public string? PaperSizeCode { get; set; } // A4, A3, etc.
    public string Status { get; set; } = string.Empty;
    public DateTime? CreatedOn { get; set; }
    public int QueuePosition { get; set; } // Vị trí trong hàng (1, 2, 3...)
    public double EstimatedWaitTimeSeconds { get; set; } // Thời gian chờ ước tính (giây)
    public double EstimatedPrintTimeSeconds { get; set; } // Thời gian in ước tính cho job này (giây)
    public DateTime? EstimatedStartTime { get; set; } // Thời gian dự kiến bắt đầu in
    public DateTime? EstimatedCompleteTime { get; set; } // Thời gian dự kiến hoàn thành
}

/// <summary>
/// Response cho API lấy queue của máy in
/// </summary>
public class PrinterQueueResponseDto
{
    public int PrinterId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string? Location { get; set; }
    public int TotalJobsInQueue { get; set; } // Tổng số job (PENDING + PRINTING)
    public List<PrintQueueItemDto> QueueItems { get; set; } = new List<PrintQueueItemDto>();
}

/// <summary>
/// Response cho API thực thi in
/// </summary>
public class ExecutePrintResponseDto
{
    public int PrintJobId { get; set; }
    public int? UserId { get; set; }
    public string? UserName { get; set; }
    public string? StudentCode { get; set; }
    public string? DocumentName { get; set; }
    public int TotalPages { get; set; }
    public int Copies { get; set; }
    public bool IsColor { get; set; }
    public string? PaperSizeCode { get; set; }
    public string Status { get; set; } = string.Empty;
    public double EstimatedPrintTimeSeconds { get; set; } // Thời gian in ước tính (giây)
    public DateTime? EstimatedCompleteTime { get; set; } // Thời gian dự kiến hoàn thành
    public int RemainingPaperAfterPrint { get; set; } // Số giấy còn lại sau khi in
    public List<InkAfterPrintDto> InksAfterPrint { get; set; } = new List<InkAfterPrintDto>(); // Trạng thái mực sau khi in
}

/// <summary>
/// Thông tin mực sau khi in
/// </summary>
public class InkAfterPrintDto
{
    public int InkId { get; set; }
    public string InkCode { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public int RemainingPages { get; set; }
    public string Status { get; set; } = string.Empty;
}

