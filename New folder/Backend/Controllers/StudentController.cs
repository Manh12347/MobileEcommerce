using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;

namespace PTVBTPM.Controllers
{
[ApiController]
[Route("v1/[controller]")]
public class StudentController : ControllerBase
    {
        private readonly WebDbContext _context;

        public StudentController(WebDbContext context)
        {
            _context = context;
        }

        [HttpGet("UserReport")]
        [ProducesResponseType(typeof(UserReportResponseDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<ActionResult<UserReportResponseDto>> GetUserReport([FromQuery] string? period = "week", [FromQuery] string? startDate = null, [FromQuery] string? endDate = null)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                // Kiểm tra quyền student
                var user = await _context.Users.FirstOrDefaultAsync(u => u.UserId == userId);
                if (user == null || (user.Role != "STUDENT" && user.Role != "SPSO"))
                    return Forbid();

                DateTime start;
                DateTime end;
                var now = DbTime.Today();
                bool isCustomDateRange = !string.IsNullOrWhiteSpace(startDate) && !string.IsNullOrWhiteSpace(endDate);

                // Xử lý custom date range
                if (isCustomDateRange && DateTime.TryParse(startDate, out var parsedStart) && DateTime.TryParse(endDate, out var parsedEnd))
                {
                    start = DbTime.ToUnspecified(parsedStart.Date);
                    end = DbTime.ToUnspecified(parsedEnd.Date);
                    period = "custom";
                }
                else
                {
                    // Xử lý các period định sẵn
                    period = period ?? "week";
                    switch (period.ToLower())
                    {
                        case "week":
                            end = now;
                            start = DbTime.ToUnspecified(end.AddDays(-6));
                            break;
                        case "month":
                            end = now;
                            start = DbTime.ToUnspecified(end.AddDays(-29));
                            break;
                        case "quarter":
                            end = now;
                            start = end.AddMonths(-11);
                            start = DbTime.ToUnspecified(new DateTime(start.Year, start.Month, 1));
                            break;
                        case "year":
                            end = now;
                            start = DbTime.ToUnspecified(new DateTime(end.Year - 4, 1, 1));
                            break;
                        default:
                            end = now;
                            start = DbTime.ToUnspecified(end.AddDays(-6));
                            period = "week";
                            break;
                    }
                }

                // Lấy dữ liệu purchase_transactions cho khoảng thời gian
                var purchasesInRange = await _context.PurchaseTransactions
                    .Where(pt => pt.UserId == userId &&
                                 pt.Status == "SUCCESS" &&
                                 pt.CreatedAt >= start &&
                                 pt.CreatedAt <= end.AddDays(1))
                    .ToListAsync();

                List<UserReportByPeriodDto> reportsByPeriod;

                if (period.ToLower() == "quarter")
                {
                    // Group theo quý (4 quý gần nhất)
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.UserId == userId &&
                                   j.Status == "DONE" &&
                                   j.CreatedOn.HasValue &&
                                   j.CreatedOn.Value >= start &&
                                   j.CreatedOn.Value <= end.AddDays(1))
                        .Include(j => j.PaperSize)
                        .ToListAsync();

                    var reportsByQuarter = printJobsInRange
                        .GroupBy(j => new {
                            Year = j.CreatedOn!.Value.Year,
                            Quarter = (j.CreatedOn!.Value.Month - 1) / 3 + 1
                        })
                        .Select(g => new
                        {
                            Year = g.Key.Year,
                            Quarter = g.Key.Quarter,
                            PagesUsed = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                            MoneySpent = g.Sum(j =>
                                (j.PaperSize?.Price ?? 0) * (j.TotalPages ?? 0) * (j.Copies ?? 1)
                            ),
                            DocumentsPrinted = g.Where(j => j.DocumentId.HasValue).Select(j => j.DocumentId!.Value).Distinct().Count()
                        })
                        .ToList();

                    // Tính tổng tiền từ purchase_transactions theo quý
                    var purchasesByQuarter = purchasesInRange
                        .GroupBy(pt => new {
                            Year = pt.CreatedAt.Year,
                            Quarter = (pt.CreatedAt.Month - 1) / 3 + 1
                        })
                        .Select(g => new
                        {
                            Year = g.Key.Year,
                            Quarter = g.Key.Quarter,
                            MoneySpentOnPages = g.Where(pt => pt.TransactionType == "PAGE_PURCHASE").Sum(pt => pt.TotalAmount),
                            MoneySpentOnStorage = g.Where(pt => pt.TransactionType == "STORAGE_PURCHASE").Sum(pt => pt.TotalAmount),
                            PagesPurchased = g.Where(pt => pt.TransactionType == "PAGE_PURCHASE").Sum(pt => pt.Quantity),
                            StoragePurchased = g.Where(pt => pt.TransactionType == "STORAGE_PURCHASE").Sum(pt => pt.Quantity)
                        })
                        .ToList();

                    reportsByPeriod = new List<UserReportByPeriodDto>();
                    var currentDate = now;
                    for (int i = 0; i < 4; i++)
                    {
                        var quarterDate = currentDate.AddMonths(-3 * i);
                        var year = quarterDate.Year;
                        var quarter = (quarterDate.Month - 1) / 3 + 1;

                        var report = reportsByQuarter.FirstOrDefault(r => r.Year == year && r.Quarter == quarter);
                        var purchaseReport = purchasesByQuarter.FirstOrDefault(p => p.Year == year && p.Quarter == quarter);
                        var quarterStartDate = new DateTime(year, (quarter - 1) * 3 + 1, 1);

                        reportsByPeriod.Insert(0, new UserReportByPeriodDto
                        {
                            PeriodLabel = $"Q{quarter}/{year}",
                            Date = quarterStartDate.ToString("yyyy-MM-dd"),
                            PagesUsed = report?.PagesUsed ?? 0,
                            MoneySpent = report?.MoneySpent ?? 0,
                            DocumentsPrinted = report?.DocumentsPrinted ?? 0,
                            MoneySpentOnPages = purchaseReport?.MoneySpentOnPages ?? 0,
                            MoneySpentOnStorage = purchaseReport?.MoneySpentOnStorage ?? 0,
                            PagesPurchased = purchaseReport?.PagesPurchased ?? 0,
                            StoragePurchased = purchaseReport?.StoragePurchased ?? 0
                        });
                    }
                }
                else if (period.ToLower() == "year")
                {
                    // Group theo năm (5 năm gần nhất)
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.UserId == userId &&
                                   j.Status == "DONE" &&
                                   j.CreatedOn.HasValue &&
                                   j.CreatedOn.Value >= start &&
                                   j.CreatedOn.Value <= end.AddDays(1))
                        .Include(j => j.PaperSize)
                        .ToListAsync();

                    var reportsByYear = printJobsInRange
                        .GroupBy(j => j.CreatedOn!.Value.Year)
                        .Select(g => new
                        {
                            Year = g.Key,
                            PagesUsed = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                            MoneySpent = g.Sum(j =>
                                (j.PaperSize?.Price ?? 0) * (j.TotalPages ?? 0) * (j.Copies ?? 1)
                            ),
                            DocumentsPrinted = g.Where(j => j.DocumentId.HasValue).Select(j => j.DocumentId!.Value).Distinct().Count()
                        })
                        .ToList();

                    // Tính tổng tiền từ purchase_transactions theo năm
                    var purchasesByYear = purchasesInRange
                        .GroupBy(pt => pt.CreatedAt.Year)
                        .Select(g => new
                        {
                            Year = g.Key,
                            MoneySpentOnPages = g.Where(pt => pt.TransactionType == "PAGE_PURCHASE").Sum(pt => pt.TotalAmount),
                            MoneySpentOnStorage = g.Where(pt => pt.TransactionType == "STORAGE_PURCHASE").Sum(pt => pt.TotalAmount),
                            PagesPurchased = g.Where(pt => pt.TransactionType == "PAGE_PURCHASE").Sum(pt => pt.Quantity),
                            StoragePurchased = g.Where(pt => pt.TransactionType == "STORAGE_PURCHASE").Sum(pt => pt.Quantity)
                        })
                        .ToList();

                    reportsByPeriod = new List<UserReportByPeriodDto>();
                    var currentYear = now.Year;
                    for (int i = 0; i < 5; i++)
                    {
                        var year = currentYear - i;
                        var report = reportsByYear.FirstOrDefault(r => r.Year == year);
                        var purchaseReport = purchasesByYear.FirstOrDefault(p => p.Year == year);

                        reportsByPeriod.Insert(0, new UserReportByPeriodDto
                        {
                            PeriodLabel = year.ToString(),
                            Date = DbTime.ToUnspecified(new DateTime(year, 1, 1)).ToString("yyyy-MM-dd"),
                            PagesUsed = report?.PagesUsed ?? 0,
                            MoneySpent = report?.MoneySpent ?? 0,
                            DocumentsPrinted = report?.DocumentsPrinted ?? 0,
                            MoneySpentOnPages = purchaseReport?.MoneySpentOnPages ?? 0,
                            MoneySpentOnStorage = purchaseReport?.MoneySpentOnStorage ?? 0,
                            PagesPurchased = purchaseReport?.PagesPurchased ?? 0,
                            StoragePurchased = purchaseReport?.StoragePurchased ?? 0
                        });
                    }
                }
                else
                {
                    // Group theo ngày
                    var printJobsInRange = await _context.PrintJobs
                        .Where(j => j.UserId == userId &&
                                   j.Status == "DONE" &&
                                   j.CreatedOn.HasValue &&
                                   j.CreatedOn.Value >= start &&
                                   j.CreatedOn.Value <= end.AddDays(1))
                        .Include(j => j.PaperSize)
                        .ToListAsync();

                    var reportsByDate = printJobsInRange
                        .GroupBy(j => j.CreatedOn!.Value.Date)
                        .Select(g => new
                        {
                            Date = g.Key,
                            PagesUsed = g.Sum(j => (j.TotalPages ?? 0) * (j.Copies ?? 1)),
                            MoneySpent = g.Sum(j =>
                                (j.PaperSize?.Price ?? 0) * (j.TotalPages ?? 0) * (j.Copies ?? 1)
                            ),
                            DocumentsPrinted = g.Where(j => j.DocumentId.HasValue).Select(j => j.DocumentId!.Value).Distinct().Count()
                        })
                        .ToList();

                    // Tính tổng tiền từ purchase_transactions theo ngày
                    var purchasesByDate = purchasesInRange
                        .GroupBy(pt => pt.CreatedAt.Date)
                        .Select(g => new
                        {
                            Date = g.Key,
                            MoneySpentOnPages = g.Where(pt => pt.TransactionType == "PAGE_PURCHASE").Sum(pt => pt.TotalAmount),
                            MoneySpentOnStorage = g.Where(pt => pt.TransactionType == "STORAGE_PURCHASE").Sum(pt => pt.TotalAmount),
                            PagesPurchased = g.Where(pt => pt.TransactionType == "PAGE_PURCHASE").Sum(pt => pt.Quantity),
                            StoragePurchased = g.Where(pt => pt.TransactionType == "STORAGE_PURCHASE").Sum(pt => pt.Quantity)
                        })
                        .ToList();

                    reportsByPeriod = new List<UserReportByPeriodDto>();

                    var dayLabels = new Dictionary<DayOfWeek, string>
                    {
                        { DayOfWeek.Monday, "T2" },
                        { DayOfWeek.Tuesday, "T3" },
                        { DayOfWeek.Wednesday, "T4" },
                        { DayOfWeek.Thursday, "T5" },
                        { DayOfWeek.Friday, "T6" },
                        { DayOfWeek.Saturday, "T7" },
                        { DayOfWeek.Sunday, "CN" }
                    };

                    for (var date = start; date <= end; date = date.AddDays(1))
                    {
                        var dateOnly = date.Date;
                        var report = reportsByDate.FirstOrDefault(r => r.Date == dateOnly);
                        var purchaseReport = purchasesByDate.FirstOrDefault(p => p.Date == dateOnly);
                        var dayLabel = dayLabels.ContainsKey(date.DayOfWeek) ? dayLabels[date.DayOfWeek] : date.DayOfWeek.ToString();

                        reportsByPeriod.Add(new UserReportByPeriodDto
                        {
                            PeriodLabel = dayLabel,
                            Date = date.ToString("yyyy-MM-dd"),
                            PagesUsed = report?.PagesUsed ?? 0,
                            MoneySpent = report?.MoneySpent ?? 0,
                            DocumentsPrinted = report?.DocumentsPrinted ?? 0,
                            MoneySpentOnPages = purchaseReport?.MoneySpentOnPages ?? 0,
                            MoneySpentOnStorage = purchaseReport?.MoneySpentOnStorage ?? 0,
                            PagesPurchased = purchaseReport?.PagesPurchased ?? 0,
                            StoragePurchased = purchaseReport?.StoragePurchased ?? 0
                        });
                    }
                }

                var highestPagesUsed = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.PagesUsed) : 0;
                var highestMoneySpent = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.MoneySpent) : 0;
                var highestDocumentsPrinted = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.DocumentsPrinted) : 0;
                var highestMoneySpentOnPages = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.MoneySpentOnPages) : 0;
                var highestMoneySpentOnStorage = reportsByPeriod.Any() ? reportsByPeriod.Max(r => r.MoneySpentOnStorage) : 0;

                var totalMoneySpentOnPages = reportsByPeriod.Sum(r => r.MoneySpentOnPages);
                var totalMoneySpentOnStorage = reportsByPeriod.Sum(r => r.MoneySpentOnStorage);
                var totalPagesPurchased = reportsByPeriod.Sum(r => r.PagesPurchased);
                var totalStoragePurchased = reportsByPeriod.Sum(r => r.StoragePurchased);

                var response = new UserReportResponseDto
                {
                    ReportsByPeriod = reportsByPeriod,
                    HighestPagesUsed = highestPagesUsed,
                    HighestMoneySpent = highestMoneySpent,
                    HighestDocumentsPrinted = highestDocumentsPrinted,
                    HighestMoneySpentOnPages = highestMoneySpentOnPages,
                    HighestMoneySpentOnStorage = highestMoneySpentOnStorage,
                    Period = period.ToLower(),
                    TotalMoneySpentOnPages = totalMoneySpentOnPages,
                    TotalMoneySpentOnStorage = totalMoneySpentOnStorage,
                    TotalPagesPurchased = totalPagesPurchased,
                    TotalStoragePurchased = totalStoragePurchased
                };

                return Ok(new { success = true, data = response });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in GetUserReport: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy báo cáo sử dụng.", error = ex.Message });
            }
        }
    }
}
