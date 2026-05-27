namespace PTVBTPM.Models.DTOs;

public class SystemConfigDto
{
    public int ConfigId { get; set; }
    public string SystemName { get; set; } = string.Empty;
    public bool MaintenanceMode { get; set; }
    public long MaxFileSize { get; set; }
    public string AllowedFileFormats { get; set; } = string.Empty;
    public int DefaultPagesForStudent { get; set; }
    public decimal PaperPrice { get; set; }
    // PageFactor as integer per new requirement
    public int PageFactor { get; set; }
    public bool AutoAssignPages { get; set; }
    // Các mốc ngày cấp giấy, định dạng: "ngày/tháng;ngày/tháng" (ví dụ: "7/10;20/12;1/1")
    public string AutoAssignDays { get; set; } = "1";
    public int AutoAssignDayOfMonth { get; set; }
    public int SessionTimeoutMinutes { get; set; }
    public int MaxLoginAttempts { get; set; }
    public int MinPasswordLength { get; set; }
    public bool RequirePasswordFormat { get; set; }
    public long StorageLimitMb { get; set; }
    public decimal StoragePricePerMb { get; set; }
    public int DefaultAdditionalPaper { get; set; }
    public string? PictureUrl { get; set; }
    public int PageDefaultCreate { get; set; }
}

public class UpdateSystemConfigDto
{
    public string? SystemName { get; set; }
    public bool? MaintenanceMode { get; set; }
    public long? MaxFileSize { get; set; }
    public string? AllowedFileFormats { get; set; }
    public int? DefaultPagesForStudent { get; set; }
    public decimal? PaperPrice { get; set; }
    public int? PageFactor { get; set; }
    public bool? AutoAssignPages { get; set; }
    public string? AutoAssignDays { get; set; }
    public int? AutoAssignDayOfMonth { get; set; }
    public int? SessionTimeoutMinutes { get; set; }
    public int? MaxLoginAttempts { get; set; }
    public int? MinPasswordLength { get; set; }
    public bool? RequirePasswordFormat { get; set; }
    public long? StorageLimitMb { get; set; }
    public decimal? StoragePricePerMb { get; set; }
    public int? DefaultAdditionalPaper { get; set; }
    public string? PictureUrl { get; set; }
    public int? PageDefaultCreate { get; set; }
}

