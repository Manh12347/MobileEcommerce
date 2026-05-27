using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Models.Configurations;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using PTVBTPM.Helper;
using System.Security.Cryptography;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    [Produces("application/json")]
    public class PaymentController : ControllerBase
    {
        private readonly SepayConfig _sepayConfig;
        private readonly IMemoryCache _cache;
        private readonly WebDbContext _context;
        private readonly ILogger<PaymentController> _logger;


        public PaymentController(
            IOptions<SepayConfig> sepayConfig,
            IMemoryCache cache,
            WebDbContext context,
            ILogger<PaymentController> logger)
        {
            _sepayConfig = sepayConfig.Value;
            _cache = cache;
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Generate QR Code URL cho thanh toán
        /// </summary>
        /// <param name="amount">Số tiền thanh toán</param>
        /// <param name="gencode">Mã gencode để đối chiếu</param>
        /// <response code="200">Trả về QR URL</response>
        /// <response code="400">Amount hoặc gencode không hợp lệ</response>
        [HttpGet("GenerateQr")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        public IActionResult GenerateQr([FromQuery] decimal amount, [FromQuery] string gencode)
        {
            if (amount <= 0 || string.IsNullOrWhiteSpace(gencode))
                return BadRequest(new { success = false, message = "Amount or gencode is invalid." });

            // Format amount với 2 chữ số thập phân (giống ModernIssues để đảm bảo format đúng cho SePay)
            // Ví dụ: 2500 -> 2500.00
            var formattedAmount = amount.ToString("F2", System.Globalization.CultureInfo.InvariantCulture);

            // Tạo QR URL với template compact (giao diện QR code nhỏ gọn hơn)
            // template=compact chỉ ảnh hưởng đến giao diện, không ảnh hưởng đến webhook
            var qrUrl = $"https://qr.sepay.vn/img?bank={_sepayConfig.BankName}&acc={_sepayConfig.AccountNumber}&amount={formattedAmount}&des={gencode}&template=compact";

            return Ok(new { success = true, data = new { qrUrl } });
        }

        /// <summary>
        /// Tạo đơn hàng mua thêm giấy và generate QR code thanh toán
        /// </summary>
        /// <param name="request">Thông tin số lượng trang muốn mua</param>
        /// <response code="200">Trả về thông tin đơn hàng và QR code</response>
        /// <response code="400">Request không hợp lệ</response>
        /// <response code="401">Chưa đăng nhập</response>
        /// <response code="500">Lỗi server</response>
        [HttpPost("PurchasePages")]
        [ProducesResponseType(typeof(PurchasePagesResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> PurchasePages([FromBody] PurchasePagesRequestDto request)
        {
            try
            {
                _logger.LogInformation("[PurchasePages] ===== Request received =====");
                _logger.LogInformation($"[PurchasePages] Pages: {request.Pages}");

                // 1. Kiểm tra đăng nhập
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    _logger.LogWarning("[PurchasePages] ❌ User not logged in");
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập để mua thêm giấy." });
                }

                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (!userId.HasValue)
                {
                    _logger.LogWarning("[PurchasePages] ❌ Cannot get userId from session");
                    return Unauthorized(new { success = false, message = "Không thể xác định người dùng." });
                }

                _logger.LogInformation($"[PurchasePages] UserId: {userId.Value}");

                // 2. Validate request
                if (request.Pages <= 0)
                {
                    _logger.LogWarning($"[PurchasePages] ❌ Invalid pages: {request.Pages}");
                    return BadRequest(new { success = false, message = "Số lượng trang phải lớn hơn 0." });
                }

                if (request.Pages > 10000)
                {
                    _logger.LogWarning($"[PurchasePages] ❌ Pages too large: {request.Pages}");
                    return BadRequest(new { success = false, message = "Số lượng trang không được vượt quá 10,000 trang." });
                }

                // 3. Kiểm tra user tồn tại
                var user = await _context.Users.FindAsync(userId.Value);
                if (user == null)
                {
                    _logger.LogWarning($"[PurchasePages] ❌ User not found: {userId.Value}");
                    return BadRequest(new { success = false, message = "Người dùng không tồn tại." });
                }

                // 4. Lấy giá mua thêm giấy từ database (dùng giá A4 đen trắng làm mặc định)
                var pagePurchasePrice = await GetPagePurchasePriceAsync();
                if (pagePurchasePrice == null)
                {
                    _logger.LogError("[PurchasePages] ❌ Cannot get page purchase price from database");
                    return StatusCode(500, new { success = false, message = "Không thể lấy giá mua giấy. Vui lòng thử lại sau." });
                }

                // 5. Tính số tiền cần thanh toán
                var totalAmount = request.Pages * pagePurchasePrice.PricePerPage;
                _logger.LogInformation($"[PurchasePages] Total amount: {totalAmount} VNĐ ({request.Pages} pages × {pagePurchasePrice.PricePerPage} VNĐ)");

                // 6. Tạo OrderId đơn giản (dùng timestamp ngắn)
                var orderId = (int)(DateTime.UtcNow.Ticks % 1000000000); // 9 số

                // 7. Tạo gencode ngắn gọn (khoảng 20 ký tự): PAGES + 15 ký tự random
                var randomBytes = new byte[10];
                using (var rng = RandomNumberGenerator.Create())
                {
                    rng.GetBytes(randomBytes);
                }
                // Tạo 15 ký tự random từ hex (A-Z0-9)
                var randomHex = BitConverter.ToString(randomBytes).Replace("-", "").ToUpper();
                var randomPart = randomHex.Substring(0, 15);
                var gencode = $"PAGES{randomPart}"; // PAGES (5) + 15 = 20 ký tự
                _logger.LogInformation($"[PurchasePages] Generated gencode: {gencode} (length: {gencode.Length})");

                // 8. Tạo PurchaseTransaction record ngay lập tức (không chờ webhook)
                var purchaseTransaction = new PurchaseTransaction
                {
                    UserId = userId.Value,
                    TransactionType = "PAGE_PURCHASE",
                    Quantity = request.Pages,
                    PricePerUnit = pagePurchasePrice.PricePerPage,
                    TotalAmount = totalAmount,
                    TransactionCode = gencode,
                    Status = "PENDING"
                };

                _context.PurchaseTransactions.Add(purchaseTransaction);
                await _context.SaveChangesAsync();

                var transactionId = purchaseTransaction.Id;
                _logger.LogInformation($"[PurchasePages] ✅ Purchase transaction created with ID: {transactionId}");

                // 9. Lưu thông tin đơn hàng vào cache (OrderId = transactionId để dễ tìm)
                var cacheKey = $"gencode_{gencode}";
                var cacheInfo = new OrderCacheInfo
                {
                    OrderId = transactionId, // Dùng transaction ID làm order ID
                    UserId = userId.Value,
                    TotalAmount = totalAmount,
                    PaymentType = "PURCHASE_PAGES",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow,
                    Pages = request.Pages
                };

                // Cache trong 30 phút (thời gian thanh toán)
                var cacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(30),
                    SlidingExpiration = TimeSpan.FromMinutes(5)
                };

                _cache.Set(cacheKey, cacheInfo, cacheOptions);
                _logger.LogInformation($"[PurchasePages] ✅ Order cached with key: {cacheKey}");

                // 9. Generate QR code URL
                // Format amount với 2 chữ số thập phân (giống ModernIssues để đảm bảo format đúng cho SePay)
                // Ví dụ: 2500 -> 2500.00
                var formattedAmount = totalAmount.ToString("F2", System.Globalization.CultureInfo.InvariantCulture);

                // Tạo QR URL với template compact (giao diện QR code nhỏ gọn hơn)
                // template=compact chỉ ảnh hưởng đến giao diện, không ảnh hưởng đến webhook
                var qrUrl = $"https://qr.sepay.vn/img?bank={_sepayConfig.BankName}&acc={_sepayConfig.AccountNumber}&amount={formattedAmount}&des={gencode}&template=compact";
                _logger.LogInformation($"[PurchasePages] ✅ QR URL generated: {qrUrl}");

                // 10. Tạo response
                var response = new PurchasePagesResponseDto
                {
                    OrderId = orderId,
                    Gencode = gencode,
                    Pages = request.Pages,
                    Amount = totalAmount,
                    QrUrl = qrUrl,
                    CreatedAt = DateTime.UtcNow
                };

                _logger.LogInformation($"[PurchasePages] ✅ Purchase pages order created successfully");

                return Ok(new
                {
                    success = true,
                    message = "Đơn hàng mua giấy đã được tạo. Vui lòng quét QR code để thanh toán.",
                    data = response
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PurchasePages] ❌ Error creating purchase pages order");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Có lỗi xảy ra khi tạo đơn hàng mua giấy.",
                    error = ex.Message
                });
            }
        }


        /// <summary>
        /// Lấy giá mua thêm giấy (dùng giá A4 đen trắng làm mặc định)
        /// </summary>
        /// <response code="200">Trả về giá mua thêm giấy</response>
        /// <response code="500">Lỗi server</response>
        [HttpGet("PagePurchasePrice")]
        [ProducesResponseType(typeof(PagePurchasePriceDto), 200)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetPagePurchasePrice()
        {
            try
            {
                _logger.LogInformation("[GetPagePurchasePrice] ===== Request received =====");

                var price = await GetPagePurchasePriceAsync();
                if (price == null)
                {
                    _logger.LogError("[GetPagePurchasePrice] ❌ Cannot get page purchase price from database");
                    return StatusCode(500, new
                    {
                        success = false,
                        message = "Không thể lấy giá mua giấy. Vui lòng thử lại sau."
                    });
                }

                _logger.LogInformation($"[GetPagePurchasePrice] ✅ Page purchase price: {price.PricePerPage} VNĐ");

                return Ok(new
                {
                    success = true,
                    data = price
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[GetPagePurchasePrice] ❌ Error getting page purchase price");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Có lỗi xảy ra khi lấy giá mua giấy.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Lấy giá mua thêm dung lượng lưu trữ (dùng giá từ system config)
        /// </summary>
        /// <response code="200">Trả về giá mua thêm dung lượng</response>
        /// <response code="500">Lỗi server</response>
        [HttpGet("StoragePurchasePrice")]
        [ProducesResponseType(typeof(StoragePurchasePriceDto), 200)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetStoragePurchasePrice()
        {
            try
            {
                _logger.LogInformation("[GetStoragePurchasePrice] ===== Request received =====");

                var price = await GetStoragePurchasePriceAsync();
                if (price == null)
                {
                    _logger.LogError("[GetStoragePurchasePrice] ❌ Cannot get storage purchase price from database");
                    return StatusCode(500, new
                    {
                        success = false,
                        message = "Không thể lấy giá mua dung lượng. Vui lòng thử lại sau."
                    });
                }

                _logger.LogInformation($"[GetStoragePurchasePrice] ✅ Storage purchase price: {price.PricePerMb} VNĐ/MB");

                return Ok(new
                {
                    success = true,
                    data = price
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[GetStoragePurchasePrice] ❌ Error getting storage purchase price");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Có lỗi xảy ra khi lấy giá mua dung lượng.",
                    error = ex.Message
                });
            }
        }

        /// <summary>
        /// Helper method để lấy giá mua thêm giấy từ system config
        /// </summary>
        private async Task<PagePurchasePriceDto?> GetPagePurchasePriceAsync()
        {
            try
            {
                // Lấy giá từ system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                if (systemConfig == null)
                {
                    _logger.LogWarning("[GetPagePurchasePriceAsync] ⚠️  System config not found");
                    return null;
                }

                if (systemConfig.PaperPrice <= 0)
                {
                    _logger.LogWarning("[GetPagePurchasePriceAsync] ⚠️  Paper price not set in system config");
                    return null;
                }

                return new PagePurchasePriceDto
                {
                    PricePerPage = systemConfig.PaperPrice,
                    Currency = "VND",
                    Description = "Giá mua thêm giấy (theo cấu hình hệ thống)"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[GetPagePurchasePriceAsync] ❌ Error getting page purchase price");
                return null;
            }
        }

        /// <summary>
        /// Helper method để lấy giá mua thêm dung lượng từ system config
        /// </summary>
        private async Task<StoragePurchasePriceDto?> GetStoragePurchasePriceAsync()
        {
            try
            {
                // Lấy giá từ system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                if (systemConfig == null)
                {
                    _logger.LogWarning("[GetStoragePurchasePriceAsync] ⚠️  System config not found");
                    return null;
                }

                if (systemConfig.StoragePricePerMb <= 0)
                {
                    _logger.LogWarning("[GetStoragePurchasePriceAsync] ⚠️  Storage price not set in system config");
                    return null;
                }

                return new StoragePurchasePriceDto
                {
                    PricePerMb = systemConfig.StoragePricePerMb,
                    Currency = "VND",
                    Description = "Giá mua thêm dung lượng (theo cấu hình hệ thống)"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[GetStoragePurchasePriceAsync] ❌ Error getting storage purchase price");
                return null;
            }
        }

        /// <summary>
        /// Mua thêm dung lượng lưu trữ
        /// </summary>
        /// <param name="request">Thông tin mua dung lượng</param>
        /// <response code="200">Trả về thông tin đơn hàng</response>
        /// <response code="400">Dữ liệu không hợp lệ</response>
        /// <response code="401">Chưa đăng nhập</response>
        /// <response code="500">Lỗi server</response>
        [HttpPost("PurchaseStorage")]
        [ProducesResponseType(typeof(PurchaseStorageResponseDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> PurchaseStorage([FromBody] PurchaseStorageRequestDto request)
        {
            try
            {
                _logger.LogInformation("[PurchaseStorage] ===== Request received =====");
                _logger.LogInformation($"[PurchaseStorage] StorageMb: {request.StorageMb}, PricePerMb: {request.PricePerMb}");

                // Validate request object
                if (request == null)
                {
                    _logger.LogWarning("[PurchaseStorage] ❌ Request is null");
                    return BadRequest(new { success = false, message = "Request không hợp lệ." });
                }

                // 1. Kiểm tra đăng nhập
                if (!AuthHelper.IsLoggedIn(HttpContext))
                {
                    _logger.LogWarning("[PurchaseStorage] ❌ User not logged in");
                    return Unauthorized(new { success = false, message = "Bạn cần đăng nhập để mua thêm dung lượng." });
                }

                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (!userId.HasValue)
                {
                    _logger.LogWarning("[PurchaseStorage] ❌ Cannot get userId from session");
                    return Unauthorized(new { success = false, message = "Không thể xác định người dùng." });
                }

                _logger.LogInformation($"[PurchaseStorage] UserId: {userId.Value}");

                // 2. Validate request
                if (request.StorageMb <= 0)
                {
                    _logger.LogWarning($"[PurchaseStorage] ❌ Invalid storage: {request.StorageMb}");
                    return BadRequest(new { success = false, message = "Dung lượng phải lớn hơn 0." });
                }

                if (request.StorageMb > 100000)
                {
                    _logger.LogWarning($"[PurchaseStorage] ❌ Storage too large: {request.StorageMb}");
                    return BadRequest(new { success = false, message = "Dung lượng không được vượt quá 100,000 MB (100GB)." });
                }

                if (request.PricePerMb <= 0)
                {
                    _logger.LogWarning($"[PurchaseStorage] ❌ Invalid price: {request.PricePerMb}");
                    return BadRequest(new { success = false, message = "Giá mỗi MB phải lớn hơn 0." });
                }

                // 3. Kiểm tra user tồn tại
                var user = await _context.Users.FindAsync(userId.Value);
                if (user == null)
                {
                    _logger.LogWarning($"[PurchaseStorage] ❌ User not found: {userId.Value}");
                    return BadRequest(new { success = false, message = "Người dùng không tồn tại." });
                }

                // 4. Tính tổng tiền
                var totalAmount = request.StorageMb * request.PricePerMb;
                _logger.LogInformation($"[PurchaseStorage] Total amount: {totalAmount} VNĐ ({request.StorageMb} MB × {request.PricePerMb} VNĐ)");

                // 5. Tạo OrderId đơn giản (dùng timestamp ngắn)
                var orderId = (int)(DateTime.UtcNow.Ticks % 1000000000); // 9 số

                // 6. Tạo gencode: STORE + 15 ký tự random hex
                var randomBytes = new byte[8]; // 8 bytes = 16 hex chars, take 15
                using (var rng = RandomNumberGenerator.Create())
                {
                    rng.GetBytes(randomBytes);
                }
                var randomHex = BitConverter.ToString(randomBytes).Replace("-", "").ToUpper();
                var gencode = $"STORE{randomHex.Substring(0, 15)}"; // STORE (5) + 15 = 20 ký tự
                _logger.LogInformation($"[PurchaseStorage] Generated gencode: {gencode} (length: {gencode.Length})");

                // 7. Tạo PurchaseTransaction record ngay lập tức (không chờ webhook)
                var purchaseTransaction = new PurchaseTransaction
                {
                    UserId = userId.Value,
                    TransactionType = "STORAGE_PURCHASE",
                    Quantity = (int)request.StorageMb,
                    PricePerUnit = request.PricePerMb,
                    TotalAmount = totalAmount,
                    TransactionCode = gencode,
                    Status = "PENDING"
                };

                _context.PurchaseTransactions.Add(purchaseTransaction);
                await _context.SaveChangesAsync();

                var transactionId = purchaseTransaction.Id;
                _logger.LogInformation($"[PurchaseStorage] ✅ Purchase transaction created with ID: {transactionId}");

                // 8. Lưu thông tin đơn hàng vào cache (OrderId = transactionId để dễ tìm)
                var cacheKey = $"gencode_{gencode}";
                var cacheInfo = new OrderCacheInfo
                {
                    OrderId = transactionId, // Dùng transaction ID làm order ID
                    UserId = userId.Value,
                    TotalAmount = totalAmount,
                    PaymentType = "PURCHASE_STORAGE",
                    Status = "PENDING",
                    CreatedAt = DateTime.UtcNow,
                    StorageMb = request.StorageMb
                };

                // Cache trong 30 phút (thời gian thanh toán)
                var cacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(30),
                    SlidingExpiration = TimeSpan.FromMinutes(5)
                };

                _cache.Set(cacheKey, cacheInfo, cacheOptions);
                _logger.LogInformation($"[PurchaseStorage] ✅ Order cached with key: {cacheKey}");

                // 8. Generate QR code URL
                // Format amount với 2 chữ số thập phân (giống ModernIssues để đảm bảo format đúng cho SePay)
                // Ví dụ: 2500 -> 2500.00
                var formattedAmount = totalAmount.ToString("F2", System.Globalization.CultureInfo.InvariantCulture);

                // Tạo QR URL với template compact (giao diện QR code nhỏ gọn hơn)
                // template=compact chỉ ảnh hưởng đến giao diện, không ảnh hưởng đến webhook
                var qrUrl = $"https://qr.sepay.vn/img?bank={_sepayConfig.BankName}&acc={_sepayConfig.AccountNumber}&amount={formattedAmount}&des={gencode}&template=compact";
                _logger.LogInformation($"[PurchaseStorage] ✅ QR URL generated: {qrUrl}");

                // 9. Tạo response
                var response = new PurchaseStorageResponseDto
                {
                    OrderId = orderId,
                    Gencode = gencode,
                    StorageMb = request.StorageMb,
                    Amount = totalAmount,
                    QrUrl = qrUrl,
                    CreatedAt = DateTime.UtcNow
                };

                _logger.LogInformation($"[PurchaseStorage] ✅ Purchase storage order created successfully");

                return Ok(new
                {
                    success = true,
                    data = response
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PurchaseStorage] ❌ Error creating purchase storage order");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Có lỗi xảy ra khi tạo đơn hàng mua dung lượng.",
                    error = ex.Message
                });
            }
        }
    }
}