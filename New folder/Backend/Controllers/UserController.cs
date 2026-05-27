using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;
using PTVBTPM.Services;
using System.Collections.Generic;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    public class UserController : ControllerBase
    {
        private readonly HooksService _hooksService;
        private readonly WebDbContext _context;
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<UserController> _logger;

        public UserController(HooksService hooksService, WebDbContext context, IWebHostEnvironment environment, ILogger<UserController> logger)
        {
            _hooksService = hooksService;
            _context = context;
            _environment = environment;
            _logger = logger;
        }

        [HttpGet("All")]
        public async Task<ActionResult<List<UserInfoDto>>> All()
        {
            var users = await _hooksService.GetAllUsersAsync();
            var result = new List<UserInfoDto>();
            foreach (var user in users)
            {
                result.Add(await ToUserInfoAsync(user, _context));
            }
            return Ok(new { success = true, data = result });
        }

        [HttpGet("GetUser/{id}")]
        public async Task<ActionResult<UserInfoDto>> GetUser(int id)
        {
            var user = await _hooksService.GetUserByIdAsync(id);
            if (user == null) return NotFound();
            return Ok(new { success = true, data = await ToUserInfoAsync(user, _context) });
        }

        [HttpPost("AddUser")]
        public async Task<ActionResult<UserInfoDto>> AddUser([FromBody] UserUpsertDto user)
        {
            if (string.IsNullOrWhiteSpace(user.Password))
                return BadRequest("Password is required.");

            // Debug logging
            Console.WriteLine($"AddUser received: PhoneNumber={user.PhoneNumber}, FullName={user.FullName}");

            // Validate role
            var normalizedRole = ValidateAndNormalizeRole(user.Role);
            if (normalizedRole == null)
                return BadRequest("Role must be either 'STUDENT' or 'SPSO'.");

            // Generate code if not provided
            string studentCode = user.StudentCode;
            if (string.IsNullOrWhiteSpace(studentCode))
            {
                studentCode = await GenerateStudentCodeAsync(_context, normalizedRole);
            }

            // Check if email already exists
            var existingUser = await _context.Users
                .FirstOrDefaultAsync(u => u.Email.ToLower() == user.Email.ToLower());
            if (existingUser != null)
                return BadRequest("Email đã tồn tại trong hệ thống.");

            // Check if student code already exists
            var existingCodeUser = await _context.Users
                .FirstOrDefaultAsync(u => u.StudentCode == studentCode);
            if (existingCodeUser != null)
                return BadRequest("Mã sinh viên/quản trị viên đã tồn tại trong hệ thống.");

            // PostgreSQL column type is "timestamp without time zone" -> use Kind=Unspecified
            var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

            var entity = new User
            {
                StudentCode = studentCode,
                FullName = user.FullName,
                Email = user.Email,
                PasswordHash = PasswordHelper.HashPassword(user.Password),
                Role = normalizedRole,
                Status = string.IsNullOrWhiteSpace(user.Status) ? "ACTIVE" : user.Status.ToUpper(),
                PhoneNumber = string.IsNullOrWhiteSpace(user.PhoneNumber) ? null : user.PhoneNumber,
                Address = string.IsNullOrWhiteSpace(user.Address) ? null : user.Address,
                AvatarUrl = string.IsNullOrWhiteSpace(user.AvatarUrl) ? null : user.AvatarUrl,
                DateOfBirth = user.DateOfBirth,
                PageDefaultBalance = (normalizedRole == "STUDENT" || normalizedRole == "SPSO") ? 40 : 0, // Default 40 pages for students and admins
                PagePurchasedBalance = 0, // Start with 0 purchased pages
                EmailConfirmed = user.ConfirmEmail.HasValue ? user.ConfirmEmail.Value : true, // Admin-created users default confirmed
                CreatedOn = now,
                ModifiedOn = now
            };

            var created = await _hooksService.CreateUserAsync(entity);
            return Ok(new { success = true, data = await ToUserInfoAsync(created, _context) });
        }

        [HttpPut("UpdateUser/{id}")]
        public async Task<ActionResult<UserInfoDto>> UpdateUser(int id, [FromBody] UserUpsertDto user)
        {
            // Validate role if provided
            string? normalizedRole = null;
            if (!string.IsNullOrWhiteSpace(user.Role))
            {
                normalizedRole = ValidateAndNormalizeRole(user.Role);
                if (normalizedRole == null)
                    return BadRequest("Role must be either 'STUDENT' or 'SPSO'.");
            }

            // Check if email already exists (excluding current user)
            if (!string.IsNullOrWhiteSpace(user.Email))
            {
                var existingUser = await _context.Users
                    .FirstOrDefaultAsync(u => u.Email.ToLower() == user.Email.ToLower() && u.UserId != id);
                if (existingUser != null)
                    return BadRequest("Email đã tồn tại trong hệ thống.");
            }

            // Check if student code already exists (if provided and changed)
            if (!string.IsNullOrWhiteSpace(user.StudentCode))
            {
                var existingCodeUser = await _context.Users
                    .FirstOrDefaultAsync(u => u.StudentCode == user.StudentCode && u.UserId != id);
                if (existingCodeUser != null)
                    return BadRequest("Mã sinh viên/quản trị viên đã tồn tại trong hệ thống.");
            }

            var now = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

            var entity = new User
            {
                StudentCode = user.StudentCode,
                FullName = user.FullName,
                Email = user.Email,
                PasswordHash = string.IsNullOrWhiteSpace(user.Password) ? string.Empty : PasswordHelper.HashPassword(user.Password),
                Role = normalizedRole ?? string.Empty, // Will be updated only if provided
                Status = string.IsNullOrWhiteSpace(user.Status) ? "ACTIVE" : user.Status.ToUpper(),
                PhoneNumber = user.PhoneNumber,
                Address = user.Address,
                AvatarUrl = user.AvatarUrl,
                DateOfBirth = user.DateOfBirth,
                ModifiedOn = now
            };

            var updated = await _hooksService.UpdateUserAsync(id, entity);
            if (updated == null) return NotFound();
            return Ok(new { success = true, data = await ToUserInfoAsync(updated, _context) });
        }

        /// <summary>
        /// Add paper to user's default balance (admin only)
        /// </summary>
        [HttpPost("AddPaper/{id}")]
        public async Task<ActionResult<UserInfoDto>> AddPaper(int id, [FromBody] AddPaperDto request)
        {
            if (!ModelState.IsValid)
                return BadRequest(new { success = false, message = "Dữ liệu không hợp lệ.", errors = ModelState.Values.SelectMany(v => v.Errors.Select(e => e.ErrorMessage)) });

            var user = await _hooksService.GetUserByIdAsync(id);
            if (user == null)
                return NotFound(new { success = false, message = "Không tìm thấy người dùng." });

            // Update paper balance
            user.PageDefaultBalance += request.PaperCount;
            user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

            var updated = await _hooksService.UpdateUserAsync(id, user);
            if (updated == null)
                return BadRequest(new { success = false, message = "Không thể cập nhật số giấy." });

            return Ok(new { success = true, data = await ToUserInfoAsync(updated, _context), message = $"Đã thêm {request.PaperCount} tờ giấy thành công." });
        }

        /// <summary>
        /// Upload avatar for a specific user (admin)
        /// </summary>
        [HttpPost("UploadAvatar/{id}")] 
        public async Task<IActionResult> UploadAvatar(int id, IFormFile avatar)
        {
            try
            {
                if (avatar == null || avatar.Length == 0)
                {
                    return BadRequest(new { success = false, message = "Vui lòng chọn file ảnh để upload." });
                }

                var user = await _hooksService.GetUserByIdAsync(id);
                if (user == null) return NotFound(new { success = false, message = "Không tìm thấy người dùng." });

                // Validate file type
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
                var fileExtension = Path.GetExtension(avatar.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(fileExtension))
                {
                    return BadRequest(new { success = false, message = $"Định dạng ảnh không được hỗ trợ. Chỉ chấp nhận: {string.Join(", ", allowedExtensions)}" });
                }

                // Check file size (max 5MB)
                const long maxFileSize = 5 * 1024 * 1024;
                if (avatar.Length > maxFileSize)
                {
                    return BadRequest(new { success = false, message = "Ảnh quá lớn. Kích thước tối đa là 5MB." });
                }

                // Save to Avt folder under wwwroot
                var avtFolder = Path.Combine(_environment.WebRootPath, "Avt");
                if (!Directory.Exists(avtFolder))
                    Directory.CreateDirectory(avtFolder);

                // Delete old avatar if exists
                if (!string.IsNullOrWhiteSpace(user.AvatarUrl))
                {
                    try
                    {
                        var oldPath = Path.Combine(_environment.WebRootPath, user.AvatarUrl);
                        if (System.IO.File.Exists(oldPath))
                        {
                            System.IO.File.Delete(oldPath);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Failed to delete old avatar for user {id}");
                    }
                }

                var avatarFileName = $"{Guid.NewGuid()}{fileExtension}";
                var avatarFilePath = Path.Combine(avtFolder, avatarFileName);
                using (var stream = new FileStream(avatarFilePath, FileMode.Create))
                {
                    await avatar.CopyToAsync(stream);
                }

                // Update user's AvatarUrl
                user.AvatarUrl = $"Avt/{avatarFileName}";
                user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
                await _hooksService.UpdateUserAsync(user.UserId, user);

                return Ok(new { success = true, data = new { avatarUrl = user.AvatarUrl }, message = "Upload avatar thành công." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error uploading avatar");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi upload avatar." });
            }
        }

        /// <summary>
        /// Upload avatar (temporary or before user exists) - returns avatarUrl saved under Avt/
        /// </summary>
        [HttpPost("UploadAvatarTemp")]
        public async Task<IActionResult> UploadAvatarTemp(IFormFile avatar)
        {
            try
            {
                if (avatar == null || avatar.Length == 0)
                {
                    return BadRequest(new { success = false, message = "Vui lòng chọn file ảnh để upload." });
                }

                // Validate file type
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
                var fileExtension = Path.GetExtension(avatar.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(fileExtension))
                {
                    return BadRequest(new { success = false, message = $"Định dạng ảnh không được hỗ trợ. Chỉ chấp nhận: {string.Join(", ", allowedExtensions)}" });
                }

                // Check file size (max 5MB)
                const long maxFileSize = 5 * 1024 * 1024;
                if (avatar.Length > maxFileSize)
                {
                    return BadRequest(new { success = false, message = "Ảnh quá lớn. Kích thước tối đa là 5MB." });
                }

                // Save to Avt folder under wwwroot
                var avtFolder = Path.Combine(_environment.WebRootPath, "Avt");
                if (!Directory.Exists(avtFolder))
                    Directory.CreateDirectory(avtFolder);

                var avatarFileName = $"{Guid.NewGuid()}{fileExtension}";
                var avatarFilePath = Path.Combine(avtFolder, avatarFileName);
                using (var stream = new FileStream(avatarFilePath, FileMode.Create))
                {
                    await avatar.CopyToAsync(stream);
                }

                var avatarUrl = $"Avt/{avatarFileName}";
                return Ok(new { success = true, data = new { avatarUrl }, message = "Upload avatar thành công." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error uploading temp avatar");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi upload avatar." });
            }
        }

        [HttpDelete("DeleteUser/{id}")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            // Change behavior: instead of physically deleting the user, mark as INACTIVE (vô hiệu hóa)
            var user = await _hooksService.GetUserByIdAsync(id);
            if (user == null) return NotFound(new { success = false, message = "Không tìm thấy người dùng." });

            user.Status = "INACTIVE";
            user.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
            var updated = await _hooksService.UpdateUserAsync(id, user);
            if (updated == null) return NotFound(new { success = false, message = "Không thể cập nhật trạng thái người dùng." });

            return Ok(new { success = true, message = "Người dùng đã được vô hiệu hóa." });
        }

        /// <summary>
        /// Get pages balances for provided user ids (csv param ids)
        /// Returns: [{ userId, defaultBalance, purchaseBalance, total }, ...]
        /// </summary>
        [HttpGet("PagesBalances")]
        public async Task<IActionResult> PagesBalances([FromQuery] string ids)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(ids)) return BadRequest(new { success = false, message = "ids parameter required" });
                var idList = ids.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(s => int.TryParse(s, out var v) ? v : (int?)null).Where(i => i.HasValue).Select(i => i!.Value).ToList();
                var balances = await _hooksService.GetPagesBalancesAsync(idList);
                return Ok(new { success = true, data = balances });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in PagesBalances");
                return StatusCode(500, new { success = false, message = "Lỗi khi lấy số dư trang" });
            }
        }

        /// <summary>
        /// Get last activity (last login) for provided user ids (csv param ids)
        /// Returns: [{ userId, lastLogin, lastActive }, ...]
        /// </summary>
        [HttpGet("LastActivity")]
        public async Task<IActionResult> LastActivity([FromQuery] string ids)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(ids)) return BadRequest(new { success = false, message = "ids parameter required" });
                var idList = ids.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(s => int.TryParse(s, out var v) ? v : (int?)null).Where(i => i.HasValue).Select(i => i!.Value).ToList();
                var activities = await _hooksService.GetLastActivityAsync(idList);
                return Ok(new { success = true, data = activities });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in LastActivity");
                return StatusCode(500, new { success = false, message = "Lỗi khi lấy hoạt động gần nhất" });
            }
        }

        /// <summary>
        /// Create a login log entry (success, failed password, locked)
        /// </summary>
        [HttpPost("LogLogin")]
        public async Task<IActionResult> LogLogin([FromBody] Models.DTOs.LoginLogCreateDto dto)
        {
            try
            {
                if (dto == null) return BadRequest(new { success = false, message = "Payload required" });
                var history = new LoginHistory
                {
                    UserId = dto.UserId,
                    LoginTime = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified),
                    IpAddress = string.IsNullOrWhiteSpace(dto.IpAddress) ? HttpContext.Connection.RemoteIpAddress?.ToString() : dto.IpAddress,
                    Device = dto.Device ?? dto.EventType,
                    Description = dto.Message,
                    CreatedBy = "SYSTEM",
                };

                await _hooksService.AddLoginHistoryAsync(history);

                return Ok(new { success = true, data = history });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in LogLogin");
                return StatusCode(500, new { success = false, message = "Lỗi khi ghi log đăng nhập" });
            }
        }

        /// <summary>
        /// Validate và normalize role - chỉ cho phép STUDENT hoặc SPSO
        /// </summary>
        private static string? ValidateAndNormalizeRole(string? role)
        {
            if (string.IsNullOrWhiteSpace(role))
                return "STUDENT"; // Default role

            var normalizedRole = role.Trim().ToUpper();
            
            // Chỉ cho phép STUDENT hoặc SPSO
            if (normalizedRole == "STUDENT" || normalizedRole == "SPSO")
                return normalizedRole;

            // Nếu role không hợp lệ, trả về null để báo lỗi
            return null;
        }

        private static async Task<string> GenerateStudentCodeAsync(WebDbContext context, string role)
        {
            // Generate code format based on role:
            // STUDENT: SV + YYYY + 3-digit sequential number
            // SPSO: QTV + YYYY + 3-digit sequential number
            var currentYear = DateTime.Now.Year;
            var prefix = role == "STUDENT" ? $"SV{currentYear}" : $"QTV{currentYear}";

            // Find the highest existing code for current year and role
            var lastCode = await context.Users
                .Where(u => u.Role == role && u.StudentCode != null && u.StudentCode.StartsWith(prefix))
                .OrderByDescending(u => u.StudentCode)
                .Select(u => u.StudentCode)
                .FirstOrDefaultAsync();

            int nextNumber = 1;
            if (!string.IsNullOrEmpty(lastCode))
            {
                // Extract the number part after the prefix
                var numberPart = lastCode.Substring(prefix.Length);
                if (int.TryParse(numberPart, out int lastNumber))
                {
                    nextNumber = lastNumber + 1;
                }
            }

            // Format with 3 digits (001, 002, etc.)
            return $"{prefix}{nextNumber:D3}";
        }

        private static async Task<UserInfoDto> ToUserInfoAsync(User user, WebDbContext context)
        {
            // Lấy system config để biết storage limit
            var systemConfig = await context.SystemConfigs.FirstOrDefaultAsync();
            long storageLimitMb = systemConfig?.StorageLimitMb ?? 1024; // default 1GB

            // Tính tổng storage đã sử dụng (MB) - chuyển từ bytes sang MB
            var totalUsedBytes = await context.Documents
                .Where(d => d.UserId == user.UserId && d.FileSize.HasValue)
                .SumAsync(d => d.FileSize.Value);
            double usedStorageMb = Math.Round(totalUsedBytes / (1024.0 * 1024.0), 1); // bytes -> MB, làm tròn 1 chữ số

            return new UserInfoDto
            {
                UserId = user.UserId,
                StudentCode = user.StudentCode,
                FullName = user.FullName,
                Email = user.Email,
                EmailConfirmed = user.EmailConfirmed,
                Role = user.Role,
                Status = user.Status,
                AvatarUrl = user.AvatarUrl,
                DateOfBirth = user.DateOfBirth,
                Address = user.Address,
                PhoneNumber = user.PhoneNumber,
                StorageDefaultBalance = storageLimitMb,
                StoragePurchasedBalance = user.StoragePurchasedBalance,
                UsedStorageMb = usedStorageMb,
                TotalStorageLimitMb = storageLimitMb + user.StoragePurchasedBalance
            };
        }
    }
}
