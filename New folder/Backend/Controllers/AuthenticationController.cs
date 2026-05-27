using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using PTVBTPM.Services;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.AspNetCore.Hosting;
using System.Linq;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    public class AuthenticationController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<AuthenticationController> _logger;
        private readonly ITwoFactorAuthService _twoFactorAuthService;
        private readonly IMemoryCache _cache;
        private readonly IWebHostEnvironment _environment;
        private readonly IEmailService _emailService;
        private readonly HooksService _hooksService;
        private readonly Microsoft.AspNetCore.SignalR.IHubContext<PTVBTPM.Hubs.PresenceHub> _presenceHubContext;

        public AuthenticationController(
            WebDbContext context,
            ILogger<AuthenticationController> logger,
            ITwoFactorAuthService twoFactorAuthService,
            IMemoryCache cache,
            IWebHostEnvironment environment,
            IEmailService emailService,
            HooksService hooksService,
            Microsoft.AspNetCore.SignalR.IHubContext<PTVBTPM.Hubs.PresenceHub> presenceHubContext)
        {
            _context = context;
            _logger = logger;
            _twoFactorAuthService = twoFactorAuthService;
            _cache = cache;
            _environment = environment;
            _emailService = emailService;
            _hooksService = hooksService;
            _presenceHubContext = presenceHubContext;
        }

        /// <summary>
        /// Đăng ký tài khoản mới (không hỗ trợ upload avatar)
        /// </summary>
        [HttpPost("Register")]
        [ApiExplorerSettings(IgnoreApi = true)]
        public async Task<ActionResult<AuthResponseDto>> Register([FromBody] RegisterRequestDto request)
        {
            var studentCode = request.StudentCode;
            var fullName = request.FullName;
            var email = request.Email;
            var password = request.Password;
            var role = request.Role;

            // Auto-generate student code if not provided (before validation)
            if (string.IsNullOrWhiteSpace(studentCode))
            {
                // Get the last student code from database
                var lastUser = await _context.Users
                    .Where(u => u.StudentCode != null && u.StudentCode.StartsWith("SV"))
                    .OrderByDescending(u => u.StudentCode)
                    .FirstOrDefaultAsync();

                int nextNumber = 1;
                if (lastUser != null && !string.IsNullOrWhiteSpace(lastUser.StudentCode))
                {
                    // Extract number from last student code (format: SV00001 or SV00001xxx)
                    var lastCode = lastUser.StudentCode;
                    if (lastCode.Length > 2 && lastCode.StartsWith("SV"))
                    {
                        // Get the base number (5 digits after SV)
                        var basePart = lastCode.Substring(2, Math.Min(5, lastCode.Length - 2));
                        if (int.TryParse(basePart, out int lastNumber))
                        {
                            nextNumber = lastNumber + 1;
                        }
                    }
                }

                // Format: SV00001, SV00002, etc. (5 digits)
                studentCode = $"SV{nextNumber:D5}";

                // Extract numbers from email (before @) and append to student code
                var emailParts = email.Split('@');
                if (emailParts.Length > 0)
                {
                    var emailPrefix = emailParts[0]; // part before @
                    // Extract all digits from email prefix
                    var numbersFromEmail = new string(emailPrefix.Where(char.IsDigit).ToArray());
                    if (!string.IsNullOrWhiteSpace(numbersFromEmail))
                    {
                        studentCode = $"{studentCode}{numbersFromEmail}";
                    }
                }

                // Check if generated student code already exists (shouldn't happen, but just in case)
                var existingGeneratedCode = await _context.Users
                    .FirstOrDefaultAsync(u => u.StudentCode == studentCode);

                if (existingGeneratedCode != null)
                {
                    // If exists, increment and try again
                    nextNumber++;
                    studentCode = $"SV{nextNumber:D5}";
                    var emailPrefix = email.Split('@')[0];
                    var numbersFromEmail = new string(emailPrefix.Where(char.IsDigit).ToArray());
                    if (!string.IsNullOrWhiteSpace(numbersFromEmail))
                    {
                        studentCode = $"{studentCode}{numbersFromEmail}";
                    }
                }
            }

            try
            {
                // 1. Validate email domain
                if (!IsValidSiuEmail(email))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng sử dụng mail SIU để sử dụng dịch vụ"
                    });
                }

                // 1.5. Không cho phép đăng ký với role SPSO
                var requestedRole = string.IsNullOrWhiteSpace(role) ? "STUDENT" : role.Trim().ToUpper();
                if (requestedRole == "SPSO")
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không thể đăng ký với role SPSO. Chỉ có thể đăng ký với role STUDENT."
                    });
                }

                // 2. Check if email already exists in DB
                var existingUser = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == email.ToLower());

                if (existingUser != null)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email đã được sử dụng"
                    });
                }

                // 2.5. Check if email is pending registration in cache
                var pendingCacheKey = $"PendingUserRegistration_{email.ToLower()}";
                if (_cache.TryGetValue(pendingCacheKey, out PendingUserRegistrationDto? existingPending))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email đang chờ xác nhận. Vui lòng kiểm tra email để lấy mã OTP hoặc đợi 2 phút để đăng ký lại."
                    });
                }

                // 3. Check if student code already exists in DB (if provided manually)
                if (!string.IsNullOrWhiteSpace(studentCode))
                {
                    var existingStudentCode = await _context.Users
                        .FirstOrDefaultAsync(u => u.StudentCode == studentCode);

                    if (existingStudentCode != null)
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = "Mã sinh viên đã được sử dụng"
                        });
                    }
                }

                // 3.5. Validate password theo system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                // Nếu không có config, sử dụng giá trị mặc định
                var minPasswordLength = systemConfig?.MinPasswordLength ?? 8;
                var requireStrongFormat = systemConfig?.RequirePasswordFormat ?? true;

                var (isValid, errorMessage) = PasswordValidator.ValidatePassword(
                    password, 
                    minPasswordLength, 
                    requireStrongFormat);

                if (!isValid)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = errorMessage ?? "Mật khẩu không hợp lệ"
                    });
                }


                // 5. Generate OTP 6 số và lưu vào cache (2 phút)
                var random = new Random();
                var otp = random.Next(100000, 999999).ToString(); // 6 số
                var otpCacheKey = $"EmailConfirmation_OTP_{email.ToLower()}";
                var otpCacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(2) // OTP hết hạn sau 2 phút
                };
                _cache.Set(otpCacheKey, otp, otpCacheOptions);

                // 6. Lưu thông tin user vào cache (chưa lưu DB) - hết hạn sau 2 phút (cùng với OTP)
                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                var pendingUser = new PendingUserRegistrationDto
                {
                    StudentCode = studentCode,
                    FullName = fullName,
                    Email = email.ToLower(),
                    PasswordHash = PasswordHelper.HashPassword(password),
                    Role = "STUDENT", // Chỉ cho phép đăng ký với role STUDENT
                    AvatarUrl = null,
                    CreatedOn = now
                };

                var userCacheKey = $"PendingUserRegistration_{email.ToLower()}";
                var userCacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(2) // Hết hạn sau 2 phút, tự động xóa nếu không xác nhận
                };
                
                // Callback để xóa avatar file khi cache hết hạn (nếu không xác nhận)
                userCacheOptions.RegisterPostEvictionCallback((key, value, reason, state) =>
                {
                    if (value is PendingUserRegistrationDto pending && !string.IsNullOrWhiteSpace(pending.AvatarUrl))
                    {
                        try
                        {
                            var avatarPath = Path.Combine(_environment.WebRootPath, pending.AvatarUrl);
                            if (System.IO.File.Exists(avatarPath))
                            {
                                System.IO.File.Delete(avatarPath);
                                _logger.LogInformation($"Deleted avatar file due to expired registration cache: {pending.AvatarUrl}");
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, $"Failed to delete avatar file on cache expiry: {pending.AvatarUrl}");
                        }
                    }
                });
                
                _cache.Set(userCacheKey, pendingUser, userCacheOptions);

                // 7. Send OTP email
                try
                {
                    var emailSubject = "Xác nhận đăng ký tài khoản PTVBTPM";
                    var emailBody = $@"
                        <html>
                        <body>
                            <h2>Xác nhận đăng ký tài khoản</h2>
                            <p>Xin chào <strong>{fullName}</strong>,</p>
                            <p>Cảm ơn bạn đã đăng ký tài khoản tại hệ thống PTVBTPM.</p>
                            <p>Mã xác nhận OTP của bạn là: <strong style='font-size: 24px; color: #007bff;'>{otp}</strong></p>
                            <p>Mã này sẽ hết hạn sau 2 phút.</p>
                            <p>Vui lòng sử dụng mã này để xác nhận email của bạn.</p>
                            <p>Trân trọng,<br/>Hệ thống PTVBTPM</p>
                        </body>
                        </html>";

                    await _emailService.SendEmailAsync(pendingUser.Email, pendingUser.FullName, emailSubject, emailBody, isHtml: true);
                    _logger.LogInformation($"OTP email sent to {pendingUser.Email}");
                }
                catch (Exception emailEx)
                {
                    _logger.LogError(emailEx, $"Failed to send OTP email to {pendingUser.Email}");
                    // Nếu gửi email lỗi, xóa cache
                    _cache.Remove(userCacheKey);
                    _cache.Remove(otpCacheKey);
                    return StatusCode(500, new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không thể gửi email. Vui lòng thử lại sau."
                    });
                }

                // 8. Return response (không set session vì chưa xác nhận email, chưa lưu DB)
                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Đăng ký thành công. Vui lòng kiểm tra email để lấy mã OTP xác nhận.",
                    User = new UserInfoDto
                    {
                        UserId = 0, // Chưa có UserId vì chưa lưu DB
                        StudentCode = pendingUser.StudentCode,
                        FullName = pendingUser.FullName,
                        Email = pendingUser.Email,
                        EmailConfirmed = false,
                        Role = pendingUser.Role,
                        Status = null,
                        AvatarUrl = null,
                        DateOfBirth = null,
                        Address = null,
                        PhoneNumber = null
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during registration");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi đăng ký"
                });
            }
        }

        /// <summary>
        /// Xác nhận email bằng OTP sau khi đăng ký
        /// </summary>
        [HttpPost("ConfirmEmail")]
        public async Task<ActionResult<AuthResponseDto>> ConfirmEmail([FromBody] ConfirmEmailRequestDto request)
        {
            try
            {
                // 1. Get pending user registration from cache
                var userCacheKey = $"PendingUserRegistration_{request.Email.ToLower()}";
                if (!_cache.TryGetValue(userCacheKey, out PendingUserRegistrationDto? pendingUser) || pendingUser == null)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Thông tin đăng ký đã hết hạn hoặc không tồn tại. Vui lòng đăng ký lại."
                    });
                }

                // 2. Check if email already exists in DB (có thể đã được xác nhận trước đó)
                var existingUser = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());

                if (existingUser != null)
                {
                    // Xóa cache nếu user đã tồn tại
                    _cache.Remove(userCacheKey);
                    _cache.Remove($"EmailConfirmation_OTP_{request.Email.ToLower()}");
                    
                    if (existingUser.EmailConfirmed)
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = "Email đã được xác nhận trước đó"
                        });
                    }
                    else
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = "Email đã tồn tại trong hệ thống nhưng chưa được xác nhận. Vui lòng liên hệ admin."
                        });
                    }
                }

                // 3. Get OTP from cache
                var otpCacheKey = $"EmailConfirmation_OTP_{request.Email.ToLower()}";
                if (!_cache.TryGetValue(otpCacheKey, out string? cachedOtp) || string.IsNullOrWhiteSpace(cachedOtp))
                {
                    // OTP hết hạn, xóa thông tin đăng ký và avatar file
                    _cache.Remove(userCacheKey);
                    if (!string.IsNullOrWhiteSpace(pendingUser.AvatarUrl))
                    {
                        try
                        {
                            var avatarPath = Path.Combine(_environment.WebRootPath, pendingUser.AvatarUrl);
                            if (System.IO.File.Exists(avatarPath))
                            {
                                System.IO.File.Delete(avatarPath);
                                _logger.LogInformation($"Deleted avatar file due to expired OTP: {pendingUser.AvatarUrl}");
                            }
                        }
                        catch (Exception delEx)
                        {
                            _logger.LogWarning(delEx, $"Failed to delete avatar file: {pendingUser.AvatarUrl}");
                        }
                    }
                    
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng đăng ký lại."
                    });
                }

                // 4. Verify OTP
                if (cachedOtp != request.Otp)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mã OTP không đúng. Vui lòng kiểm tra lại."
                    });
                }

                // 5. OTP đúng - Lưu user vào DB và xóa cache
                // Lấy số trang mặc định từ system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                // Nếu không có config, sử dụng giá trị mặc định
                var defaultPages = systemConfig?.DefaultPagesForStudent ?? 100;
                var pageDefaultCreate = systemConfig?.PageDefaultCreate ?? 50;

                var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                var newUser = new User
                {
                    StudentCode = pendingUser.StudentCode,
                    FullName = pendingUser.FullName,
                    Email = pendingUser.Email.ToLower(),
                    PasswordHash = pendingUser.PasswordHash,
                    Role = pendingUser.Role,
                    Status = "ACTIVE",
                    EmailConfirmed = true, // Đã xác nhận email
                    AvatarUrl = null,
                    PageDefaultBalance = defaultPages + pageDefaultCreate, // Cấp số trang mặc định + số trang được tặng khi tạo tài khoản
                    PagePurchasedBalance = 0,
                    CreatedOn = now,
                    ModifiedOn = now
                };

                _context.Users.Add(newUser);
                await _context.SaveChangesAsync();

                // Xóa cache sau khi lưu DB thành công
                _cache.Remove(userCacheKey);
                _cache.Remove(otpCacheKey);

                // 6. Set session after email confirmation
                HttpContext.Session.SetString("UserId", newUser.UserId.ToString());
                HttpContext.Session.SetString("Email", newUser.Email);
                HttpContext.Session.SetString("Role", newUser.Role);
                HttpContext.Session.SetString("FullName", newUser.FullName);
                HttpContext.Session.SetString("StudentCode", newUser.StudentCode ?? string.Empty);

                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Xác nhận email thành công",
                    User = new UserInfoDto
                    {
                        UserId = newUser.UserId,
                        StudentCode = newUser.StudentCode ?? string.Empty,
                        FullName = newUser.FullName,
                        Email = newUser.Email,
                        EmailConfirmed = newUser.EmailConfirmed,
                        Role = newUser.Role,
                        Status = newUser.Status,
                        AvatarUrl = null,
                        DateOfBirth = newUser.DateOfBirth,
                        Address = newUser.Address,
                        PhoneNumber = newUser.PhoneNumber
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during email confirmation");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi xác nhận email"
                });
            }
        }

        /// <summary>
        /// Gửi lại OTP xác nhận email
        /// </summary>
        [HttpPost("ResendOtp")]
        public async Task<ActionResult<AuthResponseDto>> ResendOtp([FromBody] ResendOtpRequestDto request)
        {
            try
            {
                // 1. Find user by email
                var user = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());

                if (user == null)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email không tồn tại trong hệ thống"
                    });
                }

                // 2. Check if email already confirmed
                if (user.EmailConfirmed)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email đã được xác nhận trước đó"
                    });
                }

                // 3. Generate new OTP và lưu vào cache (2 phút)
                var random = new Random();
                var otp = random.Next(100000, 999999).ToString(); // 6 số
                var cacheKey = $"EmailConfirmation_OTP_{request.Email.ToLower()}";
                var cacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(2) // OTP hết hạn sau 2 phút
                };
                _cache.Set(cacheKey, otp, cacheOptions);

                // 5. Send OTP email
                try
                {
                    var emailSubject = "Mã OTP xác nhận email - PTVBTPM";
                    var emailBody = $@"
                        <html>
                        <body>
                            <h2>Mã OTP xác nhận email</h2>
                            <p>Xin chào <strong>{user.FullName}</strong>,</p>
                            <p>Mã OTP mới của bạn là: <strong style='font-size: 24px; color: #007bff;'>{otp}</strong></p>
                            <p>Mã này sẽ hết hạn sau 2 phút.</p>
                            <p>Vui lòng sử dụng mã này để xác nhận email của bạn.</p>
                            <p>Trân trọng,<br/>Hệ thống PTVBTPM</p>
                        </body>
                        </html>";

                    await _emailService.SendEmailAsync(user.Email, user.FullName, emailSubject, emailBody, isHtml: true);
                    _logger.LogInformation($"Resent OTP email to {user.Email}");

                    return Ok(new AuthResponseDto
                    {
                        Success = true,
                        Message = "Đã gửi lại mã OTP. Vui lòng kiểm tra email."
                    });
                }
                catch (Exception emailEx)
                {
                    _logger.LogError(emailEx, $"Failed to send OTP email to {user.Email}");
                    return StatusCode(500, new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không thể gửi email. Vui lòng thử lại sau."
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during resend OTP");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi gửi lại OTP"
                });
            }
        }

        /// <summary>
        /// Quên mật khẩu - Gửi OTP qua email để reset mật khẩu
        /// </summary>
        [HttpPost("ForgotPassword")]
        public async Task<ActionResult<AuthResponseDto>> ForgotPassword([FromBody] ForgotPasswordRequestDto request)
        {
            try
            {
                // 1. Validate email domain
                if (!IsValidSiuEmail(request.Email))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng sử dụng mail SIU để sử dụng dịch vụ"
                    });
                }

                // 2. Find user by email
                var user = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());

                if (user == null)
                {
                    // Không tiết lộ email có tồn tại hay không (security best practice)
                    return Ok(new AuthResponseDto
                    {
                        Success = true,
                        Message = "Nếu email tồn tại trong hệ thống, chúng tôi đã gửi mã OTP để đặt lại mật khẩu."
                    });
                }

                // 3. Check if email is confirmed
                if (!user.EmailConfirmed)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email chưa được xác nhận. Vui lòng xác nhận email trước khi đặt lại mật khẩu."
                    });
                }

                // 4. Check user status
                if (user.Status != "ACTIVE")
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Tài khoản đã bị khóa hoặc chưa được kích hoạt"
                    });
                }

                // 5. Generate OTP 6 số và lưu vào cache (2 phút)
                var random = new Random();
                var otp = random.Next(100000, 999999).ToString(); // 6 số
                var cacheKey = $"PasswordReset_OTP_{request.Email.ToLower()}";
                var cacheOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(2) // OTP hết hạn sau 2 phút
                };
                _cache.Set(cacheKey, otp, cacheOptions);

                // 6. Send OTP email
                try
                {
                    var emailSubject = "Đặt lại mật khẩu - PTVBTPM";
                    var emailBody = $@"
                        <html>
                        <body>
                            <h2>Đặt lại mật khẩu</h2>
                            <p>Xin chào <strong>{user.FullName}</strong>,</p>
                            <p>Bạn đã yêu cầu đặt lại mật khẩu cho tài khoản của mình.</p>
                            <p>Mã OTP của bạn là: <strong style='font-size: 24px; color: #007bff;'>{otp}</strong></p>
                            <p>Mã này sẽ hết hạn sau 2 phút.</p>
                            <p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>
                            <p>Trân trọng,<br/>Hệ thống PTVBTPM</p>
                        </body>
                        </html>";

                    await _emailService.SendEmailAsync(user.Email, user.FullName, emailSubject, emailBody, isHtml: true);
                    _logger.LogInformation($"Password reset OTP email sent to {user.Email}");

                    return Ok(new AuthResponseDto
                    {
                        Success = true,
                        Message = "Đã gửi mã OTP đặt lại mật khẩu. Vui lòng kiểm tra email."
                    });
                }
                catch (Exception emailEx)
                {
                    _logger.LogError(emailEx, $"Failed to send password reset OTP email to {user.Email}");
                    return StatusCode(500, new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không thể gửi email. Vui lòng thử lại sau."
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during forgot password");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi xử lý yêu cầu đặt lại mật khẩu"
                });
            }
        }

        /// <summary>
        /// Xác nhận OTP để reset mật khẩu
        /// </summary>
        [HttpPost("VerifyResetPasswordOtp")]
        public async Task<ActionResult<AuthResponseDto>> VerifyResetPasswordOtp([FromBody] VerifyResetPasswordOtpRequestDto request)
        {
            try
            {
                // 1. Validate email domain
                if (!IsValidSiuEmail(request.Email))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng sử dụng mail SIU để sử dụng dịch vụ"
                    });
                }

                // 2. Find user by email
                var user = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());

                if (user == null)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email không tồn tại trong hệ thống"
                    });
                }

                // 3. Get OTP from cache
                var cacheKey = $"PasswordReset_OTP_{request.Email.ToLower()}";
                if (!_cache.TryGetValue(cacheKey, out string? cachedOtp) || string.IsNullOrWhiteSpace(cachedOtp))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng yêu cầu gửi lại OTP."
                    });
                }

                // 4. Verify OTP
                if (cachedOtp != request.Otp)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mã OTP không đúng. Vui lòng kiểm tra lại."
                    });
                }

                // 5. OTP đúng - Lưu OTP đã verified vào cache để cho phép reset password (10 phút)
                var resetTokenKey = $"PasswordReset_Verified_{request.Email.ToLower()}";
                var resetTokenOptions = new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10) // Cho phép reset password trong 10 phút
                };
                _cache.Set(resetTokenKey, request.Otp, resetTokenOptions); // Lưu OTP đã verified

                // Xóa OTP gốc khỏi cache (đã verify rồi)
                _cache.Remove(cacheKey);

                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Xác nhận OTP thành công. Vui lòng nhập mật khẩu mới."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during verify reset password OTP");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi xác nhận OTP"
                });
            }
        }

        /// <summary>
        /// Đặt lại mật khẩu bằng OTP đã xác nhận
        /// </summary>
        [HttpPost("ResetPassword")]
        public async Task<ActionResult<AuthResponseDto>> ResetPassword([FromBody] ResetPasswordRequestDto request)
        {
            try
            {
                // 1. Validate email domain
                if (!IsValidSiuEmail(request.Email))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng sử dụng mail SIU để sử dụng dịch vụ"
                    });
                }

                // 2. Lấy system config để validate password
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                // Nếu không có config, sử dụng giá trị mặc định
                var minPasswordLength = systemConfig?.MinPasswordLength ?? 8;
                var requireStrongFormat = systemConfig?.RequirePasswordFormat ?? true;

                // Validate mật khẩu mới theo config
                var (isValid, errorMessage) = PasswordValidator.ValidatePassword(
                    request.NewPassword, 
                    minPasswordLength, 
                    requireStrongFormat);

                if (!isValid)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = errorMessage ?? "Mật khẩu không hợp lệ"
                    });
                }

                if (request.NewPassword != request.ConfirmPassword)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mật khẩu mới và xác nhận mật khẩu không khớp"
                    });
                }

                // 3. Find user by email
                var user = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());

                if (user == null)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email không tồn tại trong hệ thống"
                    });
                }

                // 4. Check user status
                if (user.Status != "ACTIVE")
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Tài khoản đã bị khóa hoặc chưa được kích hoạt"
                    });
                }

                // 5. Check if OTP has been verified (có OTP đã verified trong cache)
                var resetTokenKey = $"PasswordReset_Verified_{request.Email.ToLower()}";
                if (!_cache.TryGetValue(resetTokenKey, out string? verifiedOtp) || string.IsNullOrWhiteSpace(verifiedOtp))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng xác nhận OTP trước khi đặt lại mật khẩu."
                    });
                }

                // 6. Verify OTP again for security
                if (verifiedOtp != request.Otp)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mã OTP không đúng. Vui lòng kiểm tra lại."
                    });
                }

                // 7. Update password and remove verified token from cache
                user.PasswordHash = PasswordHelper.HashPassword(request.NewPassword);
                user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                
                // Xóa verified token khỏi cache
                _cache.Remove(resetTokenKey);

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Password reset successful for user: {user.Email}");

                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Đặt lại mật khẩu thành công. Vui lòng đăng nhập với mật khẩu mới."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during reset password");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi đặt lại mật khẩu"
                });
            }
        }

        /// <summary>
        /// Đổi mật khẩu (khi đã đăng nhập)
        /// </summary>
        [HttpPost("ChangePassword")]
        public async Task<ActionResult<AuthResponseDto>> ChangePassword([FromBody] ChangePasswordRequestDto request)
        {
            try
            {
                // 1. Kiểm tra user đã đăng nhập
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng đăng nhập trước khi đổi mật khẩu."
                    });
                }

                // 2. Tìm user trong DB
                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                {
                    return NotFound(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không tìm thấy người dùng."
                    });
                }

                // 3. Kiểm tra trạng thái tài khoản
                if (user.Status != "ACTIVE")
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Tài khoản đã bị khóa hoặc chưa được kích hoạt"
                    });
                }

                // 4. Verify mật khẩu cũ
                if (!PasswordHelper.VerifyPassword(request.OldPassword, user.PasswordHash))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mật khẩu cũ không đúng"
                    });
                }

                // 5. Lấy system config để validate password
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);
                // Nếu không có config, sử dụng giá trị mặc định
                var minPasswordLength = systemConfig?.MinPasswordLength ?? 8;
                var requireStrongFormat = systemConfig?.RequirePasswordFormat ?? true;

                // Validate mật khẩu mới theo config
                var (isValid, errorMessage) = PasswordValidator.ValidatePassword(
                    request.NewPassword, 
                    minPasswordLength, 
                    requireStrongFormat);

                if (!isValid)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = errorMessage ?? "Mật khẩu không hợp lệ"
                    });
                }

                // 6. Kiểm tra mật khẩu mới và xác nhận mật khẩu khớp
                if (request.NewPassword != request.ConfirmPassword)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mật khẩu mới và xác nhận mật khẩu không khớp"
                    });
                }

                // 7. Kiểm tra mật khẩu mới không trùng với mật khẩu cũ
                if (PasswordHelper.VerifyPassword(request.NewPassword, user.PasswordHash))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Mật khẩu mới phải khác với mật khẩu cũ"
                    });
                }

                // 8. Update mật khẩu mới
                user.PasswordHash = PasswordHelper.HashPassword(request.NewPassword);
                user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                await _context.SaveChangesAsync();

                _logger.LogInformation($"Password changed successfully for user: {user.Email}");

                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Đổi mật khẩu thành công."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during change password");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi đổi mật khẩu"
                });
            }
        }

        /// <summary>
        /// Đăng nhập
        /// </summary>
        [HttpPost("Login")]
        public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginRequestDto request)
        {
            try
            {
                // 1. Validate email domain
                if (!IsValidSiuEmail(request.Email))
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng sử dụng mail SIU để sử dụng dịch vụ"
                    });
                }

                // Lấy system config để check max login attempts
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(_context, _cache);

                // 2. Find user by email
                var user = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());

                if (user == null)
                {
                    return Unauthorized(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email hoặc mật khẩu không đúng"
                    });
                }

                // 3. Check if email is confirmed
                if (!user.EmailConfirmed)
                {
                    return Unauthorized(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email chưa được xác nhận. Vui lòng kiểm tra email và xác nhận tài khoản trước khi đăng nhập."
                    });
                }

                // 4. Check user status
                if (user.Status != "ACTIVE")
                {
                    return Unauthorized(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Tài khoản đã bị khóa hoặc chưa được kích hoạt"
                    });
                }

                // 4.5. Check login attempts nếu có config
                if (systemConfig != null && systemConfig.MaxLoginAttempts > 0)
                {
                    // Sử dụng cache để track failed attempts
                    var failedAttemptsKey = $"FailedLoginAttempts_{user.UserId}";
                    var failedAttempts = _cache.Get<int?>(failedAttemptsKey) ?? 0;

                    // Nếu vượt quá số lần cho phép, lock account
                    if (failedAttempts >= systemConfig.MaxLoginAttempts)
                    {
                        user.Status = "LOCKED";
                        user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                        // create login history for lock event
                        var lockHistory = new LoginHistory
                        {
                            UserId = user.UserId,
                            LoginTime = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified),
                            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                            Device = "LOCKED",
                            Description = $"Locked after {systemConfig.MaxLoginAttempts} failed attempts",
                            CreatedBy = "SYSTEM"
                        };

                        // Save both user status change and login history via hooks service
                        await _hooksService.AddLoginHistoryAsync(lockHistory);

                        return Unauthorized(new AuthResponseDto
                        {
                            Success = false,
                            Message = $"Tài khoản đã bị khóa do đăng nhập sai quá {systemConfig.MaxLoginAttempts} lần. Vui lòng liên hệ quản trị viên."
                        });
                    }
                }

                // 5. Verify password
                var passwordValid = PasswordHelper.VerifyPassword(request.Password, user.PasswordHash);
                
                if (!passwordValid)
                {
                    // Ghi lại failed attempt vào cache và LoginHistory
                    if (systemConfig != null && systemConfig.MaxLoginAttempts > 0)
                    {
                        var failedAttemptsKey = $"FailedLoginAttempts_{user.UserId}";
                        var currentAttempts = _cache.Get<int?>(failedAttemptsKey) ?? 0;
                        currentAttempts++;
                        
                        // Cache trong 1 giờ
                        var cacheOptions = new MemoryCacheEntryOptions
                        {
                            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
                        };
                        _cache.Set(failedAttemptsKey, currentAttempts, cacheOptions);
                        
                        // Ghi vào LoginHistory để log
                        var loginHistory = new LoginHistory
                        {
                            UserId = user.UserId,
                            LoginTime = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified),
                            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                            Device = $"FAILED_ATTEMPT_{currentAttempts}",
                            CreatedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified),
                            CreatedBy = "SYSTEM"
                        };
                        _context.LoginHistories.Add(loginHistory);
                        await _context.SaveChangesAsync();
                        
                        _logger.LogWarning($"Failed login attempt {currentAttempts}/{systemConfig.MaxLoginAttempts} for user {user.Email} from IP {loginHistory.IpAddress}");
                    }

                    return Unauthorized(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Email hoặc mật khẩu không đúng"
                    });
                }

                // Reset failed attempts nếu đăng nhập thành công
                if (systemConfig != null && systemConfig.MaxLoginAttempts > 0)
                {
                    var failedAttemptsKey = $"FailedLoginAttempts_{user.UserId}";
                    _cache.Remove(failedAttemptsKey);
                }

                // 5. Check if 2FA is enabled
                if (user.TwoFactorEnabled)
                {
                    // Don't complete login yet - return requires2FA flag
                    return Ok(new 
                    { 
                        Success = true,
                        Requires2FA = true, 
                        Email = user.Email,
                        Message = "Vui lòng nhập mã 2FA để hoàn tất đăng nhập.",
                        Method = user.TwoFactorMethod
                    });
                }

                // 6. No 2FA - Complete login immediately
                // Ghi lại successful login vào LoginHistory
                var successLoginHistory = new LoginHistory
                {
                    UserId = user.UserId,
                    LoginTime = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified),
                    IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                    Device = "SUCCESS",
                    Description = "Login successful",
                    CreatedBy = "SYSTEM"
                };
                await _hooksService.AddLoginHistoryAsync(successLoginHistory);
                try
                {
                    await _presenceHubContext.Clients.All.SendCoreAsync("UserActive", new object[] { user.UserId }, System.Threading.CancellationToken.None);
                }
                catch (Exception exp)
                {
                    _logger.LogWarning(exp, "Failed to broadcast UserActive");
                }
                
                HttpContext.Session.SetString("UserId", user.UserId.ToString());
                HttpContext.Session.SetString("Email", user.Email);
                HttpContext.Session.SetString("Role", user.Role);
                HttpContext.Session.SetString("FullName", user.FullName);
                HttpContext.Session.SetString("StudentCode", user.StudentCode ?? string.Empty);

                // 7. Return response
                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Đăng nhập thành công",
                    User = new UserInfoDto
                    {
                        UserId = user.UserId,
                        StudentCode = user.StudentCode ?? string.Empty,
                        FullName = user.FullName,
                        Email = user.Email,
                        EmailConfirmed = user.EmailConfirmed,
                        Role = user.Role,
                        Status = user.Status,
                        AvatarUrl = user.AvatarUrl,
                        DateOfBirth = user.DateOfBirth,
                        Address = user.Address,
                        PhoneNumber = user.PhoneNumber
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during login");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi đăng nhập"
                });
            }
        }

        /// <summary>
        /// Đăng xuất - xóa session và cleanup temp files
        /// </summary>
        [HttpPost("Logout")]
        public ActionResult<AuthResponseDto> Logout()
        {
            try
            {
                // Cleanup temp files trước khi clear session (để có userId)
                var userIdString = HttpContext.Session.GetString("UserId");
                if (int.TryParse(userIdString, out int userId))
                {
                    CleanupUserTempFiles(userId);
                }
                // Lưu login history cho logout (manual)
                try
                {
                    if (int.TryParse(userIdString, out int uid))
                    {
                        var logoutHistory = new LoginHistory
                        {
                            UserId = uid,
                            LoginTime = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified),
                            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                            Device = "LOGOUT",
                            Description = "User manual logout",
                            CreatedBy = "SYSTEM"
                        };
                        // Use _hooksService to save
                        // Fire-and-forget: await may not be desired during logout, but we'll save synchronously here
                        _hooksService.AddLoginHistoryAsync(logoutHistory).GetAwaiter().GetResult();
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to record logout history");
                }

                // Clear all session data
                HttpContext.Session.Clear();
                
                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Đăng xuất thành công"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during logout");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi đăng xuất"
                });
            }
        }

        /// <summary>
        /// Cleanup tất cả temp files của user (khi logout hoặc session timeout)
        /// </summary>
        private void CleanupUserTempFiles(int userId)
        {
            try
            {
                var cacheKey = $"TempFiles_{userId}";
                var tempFolder = Path.Combine(Path.GetTempPath(), "PTVBTPM", "Uploads");
                
                if (_cache.TryGetValue(cacheKey, out List<string>? tempFiles) && tempFiles != null)
                {
                    int deletedCount = 0;
                    
                    foreach (var tempFileName in tempFiles)
                    {
                        try
                        {
                            var tempFilePath = Path.Combine(tempFolder, tempFileName);
                            
                            // Xóa file gốc
                            if (System.IO.File.Exists(tempFilePath))
                            {
                                System.IO.File.Delete(tempFilePath);
                                deletedCount++;
                                _logger.LogInformation($"Deleted temp file on logout: {tempFileName}");
                            }
                            
                            // Xóa PDF đã convert (nếu có) - cho DOCX
                            var fileExtension = Path.GetExtension(tempFileName).ToLowerInvariant();
                            if (fileExtension == ".docx")
                            {
                                var tempPdfPath = Path.ChangeExtension(tempFilePath, ".pdf");
                                if (System.IO.File.Exists(tempPdfPath))
                                {
                                    System.IO.File.Delete(tempPdfPath);
                                    _logger.LogInformation($"Deleted temp PDF on logout: {Path.GetFileName(tempPdfPath)}");
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, $"Failed to delete temp file on logout: {tempFileName}");
                        }
                    }
                    
                    // Remove cache entry
                    _cache.Remove(cacheKey);
                    
                    _logger.LogInformation($"Cleaned up {deletedCount} temp files for user {userId} on logout");
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, $"Error cleaning up temp files for user {userId}");
            }
        }

        /// <summary>
        /// Kiểm tra email có đuôi @siu.edu.vn không
        /// </summary>
        private static bool IsValidSiuEmail(string email)
        {
            if (string.IsNullOrWhiteSpace(email))
                return false;

            // Check if email ends with @siu.edu.vn (case insensitive)
            return email.Trim().EndsWith("@siu.edu.vn", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Validate và normalize role - chỉ cho phép STUDENT hoặc SPSO
        /// </summary>
        private static string ValidateAndNormalizeRole(string? role)
        {
            if (string.IsNullOrWhiteSpace(role))
                return "STUDENT"; // Default role

            var normalizedRole = role.Trim().ToUpper();
            
            // Chỉ cho phép STUDENT hoặc SPSO
            if (normalizedRole == "STUDENT" || normalizedRole == "SPSO")
                return normalizedRole;

            // Nếu role không hợp lệ, mặc định là STUDENT
            return "STUDENT";
        }

        // ========== TWO-FACTOR AUTHENTICATION ENDPOINTS ==========

        /// <summary>
        /// Get 2FA status for current user
        /// </summary>
        [HttpGet("2fa/status")]
        public async Task<IActionResult> Get2FAStatus()
        {
            var userId = AuthHelper.GetCurrentUserId(HttpContext);
            if (userId == null)
                return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                return NotFound(new { message = "Không tìm thấy người dùng." });

            return Ok(new TwoFactorStatusResponse
            {
                Enabled = user.TwoFactorEnabled,
                Method = user.TwoFactorMethod,
                EnabledAt = null, // PTVBTPM User entity doesn't have this field yet
                HasRecoveryCodes = !string.IsNullOrWhiteSpace(user.TwoFactorRecoveryCodes)
            });
        }

        /// <summary>
        /// Setup 2FA - Generate QR code for authenticator app
        /// </summary>
        [HttpPost("2fa/setup")]
        public async Task<IActionResult> Setup2FA([FromBody] Enable2FARequest? request)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                    return NotFound(new { message = "Không tìm thấy người dùng." });

                if (user.TwoFactorEnabled)
                    return BadRequest(new { message = "2FA đã được bật cho tài khoản này." });

                Console.WriteLine($"[2FA Setup] Starting 2FA setup for user: {user.Email}");

                // Use default method if not provided
                var method = request?.Method ?? "authenticator";

                // Generate secret and QR code
                var secret = _twoFactorAuthService.GenerateSecret();
                var qrCodeData = _twoFactorAuthService.GenerateQrCode(user.Email, secret, "PTVBTPM");

                Console.WriteLine($"[2FA Setup] Generated secret (first 10 chars): {secret.Substring(0, Math.Min(10, secret.Length))}...");

                // IMPORTANT: Save encrypted secret to DB immediately (not enabled yet)
                var encryptedSecret = _twoFactorAuthService.EncryptSecret(secret);
                user.TwoFactorSecret = encryptedSecret;
                user.TwoFactorMethod = method;
                user.TwoFactorEnabled = false; // Not enabled until verified
                user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                await _context.SaveChangesAsync();

                Console.WriteLine($"[2FA Setup] Secret saved to DB for user {user.Email}. Enabled: false");

                return Ok(qrCodeData);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[2FA Setup] Error setting up 2FA for user");
                Console.WriteLine($"[2FA Setup] Error: {ex.Message}");
                Console.WriteLine($"[2FA Setup] Stack trace: {ex.StackTrace}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"[2FA Setup] Inner exception: {ex.InnerException.Message}");
                    Console.WriteLine($"[2FA Setup] Inner stack trace: {ex.InnerException.StackTrace}");
                }
                return StatusCode(500, new { message = "Lỗi khi thiết lập 2FA.", error = ex.Message, innerError = ex.InnerException?.Message });
            }
        }

        /// <summary>
        /// Verify 2FA setup - Confirm the code from authenticator app
        /// </summary>
        [HttpPost("2fa/verify-setup")]
        public async Task<IActionResult> Verify2FASetup([FromBody] Verify2FASetupRequest? request)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                    return NotFound(new { message = "Không tìm thấy người dùng." });

                // Check if secret exists in DB (from setup step)
                if (string.IsNullOrWhiteSpace(user.TwoFactorSecret))
                {
                    Console.WriteLine($"[2FA Verify] No secret found in DB for user {user.Email}");
                    return BadRequest(new { message = "Chưa bắt đầu thiết lập 2FA. Vui lòng chạy setup trước." });
                }

                // Validate request
                if (request == null || string.IsNullOrWhiteSpace(request.Code))
                {
                    return BadRequest(new { message = "Mã xác thực không được để trống." });
                }

                Console.WriteLine($"[2FA Verify] User: {user.Email}, Secret exists in DB: true, Code: {request.Code}");

                // Decrypt secret from DB
                var encryptedSecret = user.TwoFactorSecret;
                var secret = _twoFactorAuthService.DecryptSecret(encryptedSecret);

                // Verify the code
                if (!_twoFactorAuthService.VerifyCode(secret, request.Code))
                {
                    Console.WriteLine($"[2FA Verify] Code verification failed for user {user.Email}");
                    return BadRequest(new { message = "Mã xác thực không hợp lệ. Vui lòng thử lại." });
                }

                // Code is valid - Enable 2FA and generate recovery codes
                var recoveryCodes = _twoFactorAuthService.GenerateRecoveryCodes();

                Console.WriteLine($"[2FA Verify] Code verified! Enabling 2FA for user {user.Email}");

                user.TwoFactorEnabled = true;
                user.TwoFactorRecoveryCodes = JsonSerializer.Serialize(recoveryCodes);
                user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                await _context.SaveChangesAsync();

                Console.WriteLine($"[2FA Verify] 2FA enabled successfully for user {user.Email}");

                return Ok(new Enable2FAResponse
                {
                    Success = true,
                    Message = "Xác thực hai yếu tố đã được bật thành công!",
                    RecoveryCodes = recoveryCodes
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[2FA Verify] Error verifying 2FA setup");
                Console.WriteLine($"[2FA Verify] Error: {ex.Message}");
                Console.WriteLine($"[2FA Verify] Stack trace: {ex.StackTrace}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"[2FA Verify] Inner exception: {ex.InnerException.Message}");
                    Console.WriteLine($"[2FA Verify] Inner stack trace: {ex.InnerException.StackTrace}");
                }
                return StatusCode(500, new { message = "Lỗi khi bật 2FA.", error = ex.Message, innerError = ex.InnerException?.Message });
            }
        }

        /// <summary>
        /// Disable 2FA - Requires password confirmation
        /// </summary>
        [HttpPost("2fa/disable")]
        public async Task<IActionResult> Disable2FA([FromBody] Disable2FARequest request)
        {
            var userId = AuthHelper.GetCurrentUserId(HttpContext);
            if (userId == null)
                return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                return NotFound(new { message = "Không tìm thấy người dùng." });

            if (!user.TwoFactorEnabled)
                return BadRequest(new { message = "2FA chưa được bật cho tài khoản này." });

            // Verify password
            if (!PasswordHelper.VerifyPassword(request.Password, user.PasswordHash))
                return BadRequest(new { message = "Mật khẩu không đúng." });

            // Disable 2FA
            user.TwoFactorEnabled = false;
            user.TwoFactorMethod = null;
            user.TwoFactorSecret = null;
            user.TwoFactorRecoveryCodes = null;
            user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

            await _context.SaveChangesAsync();

            return Ok(new { message = "Xác thực hai yếu tố đã được tắt." });
        }

        /// <summary>
        /// Verify 2FA code during login
        /// </summary>
        [HttpPost("2fa/verify-login")]
        public async Task<IActionResult> Verify2FALogin([FromBody] Verify2FALoginRequest request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());
            if (user == null)
                return BadRequest(new { message = "Yêu cầu không hợp lệ." });

            if (!user.TwoFactorEnabled)
                return BadRequest(new { message = "2FA chưa được bật cho tài khoản này." });

            bool isValid = false;
            string? updatedRecoveryCodes = null;

            if (request.UseRecoveryCode)
            {
                // Verify recovery code
                isValid = _twoFactorAuthService.VerifyRecoveryCode(
                    user.TwoFactorRecoveryCodes ?? "[]",
                    request.Code,
                    out updatedRecoveryCodes);

                if (isValid)
                {
                    // Update recovery codes (remove used one)
                    user.TwoFactorRecoveryCodes = updatedRecoveryCodes;
                    await _context.SaveChangesAsync();
                }
            }
            else
            {
                // Verify TOTP code
                var secret = _twoFactorAuthService.DecryptSecret(user.TwoFactorSecret ?? "");
                isValid = _twoFactorAuthService.VerifyCode(secret, request.Code);
            }

            if (!isValid)
                return BadRequest(new { message = "Mã xác thực không hợp lệ." });

            // Code is valid - Complete login
            HttpContext.Session.SetString("UserId", user.UserId.ToString());
            HttpContext.Session.SetString("Email", user.Email);
            HttpContext.Session.SetString("Role", user.Role);
            HttpContext.Session.SetString("FullName", user.FullName);
            HttpContext.Session.SetString("StudentCode", user.StudentCode ?? string.Empty);

            return Ok(new 
            { 
                Success = true,
                Message = "Đăng nhập thành công!", 
                User = new UserInfoDto
                {
                    UserId = user.UserId,
                    StudentCode = user.StudentCode ?? string.Empty,
                    FullName = user.FullName,
                    Email = user.Email,
                    Role = user.Role,
                    Status = user.Status
                },
                TwoFactorVerified = true
            });
        }

        /// <summary>
        /// Regenerate recovery codes
        /// </summary>
        [HttpPost("2fa/regenerate-recovery-codes")]
        public async Task<IActionResult> RegenerateRecoveryCodes()
        {
            var userId = AuthHelper.GetCurrentUserId(HttpContext);
            if (userId == null)
                return Unauthorized(new { message = "Vui lòng đăng nhập trước." });

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                return NotFound(new { message = "Không tìm thấy người dùng." });

            if (!user.TwoFactorEnabled)
                return BadRequest(new { message = "2FA chưa được bật cho tài khoản này." });

            // Generate new recovery codes
            var recoveryCodes = _twoFactorAuthService.GenerateRecoveryCodes();
            user.TwoFactorRecoveryCodes = JsonSerializer.Serialize(recoveryCodes);
            user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

            await _context.SaveChangesAsync();

            return Ok(new Enable2FAResponse
            {
                Success = true,
                Message = "Mã khôi phục đã được tạo lại thành công.",
                RecoveryCodes = recoveryCodes
            });
        }

        // ========== USER PROFILE UPDATE ENDPOINTS ==========

        /// <summary>
        /// Cập nhật thông tin cá nhân (FullName, DateOfBirth, Address, PhoneNumber, Avatar)
        /// </summary>
        [HttpPut("UpdateProfile")]
        [Consumes("multipart/form-data")]
        public async Task<ActionResult<AuthResponseDto>> UpdateProfile([FromForm] UpdateProfileRequestDto request)
        {
            try
            {
                var fullName = request.FullName;
                var dateOfBirth = request.DateOfBirth;
                var address = request.Address;
                var phoneNumber = request.PhoneNumber;
                var avatar = request.Avatar;

                // 1. Kiểm tra user đã đăng nhập
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng đăng nhập trước."
                    });
                }

                // 2. Tìm user trong DB
                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                {
                    return NotFound(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không tìm thấy người dùng."
                    });
                }

                // 3. Update các field nếu có giá trị
                bool hasChanges = false;

                if (!string.IsNullOrWhiteSpace(fullName))
                {
                    user.FullName = fullName.Trim();
                    hasChanges = true;
                }

                if (dateOfBirth.HasValue)
                {
                    user.DateOfBirth = dateOfBirth.Value;
                    hasChanges = true;
                }

                if (address != null) // Cho phép set null
                {
                    user.Address = string.IsNullOrWhiteSpace(address) ? null : address.Trim();
                    hasChanges = true;
                }

                if (phoneNumber != null) // Cho phép set null
                {
                    user.PhoneNumber = string.IsNullOrWhiteSpace(phoneNumber) ? null : phoneNumber.Trim();
                    hasChanges = true;
                }

                // 4. Handle avatar upload
                if (avatar != null && avatar.Length > 0)
                {
                    // Validate image file
                    var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
                    var fileExtension = Path.GetExtension(avatar.FileName).ToLowerInvariant();
                    if (!allowedExtensions.Contains(fileExtension))
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = $"Định dạng ảnh không được hỗ trợ. Chỉ chấp nhận: {string.Join(", ", allowedExtensions)}"
                        });
                    }

                    // Check file size (max 5MB)
                    const long maxFileSize = 5 * 1024 * 1024; // 5MB
                    if (avatar.Length > maxFileSize)
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = "Ảnh đại diện quá lớn. Kích thước tối đa là 5MB."
                        });
                    }

                    // Create Avt folder if not exists
                    var avtFolder = Path.Combine(_environment.WebRootPath, "Avt");
                    if (!Directory.Exists(avtFolder))
                    {
                        Directory.CreateDirectory(avtFolder);
                    }

                    // Xóa avatar cũ nếu có
                    if (!string.IsNullOrWhiteSpace(user.AvatarUrl))
                    {
                        try
                        {
                            var oldAvatarPath = Path.Combine(_environment.WebRootPath, user.AvatarUrl);
                            if (System.IO.File.Exists(oldAvatarPath))
                            {
                                System.IO.File.Delete(oldAvatarPath);
                                _logger.LogInformation($"Deleted old avatar: {user.AvatarUrl}");
                            }
                        }
                        catch (Exception delEx)
                        {
                            _logger.LogWarning(delEx, $"Failed to delete old avatar: {user.AvatarUrl}");
                        }
                    }

                    // Generate unique filename
                    var avatarFileName = $"{Guid.NewGuid()}{fileExtension}";
                    var avatarFilePath = Path.Combine(avtFolder, avatarFileName);

                    // Save avatar file
                    using (var stream = new FileStream(avatarFilePath, FileMode.Create))
                    {
                        await avatar.CopyToAsync(stream);
                    }

                    user.AvatarUrl = $"Avt/{avatarFileName}";
                    hasChanges = true;
                }

                if (!hasChanges)
                {
                    return BadRequest(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không có thông tin nào để cập nhật."
                    });
                }

                // 5. Update ModifiedOn và lưu
                user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                await _context.SaveChangesAsync();

                // 6. Update session nếu FullName thay đổi
                if (!string.IsNullOrWhiteSpace(fullName))
                {
                    HttpContext.Session.SetString("FullName", user.FullName);
                }

                _logger.LogInformation($"Profile updated for user: {user.Email}");

                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "Cập nhật thông tin cá nhân thành công.",
                    User = new UserInfoDto
                    {
                        UserId = user.UserId,
                        StudentCode = user.StudentCode ?? string.Empty,
                        FullName = user.FullName,
                        Email = user.Email,
                        EmailConfirmed = user.EmailConfirmed,
                        Role = user.Role,
                        Status = user.Status,
                        AvatarUrl = user.AvatarUrl,
                        DateOfBirth = user.DateOfBirth,
                        Address = user.Address,
                        PhoneNumber = user.PhoneNumber
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during update profile");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi cập nhật thông tin cá nhân"
                });
            }
        }

        /// <summary>
        /// Cập nhật trạng thái 2FA (enable/disable)
        /// </summary>
        [HttpPut("Update2FA")]
        public async Task<ActionResult<AuthResponseDto>> Update2FA([FromBody] Update2FARequestDto request)
        {
            try
            {
                // 1. Kiểm tra user đã đăng nhập
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                {
                    return Unauthorized(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Vui lòng đăng nhập trước."
                    });
                }

                // 2. Tìm user trong DB
                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                {
                    return NotFound(new AuthResponseDto
                    {
                        Success = false,
                        Message = "Không tìm thấy người dùng."
                    });
                }

                // 3. Nếu enable 2FA
                if (request.Enable)
                {
                    // Kiểm tra 2FA đã được bật chưa
                    if (user.TwoFactorEnabled)
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = "2FA đã được bật cho tài khoản này."
                        });
                    }

                    // Kiểm tra đã có secret chưa (đã setup trước đó)
                    if (string.IsNullOrWhiteSpace(user.TwoFactorSecret))
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = "Chưa thiết lập 2FA. Vui lòng sử dụng API /2fa/setup để thiết lập trước."
                        });
                    }

                    // Validate method nếu có
                    if (!string.IsNullOrWhiteSpace(request.Method))
                    {
                        var normalizedMethod = request.Method.Trim().ToLower();
                        if (normalizedMethod != "authenticator" && normalizedMethod != "email" && normalizedMethod != "both")
                        {
                            return BadRequest(new AuthResponseDto
                            {
                                Success = false,
                                Message = "Phương thức 2FA không hợp lệ. Chỉ chấp nhận: authenticator, email, both."
                            });
                        }
                        user.TwoFactorMethod = normalizedMethod;
                    }

                    // Enable 2FA (nếu đã có secret từ lần setup trước)
                    user.TwoFactorEnabled = true;
                    
                    // Generate recovery codes nếu chưa có
                    if (string.IsNullOrWhiteSpace(user.TwoFactorRecoveryCodes))
                    {
                        var recoveryCodes = _twoFactorAuthService.GenerateRecoveryCodes();
                        user.TwoFactorRecoveryCodes = JsonSerializer.Serialize(recoveryCodes);
                    }

                    user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                    await _context.SaveChangesAsync();

                    _logger.LogInformation($"2FA enabled for user: {user.Email}");

                    return Ok(new AuthResponseDto
                    {
                        Success = true,
                        Message = "Đã bật xác thực hai yếu tố (2FA) thành công."
                    });
                }
                else
                {
                    // Disable 2FA
                    if (!user.TwoFactorEnabled)
                    {
                        return BadRequest(new AuthResponseDto
                        {
                            Success = false,
                            Message = "2FA chưa được bật cho tài khoản này."
                        });
                    }

                    // Disable 2FA
                    user.TwoFactorEnabled = false;
                    user.TwoFactorMethod = null;
                    user.TwoFactorSecret = null;
                    user.TwoFactorRecoveryCodes = null;
                    user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                    await _context.SaveChangesAsync();

                    _logger.LogInformation($"2FA disabled for user: {user.Email}");

                    return Ok(new AuthResponseDto
                    {
                        Success = true,
                        Message = "Đã tắt xác thực hai yếu tố (2FA) thành công."
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during update 2FA");
                return StatusCode(500, new AuthResponseDto
                {
                    Success = false,
                    Message = "Lỗi hệ thống khi cập nhật 2FA"
                });
            }
        }
    }
}

