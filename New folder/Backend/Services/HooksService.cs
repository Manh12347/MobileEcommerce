using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using PTVBTPM.Models.Entities;
using PTVBTPM.Models.Configurations;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Hubs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Text.RegularExpressions;
using System.Text.Json;

namespace PTVBTPM.Services
{
    public class HooksService : IHooksService
    {
        private readonly WebDbContext _context;
        private readonly HooksConfig _hooksConfig;
        private readonly IMemoryCache _cache;
        private readonly IHubContext<PaymentHub> _hubContext;
        private readonly IEmailService _emailService;
        private readonly ILogger<HooksService> _logger;

        public HooksService(
            WebDbContext context, 
            IOptions<HooksConfig> hooksConfig, 
            IMemoryCache cache,
            IHubContext<PaymentHub> hubContext,
            IEmailService emailService,
            ILogger<HooksService> logger)
        {
            _context = context;
            _hooksConfig = hooksConfig.Value;
            _cache = cache;
            _hubContext = hubContext;
            _emailService = emailService;
            _logger = logger;
        }

        public async Task AddTransactionAsync(BankTransaction transaction)
        {
            if (transaction == null)
                throw new ArgumentNullException(nameof(transaction));
            await _context.BankTransactions.AddAsync(transaction);
            await _context.SaveChangesAsync();
        }

        public async Task<List<User>> GetAllUsersAsync()
        {
            return await _context.Users.ToListAsync();
        }

        public async Task<User?> GetUserByIdAsync(int id)
        {
            return await _context.Users.FindAsync(id);
        }

        public async Task<User> CreateUserAsync(User user)
        {
            // Ensure defaults & correct DateTime kind for PostgreSQL "timestamp without time zone"
            user.Status = string.IsNullOrWhiteSpace(user.Status) ? "ACTIVE" : user.Status;
            if (user.CreatedOn.HasValue)
                user.CreatedOn = DateTime.SpecifyKind(user.CreatedOn.Value, DateTimeKind.Unspecified);
            else
                user.CreatedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

            if (user.ModifiedOn.HasValue)
                user.ModifiedOn = DateTime.SpecifyKind(user.ModifiedOn.Value, DateTimeKind.Unspecified);

            _context.Users.Add(user);
            await _context.SaveChangesAsync();
            return user;
        }

        public async Task<User?> UpdateUserAsync(int id, User user)
        {
            var existing = await _context.Users.FindAsync(id);
            if (existing == null) return null;
            existing.FullName = user.FullName;
            existing.Email = user.Email;
            existing.StudentCode = user.StudentCode;
            if (!string.IsNullOrWhiteSpace(user.PasswordHash))
                existing.PasswordHash = user.PasswordHash;
            // Only update role if a non-empty value is provided to avoid violating DB role check constraint
            if (!string.IsNullOrWhiteSpace(user.Role))
            {
                existing.Role = user.Role;
            }
            existing.Status = string.IsNullOrWhiteSpace(user.Status) ? existing.Status : user.Status;
            // Update avatar if provided
            if (!string.IsNullOrWhiteSpace(user.AvatarUrl))
            {
                existing.AvatarUrl = user.AvatarUrl;
            }

            if (user.ModifiedOn.HasValue)
                existing.ModifiedOn = DateTime.SpecifyKind(user.ModifiedOn.Value, DateTimeKind.Unspecified);

            await _context.SaveChangesAsync();
            return existing;
        }

        public async Task<bool> DeleteUserAsync(int id)
        {
            // Deprecated: instead of deleting user from DB, mark as INACTIVE (vô hiệu hóa)
            var user = await _context.Users.FindAsync(id);
            if (user == null) return false;
            user.Status = "INACTIVE";
            user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<TransactionProcessResult> ProcessTransactionAsync(BankTransaction transaction)
        {
            if (transaction == null)
                throw new ArgumentNullException(nameof(transaction));

            var result = new TransactionProcessResult();

            // 1. Kiểm tra xem transaction đã tồn tại chưa (tránh duplicate)
            var existingTransaction = await _context.BankTransactions
                .FirstOrDefaultAsync(t => t.Referencecode == transaction.Referencecode 
                    && t.Transactiondate == transaction.Transactiondate 
                    && t.Transferamount == transaction.Transferamount);

            if (existingTransaction != null)
            {
                result.Message = $"Transaction {transaction.Referencecode} already processed";
                return result;
            }

            // 2. Lưu biến động số dư vào database (DB đã đổi sang timestamptz → lưu UTC)
            transaction.CreatedOn = DateTime.UtcNow;
            await _context.BankTransactions.AddAsync(transaction);
            await _context.SaveChangesAsync();

            result.Message = $"Balance change saved: {transaction.Referencecode} - {transaction.Transferamount} - {transaction.Description}";

            // 3. Đối chiếu Description với gencode trong cache
            string? gencode = ExtractGencodeFromTransaction(transaction);
            
            Console.WriteLine($"[HooksService] ===== PROCESSING TRANSACTION =====");
            Console.WriteLine($"[HooksService] Transaction Code: {transaction.Code}");
            Console.WriteLine($"[HooksService] Amount: {transaction.Transferamount}");
            Console.WriteLine($"[HooksService] Description: '{transaction.Description}'");
            Console.WriteLine($"[HooksService] Content: '{transaction.Content}'");
            Console.WriteLine($"[HooksService] Extracted gencode: {gencode ?? "NULL - GENCODE NOT FOUND"}");

            if (string.IsNullOrWhiteSpace(gencode))
            {
                Console.WriteLine($"[HooksService] ❌ CRITICAL: No gencode found in transaction description/content");
                Console.WriteLine($"[HooksService] Description length: {transaction.Description?.Length ?? 0}");
                Console.WriteLine($"[HooksService] Content length: {transaction.Content?.Length ?? 0}");
                return result;
            }
            
            if (string.IsNullOrWhiteSpace(gencode))
            {
                result.Message += ". No gencode found in transaction description/content";
                return result;
            }

            // 4. Tìm thông tin đơn hàng từ cache bằng gencode
            var cacheKey = $"gencode_{gencode}";
            Console.WriteLine($"[HooksService] Looking for cache key: {cacheKey}");
            
            if (!_cache.TryGetValue(cacheKey, out OrderCacheInfo? cacheInfo) || cacheInfo == null)
            {
                Console.WriteLine($"[HooksService] Gencode {gencode} not found in cache");
                result.Message += $". Gencode {gencode} not found in cache (may be expired or invalid)";
                return result;
            }
            
            Console.WriteLine($"[HooksService] ✅ Found cache info for orderId: {cacheInfo.OrderId}");
            Console.WriteLine($"[HooksService] Cache details: UserId={cacheInfo.UserId}, PaymentType={cacheInfo.PaymentType}, TotalAmount={cacheInfo.TotalAmount}, Gencode={cacheInfo.Gencode}");

            // 5. Kiểm tra số tiền có khớp không (với tolerance)
            var amountDifference = Math.Abs(cacheInfo.TotalAmount - transaction.Transferamount);
            Console.WriteLine($"[HooksService] Amount check: Order={cacheInfo.TotalAmount}, Transaction={transaction.Transferamount}, Difference={amountDifference}, Tolerance={_hooksConfig.AmountTolerance}");

            if (amountDifference > _hooksConfig.AmountTolerance)
            {
                Console.WriteLine($"[HooksService] ❌ Amount mismatch - REJECTED");
                result.Message += $". Amount mismatch: Order amount {cacheInfo.TotalAmount} vs Transaction amount {transaction.Transferamount}";
                result.OrderId = cacheInfo.OrderId;
                return result;
            }

            Console.WriteLine($"[HooksService] ✅ Amount matched within tolerance");

            // 6. Đảm bảo PurchaseTransaction tồn tại cho tất cả loại thanh toán
            await EnsurePurchaseTransactionExistsAsync(cacheInfo);

            // 7. Xử lý theo loại thanh toán
            if (cacheInfo.PaymentType == "PURCHASE_PAGES" && cacheInfo.UserId.HasValue && cacheInfo.Pages.HasValue)
            {
                // Xử lý mua thêm giấy: cập nhật PagePurchasedBalance cho user
                var user = await _context.Users.FindAsync(cacheInfo.UserId.Value);
                if (user != null)
                {
                    user.PagePurchasedBalance += cacheInfo.Pages.Value;
                    user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                    await _context.SaveChangesAsync();

                    Console.WriteLine($"[HooksService] ✅ BALANCE UPDATED: User {cacheInfo.UserId.Value} +{cacheInfo.Pages.Value} pages, new balance: {user.PagePurchasedBalance}");
                    _logger.LogInformation($"[HooksService] ✅ Updated PagePurchasedBalance for UserId {cacheInfo.UserId.Value}: +{cacheInfo.Pages.Value} pages (new balance: {user.PagePurchasedBalance})");
                    result.Message += $". User {cacheInfo.UserId.Value} purchased {cacheInfo.Pages.Value} pages. New PagePurchasedBalance: {user.PagePurchasedBalance}";
                }
                else
                {
                    _logger.LogWarning($"[HooksService] ⚠️  User {cacheInfo.UserId.Value} not found when processing purchase pages");
                    result.Message += $". User {cacheInfo.UserId.Value} not found";
                }
            }
            else if (cacheInfo.PaymentType == "PURCHASE_STORAGE" && cacheInfo.UserId.HasValue && cacheInfo.StorageMb.HasValue)
            {
                // Xử lý mua thêm dung lượng lưu trữ: cập nhật StoragePurchasedBalance cho user
                var user = await _context.Users.FindAsync(cacheInfo.UserId.Value);
                if (user != null)
                {
                    user.StoragePurchasedBalance += (long)cacheInfo.StorageMb.Value;
                    user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                    await _context.SaveChangesAsync();

                    Console.WriteLine($"[HooksService] ✅ STORAGE BALANCE UPDATED: User {cacheInfo.UserId.Value} +{cacheInfo.StorageMb.Value} MB, new balance: {user.StoragePurchasedBalance} MB");
                    _logger.LogInformation($"[HooksService] ✅ Updated StoragePurchasedBalance for UserId {cacheInfo.UserId.Value}: +{cacheInfo.StorageMb.Value} MB (new balance: {user.StoragePurchasedBalance} MB)");
                    result.Message += $". User {cacheInfo.UserId.Value} purchased {cacheInfo.StorageMb.Value} MB storage. New StoragePurchasedBalance: {user.StoragePurchasedBalance} MB";
                }
                else
                {
                    _logger.LogWarning($"[HooksService] ⚠️  User {cacheInfo.UserId.Value} not found when processing purchase storage");
                    result.Message += $". User {cacheInfo.UserId.Value} not found";
                }
            }
            else if (cacheInfo.PaymentType == "ORDER" && cacheInfo.UserId.HasValue)
            {
                // Xử lý đơn hàng thương mại
                _logger.LogInformation($"[HooksService] ✅ Order payment completed for UserId {cacheInfo.UserId.Value}, OrderId: {cacheInfo.OrderId}, Amount: {cacheInfo.TotalAmount}");
                result.Message += $". Order payment successful for user {cacheInfo.UserId.Value}. OrderId: {cacheInfo.OrderId}, Amount: {cacheInfo.TotalAmount}";
            }

            // 8. Xóa gencode khỏi cache sau khi xử lý thành công
            _cache.Remove(cacheKey);

            result.Message += $". Payment successful! Order {cacheInfo.OrderId} processed";
            result.OrderUpdated = true;
            result.OrderId = cacheInfo.OrderId;

            // 8. Gửi SignalR notification đến client đang chờ thanh toán
            try
            {
                var groupName = $"payment_{gencode}";
                string message;
                if (cacheInfo.PaymentType == "ORDER")
                {
                    message = "Thanh toán thành công. Tài liệu của bạn đang được in";
                }
                else if (cacheInfo.PaymentType == "PAGES" && cacheInfo.Pages.HasValue)
                {
                    message = "Thanh toán thành công. Giấy đã được cộng vào tài khoản của bạn.";
                }
                else if (cacheInfo.PaymentType == "STORE" && cacheInfo.StorageMb.HasValue)
                {
                    message = "Thanh toán thành công. Dung lượng lưu trữ của bạn đã được tăng lên.";
                }
                else
                {
                    message = "Thanh toán thành công";
                }

                var notificationData = new
                {
                    orderId = cacheInfo.OrderId,
                    gencode = gencode,
                    amount = transaction.Transferamount,
                    paymentType = cacheInfo.PaymentType,
                    pages = cacheInfo.Pages,
                    message = message,
                    timestamp = DateTime.UtcNow
                };
                Console.WriteLine($"[HooksService] ===== SENDING SIGNALR NOTIFICATION ===== ");
                Console.WriteLine($"[HooksService] Group name: {groupName}");
                Console.WriteLine($"[HooksService] OrderId: {cacheInfo.OrderId}");
                Console.WriteLine($"[HooksService] Gencode: {gencode}");
                Console.WriteLine($"[HooksService] PaymentType: {cacheInfo.PaymentType}");
                Console.WriteLine($"[HooksService] Message: {message}");
                Console.WriteLine($"[SignalR] Amount: {transaction.Transferamount}");
                Console.WriteLine($"[SignalR] Notification data: {System.Text.Json.JsonSerializer.Serialize(notificationData)}");
                
                // Send notification to all clients in the group
                await _hubContext.Clients.Group(groupName).SendAsync("PaymentSuccess", notificationData);
                
                Console.WriteLine($"[SignalR] ✅ Payment notification sent successfully to group: {groupName}");
                Console.WriteLine($"[SignalR] Note: If no clients are in the group, the message is silently ignored");
            }
            catch (Exception ex)
            {
                // Log error nhưng không fail toàn bộ process
                Console.WriteLine($"[SignalR] ❌ Error sending payment notification: {ex.Message}");
                Console.WriteLine($"[SignalR] Exception type: {ex.GetType().Name}");
                Console.WriteLine($"[SignalR] StackTrace: {ex.StackTrace}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"[SignalR] Inner exception: {ex.InnerException.Message}");
                }
            }

            return result;
        }

        // Return pages balances for given user ids
        public async Task<List<PTVBTPM.Models.DTOs.PagesBalanceDto>> GetPagesBalancesAsync(List<int> userIds)
        {
            if (userIds == null || userIds.Count == 0) return new List<PTVBTPM.Models.DTOs.PagesBalanceDto>();
            var list = await _context.Users
                .Where(u => userIds.Contains(u.UserId))
                .Select(u => new PTVBTPM.Models.DTOs.PagesBalanceDto
                {
                    UserId = u.UserId,
                    DefaultBalance = u.PageDefaultBalance,
                    PurchaseBalance = u.PagePurchasedBalance,
                    Total = u.PageDefaultBalance + u.PagePurchasedBalance
                })
                .ToListAsync();
            return list;
        }

        // Return last activity (latest login) formatted relative string per user id
        public async Task<List<PTVBTPM.Models.DTOs.UserLastActivityDto>> GetLastActivityAsync(List<int> userIds)
        {
            var result = new List<PTVBTPM.Models.DTOs.UserLastActivityDto>();
            if (userIds == null || userIds.Count == 0) return result;

            var query = await _context.LoginHistories
                .Where(l => l.UserId.HasValue && userIds.Contains(l.UserId.Value))
                .GroupBy(l => l.UserId)
                .Select(g => new
                {
                    UserId = g.Key,
                    LastLogin = g.Max(x => x.LoginTime)
                })
                .ToListAsync();

            foreach (var item in query)
            {
                var dto = new PTVBTPM.Models.DTOs.UserLastActivityDto
                {
                    UserId = item.UserId!.Value,
                    LastLogin = item.LastLogin,
                    LastActive = item.LastLogin.HasValue ? FormatRelativeTime(item.LastLogin.Value) : null
                };
                result.Add(dto);
            }

            return result;
        }

        public async Task AddLoginHistoryAsync(LoginHistory history)
        {
            if (history == null) throw new ArgumentNullException(nameof(history));
            // Normalize timestamps
            if (history.LoginTime.HasValue)
                history.LoginTime = DateTime.SpecifyKind(history.LoginTime.Value, DateTimeKind.Unspecified);
            history.CreatedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
            _context.LoginHistories.Add(history);
            await _context.SaveChangesAsync();
        }

        private string FormatRelativeTime(DateTime dt)
        {
            // Treat stored times as UTC (some DB timestamps are saved as unspecified).
            // Force the DateTime to be UTC then compare with UtcNow.
            var utcDt = DateTime.SpecifyKind(dt, DateTimeKind.Utc);
            var now = DateTime.UtcNow;
            var ts = now - utcDt;
            // If activity within a few seconds - show "Vừa xong"
            if (ts.TotalSeconds < 5) return "Vừa xong";
            // If within heartbeat window (15s) show "Hoạt động"
            if (ts.TotalSeconds < 15) return "Hoạt động";
            if (ts.TotalMinutes < 60) return $"{(int)ts.TotalMinutes} phút trước";
            if (ts.TotalHours < 24) return $"{(int)ts.TotalHours} giờ trước";
            if (ts.TotalDays < 30) return $"{(int)ts.TotalDays} ngày trước";
            // Show local time for older entries
            return utcDt.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
        }

        /// <summary>
        /// Extract gencode từ transaction description hoặc content
        /// </summary>
        private string? ExtractGencodeFromTransaction(BankTransaction transaction)
        {
            string? gencode = null;
            
            // Ưu tiên kiểm tra Content trước
            if (!string.IsNullOrWhiteSpace(transaction.Content))
            {
                gencode = ExtractGencodeFromString(transaction.Content);
                if (gencode != null) return gencode;
            }
            
            // Nếu không tìm thấy trong Content, kiểm tra Description
            if (!string.IsNullOrWhiteSpace(transaction.Description))
            {
                gencode = ExtractGencodeFromString(transaction.Description);
                if (gencode != null) return gencode;
            }

            return null;
        }

        /// <summary>
        /// Extract gencode từ một chuỗi bất kỳ
        /// </summary>
        private string? ExtractGencodeFromString(string input)
        {
            if (string.IsNullOrWhiteSpace(input)) return null;

            // Tìm vị trí của các prefix gencode (ORDER, PAGES, STORE) - case-insensitive
            var prefixes = new[] { "ORDER", "PAGES", "STORE" };
            int? foundIndex = null;
            string? foundPrefix = null;

            foreach (var prefix in prefixes)
            {
                var index = input.IndexOf(prefix, StringComparison.OrdinalIgnoreCase);
                if (index != -1)
                {
                    foundIndex = index;
                    foundPrefix = prefix;
                    break; // Lấy prefix đầu tiên tìm thấy
                }
            }

            if (!foundIndex.HasValue) return null;

            // Lấy từ prefix đến hết chuỗi (hoặc tối đa 20 ký tự nếu bị cắt)
            var remainingLength = input.Length - foundIndex.Value;
            var maxLength = Math.Min(remainingLength, 20); // Gencode mới là 20 ký tự
            var gencodeRaw = input.Substring(foundIndex.Value, maxLength);
            
            Console.WriteLine($"[ExtractGencode] Raw gencode from input: {gencodeRaw} (length: {gencodeRaw.Length}, original length: {input.Length})");

            // Ưu tiên 1: Format mới - prefix + 15 ký tự hex (20 ký tự tổng): ORDERA1B2C3D4E5F6789
            var regexNewFormat = new Regex($"^{foundPrefix}[A-Z0-9]{{15}}$", RegexOptions.IgnoreCase);
            var match = regexNewFormat.Match(gencodeRaw);
            if (match.Success)
            {
                Console.WriteLine($"[ExtractGencode] Found new format gencode: {match.Value}");
                return match.Value.ToUpper();
            }

            // Ưu tiên 2: Format mới nhưng bị cắt (ít hơn 20 ký tự) - lấy tối đa có thể
            // Nếu có đủ 5 ký tự đầu prefix và ít nhất 1 ký tự sau, thử match
            var regexNewFormatPartial = new Regex($"^{foundPrefix}[A-Z0-9]{{1,15}}", RegexOptions.IgnoreCase);
            match = regexNewFormatPartial.Match(gencodeRaw);
            if (match.Success && match.Value.Length >= foundPrefix.Length + 1) // Ít nhất prefix + 1 ký tự
            {
                // Nếu bị cắt, chỉ lấy phần đầy đủ (20 ký tự nếu có, nếu không thì lấy hết)
                var extracted = match.Value.ToUpper();
                Console.WriteLine($"[ExtractGencode] Found partial new format gencode: {extracted} (may be truncated)");
                
                // Nếu đủ 20 ký tự, trả về ngay
                if (extracted.Length == 20)
                {
                    return extracted;
                }
                
                // Nếu không đủ, thử tìm trong cache với gencode này (có thể match partial)
                // Nhưng tốt nhất là chỉ trả về nếu đủ 20 ký tự
                // Tạm thời vẫn trả về để thử match trong cache
                Console.WriteLine($"[ExtractGencode] Warning: Gencode may be truncated (length: {extracted.Length}, expected: 20)");
                return extracted;
            }

            // Ưu tiên 3: Format cũ không underscore: ORDER257202511220004345D77FE6C
            var regexWithoutUnderscore = new Regex($"^{foundPrefix}(\\d{{1,10}})(\\d{{14}})([A-Z0-9]{{8,}})", RegexOptions.IgnoreCase);
            match = regexWithoutUnderscore.Match(gencodeRaw);
            if (match.Success)
            {
                Console.WriteLine($"[ExtractGencode] Found gencode without underscore: {match.Value}");
                return match.Value.ToUpper();
            }

            // Ưu tiên 4: Format có underscore: ORDER_257_20251122000434_5D77FE6C (format cũ, để tương thích)
            var regexWithUnderscore = new Regex($"^{foundPrefix}_\\d+_\\d{{14}}_[A-Z0-9]+", RegexOptions.IgnoreCase);
            match = regexWithUnderscore.Match(gencodeRaw);
            if (match.Success)
            {
                // Convert về format không có underscore để đồng nhất
                var normalizedGencode = match.Value.Replace("_", "").ToUpper();
                Console.WriteLine($"[ExtractGencode] Converted gencode with underscore: {match.Value} → {normalizedGencode}");
                return normalizedGencode;
            }

            Console.WriteLine($"[ExtractGencode] No valid gencode pattern found in: {gencodeRaw}");
            return null;
        }

        /// <summary>
        /// Đảm bảo PurchaseTransaction tồn tại cho tất cả loại thanh toán
        /// </summary>
        private async Task EnsurePurchaseTransactionExistsAsync(OrderCacheInfo cacheInfo)
        {
            if (cacheInfo.UserId == null)
                return;

            // Tìm PurchaseTransaction theo OrderId và UserId
            var existingTransaction = await _context.PurchaseTransactions
                .FirstOrDefaultAsync(pt => pt.Id == cacheInfo.OrderId && pt.UserId == cacheInfo.UserId.Value);

            if (existingTransaction != null)
            {
                // Cập nhật status và thông tin nếu đã tồn tại
                existingTransaction.Status = "SUCCESS";
                existingTransaction.TransactionCode = cacheInfo.Gencode;
                // UpdatedAt sẽ được DB tự động update nếu có trigger

                _logger.LogInformation($"[EnsurePurchaseTransaction] ✅ Updated existing PurchaseTransaction: Type={existingTransaction.TransactionType}, OrderId={cacheInfo.OrderId}");
            }
            else
            {
                // Tạo mới PurchaseTransaction nếu chưa có
                PurchaseTransaction newTransaction;

                switch (cacheInfo.PaymentType)
                {
                    case "PAGES":
                        var pagePrice = 150.0m; // Giá mặc định, có thể lấy từ system config
                        newTransaction = new PurchaseTransaction
                        {
                            UserId = cacheInfo.UserId.Value,
                            TransactionType = "PAGE_PURCHASE",
                            Quantity = cacheInfo.Pages ?? 0,
                            PricePerUnit = pagePrice,
                            TotalAmount = cacheInfo.TotalAmount,
                            TransactionCode = cacheInfo.Gencode,
                            Status = "SUCCESS"
                        };
                        break;

                    case "PURCHASE_STORAGE":
                        var storageMb = cacheInfo.StorageMb ?? 0;
                        var storagePrice = storageMb > 0 ? cacheInfo.TotalAmount / storageMb : 0;
                        newTransaction = new PurchaseTransaction
                        {
                            UserId = cacheInfo.UserId.Value,
                            TransactionType = "STORAGE_PURCHASE",
                            Quantity = (int)storageMb,
                            PricePerUnit = storagePrice,
                            TotalAmount = cacheInfo.TotalAmount,
                            TransactionCode = cacheInfo.Gencode,
                            Status = "SUCCESS"
                        };
                        break;

                    case "ORDER":
                        var itemCount = cacheInfo.Items?.Sum(i => i.Quantity) ?? 1;
                        var avgPricePerItem = itemCount > 0 ? cacheInfo.TotalAmount / itemCount : cacheInfo.TotalAmount;
                        newTransaction = new PurchaseTransaction
                        {
                            UserId = cacheInfo.UserId.Value,
                            TransactionType = "ORDER",
                            Quantity = itemCount,
                            PricePerUnit = avgPricePerItem,
                            TotalAmount = cacheInfo.TotalAmount,
                            TransactionCode = cacheInfo.Gencode,
                            Status = "SUCCESS"
                        };
                        break;

                    default:
                        _logger.LogWarning($"[EnsurePurchaseTransaction] ⚠️  Unknown PaymentType: {cacheInfo.PaymentType}");
                        return; // Không tạo transaction cho loại không xác định
                }

                _context.PurchaseTransactions.Add(newTransaction);
                Console.WriteLine($"[HooksService] ✅ TRANSACTION CREATED: Type={newTransaction.TransactionType}, UserId={newTransaction.UserId}, Quantity={newTransaction.Quantity}, Amount={newTransaction.TotalAmount}");
                _logger.LogInformation($"[EnsurePurchaseTransaction] ✅ Created new PurchaseTransaction: Type={newTransaction.TransactionType}, OrderId={cacheInfo.OrderId}");
            }

            await _context.SaveChangesAsync();
        }
    }
}

