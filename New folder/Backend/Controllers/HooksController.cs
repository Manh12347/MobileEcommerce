using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.SignalR;
using PTVBTPM.Services;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using PTVBTPM.Models.Configurations;
using PTVBTPM.Hubs;
using System;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Text.Json;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class HooksController : Controller
    {
        private readonly IHooksService _hooksService;
        private readonly HooksConfig _hooksConfig;
        private readonly IHubContext<PaymentHub> _hubContext;
        private readonly WebDbContext _context;

        public HooksController(
            IHooksService hooksService,
            IOptions<HooksConfig> hooksConfig,
            IHubContext<PaymentHub> hubContext,
            WebDbContext context)
        {
            _hooksService = hooksService;
            _hooksConfig = hooksConfig.Value;
            _hubContext = hubContext;
            _context = context;
        }

        [HttpPost("transaction")]
        public async Task<IActionResult> ReceiveTransaction([FromBody] BankTransactionDto? dto)
        {
            // ✅ NEVER return 500 - Always return 200 OK or 400 BadRequest for webhook
            // SePay sẽ retry nếu nhận 500, gây duplicate transactions
            
            try
            {
                // Log raw request for debugging
                Console.WriteLine($"[HooksController] ===== WEBHOOK RECEIVED =====");
                Console.WriteLine($"[HooksController] Timestamp: {DateTime.UtcNow}");
                Console.WriteLine($"[HooksController] Request body: {JsonSerializer.Serialize(dto, new JsonSerializerOptions { WriteIndented = true })}");
                Console.WriteLine($"[HooksController] Code: {dto.Code}, Amount: {dto.Transferamount}, Description: '{dto.Description}', Content: '{dto.Content}'");
                
                // 1️⃣ Validate DTO is not null
                if (dto == null)
                {
                    Console.WriteLine("[HooksController] ❌ DTO is null");
                    return Ok(new { message = "Invalid request: DTO is null", processed = false });
                }

                // 2️⃣ Kiểm tra API key trong header
                if (!Request.Headers.TryGetValue("Authorization", out var authHeader))
                {
                    Console.WriteLine("[HooksController] ❌ Authorization header missing");
                    return Ok(new { message = "Authorization header missing", processed = false });
                }

                const string prefix = "Apikey ";
                var authHeaderValue = authHeader.ToString();
                if (!authHeaderValue.StartsWith(prefix))
                {
                    Console.WriteLine($"[HooksController] ❌ Invalid Authorization format: {authHeaderValue.Substring(0, Math.Min(20, authHeaderValue.Length))}...");
                    return Ok(new { message = "Invalid Authorization format", processed = false });
                }

                var incomingApiKey = authHeaderValue.Substring(prefix.Length).Trim();

                if (!string.Equals(incomingApiKey, _hooksConfig.ApiKey, StringComparison.Ordinal))
                {
                    Console.WriteLine($"[HooksController] ❌ Invalid API key (received: {incomingApiKey.Substring(0, Math.Min(5, incomingApiKey.Length))}...)");
                    return Ok(new { message = "Invalid API key", processed = false });
                }

                Console.WriteLine("[HooksController] ✅ API key validated");

                // 3️⃣ Null-safe DateTime parsing
                DateTime transactionDate = DateTime.UtcNow; // Default value
                
                if (string.IsNullOrWhiteSpace(dto.Transactiondate))
                {
                    Console.WriteLine("[HooksController] ⚠️  Transactiondate is null or empty, using UTC now");
                }
                else
                {
                    // Try multiple date formats
                    var dateFormats = new[] { "yyyy-MM-dd HH:mm:ss", "yyyy-MM-ddTHH:mm:ss", "yyyy/MM/dd HH:mm:ss" };
                    bool parsed = false;
                    
                    foreach (var format in dateFormats)
                    {
                        if (DateTime.TryParseExact(dto.Transactiondate, format, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsedDate))
                        {
                            transactionDate = parsedDate;
                            parsed = true;
                            Console.WriteLine($"[HooksController] ✅ Parsed Transactiondate: {transactionDate} (format: {format})");
                            break;
                        }
                    }
                    
                    if (!parsed)
                    {
                        // Try generic parse as fallback
                        if (DateTime.TryParse(dto.Transactiondate, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsedDate))
                        {
                            transactionDate = parsedDate;
                            Console.WriteLine($"[HooksController] ⚠️  Parsed Transactiondate using generic parse: {transactionDate}");
                        }
                        else
                        {
                            Console.WriteLine($"[HooksController] ⚠️  Failed to parse Transactiondate: {dto.Transactiondate}, using UTC now");
                        }
                    }
                }

                // 4️⃣ Null-safe entity mapping
                // DB cột đã đổi sang timestamptz → lưu UTC
                transactionDate = DateTime.SpecifyKind(transactionDate, DateTimeKind.Utc);

                var entity = new BankTransaction
                {
                    Gateway = dto.Gateway ?? "Sepay",
                    Transactiondate = transactionDate,
                    Accountnumber = dto.Accountnumber ?? string.Empty,
                    Code = dto.Code,
                    Content = dto.Content ?? string.Empty,
                    Transfertype = dto.Transfertype ?? string.Empty,
                    Transferamount = dto.Transferamount,
                    Accumulated = dto.Accumulated,
                    Subaccount = dto.Subaccount,
                    Referencecode = dto.Referencecode ?? string.Empty,
                    Description = dto.Description ?? string.Empty
                };

                Console.WriteLine($"[HooksController] ✅ Mapped entity: Referencecode={entity.Referencecode}, Amount={entity.Transferamount}, Date={entity.Transactiondate}");

                // 5️⃣ Process transaction
                var result = await _hooksService.ProcessTransactionAsync(entity);
                
                Console.WriteLine($"[HooksController] ✅ Process result: Message={result.Message}, OrderUpdated={result.OrderUpdated}, OrderId={result.OrderId}");

                // 6️⃣ Always return 200 OK (never 500)
                return Ok(new
                {
                    success = true,
                    message = result.Message,
                    orderUpdated = result.OrderUpdated,
                    orderId = result.OrderId,
                    processed = true
                });
            }
            catch (Exception ex)
            {
                // ✅ NEVER return 500 - Log error and return 200 OK
                Console.WriteLine($"[HooksController] ❌ EXCEPTION: {ex.GetType().Name}: {ex.Message}");
                Console.WriteLine($"[HooksController] StackTrace: {ex.StackTrace}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"[HooksController] InnerException: {ex.InnerException.Message}");
                }
                
                // Return 200 OK to prevent SePay from retrying
                return Ok(new
                {
                    success = false,
                    message = $"Error processing webhook: {ex.Message}",
                    processed = false,
                    error = ex.GetType().Name
                });
            }
        }

        /// <summary>
        /// Debug: Kiểm tra cache và transactions
        /// </summary>
        [HttpGet("debug")]
        [ProducesResponseType(typeof(object), 200)]
        public async Task<IActionResult> DebugPaymentStatus([FromQuery] string? gencode = null, [FromQuery] int? orderId = null)
        {
            var debugInfo = new
            {
                timestamp = DateTime.UtcNow,
                cache = new List<object>(),
                transactions = new List<object>(),
                users = new List<object>()
            };

            // Check cache if gencode provided
            if (!string.IsNullOrWhiteSpace(gencode))
            {
                var cacheKey = $"gencode_{gencode}";
                if (_hubContext is IHubContext<PaymentHub> hubContext)
                {
                    // We can't directly access cache from here, but we can check if it's in memory
                    debugInfo.cache.Add(new { cacheKey, status = "Cache access not available in this context" });
                }
            }

            // Check recent transactions
            var recentTransactions = await _context.BankTransactions
                .OrderByDescending(t => t.CreatedOn)
                .Take(5)
                .Select(t => new
                {
                    t.Id,
                    t.Code,
                    t.Transferamount,
                    t.Description,
                    t.Content,
                    t.CreatedOn,
                    t.Transactiondate
                })
                .ToListAsync();

            debugInfo.transactions.AddRange(recentTransactions);

            // Check recent purchase transactions
            var recentPurchases = await _context.PurchaseTransactions
                .OrderByDescending(pt => pt.CreatedAt)
                .Take(5)
                .Select(pt => new
                {
                    pt.Id,
                    pt.UserId,
                    pt.TransactionType,
                    pt.Quantity,
                    pt.TotalAmount,
                    pt.Status,
                    pt.TransactionCode,
                    pt.CreatedAt
                })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                message = "Debug information",
                data = debugInfo
            });
        }

        /// <summary>
        /// Test payment processing - Giả lập webhook để test việc cập nhật balance và tạo transaction
        /// </summary>
        [HttpPost("test-payment")]
        [ProducesResponseType(typeof(object), 200)]
        public async Task<IActionResult> TestPaymentProcessing(
            [FromQuery] string gencode,
            [FromQuery] decimal amount = 50000)
        {
            try
            {
                // Tạo mock transaction
                var mockTransaction = new BankTransaction
                {
                    Gateway = "Test",
                    Transactiondate = DateTime.UtcNow,
                    Accountnumber = "123456789",
                    Code = "TEST123",
                    Content = $"Thanh toan don hang {gencode}",
                    Description = $"{gencode} Thanh toan mua giay",
                    Transfertype = "IN",
                    Transferamount = amount,
                    Accumulated = 1000000,
                    Subaccount = "123",
                    Referencecode = $"REF{gencode}",
                    CreatedOn = DateTime.UtcNow
                };

                // Process như webhook thật
                var result = await _hooksService.ProcessTransactionAsync(mockTransaction);

                return Ok(new
                {
                    success = true,
                    message = "Test payment processed successfully",
                    transaction = new
                    {
                        gencode = gencode,
                        amount = amount,
                        referenceCode = mockTransaction.Referencecode
                    },
                    result = new
                    {
                        message = result.Message,
                        orderUpdated = result.OrderUpdated,
                        orderId = result.OrderId
                    }
                });
            }
            catch (Exception ex)
            {
                return Ok(new
                {
                    success = false,
                    message = $"Test payment failed: {ex.Message}",
                    error = ex.GetType().Name
                });
            }
        }

        /// <summary>
        /// Test SignalR notification - Gửi thông báo thanh toán thành công đến frontend để test
        /// </summary>
        [HttpPost("test-signalr")]
        [ProducesResponseType(typeof(object), 200)]
        [ProducesResponseType(typeof(object), 400)]
        [ProducesResponseType(typeof(object), 500)]
        public async Task<IActionResult> TestSignalR(
            [FromQuery] string gencode, 
            [FromQuery] int orderId = 255,
            [FromQuery] decimal amount = 2000.00m)
        {
            if (string.IsNullOrWhiteSpace(gencode))
            {
                return BadRequest(new { message = "gencode is required" });
            }

            try
            {
                var groupName = $"payment_{gencode}";
                var notificationData = new
                {
                    orderId = orderId,
                    gencode = gencode,
                    amount = amount,
                    message = "Test notification - Thanh toán thành công! Đơn hàng của bạn đã được xác nhận.",
                    timestamp = DateTime.UtcNow
                };
                
                Console.WriteLine($"[TestSignalR] ===== Sending test SignalR notification ===== ");
                Console.WriteLine($"[TestSignalR] Group name: {groupName}");
                Console.WriteLine($"[TestSignalR] OrderId: {orderId}");
                Console.WriteLine($"[TestSignalR] Gencode: {gencode}");
                Console.WriteLine($"[TestSignalR] Amount: {amount}");
                Console.WriteLine($"[TestSignalR] Notification data: {JsonSerializer.Serialize(notificationData)}");
                
                // Send notification to all clients in the group
                await _hubContext.Clients.Group(groupName).SendAsync("PaymentSuccess", notificationData);
                
                Console.WriteLine($"[TestSignalR] ✅ Test SignalR notification sent successfully to group: {groupName}");
                
                return Ok(new
                {
                    success = true,
                    message = "SignalR notification sent successfully",
                    groupName = groupName,
                    data = notificationData
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[TestSignalR] ❌ Error sending test SignalR notification: {ex.Message}");
                
                return StatusCode(500, new
                {
                    success = false,
                    message = "Error sending SignalR notification",
                    error = ex.Message
                });
            }
        }
    }
}

