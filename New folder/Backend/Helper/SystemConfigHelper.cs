using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using PTVBTPM.Models.Entities;

namespace PTVBTPM.Helper;

/// <summary>
/// Helper class để lấy và cache system configuration
/// </summary>
public static class SystemConfigHelper
{
    private static readonly TimeSpan CacheExpiration = TimeSpan.FromMinutes(5); // Cache 5 phút

    /// <summary>
    /// Lấy system config từ DB hoặc cache
    /// </summary>
    public static async Task<SystemConfig?> GetSystemConfigAsync(WebDbContext context, IMemoryCache? cache = null)
    {
        // Nếu có cache, thử lấy từ cache trước
        if (cache != null)
        {
            var cacheKey = "SystemConfig_Singleton";
            if (cache.TryGetValue(cacheKey, out SystemConfig? cachedConfig) && cachedConfig != null)
            {
                return cachedConfig;
            }
        }

        // Lấy từ DB
        var config = await context.SystemConfigs
            .FirstOrDefaultAsync(c => c.ConfigId == 1);

        // Nếu chưa có config trong DB, trả về null - hệ thống cần được cấu hình trước
        // Không tự động tạo config mặc định để đảm bảo 100% sử dụng từ DB
        if (config == null)
        {
            return null;
        }

        // Lưu vào cache nếu có
        if (cache != null)
        {
            var cacheKey = "SystemConfig_Singleton";
            var cacheOptions = new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = CacheExpiration,
                SlidingExpiration = TimeSpan.FromMinutes(2) // Reset timer nếu được access
            };
            cache.Set(cacheKey, config, cacheOptions);
        }

        return config;
    }

    /// <summary>
    /// Invalidate cache (gọi khi config được update)
    /// </summary>
    public static void InvalidateCache(IMemoryCache? cache)
    {
        if (cache != null)
        {
            cache.Remove("SystemConfig_Singleton");
        }
    }
}

