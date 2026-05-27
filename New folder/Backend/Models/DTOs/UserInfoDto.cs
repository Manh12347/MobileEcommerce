namespace PTVBTPM.Models.DTOs;

public sealed class UserInfoDto
{
    public int UserId { get; set; }
    public string StudentCode { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public bool EmailConfirmed { get; set; }
    public string Role { get; set; } = string.Empty;
    public string? Status { get; set; }
    public string? AvatarUrl { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? Address { get; set; }
    public string? PhoneNumber { get; set; }
    public long StoragePurchasedBalance { get; set; }
    // Storage mặc định sẽ được lấy từ system config
    public long StorageDefaultBalance { get; set; }
    public long TotalStorageBalance => StorageDefaultBalance + StoragePurchasedBalance;

    // Storage usage tracking
    public double UsedStorageMb { get; set; }
    public long TotalStorageLimitMb { get; set; }
}
