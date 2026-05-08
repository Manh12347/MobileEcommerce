package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Response DTO for OTP send operations
 * Indicates if reCAPTCHA v3 verification is required
 * reCAPTCHA v3 is invisible and runs in background
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class OtpSendResponse {
    private boolean success;
    private String message;
    private boolean requiresCaptcha;
    private String recaptchaSiteKey;  // Google reCAPTCHA v3 site key for frontend
}
