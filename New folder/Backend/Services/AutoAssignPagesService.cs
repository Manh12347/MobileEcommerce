using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Caching.Memory;
using PTVBTPM.Models.Entities;
using PTVBTPM.Helper;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace PTVBTPM.Services
{
    /// <summary>
    /// Background service để tự động cấp trang cho sinh viên theo lịch định kỳ
    /// Chạy mỗi ngày để kiểm tra xem có cần cấp trang không (theo ngày cấp trong config)
    /// </summary>
    public class AutoAssignPagesService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<AutoAssignPagesService> _logger;
        private const int CheckIntervalHours = 1; // Kiểm tra mỗi 1 giờ

        public AutoAssignPagesService(
            IServiceProvider serviceProvider,
            ILogger<AutoAssignPagesService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("AutoAssignPagesService started");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await CheckAndAssignPagesAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in AutoAssignPagesService");
                }

                // Đợi 1 giờ trước khi kiểm tra lại
                await Task.Delay(TimeSpan.FromHours(CheckIntervalHours), stoppingToken);
            }

            _logger.LogInformation("AutoAssignPagesService stopped");
        }

        /// <summary>
        /// Kiểm tra và cấp trang cho sinh viên nếu đến ngày cấp
        /// </summary>
        private async Task CheckAndAssignPagesAsync()
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<WebDbContext>();
            var cache = scope.ServiceProvider.GetRequiredService<IMemoryCache>();

            try
            {
                // Lấy system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(context, cache);
                if (systemConfig == null)
                {
                    _logger.LogWarning("[AutoAssignPages] System config not found");
                    return;
                }

                // Kiểm tra xem có bật tự động cấp trang không
                if (!systemConfig.AutoAssignPages)
                {
                    _logger.LogDebug("[AutoAssignPages] Auto assign pages is disabled");
                    return;
                }

                var today = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                var todayDay = today.Day;
                var todayMonth = today.Month;
                var todayYear = today.Year;

                // Kiểm tra xem hôm nay có phải ngày cấp không (theo chuỗi AutoAssignDays)
                var assignDays = systemConfig.AutoAssignDays?.Split(';', StringSplitOptions.RemoveEmptyEntries) ?? Array.Empty<string>();
                bool isAssignDay = false;

                foreach (var dayStr in assignDays)
                {
                    try
                    {
                        var parts = dayStr.Trim().Split('/');
                        if (parts.Length == 2 &&
                            int.TryParse(parts[0], out int assignDay) &&
                            int.TryParse(parts[1], out int assignMonth))
                        {
                            if (assignDay == todayDay && assignMonth == todayMonth)
                            {
                                isAssignDay = true;
                                break;
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"[AutoAssignPages] Invalid date format in AutoAssignDays: {dayStr}");
                    }
                }

                if (!isAssignDay)
                {
                    _logger.LogDebug($"[AutoAssignPages] Today ({todayDay}/{todayMonth}) is not an assign day. Available days: {systemConfig.AutoAssignDays}");
                    return;
                }

                _logger.LogInformation($"[AutoAssignPages] Today ({todayDay}/{todayMonth}) is assign day. Starting auto assign pages...");

                // Lấy tất cả sinh viên (STUDENT role) đang ACTIVE
                var students = await context.Users
                    .Where(u => u.Role == "STUDENT" && u.Status == "ACTIVE")
                    .ToListAsync();

                int assignedCount = 0;
                foreach (var student in students)
                {
                    try
                    {
                        // Kiểm tra xem đã cấp trang trong tháng này chưa
                        // Sử dụng ModifiedOn của PageDefaultBalance để track
                        // Nếu ModifiedOn trong tháng này thì đã cấp rồi
                        var lastAssignedMonth = student.ModifiedOn?.Month;
                        var lastAssignedYear = student.ModifiedOn?.Year;

                        if (lastAssignedMonth == todayMonth && lastAssignedYear == todayYear)
                        {
                            _logger.LogDebug($"[AutoAssignPages] User {student.UserId} ({student.Email}) already assigned pages this month");
                            continue;
                        }

                        // Cấp trang mặc định
                        student.PageDefaultBalance += systemConfig.DefaultPagesForStudent;
                        student.ModifiedOn = today;
                        student.ModifiedBy = "SYSTEM_AUTO_ASSIGN";

                        assignedCount++;
                        _logger.LogInformation($"[AutoAssignPages] Assigned {systemConfig.DefaultPagesForStudent} pages to user {student.UserId} ({student.Email})");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"[AutoAssignPages] Error assigning pages to user {student.UserId}");
                    }
                }

                if (assignedCount > 0)
                {
                    await context.SaveChangesAsync();
                    _logger.LogInformation($"[AutoAssignPages] Successfully assigned pages to {assignedCount} students");
                }
                else
                {
                    _logger.LogInformation("[AutoAssignPages] No students needed page assignment");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[AutoAssignPages] Error in CheckAndAssignPagesAsync");
            }
        }
    }
}

