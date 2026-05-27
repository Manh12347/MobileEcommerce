using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Models.Entities;
using PTVBTPM.Services;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace PTVBTPM.Controllers;

[ApiController]
[Route("v1/[controller]")]
[Produces("application/json")]
public class ReportController : ControllerBase
{
    private readonly ReportService _reportService;
    private readonly WebDbContext _context;
    private readonly IWebHostEnvironment _environment;

    public ReportController(ReportService reportService, WebDbContext context, IWebHostEnvironment environment)
    {
        _reportService = reportService;
        _context = context;
        _environment = environment;
    }

    /// <summary>
    /// Tạo báo cáo 30 ngày gần nhất (dễ test)
    /// </summary>
    [HttpPost("generate-quick")]
    [ProducesResponseType(200)]
    [ProducesResponseType(500)]
    public async Task<IActionResult> GenerateQuickReport()
    {
        try
        {
            // Tự động tính 30 ngày gần nhất
            var endDate = DateTime.UtcNow;
            var startDate = endDate.AddDays(-30);

            var fileName = await _reportService.GenerateGeneralReportAsync(startDate, endDate);

            return Ok(new
            {
                success = true,
                message = $"Đã tạo báo cáo 30 ngày gần nhất ({startDate:dd/MM/yyyy} - {endDate:dd/MM/yyyy})",
                data = new
                {
                    fileName,
                    downloadUrl = $"/v1/Report/download/{fileName}",
                    reportUrl = $"/Reports/{fileName}",
                    period = $"{startDate:dd/MM/yyyy} - {endDate:dd/MM/yyyy}",
                    days = 30,
                    createdAt = DateTime.UtcNow
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi tạo báo cáo nhanh", error = ex.Message });
        }
    }

    /// <summary>
    /// Tạo báo cáo tổng quát thủ công với khoảng thời gian tùy chỉnh
    /// </summary>
    [HttpPost("generate")]
    [Authorize(Roles = "ADMIN,SPSO")]
    [ProducesResponseType(200)]
    [ProducesResponseType(500)]
    public async Task<IActionResult> GenerateReport([FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate)
    {
        try
        {
            var fileName = await _reportService.GenerateGeneralReportAsync(startDate, endDate);

            return Ok(new
            {
                success = true,
                message = "Đã tạo báo cáo thành công",
                data = new
                {
                    fileName,
                    downloadUrl = $"/Reports/{fileName}"
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi tạo báo cáo", error = ex.Message });
        }
    }

    /// <summary>
    /// Liệt kê các báo cáo đã tạo (deprecated - dùng reports-list)
    /// </summary>
    [HttpGet("list")]
    [Authorize(Roles = "ADMIN,SPSO")]
    [ProducesResponseType(200)]
    public IActionResult ListReports()
    {
        try
        {
            var reportsFolder = Path.Combine(_environment.WebRootPath, "Reports");
            if (!Directory.Exists(reportsFolder))
                return Ok(new { success = true, data = new { reports = Array.Empty<object>() } });

            var reportFiles = Directory.GetFiles(reportsFolder, "*.xlsx")
                .Select(filePath =>
                {
                    var fileInfo = new FileInfo(filePath);
                    return new
                    {
                        fileName = Path.GetFileName(filePath),
                        size = fileInfo.Length,
                        createdDate = fileInfo.CreationTime,
                        downloadUrl = $"/Reports/{Path.GetFileName(filePath)}"
                    };
                })
                .OrderByDescending(r => r.createdDate)
                .ToArray();

            return Ok(new
            {
                success = true,
                data = new { reports = reportFiles }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi lấy danh sách báo cáo", error = ex.Message });
        }
    }

    /// <summary>
    /// Kiểm tra xem có nên tạo báo cáo định kỳ không (dựa trên cấu hình hệ thống)
    /// </summary>
    [HttpGet("should-generate")]
    [Authorize(Roles = "ADMIN,SPSO")]
    [ProducesResponseType(200)]
    public async Task<IActionResult> ShouldGenerateReport()
    {
        try
        {
            var systemConfig = await _context.SystemConfigs.FirstOrDefaultAsync();
            if (systemConfig == null)
            {
                return Ok(new
                {
                    success = true,
                    data = new
                    {
                        shouldGenerate = false,
                        reason = "Chưa có cấu hình hệ thống"
                    }
                });
            }

            // Kiểm tra xem hôm nay có phải là ngày tạo báo cáo không
            var today = DateTime.UtcNow.Day;
            var shouldGenerate = today == systemConfig.AutoAssignDayOfMonth;

            return Ok(new
            {
                success = true,
                data = new
                {
                    shouldGenerate,
                    currentDay = today,
                    configDay = systemConfig.AutoAssignDayOfMonth,
                    reason = shouldGenerate ? "Đến ngày tạo báo cáo định kỳ" : $"Chưa đến ngày tạo báo cáo (ngày {systemConfig.AutoAssignDayOfMonth})"
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi kiểm tra cấu hình báo cáo", error = ex.Message });
        }
    }

    /// <summary>
    /// Lấy thống kê 30 ngày gần nhất (dễ test)
    /// </summary>
    [HttpGet("quick-stats")]
    [Authorize(Roles = "ADMIN,SPSO")]
    [ProducesResponseType(200)]
    public async Task<IActionResult> GetQuickStats()
    {
        try
        {
            var endDate = DateTime.UtcNow;
            var startDate = endDate.AddDays(-30);

            // Tổng doanh thu 30 ngày
            var totalRevenue = await _context.PurchaseTransactions
                .Where(pt => pt.CreatedAt >= startDate && pt.Status == "COMPLETED")
                .SumAsync(pt => pt.TotalAmount);

            // Tổng trang đã in 30 ngày
            var totalPagesPrinted = await _context.PrintJobs
                .Where(pj => pj.CreatedOn >= startDate && pj.Status == "COMPLETED")
                .SumAsync(pj => pj.TotalPages ?? 0);

            // Máy in hoạt động
            var activePrinters = await _context.Printers
                .CountAsync(p => p.Status == "Active" || p.Status == "Available");

            // Người dùng hoạt động trong 30 ngày
            var activeUsers = await _context.Users
                .Where(u => _context.LoginHistories
                    .Any(lh => lh.UserId == u.UserId && lh.LoginTime >= startDate))
                .CountAsync();

            // Máy in mực thấp
            var lowInkPrinters = await _context.Printers
                .Where(p => p.Status == "Active" || p.Status == "Available")
                .Join(_context.Inks,
                    printer => printer.InkId,
                    ink => ink.InkId,
                    (printer, ink) => new
                    {
                        RemainingPercent = ink.CapacityPages > 0 ? (decimal)ink.CurrentPages / ink.CapacityPages * 100 : 0
                    })
                .CountAsync(x => x.RemainingPercent < 20);

            return Ok(new
            {
                success = true,
                message = "Thống kê 30 ngày gần nhất",
                data = new
                {
                    period = $"{startDate:dd/MM/yyyy} - {endDate:dd/MM/yyyy}",
                    days = 30,
                    totalRevenue,
                    totalPagesPrinted,
                    activePrinters,
                    activeUsers,
                    lowInkPrinters
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi lấy thống kê nhanh", error = ex.Message });
        }
    }

    /// <summary>
    /// Liệt kê các báo cáo đã tạo
    /// </summary>
    [HttpGet("reports-list")]
    [ProducesResponseType(200)]
    public IActionResult GetReportList()
    {
        try
        {
            var reportsPath = Path.Combine(_environment.WebRootPath, "Reports");

            if (!Directory.Exists(reportsPath))
            {
                return Ok(new
                {
                    success = true,
                    message = "Chưa có báo cáo nào được tạo",
                    data = new List<object>()
                });
            }

            var reportFiles = Directory.GetFiles(reportsPath, "*.xlsx")
                .Select(filePath =>
                {
                    var fileInfo = new FileInfo(filePath);
                    return new
                    {
                        fileName = Path.GetFileName(filePath),
                        fileSize = fileInfo.Length,
                        createdDate = fileInfo.CreationTimeUtc,
                        downloadUrl = $"/v1/Report/download/{Path.GetFileName(filePath)}"
                    };
                })
                .OrderByDescending(r => r.createdDate)
                .ToList();

            return Ok(new
            {
                success = true,
                message = $"Tìm thấy {reportFiles.Count} báo cáo",
                data = reportFiles
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi lấy danh sách báo cáo", error = ex.Message });
        }
    }

    /// <summary>
    /// Tải xuống báo cáo Excel đã tạo
    /// </summary>
    [HttpGet("download/{fileName}")]
    [ProducesResponseType(200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> DownloadReport(string fileName)
    {
        try
        {
            var reportsPath = Path.Combine(_environment.WebRootPath, "Reports");

            // Validate filename để tránh path traversal
            if (string.IsNullOrEmpty(fileName) || !fileName.EndsWith(".xlsx") ||
                fileName.Contains("..") || fileName.Contains("/") || fileName.Contains("\\"))
            {
                return BadRequest(new { success = false, message = "Tên file không hợp lệ" });
            }

            var filePath = Path.Combine(reportsPath, fileName);

            if (!System.IO.File.Exists(filePath))
            {
                return NotFound(new { success = false, message = "File báo cáo không tồn tại" });
            }

            var fileBytes = await System.IO.File.ReadAllBytesAsync(filePath);
            var fileNameSafe = $"BaoCao_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx";

            return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileNameSafe);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi tải báo cáo", error = ex.Message });
        }
    }

    /// <summary>
    /// Lấy thống kê hiện tại cho dashboard
    /// </summary>
    [HttpGet("current-stats")]
    [Authorize(Roles = "ADMIN,SPSO")]
    [ProducesResponseType(200)]
    public async Task<IActionResult> GetCurrentStats()
    {
        try
        {
            var now = DateTime.UtcNow;
            var startOfMonth = new DateTime(now.Year, now.Month, 1);

            // Tổng doanh thu tháng này
            var monthlyRevenue = await _context.PurchaseTransactions
                .Where(pt => pt.CreatedAt >= startOfMonth && pt.Status == "COMPLETED")
                .SumAsync(pt => pt.TotalAmount);

            // Tổng trang đã in tháng này
            var monthlyPagesPrinted = await _context.PrintJobs
                .Where(pj => pj.CreatedOn >= startOfMonth && pj.Status == "COMPLETED")
                .SumAsync(pj => pj.TotalPages ?? 0);

            // Máy in hoạt động
            var activePrinters = await _context.Printers
                .CountAsync(p => p.Status == "Active" || p.Status == "Available");

            // Mực thấp (< 20%)
            var lowInkPrinters = await _context.Printers
                .Where(p => p.Status == "Active" || p.Status == "Available")
                .Join(_context.Inks,
                    printer => printer.InkId,
                    ink => ink.InkId,
                    (printer, ink) => new
                    {
                        Printer = printer,
                        Ink = ink,
                        RemainingPercent = ink.CapacityPages > 0 ? (decimal)ink.CurrentPages / ink.CapacityPages * 100 : 0
                    })
                .CountAsync(x => x.RemainingPercent < 20);

            // Người dùng hoạt động tháng này
            var activeUsers = await _context.Users
                .Where(u => _context.LoginHistories
                    .Any(lh => lh.UserId == u.UserId && lh.LoginTime >= startOfMonth))
                .CountAsync();

            return Ok(new
            {
                success = true,
                data = new
                {
                    monthlyRevenue,
                    monthlyPagesPrinted,
                    activePrinters,
                    lowInkPrinters,
                    activeUsers,
                    generatedAt = now
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi lấy thống kê hiện tại", error = ex.Message });
        }
    }
}
