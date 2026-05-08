package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for Google reCAPTCHA v3 verification
 * reCAPTCHA v3 is invisible and runs in background
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CaptchaVerificationRequest {
    private String email;
    private String recaptchaToken;  // Token from grecaptcha.execute() call
}
