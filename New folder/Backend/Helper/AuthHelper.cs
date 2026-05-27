using Microsoft.AspNetCore.Http;

namespace PTVBTPM.Helper
{
    public static class AuthHelper
    {
        /// <summary>
        /// Kiểm tra xem user có đăng nhập hay không
        /// </summary>
        public static bool IsLoggedIn(HttpContext httpContext)
        {
            var userId = httpContext.Session.GetString("UserId");
            return !string.IsNullOrEmpty(userId);
        }

        /// <summary>
        /// Lấy userId của user hiện tại
        /// </summary>
        public static int? GetCurrentUserId(HttpContext httpContext)
        {
            var userIdString = httpContext.Session.GetString("UserId");
            if (int.TryParse(userIdString, out int userId))
            {
                return userId;
            }
            return null;
        }

        /// <summary>
        /// Lấy email của user hiện tại
        /// </summary>
        public static string? GetCurrentEmail(HttpContext httpContext)
        {
            return httpContext.Session.GetString("Email");
        }

        /// <summary>
        /// Lấy role của user hiện tại
        /// </summary>
        public static string? GetCurrentRole(HttpContext httpContext)
        {
            return httpContext.Session.GetString("Role");
        }

        /// <summary>
        /// Kiểm tra xem user có phải SPSO hay không
        /// </summary>
        public static bool IsSPSO(HttpContext httpContext)
        {
            var role = httpContext.Session.GetString("Role");
            return role == "SPSO";
        }
    }
}

