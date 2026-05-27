using ClosedXML.Excel;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Models.Entities;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace PTVBTPM.Services;

public class ReportService
{
    private readonly WebDbContext _context;
    private readonly IWebHostEnvironment _environment;

    public ReportService(WebDbContext context, IWebHostEnvironment environment)
    {
        _context = context;
        _environment = environment;
    }

    public async Task<string> GenerateGeneralReportAsync(DateTime? startDate = null, DateTime? endDate = null)
    {
        // Set default date range (current month)
        var now = DateTime.Now; // Use local time instead of UTC
        startDate ??= new DateTime(now.Year, now.Month, 1);
        endDate ??= now;

        // Convert to unspecified kind to avoid PostgreSQL timestamp issues
        startDate = DateTime.SpecifyKind(startDate.Value, DateTimeKind.Unspecified);
        endDate = DateTime.SpecifyKind(endDate.Value, DateTimeKind.Unspecified);

        using var workbook = new XLWorkbook();

        // Sheet 1: Tổng quan
        await CreateOverviewSheetAsync(workbook, startDate.Value, endDate.Value);

        // Sheet 2: Chi tiết người dùng
        await CreateUserDetailsSheetAsync(workbook, startDate.Value, endDate.Value);

        // Sheet 3: Máy in có mực thấp
        await CreateLowInkPrintersSheetAsync(workbook);

        // Save file
        var reportsFolder = Path.Combine(_environment.WebRootPath, "Reports");
        if (!Directory.Exists(reportsFolder))
            Directory.CreateDirectory(reportsFolder);

        var fileName = $"BaoCaoTongQuat_{startDate.Value:yyyyMMdd}_{endDate.Value:yyyyMMdd}_{DateTime.UtcNow:HHmmss}.xlsx";
        var filePath = Path.Combine(reportsFolder, fileName);

        workbook.SaveAs(filePath);

        return fileName;
    }

    private async Task CreateOverviewSheetAsync(XLWorkbook workbook, DateTime startDate, DateTime endDate)
    {
        var worksheet = workbook.Worksheets.Add("TongQuan");

        // Header
        worksheet.Cell(1, 1).Value = "BÁO CÁO TỔNG QUAN HỆ THỐNG IN ẤN";
        worksheet.Cell(1, 1).Style.Font.Bold = true;
        worksheet.Cell(1, 1).Style.Font.FontSize = 16;
        worksheet.Range(1, 1, 1, 3).Merge();

        worksheet.Cell(2, 1).Value = $"Thời gian: {startDate:dd/MM/yyyy} - {endDate:dd/MM/yyyy}";
        worksheet.Range(2, 1, 2, 3).Merge();

        // Data section
        int currentRow = 4;

        // Tổng doanh thu từ PurchaseTransactions
        var totalRevenue = await _context.PurchaseTransactions
            .Where(pt => pt.CreatedAt >= startDate && pt.CreatedAt <= endDate && pt.Status == "COMPLETED")
            .SumAsync(pt => pt.TotalAmount);

        worksheet.Cell(currentRow, 1).Value = "Tổng doanh thu (VNĐ):";
        worksheet.Cell(currentRow, 1).Style.Font.Bold = true;
        worksheet.Cell(currentRow, 2).Value = totalRevenue;
        worksheet.Cell(currentRow, 2).Style.NumberFormat.Format = "#,##0";
        currentRow++;

        // Tổng trang đã in
        var totalPagesPrinted = await _context.PrintJobs
            .Where(pj => pj.CreatedOn >= startDate && pj.CreatedOn <= endDate && pj.Status == "COMPLETED")
            .SumAsync(pj => pj.TotalPages ?? 0);

        worksheet.Cell(currentRow, 1).Value = "Tổng trang đã in:";
        worksheet.Cell(currentRow, 1).Style.Font.Bold = true;
        worksheet.Cell(currentRow, 2).Value = totalPagesPrinted;
        currentRow++;

        // Tổng máy in hoạt động
        var activePrintersCount = await _context.Printers
            .CountAsync(p => p.Status == "Active" || p.Status == "Available");

        worksheet.Cell(currentRow, 1).Value = "Số máy in hoạt động:";
        worksheet.Cell(currentRow, 1).Style.Font.Bold = true;
        worksheet.Cell(currentRow, 2).Value = activePrintersCount;
        currentRow++;

        // Tổng cuộn mực đang sử dụng
        var activeInksCount = await _context.Inks
            .CountAsync(i => i.Status == "Active" || i.Status == "InUse");

        worksheet.Cell(currentRow, 1).Value = "Số cuộn mực đang sử dụng:";
        worksheet.Cell(currentRow, 1).Style.Font.Bold = true;
        worksheet.Cell(currentRow, 2).Value = activeInksCount;
        currentRow++;

        // Tổng số người dùng
        var totalUsers = await _context.Users.CountAsync();

        worksheet.Cell(currentRow, 1).Value = "Tổng số người dùng:";
        worksheet.Cell(currentRow, 1).Style.Font.Bold = true;
        worksheet.Cell(currentRow, 2).Value = totalUsers;
        currentRow++;

        // Số người dùng hoạt động (đã đăng nhập trong tháng)
        var activeUsersCount = await _context.Users
            .Where(u => _context.LoginHistories
                .Any(lh => lh.UserId == u.UserId && lh.LoginTime >= startDate && lh.LoginTime <= endDate))
            .CountAsync();

        worksheet.Cell(currentRow, 1).Value = "Người dùng hoạt động (tháng):";
        worksheet.Cell(currentRow, 1).Style.Font.Bold = true;
        worksheet.Cell(currentRow, 2).Value = activeUsersCount;
        currentRow++;

        // Format columns
        worksheet.Column(1).Width = 30;
        worksheet.Column(2).Width = 20;
        worksheet.Column(3).Width = 20;
    }

    private async Task CreateUserDetailsSheetAsync(XLWorkbook workbook, DateTime startDate, DateTime endDate)
    {
        var worksheet = workbook.Worksheets.Add("ChiTietNguoiDung");

        // Header
        worksheet.Cell(1, 1).Value = "CHI TIẾT NGƯỜI DÙNG";
        worksheet.Cell(1, 1).Style.Font.Bold = true;
        worksheet.Cell(1, 1).Style.Font.FontSize = 14;
        worksheet.Range(1, 1, 1, 5).Merge();

        // Column headers
        worksheet.Cell(3, 1).Value = "Mã SV";
        worksheet.Cell(3, 2).Value = "Họ tên";
        worksheet.Cell(3, 3).Value = "Trang mặc định";
        worksheet.Cell(3, 4).Value = "Trang đã mua";
        worksheet.Cell(3, 5).Value = "Lần đăng nhập cuối";

        // Style headers
        var headerRange = worksheet.Range(3, 1, 3, 5);
        headerRange.Style.Font.Bold = true;
        headerRange.Style.Fill.BackgroundColor = XLColor.LightGray;

        // Get user data with last login
        var userIds = await _context.Users.Select(u => u.UserId).ToListAsync();

        var lastLogins = await _context.LoginHistories
            .Where(lh => lh.UserId.HasValue && userIds.Contains(lh.UserId.Value))
            .GroupBy(lh => lh.UserId)
            .Select(g => new
            {
                UserId = g.Key,
                LastLogin = g.Max(lh => lh.LoginTime)
            })
            .ToDictionaryAsync(x => x.UserId.Value, x => x.LastLogin);

        var users = await _context.Users
            .Select(u => new
            {
                u.UserId,
                u.StudentCode,
                u.FullName,
                u.PageDefaultBalance,
                u.PagePurchasedBalance
            })
            .ToListAsync();

        // Combine data
        var userData = users.Select(u => new
        {
            u.StudentCode,
            u.FullName,
            u.PageDefaultBalance,
            u.PagePurchasedBalance,
            LastLogin = lastLogins.ContainsKey(u.UserId) ? lastLogins[u.UserId] : (DateTime?)null
        }).ToList();

        int currentRow = 4;
        foreach (var user in userData)
        {
            worksheet.Cell(currentRow, 1).Value = user.StudentCode ?? "";
            worksheet.Cell(currentRow, 2).Value = user.FullName ?? "";
            worksheet.Cell(currentRow, 3).Value = user.PageDefaultBalance;
            worksheet.Cell(currentRow, 4).Value = user.PagePurchasedBalance;
            worksheet.Cell(currentRow, 5).Value = user.LastLogin?.ToString("dd/MM/yyyy HH:mm") ?? "Chưa đăng nhập";

            currentRow++;
        }

        // Format columns
        worksheet.Column(1).Width = 15;
        worksheet.Column(2).Width = 25;
        worksheet.Column(3).Width = 15;
        worksheet.Column(4).Width = 15;
        worksheet.Column(5).Width = 20;
    }

    private async Task CreateLowInkPrintersSheetAsync(XLWorkbook workbook)
    {
        var worksheet = workbook.Worksheets.Add("MayInMucThap");

        // Header
        worksheet.Cell(1, 1).Value = "MÁY IN CÓ MỰC THẤP";
        worksheet.Cell(1, 1).Style.Font.Bold = true;
        worksheet.Cell(1, 1).Style.Font.FontSize = 14;
        worksheet.Range(1, 1, 1, 6).Merge();

        // Column headers
        worksheet.Cell(3, 1).Value = "Mã máy in";
        worksheet.Cell(3, 2).Value = "Tên máy in";
        worksheet.Cell(3, 3).Value = "Vị trí";
        worksheet.Cell(3, 4).Value = "Mực hiện tại";
        worksheet.Cell(3, 5).Value = "Dung tích tối đa";
        worksheet.Cell(3, 6).Value = "Phần trăm còn lại";

        // Style headers
        var headerRange = worksheet.Range(3, 1, 3, 6);
        headerRange.Style.Font.Bold = true;
        headerRange.Style.Fill.BackgroundColor = XLColor.LightGray;

        // Get low ink printers (dưới 20%)
        var lowInkPrinters = await _context.Printers
            .Where(p => p.Status == "Active" || p.Status == "Available")
            .Join(_context.Inks,
                printer => printer.InkId,
                ink => ink.InkId,
                (printer, ink) => new
                {
                    PrinterCode = printer.PrinterCode,
                    PrinterBrand = printer.Brand,
                    PrinterModel = printer.Model,
                    Location = printer.Location,
                    CurrentPages = ink.CurrentPages,
                    CapacityPages = ink.CapacityPages,
                    RemainingPercent = ink.CapacityPages > 0 ? (decimal)ink.CurrentPages / ink.CapacityPages * 100 : 0
                })
            .Where(x => x.RemainingPercent < 20)
            .OrderBy(x => x.RemainingPercent)
            .ToListAsync();

        int currentRow = 4;
        foreach (var printer in lowInkPrinters)
        {
            worksheet.Cell(currentRow, 1).Value = printer.PrinterCode ?? "";
            worksheet.Cell(currentRow, 2).Value = $"{printer.PrinterBrand} {printer.PrinterModel}";
            worksheet.Cell(currentRow, 3).Value = printer.Location ?? "";
            worksheet.Cell(currentRow, 4).Value = printer.CurrentPages;
            worksheet.Cell(currentRow, 5).Value = printer.CapacityPages;
            worksheet.Cell(currentRow, 6).Value = Math.Round(printer.RemainingPercent, 1);
            worksheet.Cell(currentRow, 6).Style.NumberFormat.Format = "0.0'%'";

            // Highlight low ink
            if (printer.RemainingPercent < 10)
            {
                worksheet.Row(currentRow).Style.Fill.BackgroundColor = XLColor.Red;
            }
            else if (printer.RemainingPercent < 15)
            {
                worksheet.Row(currentRow).Style.Fill.BackgroundColor = XLColor.Yellow;
            }

            currentRow++;
        }

        // Format columns
        worksheet.Column(1).Width = 15;
        worksheet.Column(2).Width = 20;
        worksheet.Column(3).Width = 25;
        worksheet.Column(4).Width = 15;
        worksheet.Column(5).Width = 15;
        worksheet.Column(6).Width = 15;
    }
}
