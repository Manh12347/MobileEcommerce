using OtpNet;
using QRCoder;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text.Json;
using PTVBTPM.Models.DTOs;

namespace PTVBTPM.Services
{
    public class TwoFactorAuthService : ITwoFactorAuthService
    {
        // TODO: Move these to appsettings.json or environment variables
        private const string EncryptionKeyString = "PTVBTPM2FA_SecretKey_32Byt"; // Base string for key derivation
        private const string EncryptionIVString = "PTVBTPM2FA!"; // Base string for IV derivation
        
        // AES-256 requires exactly 32 bytes (256 bits) for key
        private static readonly byte[] EncryptionKey = GetKeyBytes(EncryptionKeyString, 32);
        // AES requires exactly 16 bytes (128 bits) for IV
        private static readonly byte[] EncryptionIV = GetKeyBytes(EncryptionIVString, 16);
        
        /// <summary>
        /// Convert string to byte array with exact size requirement
        /// Uses SHA256 for key derivation to ensure consistent size
        /// </summary>
        private static byte[] GetKeyBytes(string input, int requiredSize)
        {
            if (requiredSize == 32)
            {
                // For 32 bytes, use SHA256 hash (always 32 bytes)
                using var sha256 = SHA256.Create();
                return sha256.ComputeHash(System.Text.Encoding.UTF8.GetBytes(input));
            }
            else if (requiredSize == 16)
            {
                // For 16 bytes, use first 16 bytes of SHA256 hash
                using var sha256 = SHA256.Create();
                var hash = sha256.ComputeHash(System.Text.Encoding.UTF8.GetBytes(input));
                var result = new byte[16];
                Array.Copy(hash, 0, result, 0, 16);
                return result;
            }
            else
            {
                // For other sizes, pad or truncate
                var bytes = System.Text.Encoding.UTF8.GetBytes(input);
                var result = new byte[requiredSize];
                Array.Copy(bytes, 0, result, 0, Math.Min(bytes.Length, requiredSize));
                // If input is shorter, pad with zeros (not ideal, but works)
                return result;
            }
        }

        public string GenerateSecret()
        {
            // Generate 20 bytes (160 bits) random secret
            var key = KeyGeneration.GenerateRandomKey(20);
            // Return as Base32 string (compatible with Google Authenticator)
            return Base32Encoding.ToString(key);
        }

        public Setup2FAResponse GenerateQrCode(string email, string secret, string issuer = "PTVBTPM")
        {
            try
            {
                // Create otpauth URI
                var authenticatorUri = $"otpauth://totp/{Uri.EscapeDataString(issuer)}:{Uri.EscapeDataString(email)}?secret={secret}&issuer={Uri.EscapeDataString(issuer)}";

                // Generate QR code
                using var qrGenerator = new QRCodeGenerator();
                var qrCodeData = qrGenerator.CreateQrCode(authenticatorUri, QRCodeGenerator.ECCLevel.Q);
                using var qrCode = new PngByteQRCode(qrCodeData);
                var qrCodeImage = qrCode.GetGraphic(20);

                // Convert to base64 data URL
                var qrCodeDataUrl = $"data:image/png;base64,{Convert.ToBase64String(qrCodeImage)}";

                return new Setup2FAResponse
                {
                    Secret = secret,
                    QrCodeDataUrl = qrCodeDataUrl,
                    ManualEntryKey = FormatSecretForManualEntry(secret),
                    AuthenticatorUri = authenticatorUri
                };
            }
            catch (Exception ex)
            {
                // Log error for debugging
                Console.WriteLine($"[GenerateQrCode] Error: {ex.Message}");
                Console.WriteLine($"[GenerateQrCode] Stack trace: {ex.StackTrace}");
                throw new Exception($"Không thể tạo QR code: {ex.Message}", ex);
            }
        }

        public bool VerifyCode(string secret, string code)
        {
            if (string.IsNullOrWhiteSpace(secret) || string.IsNullOrWhiteSpace(code))
                return false;

            try
            {
                var secretBytes = Base32Encoding.ToBytes(secret);
                var totp = new Totp(secretBytes);
                
                // Verify with time window (allow 1 step before and after current time)
                var currentTime = DateTimeOffset.UtcNow;
                return totp.VerifyTotp(code, out _, new VerificationWindow(1, 1));
            }
            catch
            {
                return false;
            }
        }

        public List<string> GenerateRecoveryCodes(int count = 10)
        {
            var codes = new List<string>();
            for (int i = 0; i < count; i++)
            {
                // Generate 8-character alphanumeric code
                var code = GenerateRandomCode(8);
                // Format as XXXX-XXXX for readability
                codes.Add($"{code.Substring(0, 4)}-{code.Substring(4, 4)}");
            }
            return codes;
        }

        public string EncryptSecret(string secret)
        {
            if (string.IsNullOrWhiteSpace(secret))
                return string.Empty;

            using var aes = Aes.Create();
            aes.Key = EncryptionKey;
            aes.IV = EncryptionIV;

            using var encryptor = aes.CreateEncryptor();
            var plainBytes = System.Text.Encoding.UTF8.GetBytes(secret);
            var encryptedBytes = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
            
            return Convert.ToBase64String(encryptedBytes);
        }

        public string DecryptSecret(string encryptedSecret)
        {
            if (string.IsNullOrWhiteSpace(encryptedSecret))
                return string.Empty;

            try
            {
                using var aes = Aes.Create();
                aes.Key = EncryptionKey;
                aes.IV = EncryptionIV;

                using var decryptor = aes.CreateDecryptor();
                var encryptedBytes = Convert.FromBase64String(encryptedSecret);
                var decryptedBytes = decryptor.TransformFinalBlock(encryptedBytes, 0, encryptedBytes.Length);
                
                return System.Text.Encoding.UTF8.GetString(decryptedBytes);
            }
            catch
            {
                return string.Empty;
            }
        }

        public bool VerifyRecoveryCode(string recoveryCodesJson, string code, out string updatedRecoveryCodesJson)
        {
            updatedRecoveryCodesJson = recoveryCodesJson;

            if (string.IsNullOrWhiteSpace(recoveryCodesJson) || string.IsNullOrWhiteSpace(code))
                return false;

            try
            {
                var codes = JsonSerializer.Deserialize<List<string>>(recoveryCodesJson);
                if (codes == null || codes.Count == 0)
                    return false;

                // Check if code exists (case-insensitive, remove spaces and dashes)
                var normalizedCode = code.Replace("-", "").Replace(" ", "").ToUpper();
                var matchingCode = codes.FirstOrDefault(c => 
                    c.Replace("-", "").Replace(" ", "").ToUpper() == normalizedCode);

                if (matchingCode != null)
                {
                    // Remove used code
                    codes.Remove(matchingCode);
                    updatedRecoveryCodesJson = JsonSerializer.Serialize(codes);
                    return true;
                }

                return false;
            }
            catch
            {
                return false;
            }
        }

        // Helper methods
        private string GenerateRandomCode(int length)
        {
            const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // Exclude confusing characters
            var random = new Random();
            return new string(Enumerable.Repeat(chars, length)
                .Select(s => s[random.Next(s.Length)]).ToArray());
        }

        private string FormatSecretForManualEntry(string secret)
        {
            // Format as groups of 4 characters for easier manual entry
            // Example: ABCD EFGH IJKL MNOP
            var formatted = string.Empty;
            for (int i = 0; i < secret.Length; i += 4)
            {
                if (i > 0) formatted += " ";
                formatted += secret.Substring(i, Math.Min(4, secret.Length - i));
            }
            return formatted;
        }
    }
}

