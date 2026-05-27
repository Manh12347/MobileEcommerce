using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.AspNetCore.Hosting;
using PTVBTPM.Helper;
using PTVBTPM.Models.DTOs;
using PTVBTPM.Models.Entities;

namespace PTVBTPM.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    [Produces("application/json")]
    public class SystemConfigController : ControllerBase
    {
        private readonly WebDbContext _context;
        private readonly ILogger<SystemConfigController> _logger;
        private readonly IMemoryCache _cache;
        private readonly IWebHostEnvironment _environment;

        public SystemConfigController(WebDbContext context, ILogger<SystemConfigController> logger, IMemoryCache cache, IWebHostEnvironment environment)
        {
            _context = context;
            _logger = logger;
            _cache = cache;
            _environment = environment;
        }

        /// <summary>
        /// Lấy URL ảnh background cho trang login (public - không yêu cầu đăng nhập)
        /// </summary>
        [HttpGet("BackgroundImage")]
        [AllowAnonymous]
        [ProducesResponseType(200)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetBackgroundImage()
        {
            try
            {
                // Lấy config (chỉ có 1 record với ConfigId = 1)
                var config = await _context.SystemConfigs
                    .FirstOrDefaultAsync(c => c.ConfigId == 1);

                if (config != null && !string.IsNullOrWhiteSpace(config.PictureUrl))
                {
                    return Ok(new
                    {
                        success = true,
                        data = new
                        {
                            backgroundUrl = config.PictureUrl
                        }
                    });
                }

                // Nếu chưa có config hoặc không có PictureUrl, trả về ảnh mặc định
                return Ok(new
                {
                    success = true,
                    data = new
                    {
                        backgroundUrl = "Uploads/589570862_1286011440226060_1876511563312467239_n.jpg"
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting background image");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy ảnh background.", error = ex.Message });
            }
        }

        /// <summary>
        /// Lấy cấu hình mật khẩu (public - không yêu cầu đăng nhập)
        /// </summary>
        [HttpGet("PasswordConfig")]
        [AllowAnonymous]
        [ProducesResponseType(200)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetPasswordConfig()
        {
            try
            {
                // Lấy config (chỉ có 1 record với ConfigId = 1)
                var config = await _context.SystemConfigs
                    .FirstOrDefaultAsync(c => c.ConfigId == 1);

                if (config == null)
                {
                    // Nếu chưa có config trong DB, trả về lỗi
                    return StatusCode(500, new { success = false, message = "Hệ thống chưa được cấu hình. Vui lòng liên hệ Admin để thiết lập cấu hình hệ thống." });
                }

                return Ok(new
                {
                    success = true,
                    data = new
                    {
                        minPasswordLength = config?.MinPasswordLength ?? 8,
                        requirePasswordFormat = config?.RequirePasswordFormat ?? true
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting password config");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy cấu hình mật khẩu.", error = ex.Message });
            }
        }


        /// <summary>
        /// Lấy cấu hình hệ thống (admin/SPSO) hoặc chỉ tên hệ thống (student)
        /// </summary>
        [HttpGet]
        [ProducesResponseType(typeof(SystemConfigDto), 200)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> GetSystemConfig()
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                    return Unauthorized(new { success = false, message = "Người dùng không tồn tại." });

                var isAdminOrSpso = user.Role?.ToUpper() == "ADMIN" || user.Role?.ToUpper() == "SPSO";

                // Lấy config (chỉ có 1 record với ConfigId = 1)
                var config = await _context.SystemConfigs
                    .FirstOrDefaultAsync(c => c.ConfigId == 1);

                if (config == null)
                {
                    // Nếu chưa có config trong DB
                    if (isAdminOrSpso)
                    {
                        // Admin/SPSO nhận thông báo cần khởi tạo
                        return Ok(new
                        {
                            success = true,
                            data = new
                            {
                                needsInitialization = true,
                                message = "Hệ thống chưa được cấu hình. Vui lòng khởi tạo cấu hình hệ thống trước."
                            }
                        });
                    }
                    else
                    {
                        // Student nhận thông báo hệ thống đang bảo trì
                        return Ok(new
                        {
                            success = true,
                            data = new
                            {
                                systemName = "Hệ thống đang được cấu hình",
                                maintenanceMode = true
                            }
                        });
                    }
                }

                if (!isAdminOrSpso)
                {
                    // STUDENT chỉ nhận systemName
                    return Ok(new
                    {
                        success = true,
                        data = new
                        {
                            systemName = config.SystemName
                        }
                    });
                }

                var dto = new SystemConfigDto
                {
                    ConfigId = config.ConfigId,
                    SystemName = config.SystemName,
                    MaintenanceMode = config.MaintenanceMode,
                    MaxFileSize = config.MaxFileSize,
                    AllowedFileFormats = config.AllowedFileFormats,
                    DefaultPagesForStudent = config.DefaultPagesForStudent,
                    PaperPrice = config.PaperPrice,
                    PageFactor = config.PageFactor,
                    AutoAssignPages = config.AutoAssignPages,
                    AutoAssignDays = config.AutoAssignDays,
                    AutoAssignDayOfMonth = config.AutoAssignDayOfMonth,
                    SessionTimeoutMinutes = config.SessionTimeoutMinutes,
                    MaxLoginAttempts = config.MaxLoginAttempts,
                    MinPasswordLength = config.MinPasswordLength,
                    RequirePasswordFormat = config.RequirePasswordFormat,
                    StorageLimitMb = config.StorageLimitMb,
                    StoragePricePerMb = config.StoragePricePerMb,
                    DefaultAdditionalPaper = config.DefaultAdditionalPaper,
                    PictureUrl = config.PictureUrl,
                    PageDefaultCreate = config.PageDefaultCreate
                };

                return Ok(new { success = true, data = dto });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting system config");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi lấy cấu hình.", error = ex.Message });
            }
        }

        /// <summary>
        /// Khởi tạo cấu hình hệ thống ban đầu (chỉ dùng khi chưa có config)
        /// </summary>
        [HttpPost("Initialize")]
        [ProducesResponseType(typeof(SystemConfigDto), 201)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(409)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> InitializeSystemConfig([FromBody] UpdateSystemConfigDto initDto)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                // Kiểm tra quyền admin
                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền khởi tạo cấu hình hệ thống." });

                // Kiểm tra xem đã có config chưa
                var existingConfig = await _context.SystemConfigs
                    .FirstOrDefaultAsync(c => c.ConfigId == 1);

                if (existingConfig != null)
                {
                    return Conflict(new { success = false, message = "Hệ thống đã được cấu hình. Sử dụng PUT để cập nhật." });
                }

                // Validate required fields
                if (string.IsNullOrWhiteSpace(initDto.SystemName))
                    return BadRequest(new { success = false, message = "Tên hệ thống là bắt buộc." });
                if (!initDto.MaxFileSize.HasValue || initDto.MaxFileSize.Value <= 0)
                    return BadRequest(new { success = false, message = "Kích thước file tối đa phải lớn hơn 0." });
                if (string.IsNullOrWhiteSpace(initDto.AllowedFileFormats))
                    return BadRequest(new { success = false, message = "Định dạng file cho phép là bắt buộc." });
                if (!initDto.DefaultPagesForStudent.HasValue || initDto.DefaultPagesForStudent.Value < 0)
                    return BadRequest(new { success = false, message = "Số trang mặc định cho sinh viên phải là số không âm." });
                if (!initDto.PaperPrice.HasValue || initDto.PaperPrice.Value <= 0)
                    return BadRequest(new { success = false, message = "Giá giấy phải lớn hơn 0." });
                if (!initDto.PageFactor.HasValue || initDto.PageFactor.Value < 0)
                    return BadRequest(new { success = false, message = "Hệ số phân trang phải là số không âm." });
                if (string.IsNullOrWhiteSpace(initDto.AutoAssignDays))
                    return BadRequest(new { success = false, message = "Các mốc ngày cấp giấy là bắt buộc." });
                if (!initDto.SessionTimeoutMinutes.HasValue || initDto.SessionTimeoutMinutes.Value <= 0)
                    return BadRequest(new { success = false, message = "Thời gian hết phiên phải lớn hơn 0." });
                if (!initDto.MaxLoginAttempts.HasValue || initDto.MaxLoginAttempts.Value <= 0)
                    return BadRequest(new { success = false, message = "Số lần nhập sai tối đa phải lớn hơn 0." });
                if (!initDto.MinPasswordLength.HasValue || initDto.MinPasswordLength.Value < 6)
                    return BadRequest(new { success = false, message = "Độ dài mật khẩu tối thiểu phải từ 6 ký tự trở lên." });
                if (!initDto.StorageLimitMb.HasValue || initDto.StorageLimitMb.Value < 0)
                    return BadRequest(new { success = false, message = "Giới hạn lưu trữ phải là số không âm (MB)." });
                if (!initDto.StoragePricePerMb.HasValue || initDto.StoragePricePerMb.Value < 0)
                    return BadRequest(new { success = false, message = "Giá mỗi MB phải là số không âm (VNĐ/MB)." });
                if (!initDto.DefaultAdditionalPaper.HasValue || initDto.DefaultAdditionalPaper.Value < 0)
                    return BadRequest(new { success = false, message = "Số giấy thêm mặc định phải là số không âm." });
                if (!initDto.PageDefaultCreate.HasValue || initDto.PageDefaultCreate.Value < 0)
                    return BadRequest(new { success = false, message = "Số trang giấy mặc định cấp cho tài khoản mới phải là số không âm." });
                if (!initDto.AutoAssignDayOfMonth.HasValue || initDto.AutoAssignDayOfMonth.Value < 1 || initDto.AutoAssignDayOfMonth.Value > 31)
                    return BadRequest(new { success = false, message = "Ngày tạo báo cáo tự động phải từ 1 đến 31." });
                // PictureUrl có thể null (không bắt buộc)

                // Validate AutoAssignDays format
                var parts = initDto.AutoAssignDays.Split(';', System.StringSplitOptions.RemoveEmptyEntries);
                foreach (var p in parts)
                {
                    var seg = p.Trim();
                    if (string.IsNullOrEmpty(seg)) continue;
                    var dm = seg.Split('/');
                    if (dm.Length != 2
                        || !int.TryParse(dm[0], out var d)
                        || !int.TryParse(dm[1], out var m)
                        || d < 1 || d > 31
                        || m < 1 || m > 12)
                    {
                        return BadRequest(new { success = false, message = "AutoAssignDays phải có định dạng 'd/m;d/m' với ngày 1-31 và tháng 1-12." });
                    }
                }

                // Tạo config mới
                var newConfig = new SystemConfig
                {
                    ConfigId = 1,
                    SystemName = initDto.SystemName,
                    MaintenanceMode = initDto.MaintenanceMode ?? false,
                    MaxFileSize = initDto.MaxFileSize.Value,
                    AllowedFileFormats = initDto.AllowedFileFormats,
                    DefaultPagesForStudent = initDto.DefaultPagesForStudent.Value,
                    PaperPrice = initDto.PaperPrice.Value,
                    PageFactor = initDto.PageFactor.Value,
                    AutoAssignPages = initDto.AutoAssignPages ?? true,
                    AutoAssignDays = initDto.AutoAssignDays,
                    AutoAssignDayOfMonth = initDto.AutoAssignDayOfMonth.Value,
                    SessionTimeoutMinutes = initDto.SessionTimeoutMinutes.Value,
                    MaxLoginAttempts = initDto.MaxLoginAttempts.Value,
                    MinPasswordLength = initDto.MinPasswordLength.Value,
                    RequirePasswordFormat = initDto.RequirePasswordFormat ?? true,
                    StorageLimitMb = initDto.StorageLimitMb.Value,
                    StoragePricePerMb = initDto.StoragePricePerMb.Value,
                    DefaultAdditionalPaper = initDto.DefaultAdditionalPaper.Value,
                    PictureUrl = initDto.PictureUrl,
                    PageDefaultCreate = initDto.PageDefaultCreate.Value,
                    CreatedBy = user.StudentCode ?? "ADMIN",
                    CreatedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified)
                };

                _context.SystemConfigs.Add(newConfig);
                await _context.SaveChangesAsync();

                // Invalidate cache
                SystemConfigHelper.InvalidateCache(_cache);

                _logger.LogInformation($"System config initialized by user {userId}.");

                var dto = new SystemConfigDto
                {
                    ConfigId = newConfig.ConfigId,
                    SystemName = newConfig.SystemName,
                    MaintenanceMode = newConfig.MaintenanceMode,
                    MaxFileSize = newConfig.MaxFileSize,
                    AllowedFileFormats = newConfig.AllowedFileFormats,
                    DefaultPagesForStudent = newConfig.DefaultPagesForStudent,
                    PaperPrice = newConfig.PaperPrice,
                    PageFactor = newConfig.PageFactor,
                    AutoAssignPages = newConfig.AutoAssignPages,
                    AutoAssignDays = newConfig.AutoAssignDays,
                    SessionTimeoutMinutes = newConfig.SessionTimeoutMinutes,
                    MaxLoginAttempts = newConfig.MaxLoginAttempts,
                    MinPasswordLength = newConfig.MinPasswordLength,
                    RequirePasswordFormat = newConfig.RequirePasswordFormat,
                    StorageLimitMb = newConfig.StorageLimitMb,
                    StoragePricePerMb = newConfig.StoragePricePerMb,
                    DefaultAdditionalPaper = newConfig.DefaultAdditionalPaper,
                    PictureUrl = newConfig.PictureUrl,
                    PageDefaultCreate = newConfig.PageDefaultCreate
                };

                return StatusCode(201, new { success = true, message = "Đã khởi tạo cấu hình hệ thống thành công.", data = dto });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error initializing system config");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi khởi tạo cấu hình.", error = ex.Message });
            }
        }

        /// <summary>
        /// Upload ảnh background cho hệ thống
        /// </summary>
        [HttpPost("UploadBackground")]
        [ProducesResponseType(200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> UploadBackgroundImage(IFormFile background)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                // Kiểm tra quyền admin
                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền upload ảnh background." });

                if (background == null || background.Length == 0)
                    return BadRequest(new { success = false, message = "Vui lòng chọn file ảnh để upload." });

                // Validate file type
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp" };
                var fileExtension = Path.GetExtension(background.FileName).ToLower();
                if (!allowedExtensions.Contains(fileExtension))
                    return BadRequest(new { success = false, message = "Chỉ cho phép upload file ảnh (jpg, jpeg, png, gif, bmp, webp)." });

                // Validate file size (max 5MB)
                if (background.Length > 5 * 1024 * 1024)
                    return BadRequest(new { success = false, message = "Kích thước file không được vượt quá 5MB." });

                // Tạo thư mục Uploads nếu chưa có
                var uploadsFolder = Path.Combine(_environment.WebRootPath, "Uploads");
                if (!Directory.Exists(uploadsFolder))
                    Directory.CreateDirectory(uploadsFolder);

                // Tạo tên file unique
                var fileName = $"background_{DateTime.UtcNow:yyyyMMddHHmmss}_{Guid.NewGuid().ToString().Substring(0, 8)}{fileExtension}";
                var filePath = Path.Combine(uploadsFolder, fileName);

                // Lưu file
                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await background.CopyToAsync(stream);
                }

                var pictureUrl = $"Uploads/{fileName}";

                _logger.LogInformation($"Background image uploaded by user {userId}: {pictureUrl}");

                return Ok(new
                {
                    success = true,
                    message = "Upload ảnh background thành công.",
                    data = new { pictureUrl }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error uploading background image");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi upload ảnh background.", error = ex.Message });
            }
        }

        /// <summary>
        /// Cập nhật cấu hình hệ thống
        /// </summary>
        [HttpPut]
        [ProducesResponseType(typeof(SystemConfigDto), 200)]
        [ProducesResponseType(400)]
        [ProducesResponseType(401)]
        [ProducesResponseType(403)]
        [ProducesResponseType(500)]
        public async Task<IActionResult> UpdateSystemConfig([FromBody] UpdateSystemConfigDto updateDto)
        {
            try
            {
                var userId = AuthHelper.GetCurrentUserId(HttpContext);
                if (userId == null)
                    return Unauthorized(new { success = false, message = "Vui lòng đăng nhập trước." });

                // Kiểm tra quyền admin
                var user = await _context.Users.FindAsync(userId);
                if (user == null || (user.Role?.ToUpper() != "ADMIN" && user.Role?.ToUpper() != "SPSO"))
                    return StatusCode(403, new { success = false, message = "Chỉ Admin/SPSO mới có quyền xem cấu hình hệ thống." });

                // Lấy config hiện tại
                var config = await _context.SystemConfigs
                    .FirstOrDefaultAsync(c => c.ConfigId == 1);

                if (config == null)
                {
                    // Nếu chưa có config trong DB, yêu cầu khởi tạo đầy đủ
                    return BadRequest(new { success = false, message = "Hệ thống chưa được cấu hình. Vui lòng cung cấp đầy đủ thông tin cấu hình ban đầu." });
                }

                // Cập nhật các trường
                if (updateDto.SystemName != null)
                    config.SystemName = updateDto.SystemName;
                if (updateDto.MaintenanceMode.HasValue)
                    config.MaintenanceMode = updateDto.MaintenanceMode.Value;
                if (updateDto.MaxFileSize.HasValue)
                    config.MaxFileSize = updateDto.MaxFileSize.Value;
                if (updateDto.AllowedFileFormats != null)
                    config.AllowedFileFormats = updateDto.AllowedFileFormats;
                if (updateDto.DefaultPagesForStudent.HasValue)
                    config.DefaultPagesForStudent = updateDto.DefaultPagesForStudent.Value;
                if (updateDto.PaperPrice.HasValue)
                    config.PaperPrice = updateDto.PaperPrice.Value;
                if (updateDto.PageFactor.HasValue)
                {
                    if (updateDto.PageFactor.Value < 0)
                        return BadRequest(new { success = false, message = "Hệ số phân trang phải là số không âm." });
                    config.PageFactor = (int)updateDto.PageFactor.Value;
                }
                if (updateDto.AutoAssignPages.HasValue)
                    config.AutoAssignPages = updateDto.AutoAssignPages.Value;
                if (!string.IsNullOrWhiteSpace(updateDto.AutoAssignDays))
                {
                    // validate format: "d/m;d/m;..."
                    var parts = updateDto.AutoAssignDays.Split(';', System.StringSplitOptions.RemoveEmptyEntries);
                    foreach (var p in parts)
                    {
                        var seg = p.Trim();
                        if (string.IsNullOrEmpty(seg)) continue;
                        var dm = seg.Split('/');
                        if (dm.Length != 2
                            || !int.TryParse(dm[0], out var d)
                            || !int.TryParse(dm[1], out var m)
                            || d < 1 || d > 31
                            || m < 1 || m > 12)
                        {
                            return BadRequest(new { success = false, message = "AutoAssignDays phải có định dạng 'd/m;d/m' với ngày 1-31 và tháng 1-12." });
                        }
                    }
                    // store raw string
                    config.AutoAssignDays = updateDto.AutoAssignDays;
                }
                if (updateDto.AutoAssignDayOfMonth.HasValue)
                {
                    if (updateDto.AutoAssignDayOfMonth.Value < 1 || updateDto.AutoAssignDayOfMonth.Value > 31)
                        return BadRequest(new { success = false, message = "Ngày tạo báo cáo tự động phải từ 1 đến 31." });
                    config.AutoAssignDayOfMonth = updateDto.AutoAssignDayOfMonth.Value;
                }
                if (updateDto.SessionTimeoutMinutes.HasValue)
                {
                    if (updateDto.SessionTimeoutMinutes.Value <= 0)
                        return BadRequest(new { success = false, message = "Thời gian hết phiên phải lớn hơn 0." });
                    config.SessionTimeoutMinutes = updateDto.SessionTimeoutMinutes.Value;
                }
                if (updateDto.MaxLoginAttempts.HasValue)
                {
                    if (updateDto.MaxLoginAttempts.Value <= 0)
                        return BadRequest(new { success = false, message = "Số lần nhập sai tối đa phải lớn hơn 0." });
                    config.MaxLoginAttempts = updateDto.MaxLoginAttempts.Value;
                }
                if (updateDto.MinPasswordLength.HasValue)
                {
                    if (updateDto.MinPasswordLength.Value < 6)
                        return BadRequest(new { success = false, message = "Độ dài mật khẩu tối thiểu phải từ 6 ký tự trở lên." });
                    config.MinPasswordLength = updateDto.MinPasswordLength.Value;
                }
                if (updateDto.RequirePasswordFormat.HasValue)
                    config.RequirePasswordFormat = updateDto.RequirePasswordFormat.Value;
                if (updateDto.StorageLimitMb.HasValue)
                {
                    if (updateDto.StorageLimitMb.Value < 0)
                        return BadRequest(new { success = false, message = "Giới hạn lưu trữ phải là số không âm (MB)." });
                    config.StorageLimitMb = updateDto.StorageLimitMb.Value;
                }
                if (updateDto.StoragePricePerMb.HasValue)
                {
                    if (updateDto.StoragePricePerMb.Value < 0)
                        return BadRequest(new { success = false, message = "Giá mỗi MB phải là số không âm (VNĐ/MB)." });
                    config.StoragePricePerMb = updateDto.StoragePricePerMb.Value;
                }
                if (updateDto.DefaultAdditionalPaper.HasValue)
                {
                    if (updateDto.DefaultAdditionalPaper.Value < 0)
                        return BadRequest(new { success = false, message = "Số giấy thêm mặc định phải là số không âm." });
                    config.DefaultAdditionalPaper = updateDto.DefaultAdditionalPaper.Value;
                }
                if (updateDto.PictureUrl != null)
                {
                    config.PictureUrl = updateDto.PictureUrl;
                }
                if (updateDto.PageDefaultCreate.HasValue)
                {
                    if (updateDto.PageDefaultCreate.Value < 0)
                        return BadRequest(new { success = false, message = "Số trang giấy mặc định cấp cho tài khoản mới phải là số không âm." });
                    config.PageDefaultCreate = updateDto.PageDefaultCreate.Value;
                }

                config.ModifiedBy = user.StudentCode ?? "ADMIN";
                config.ModifiedOn = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);

                await _context.SaveChangesAsync();

                // Invalidate cache để áp dụng config mới ngay lập tức
                SystemConfigHelper.InvalidateCache(_cache);

                _logger.LogInformation($"System config updated by user {userId}. Cache invalidated.");

                var dto = new SystemConfigDto
                {
                    ConfigId = config.ConfigId,
                    SystemName = config.SystemName,
                    MaintenanceMode = config.MaintenanceMode,
                    MaxFileSize = config.MaxFileSize,
                    AllowedFileFormats = config.AllowedFileFormats,
                    DefaultPagesForStudent = config.DefaultPagesForStudent,
                    PaperPrice = config.PaperPrice,
                    PageFactor = config.PageFactor,
                    AutoAssignPages = config.AutoAssignPages,
                    AutoAssignDays = config.AutoAssignDays,
                    AutoAssignDayOfMonth = config.AutoAssignDayOfMonth,
                    SessionTimeoutMinutes = config.SessionTimeoutMinutes,
                    MaxLoginAttempts = config.MaxLoginAttempts,
                    MinPasswordLength = config.MinPasswordLength,
                    RequirePasswordFormat = config.RequirePasswordFormat,
                    StorageLimitMb = config.StorageLimitMb,
                    StoragePricePerMb = config.StoragePricePerMb,
                    DefaultAdditionalPaper = config.DefaultAdditionalPaper,
                    PictureUrl = config.PictureUrl,
                    PageDefaultCreate = config.PageDefaultCreate
                };

                return Ok(new { success = true, message = "Đã cập nhật cấu hình hệ thống thành công.", data = dto });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating system config");
                return StatusCode(500, new { success = false, message = "Lỗi hệ thống khi cập nhật cấu hình.", error = ex.Message });
            }
        }
    }
}

