using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PTVBTPM.Models.Entities;
using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace PTVBTPM.Services;

public class ReportBackgroundService : BackgroundService
{
    private readonly ILogger<ReportBackgroundService> _logger;
    private readonly IServiceProvider _serviceProvider;
    private readonly TimeSpan _checkInterval = TimeSpan.FromHours(1); // Kiểm tra mỗi giờ

    public ReportBackgroundService(
        ILogger<ReportBackgroundService> logger,
        IServiceProvider serviceProvider)
    {
        _logger = logger;
        _serviceProvider = serviceProvider;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Report Background Service started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CheckAndGenerateReportAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in Report Background Service");
            }

            // Chờ đến lần kiểm tra tiếp theo
            await Task.Delay(_checkInterval, stoppingToken);
        }

        _logger.LogInformation("Report Background Service stopped");
    }

    private async Task CheckAndGenerateReportAsync()
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<WebDbContext>();
        var reportService = scope.ServiceProvider.GetRequiredService<ReportService>();

        try
        {
            // Lấy cấu hình hệ thống
            var systemConfig = await context.SystemConfigs.FirstOrDefaultAsync();
            if (systemConfig == null)
            {
                _logger.LogWarning("System config not found, skipping report generation");
                return;
            }

            // Kiểm tra xem hôm nay có phải là ngày tạo báo cáo không
            var today = DateTime.UtcNow.Day;
            var reportDay = systemConfig?.AutoAssignDayOfMonth ?? 1;
            if (today != reportDay)
            {
                _logger.LogDebug($"Not report day (config: {systemConfig.AutoAssignDays}, today: {today})");
                return;
            }

            // Kiểm tra xem đã tạo báo cáo hôm nay chưa
            var reportsFolder = Path.Combine(scope.ServiceProvider.GetRequiredService<IWebHostEnvironment>().WebRootPath, "Reports");
            if (!Directory.Exists(reportsFolder))
                Directory.CreateDirectory(reportsFolder);

            var todayFileName = $"BaoCaoTongQuat_{DateTime.UtcNow:yyyyMMdd}_*.xlsx";
            var existingReports = Directory.GetFiles(reportsFolder, todayFileName);

            if (existingReports.Any())
            {
                _logger.LogInformation($"Report already generated today: {Path.GetFileName(existingReports.First())}");
                return;
            }

            // Tạo báo cáo cho tháng hiện tại
            var startOfMonth = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1);
            var fileName = await reportService.GenerateGeneralReportAsync(startOfMonth, DateTime.UtcNow);

            _logger.LogInformation($"Auto-generated monthly report: {fileName}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating automatic report");
        }
    }
}
