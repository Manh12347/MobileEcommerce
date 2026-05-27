using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using PTVBTPM.Helper;
using PTVBTPM.Models.Entities;

namespace PTVBTPM.Middleware;

/// <summary>
/// Middleware để check session timeout dựa trên system config
/// </summary>
public class SessionTimeoutMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<SessionTimeoutMiddleware> _logger;

    public SessionTimeoutMiddleware(RequestDelegate next, ILogger<SessionTimeoutMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, WebDbContext dbContext, IMemoryCache cache, Microsoft.AspNetCore.SignalR.IHubContext<PTVBTPM.Hubs.PresenceHub> presenceHub)
    {
        // Chỉ check session cho các request đã authenticated
        if (context.Session.IsAvailable && context.Session.Keys.Contains("UserId"))
        {
            try
            {
                // Lấy system config
                var systemConfig = await SystemConfigHelper.GetSystemConfigAsync(dbContext, cache);
                if (systemConfig != null && systemConfig.SessionTimeoutMinutes > 0)
                {
                    // Check last activity time từ session
                    var lastActivityKey = "LastActivity";
                    var lastActivityString = context.Session.GetString(lastActivityKey);
                    
                    if (!string.IsNullOrEmpty(lastActivityString) && DateTime.TryParse(lastActivityString, out var lastActivity))
                    {
                        var timeoutMinutes = systemConfig.SessionTimeoutMinutes;
                        var elapsed = DateTime.UtcNow - lastActivity;
                        
                        if (elapsed.TotalMinutes > timeoutMinutes)
                        {
                            // Session đã hết hạn, lưu log logout do timeout, sau đó clear session
                            var userIdString = context.Session.GetString("UserId");
                            if (int.TryParse(userIdString, out var userId))
                            {
                                try
                                {
                                    var history = new LoginHistory
                                    {
                                        UserId = userId,
                                        LoginTime = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified),
                                        IpAddress = context.Connection.RemoteIpAddress?.ToString(),
                                        Device = "LOGOUT",
                                        Description = $"Session timeout after {elapsed.TotalMinutes:N0} minutes",
                                        CreatedBy = "SYSTEM"
                                    };
                                    dbContext.LoginHistories.Add(history);
                                    await dbContext.SaveChangesAsync();
                                    _logger.LogInformation($"Session timeout log saved for user {userId}");
                                    // broadcast presence inactive
                                    try
                                    {
                                        await presenceHub.Clients.All.SendCoreAsync("UserInactive", new object[] { userId }, System.Threading.CancellationToken.None);
                                    }
                                    catch (Exception ex2)
                                    {
                                        _logger.LogWarning(ex2, "Failed to broadcast UserInactive");
                                    }
                                }
                                catch (Exception ex)
                                {
                                    _logger.LogWarning(ex, "Failed to save session timeout login history");
                                }
                            }
                            _logger.LogInformation($"Session expired for user {context.Session.GetString("UserId")}. Elapsed: {elapsed.TotalMinutes} minutes, Timeout: {timeoutMinutes} minutes");
                            context.Session.Clear();
                            
                            // Nếu là API request, trả về 401
                            if (context.Request.Path.StartsWithSegments("/v1"))
                            {
                                context.Response.StatusCode = 401;
                                await context.Response.WriteAsJsonAsync(new
                                {
                                    success = false,
                                    message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
                                });
                                return;
                            }
                        }
                    }
                    
                    // Update last activity time
                    context.Session.SetString(lastActivityKey, DateTime.UtcNow.ToString("O"));
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in SessionTimeoutMiddleware");
                // Continue với request nếu có lỗi
            }
        }

        await _next(context);
    }
}

