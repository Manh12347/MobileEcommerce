using System.Text.RegularExpressions;

namespace PTVBTPM.Helper;

/// <summary>
/// Helper class để validate password theo yêu cầu của system config
/// </summary>
public static class PasswordValidator
{
    /// <summary>
    /// Validate password theo config
    /// </summary>
    /// <param name="password">Password cần validate</param>
    /// <param name="minLength">Độ dài tối thiểu</param>
    /// <param name="requireStrongFormat">Có yêu cầu format mạnh không (chữ hoa, chữ thường, số, ký tự đặc biệt)</param>
    /// <returns>Tuple (isValid, errorMessage)</returns>
    public static (bool isValid, string? errorMessage) ValidatePassword(
        string password, 
        int minLength, 
        bool requireStrongFormat)
    {
        if (string.IsNullOrWhiteSpace(password))
        {
            return (false, "Mật khẩu không được để trống.");
        }

        // Kiểm tra độ dài tối thiểu
        if (password.Length < minLength)
        {
            return (false, $"Mật khẩu phải có ít nhất {minLength} ký tự.");
        }

        // Nếu không yêu cầu format mạnh, chỉ cần đủ độ dài
        if (!requireStrongFormat)
        {
            return (true, null);
        }

        // Kiểm tra format mạnh: phải có chữ hoa, chữ thường, số và ký tự đặc biệt
        bool hasUpperCase = Regex.IsMatch(password, @"[A-Z]");
        bool hasLowerCase = Regex.IsMatch(password, @"[a-z]");
        bool hasDigit = Regex.IsMatch(password, @"[0-9]");
        bool hasSpecialChar = Regex.IsMatch(password, @"[!@#$%^&*()_+\-=\[\]{};':""\\|,.<>\/?]");

        if (!hasUpperCase)
        {
            return (false, "Mật khẩu phải có ít nhất một chữ cái viết hoa.");
        }

        if (!hasLowerCase)
        {
            return (false, "Mật khẩu phải có ít nhất một chữ cái viết thường.");
        }

        if (!hasDigit)
        {
            return (false, "Mật khẩu phải có ít nhất một chữ số.");
        }

        if (!hasSpecialChar)
        {
            return (false, "Mật khẩu phải có ít nhất một ký tự đặc biệt (!@#$%^&*()_+-=[]{}|;':\",./<>?).");
        }

        return (true, null);
    }
}

