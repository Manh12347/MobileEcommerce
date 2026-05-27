using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.DTOs
{
    /// <summary>
    /// Request để enable 2FA với Authenticator app
    /// </summary>
    public class Enable2FARequest
    {
        public string Method { get; set; } = "authenticator"; // 'authenticator', 'email', 'both'
    }

    /// <summary>
    /// Response chứa thông tin để setup Authenticator
    /// </summary>
    public class Setup2FAResponse
    {
        public string Secret { get; set; } = null!; // Base32 encoded secret
        public string QrCodeDataUrl { get; set; } = null!; // Base64 QR code image
        public string ManualEntryKey { get; set; } = null!; // For manual entry
        public string AuthenticatorUri { get; set; } = null!; // otpauth:// URI
    }

    /// <summary>
    /// Request để verify code khi enable 2FA
    /// </summary>
    public class Verify2FASetupRequest
    {
        public string Code { get; set; } = null!; // 6-digit code from authenticator
    }

    /// <summary>
    /// Request để verify code khi login
    /// </summary>
    public class Verify2FALoginRequest
    {
        public string Email { get; set; } = null!;
        public string Code { get; set; } = null!; // 6-digit code
        public bool UseRecoveryCode { get; set; } = false; // True if using recovery code
    }

    /// <summary>
    /// Response sau khi enable 2FA thành công
    /// </summary>
    public class Enable2FAResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; } = null!;
        public List<string>? RecoveryCodes { get; set; } // Backup codes
    }

    /// <summary>
    /// Request để disable 2FA
    /// </summary>
    public class Disable2FARequest
    {
        public string Password { get; set; } = null!; // Require password to disable
    }

    /// <summary>
    /// Response chứa trạng thái 2FA của user
    /// </summary>
    public class TwoFactorStatusResponse
    {
        public bool Enabled { get; set; }
        public string? Method { get; set; }
        public DateTime? EnabledAt { get; set; }
        public bool HasRecoveryCodes { get; set; }
    }
}

