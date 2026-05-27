using PTVBTPM.Models.DTOs;
using System.Collections.Generic;

namespace PTVBTPM.Services
{
    public interface ITwoFactorAuthService
    {
        /// <summary>
        /// Generate secret key for TOTP
        /// </summary>
        string GenerateSecret();

        /// <summary>
        /// Generate QR code for authenticator app
        /// </summary>
        Setup2FAResponse GenerateQrCode(string email, string secret, string issuer = "PTVBTPM");

        /// <summary>
        /// Verify TOTP code
        /// </summary>
        bool VerifyCode(string secret, string code);

        /// <summary>
        /// Generate recovery codes
        /// </summary>
        List<string> GenerateRecoveryCodes(int count = 10);

        /// <summary>
        /// Encrypt secret before saving to database
        /// </summary>
        string EncryptSecret(string secret);

        /// <summary>
        /// Decrypt secret from database
        /// </summary>
        string DecryptSecret(string encryptedSecret);

        /// <summary>
        /// Verify recovery code
        /// </summary>
        bool VerifyRecoveryCode(string recoveryCodesJson, string code, out string updatedRecoveryCodesJson);
    }
}

