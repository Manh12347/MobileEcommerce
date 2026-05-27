using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.SignalR;
using PTVBTPM.Models.Entities;
using PTVBTPM.Hubs;
using PTVBTPM.Models.DTOs;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace PTVBTPM.Services
{
    /// <summary>
    /// Background service để tự động xử lý print jobs:
    /// - Sau thời gian in (0.5s x số trang) → chuyển PRINTING → DONE và trừ giấy/mực
    /// - Sau 1 phút làm lạnh → máy in quay lại AVAILABLE
    /// </summary>
    public class PrintJobProcessingService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<PrintJobProcessingService> _logger;
        private const int CheckIntervalSeconds = 1; // Kiểm tra mỗi 1 giây

        public PrintJobProcessingService(
            IServiceProvider serviceProvider,
            ILogger<PrintJobProcessingService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("PrintJobProcessingService started");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ProcessPrintJobsAsync();
                    await ProcessPrinterCoolingAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in PrintJobProcessingService");
                }

                // Đợi 1 giây trước khi kiểm tra lại
                await Task.Delay(TimeSpan.FromSeconds(CheckIntervalSeconds), stoppingToken);
            }

            _logger.LogInformation("PrintJobProcessingService stopped");
        }

        /// <summary>
        /// Xử lý các print job đang PRINTING: sau thời gian in → chuyển DONE và trừ giấy/mực
        /// </summary>
        private async Task ProcessPrintJobsAsync()
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<PTVBTPM.Models.Entities.WebDbContext>();
            var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<PrintHub>>();

            var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

            // Lấy tất cả print jobs đang PRINTING
            var printingJobs = await context.PrintJobs
                .Where(j => j.Status == "PRINTING" && j.ModifiedOn.HasValue)
                .Include(j => j.PaperSize)
                .Include(j => j.Printer)
                .Include(j => j.User)
                .Include(j => j.Document)
                .ToListAsync();

            foreach (var job in printingJobs)
            {
                try
                {
                    // Tính thời gian in (0.5s x số trang cho A4, 0.7s x số trang cho A3)
                    var (actualPagesPerCopy, paperSizeCode, isDoubleSided) = CalculateActualPagesFromPrintJob(job);
                    var totalPapersNeeded = actualPagesPerCopy * (job.Copies ?? 1);

                    const double secondsPerPaperA4 = 0.5;
                    const double secondsPerPaperA3 = 0.7;
                    double secondsPerPaper = paperSizeCode == "A3" ? secondsPerPaperA3 : secondsPerPaperA4;
                    var printTimeSeconds = totalPapersNeeded * secondsPerPaper;

                    // Thời gian bắt đầu in = ModifiedOn (khi chuyển sang PRINTING)
                    var printStartTime = job.ModifiedOn!.Value;
                    var printEndTime = printStartTime.AddSeconds(printTimeSeconds);

                    // Tính tiến trình để log
                    var totalDuration = (printEndTime - printStartTime).TotalSeconds;
                    var elapsed = (now - printStartTime).TotalSeconds;
                    var progressPercentage = totalDuration > 0
                        ? Math.Min(100, Math.Max(0, (int)((elapsed / totalDuration) * 100)))
                        : 0;

                    // Gửi SignalR update về tiến trình in
                    _logger.LogInformation($"[PrintJobProcessing] Sending progress update for job {job.PrintJobId}: {progressPercentage}%");
                    await SendPrintJobProgressUpdateAsync(hubContext, job, printStartTime, printEndTime, now, totalPapersNeeded);

                    // Nếu đã hết thời gian in → chuyển DONE và trừ giấy/mực
                    if (now >= printEndTime)
                    {
                        await CompletePrintJobAsync(context, hubContext, job, totalPapersNeeded, isDoubleSided, now);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error processing print job {job.PrintJobId}");
                }
            }

            // Xử lý hàng chờ: lấy job PENDING đầu tiên cho máy in AVAILABLE
            await ProcessPrintQueueAsync(context, hubContext, now);
        }

        /// <summary>
        /// Xử lý hàng chờ cho một máy in cụ thể
        /// </summary>
        private async Task ProcessPrintQueueForPrinterAsync(WebDbContext context, IHubContext<PrintHub> hubContext, DateTime now, int printerId)
        {
            try
            {
                var printer = await context.Printers.FindAsync(printerId);
                if (printer?.Status != "AVAILABLE")
                {
                    return; // Chỉ xử lý khi máy in AVAILABLE
                }

                // Kiểm tra máy in này có job PRINTING nào không
                var hasPrintingJob = await context.PrintJobs
                    .AnyAsync(j => j.PrinterId == printerId && j.Status == "PRINTING");

                if (hasPrintingJob)
                {
                    return; // Máy in đang bận
                }

                // Lấy job PENDING đầu tiên cho máy in này (theo thứ tự thời gian tạo)
                var nextPendingJob = await context.PrintJobs
                    .Where(j => j.PrinterId == printerId && j.Status == "PENDING")
                    .Include(j => j.PaperSize)
                    .Include(j => j.Printer)
                    .Include(j => j.User)
                    .Include(j => j.Document)
                    .OrderBy(j => j.CreatedOn)
                    .FirstOrDefaultAsync();

                if (nextPendingJob != null)
                {
                    _logger.LogInformation($"[ProcessPrintQueueForPrinter] Starting pending job {nextPendingJob.PrintJobId} on printer {printerId}");

                    // Cập nhật job thành PRINTING và thời gian bắt đầu
                    nextPendingJob.Status = "PRINTING";
                    nextPendingJob.ModifiedOn = now;

                    // Cập nhật máy in thành BUSY
                    printer.Status = "BUSY";
                    printer.ModifiedOn = now;

                    await context.SaveChangesAsync();

                    // Gửi SignalR updates
                    await SendPrintJobStatusUpdateAsync(hubContext, nextPendingJob, now);
                    await SendPrinterStatusUpdateAsync(hubContext, printer, now);

                    _logger.LogInformation($"[ProcessPrintQueueForPrinter] Job {nextPendingJob.PrintJobId} started printing on printer {printerId}");
                }
                else
                {
                    _logger.LogInformation($"[ProcessPrintQueueForPrinter] No pending jobs for printer {printerId}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error processing print queue for printer {printerId}");
            }
        }

        /// <summary>
        /// Xử lý hàng chờ: lấy job PENDING đầu tiên cho tất cả máy in AVAILABLE
        /// </summary>
        private async Task ProcessPrintQueueAsync(WebDbContext context, IHubContext<PrintHub> hubContext, DateTime now)
        {
            try
            {
                // Lấy tất cả máy in AVAILABLE
                var availablePrinters = await context.Printers
                    .Where(p => p.Status == "AVAILABLE")
                    .ToListAsync();

                foreach (var printer in availablePrinters)
                {
                    await ProcessPrintQueueForPrinterAsync(context, hubContext, now, printer.PrinterId);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing print queue");
            }
        }

        /// <summary>
        /// Xử lý làm lạnh máy in: sau 1 phút làm lạnh → máy in quay lại AVAILABLE
        /// </summary>
        private async Task ProcessPrinterCoolingAsync()
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<PTVBTPM.Models.Entities.WebDbContext>();
            var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<PrintHub>>();

            var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
            const double coolingTimeSeconds = 60.0; // 1 phút làm lạnh

            _logger.LogInformation($"[ProcessPrinterCooling] Starting at {now}");

            // Lấy tất cả máy in có status BUSY
            var busyPrinters = await context.Printers
                .Where(p => p.Status == "BUSY")
                .ToListAsync();

            foreach (var printer in busyPrinters)
            {
                try
                {
                    // Kiểm tra có print job nào đang PRINTING không
                    var hasPrintingJob = await context.PrintJobs
                        .AnyAsync(j => j.PrinterId == printer.PrinterId && j.Status == "PRINTING");

                    if (hasPrintingJob)
                    {
                        // Vẫn đang in, giữ status BUSY
                        continue;
                    }

                    // Không có job đang in → kiểm tra thời gian làm lạnh
                    // Lấy print job DONE gần nhất của máy in này
                    var lastDoneJob = await context.PrintJobs
                        .Where(j => j.PrinterId == printer.PrinterId && j.Status == "DONE" && j.CompletedAt.HasValue)
                        .OrderByDescending(j => j.CompletedAt)
                        .FirstOrDefaultAsync();

                    if (lastDoneJob != null && lastDoneJob.CompletedAt.HasValue)
                    {
                        var coolingEndTime = lastDoneJob.CompletedAt.Value.AddSeconds(coolingTimeSeconds);

                        // Nếu đã hết thời gian làm lạnh → máy in quay lại AVAILABLE
                        if (now >= coolingEndTime)
                        {
                            _logger.LogInformation($"[ProcessPrinterCooling] Printer {printer.PrinterId} cooling completed, setting AVAILABLE");
                            printer.Status = "AVAILABLE";
                            printer.ModifiedOn = now;
                            await context.SaveChangesAsync();
                            _logger.LogInformation($"Printer {printer.PrinterId} ({printer.PrinterCode}) is now AVAILABLE after cooling");

                            // Gửi SignalR notification về trạng thái máy in
                            await SendPrinterStatusUpdateAsync(hubContext, printer, now);

                            // Xử lý hàng chờ: lấy job PENDING đầu tiên cho máy in này
                            _logger.LogInformation($"[ProcessPrinterCooling] Processing queue for printer {printer.PrinterId} after cooling");
                            await ProcessPrintQueueForPrinterAsync(context, hubContext, now, printer.PrinterId);

                            var pendingCount = await context.PrintJobs
                                .CountAsync(j => j.PrinterId == printer.PrinterId && j.Status == "PENDING");
                            _logger.LogInformation($"[ProcessPrinterCooling] Printer {printer.PrinterId} has {pendingCount} pending jobs");
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error processing printer cooling for printer {printer.PrinterId}");
                }
            }
        }

        /// <summary>
        /// Hoàn thành print job: trừ giấy/mực, chuyển DONE, trừ page balance của user
        /// </summary>
        private async Task CompletePrintJobAsync(
            PTVBTPM.Models.Entities.WebDbContext context,
            IHubContext<PrintHub> hubContext,
            PrintJob job,
            int totalPapersNeeded,
            bool isDoubleSided,
            DateTime now)
        {
            // 1. Trừ giấy trong máy in
            if (job.Printer != null && job.Printer.CurrentPaper.HasValue)
            {
                if (job.Printer.CurrentPaper.Value >= totalPapersNeeded)
                {
                    job.Printer.CurrentPaper = job.Printer.CurrentPaper.Value - totalPapersNeeded;
                    job.Printer.ModifiedOn = now;
                }
                else
                {
                    _logger.LogWarning($"Printer {job.PrinterId} doesn't have enough paper. Required: {totalPapersNeeded}, Available: {job.Printer.CurrentPaper.Value}");
                }
            }

            // 2. Trừ mực
            var inkConsumptionPerPaper = isDoubleSided ? 2 : 1;
            var totalInkNeeded = totalPapersNeeded * inkConsumptionPerPaper;

            var inkColorsToUpdate = job.IsColor
                ? new[] { "BLACK", "COLOR" }
                : new[] { "BLACK" };

            var inksToUpdate = await context.Inks
                .Where(i => i.Status == "AVAILABLE" && inkColorsToUpdate.Contains(i.Color.ToUpper()))
                .ToListAsync();

            foreach (var ink in inksToUpdate)
            {
                if (ink.CurrentPages >= totalInkNeeded)
                {
                    ink.CurrentPages = ink.CurrentPages - totalInkNeeded;
                    if (ink.CurrentPages == 0)
                    {
                        ink.Status = "OFFLINE";
                    }
                    else if (ink.CurrentPages <= (ink.CapacityPages * 0.2)) // Nếu còn ≤ 20% thì chuyển LOW
                    {
                        ink.Status = "LOW";
                    }
                    // AVAILABLE status is implicit - no change needed if > 50%
                    ink.ModifiedOn = now;
                }
                else
                {
                    _logger.LogWarning($"Ink {ink.InkId} ({ink.Color}) doesn't have enough pages. Required: {totalInkNeeded}, Available: {ink.CurrentPages}");
                }
            }

            // 3. Trừ page balance của user: trừ từ PageDefaultBalance trước, hết mới trừ PagePurchasedBalance
            if (job.UserId.HasValue)
            {
                var user = await context.Users.FindAsync(job.UserId.Value);
                if (user != null)
                {
                    // Tính số trang cần trừ (TotalPages đã là số trang A4 tương đương)
                    int pagesToDeduct = (job.TotalPages ?? 0) * (job.Copies ?? 1);
                    _logger.LogInformation($"PrintJob {job.PrintJobId}: TotalPages={job.TotalPages}, Copies={job.Copies}, pagesToDeduct={pagesToDeduct}, UserBalanceBefore: Default={user.PageDefaultBalance}, Purchased={user.PagePurchasedBalance}");

                    if (pagesToDeduct > 0)
                    {
                        // Trừ từ PageDefaultBalance trước
                        if (user.PageDefaultBalance >= pagesToDeduct)
                        {
                            user.PageDefaultBalance -= pagesToDeduct;
                            _logger.LogInformation($"Deducted {pagesToDeduct} pages from PageDefaultBalance for user {user.UserId}. Remaining: {user.PageDefaultBalance}");
                        }
                        else
                        {
                            // Hết PageDefaultBalance, trừ phần còn lại từ PagePurchasedBalance
                            int remainingPages = pagesToDeduct - user.PageDefaultBalance;
                            user.PageDefaultBalance = 0;

                            if (user.PagePurchasedBalance >= remainingPages)
                            {
                                user.PagePurchasedBalance -= remainingPages;
                                _logger.LogInformation($"Deducted {user.PageDefaultBalance + remainingPages} pages (all default + {remainingPages} purchased) for user {user.UserId}. Remaining purchased: {user.PagePurchasedBalance}");
                            }
                            else
                            {
                                // Không đủ giấy, nhưng vẫn trừ hết (đã kiểm tra trước khi tạo print job)
                                user.PagePurchasedBalance = 0;
                                _logger.LogWarning($"User {user.UserId} doesn't have enough pages. Deducted all available pages.");
                            }
                        }

                        user.ModifiedOn = now;
                    }
                }
            }

            // 4. Cập nhật PrintJob status → DONE
            job.Status = "DONE";
            job.CompletedAt = now;
            job.ModifiedOn = now;

            // 5. Máy in vẫn ở trạng thái BUSY (đang làm lạnh)
            // Status sẽ được chuyển về AVAILABLE sau 1 phút làm lạnh trong ProcessPrinterCoolingAsync

            await context.SaveChangesAsync();
            _logger.LogInformation($"Completed print job {job.PrintJobId} - Printed {totalPapersNeeded} papers, deducted ink and paper");

            // Gửi SignalR notifications
            await SendPrintJobStatusUpdateAsync(hubContext, job, now);
            if (job.Printer != null)
            {
                await SendPrinterStatusUpdateAsync(hubContext, job.Printer, now);
            }
        }

        /// <summary>
        /// Helper: Tính số giấy thực tế từ PrintJob
        /// </summary>
        private (int actualPagesPerCopy, string? paperSizeCode, bool isDoubleSided) CalculateActualPagesFromPrintJob(PrintJob job)
        {
            var paperSizeCode = job.PaperSize?.Code?.ToUpper() ?? "A4";
            int actualPagesPerCopy = job.TotalPages ?? 0;

            // Nếu là A3, TotalPages đã được nhân 2 (A3 = 2x A4), nên chia lại
            if (paperSizeCode == "A3")
            {
                actualPagesPerCopy = actualPagesPerCopy / 2;
            }

            // Parse double-sided từ PagesToPrint
            bool isDoubleSided = false;
            if (!string.IsNullOrWhiteSpace(job.PagesToPrint) && 
                job.PagesToPrint.Contains("|DOUBLE_SIDED", StringComparison.OrdinalIgnoreCase))
            {
                isDoubleSided = true;
            }

            return (actualPagesPerCopy, paperSizeCode, isDoubleSided);
        }

        /// <summary>
        /// Map trạng thái máy in sang tiếng Việt
        /// </summary>
        private string MapPrinterStatusToVietnamese(string? status)
        {
            return (status ?? "UNKNOWN").ToUpper() switch
            {
                "AVAILABLE" => "Khả dụng",
                "BUSY" => "Bận",
                "PRINTING" => "Đang in",
                "OFFLINE" => "Offline",
                _ => status ?? "Không xác định"
            };
        }

        /// <summary>
        /// Map trạng thái print job sang tiếng Việt
        /// </summary>
        private string MapPrintJobStatusToVietnamese(string? status)
        {
            return (status ?? "UNKNOWN").ToUpper() switch
            {
                "PENDING" => "Đang chờ",
                "PRINTING" => "Đang in",
                "DONE" => "Hoàn thành",
                "COMPLETED" => "Hoàn thành",
                "SUCCESS" => "Hoàn thành",
                "FAILED" => "Thất bại",
                "ERROR" => "Thất bại",
                "CANCELLED" => "Đã hủy",
                _ => status ?? "Không xác định"
            };
        }

        /// <summary>
        /// Gửi SignalR notification về trạng thái máy in
        /// </summary>
        private async Task SendPrinterStatusUpdateAsync(IHubContext<PrintHub> hubContext, Printer printer, DateTime now)
        {
            try
            {
                var status = printer.Status ?? "UNKNOWN";
                var update = new PrinterStatusUpdateDto
                {
                    PrinterId = printer.PrinterId,
                    PrinterCode = printer.PrinterCode,
                    Status = status,
                    StatusVi = MapPrinterStatusToVietnamese(status),
                    CurrentPaper = printer.CurrentPaper,
                    UpdatedAt = now
                };

                // Gửi đến group printer
                var printerGroup = $"printer_{printer.PrinterId}";
                await hubContext.Clients.Group(printerGroup).SendAsync("PrinterStatusUpdate", update);
                
                _logger.LogDebug($"Sent printer status update for printer {printer.PrinterId} to group {printerGroup}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending printer status update for printer {printer.PrinterId}");
            }
        }

        /// <summary>
        /// Gửi SignalR notification về trạng thái print job
        /// </summary>
        private async Task SendPrintJobStatusUpdateAsync(IHubContext<PrintHub> hubContext, PrintJob job, DateTime now)
        {
            try
            {
                var year = job.CreatedOn?.Year ?? DateTime.Now.Year;
                var orderCode = $"PJ-{year}-{job.PrintJobId:D3}";

                var printerName = job.Printer != null
                    ? $"{job.Printer.Brand} {job.Printer.Model}".Trim()
                    : null;

                var status = job.Status ?? "UNKNOWN";
                var update = new PrintJobStatusUpdateDto
                {
                    PrintJobId = job.PrintJobId,
                    OrderCode = orderCode,
                    Status = status,
                    StatusVi = MapPrintJobStatusToVietnamese(status),
                    FileName = job.Document?.FileName,
                    PrinterId = job.PrinterId,
                    PrinterName = printerName,
                    UpdatedAt = now
                };

                // Gửi đến các groups
                if (job.UserId.HasValue)
                {
                    var userGroup = $"user_print_{job.UserId.Value}";
                    await hubContext.Clients.Group(userGroup).SendAsync("PrintJobStatusUpdate", update);
                }

                var printJobGroup = $"printjob_{job.PrintJobId}";
                await hubContext.Clients.Group(printJobGroup).SendAsync("PrintJobStatusUpdate", update);

                if (job.PrinterId.HasValue)
                {
                    var printerGroup = $"printer_{job.PrinterId.Value}";
                    await hubContext.Clients.Group(printerGroup).SendAsync("PrintJobStatusUpdate", update);
                }

                _logger.LogDebug($"Sent print job status update for job {job.PrintJobId}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending print job status update for job {job.PrintJobId}");
            }
        }

        /// <summary>
        /// Gửi SignalR notification về tiến trình in
        /// </summary>
        private async Task SendPrintJobProgressUpdateAsync(
            IHubContext<PrintHub> hubContext,
            PrintJob job,
            DateTime startTime,
            DateTime endTime,
            DateTime now,
            int totalPapersNeeded)
        {
            try
            {
                var year = job.CreatedOn?.Year ?? DateTime.Now.Year;
                var orderCode = $"PJ-{year}-{job.PrintJobId:D3}";

                // Tính tiến trình (0-100%)
                var totalDuration = (endTime - startTime).TotalSeconds;
                var elapsed = (now - startTime).TotalSeconds;
                var progressPercentage = totalDuration > 0
                    ? Math.Min(100, Math.Max(0, (int)((elapsed / totalDuration) * 100)))
                    : 0;

                // Tính số trang đã in (ước tính)
                var totalPages = job.TotalPages ?? 0;
                var copies = job.Copies ?? 1;
                var totalPagesToPrint = totalPages * copies;
                var pagesPrinted = (int)(totalPagesToPrint * (progressPercentage / 100.0));

                var status = job.Status ?? "PRINTING";
                var progress = new PrintJobProgressDto
                {
                    PrintJobId = job.PrintJobId,
                    PrinterId = job.PrinterId,
                    OrderCode = orderCode,
                    Status = status,
                    StatusVi = MapPrintJobStatusToVietnamese(status),
                    TotalPages = totalPages,
                    Copies = copies,
                    TotalPagesPrinted = pagesPrinted,
                    ProgressPercentage = progressPercentage,
                    StartTime = startTime,
                    EstimatedEndTime = endTime,
                    UpdatedAt = now
                };

                // Gửi đến các groups
                if (job.UserId.HasValue)
                {
                    var userGroup = $"user_print_{job.UserId.Value}";
                    await hubContext.Clients.Group(userGroup).SendAsync("PrintJobProgress", progress);
                }

                var printJobGroup = $"printjob_{job.PrintJobId}";
                await hubContext.Clients.Group(printJobGroup).SendAsync("PrintJobProgress", progress);

                if (job.PrinterId.HasValue)
                {
                    var printerGroup = $"printer_{job.PrinterId.Value}";
                    await hubContext.Clients.Group(printerGroup).SendAsync("PrintJobProgress", progress);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending print job progress update for job {job.PrintJobId}");
            }
        }
    }
}

