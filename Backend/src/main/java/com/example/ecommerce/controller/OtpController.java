package com.example.ecommerce.controller;

import com.example.ecommerce.dto.CaptchaVerificationRequest;
import com.example.ecommerce.dto.OtpSendResponse;
import com.example.ecommerce.service.OtpService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/api/auth/otp")
@RequiredArgsConstructor
@Slf4j
public class OtpController {

    private final OtpService otpService;

    /**
     * Gửi OTP qua email
     * POST /v1/api/auth/otp/send
     * Body: {"email": "user@example.com"}
     * 
     * Rate limiting với reCAPTCHA v3:
     * 1-5 attempts: Send OTP directly (no CAPTCHA)
     * 6-10 attempts: Require reCAPTCHA v3 verification
     * >10 attempts: Lock email 15-30 minutes
     */
    @PostMapping("/send")
    public ResponseEntity<?> sendOtp(@RequestBody SendOtpRequest request) {
        try {
            OtpSendResponse response = otpService.generateAndSendOtp(request.getEmail());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error sending OTP", e);
            return ResponseEntity.badRequest().body(new ApiResponse("Lỗi gửi OTP: " + e.getMessage(), false));
        }
    }

    /**
     * Xác thực OTP
     * POST /v1/api/auth/otp/verify
     * Body: {"email": "user@example.com", "otp": "123456"}
     */
    @PostMapping("/verify")
    public ResponseEntity<?> verifyOtp(@RequestBody VerifyOtpRequest request) {
        try {
            otpService.verifyOtp(request.getEmail(), request.getOtp());
            return ResponseEntity.ok(new ApiResponse("Xác thực OTP thành công", true));
        } catch (Exception e) {
            log.error("Error verifying OTP", e);
            return ResponseEntity.badRequest().body(new ApiResponse("Lỗi xác thực: " + e.getMessage(), false));
        }
    }

    /**
     * Gửi lại OTP
     * POST /v1/api/auth/otp/resend
     * Body: {"email": "user@example.com"}
     * Resend OTP if account is pending verification or pending registration
     */
    @PostMapping("/resend")
    public ResponseEntity<?> resendOtp(@RequestBody SendOtpRequest request) {
        try {
            OtpSendResponse response = otpService.resendOtp(request.getEmail());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error resending OTP", e);
            return ResponseEntity.badRequest().body(new ApiResponse("Lỗi gửi lại OTP: " + e.getMessage(), false));
        }
    }

    /**
     * Verify reCAPTCHA v3 and Resend OTP
     * POST /v1/api/auth/otp/resend-with-captcha
     * Body: {"email": "user@example.com", "recaptchaToken": "token_from_grecaptcha.execute()"}
     * 
     * Used when requiresCaptcha = true (6-10 attempts)
     * Verifies reCAPTCHA v3 score before allowing resend
     * Frontend calls grecaptcha.execute() to get token
     */
    @PostMapping("/resend-with-captcha")
    public ResponseEntity<?> resendOtpWithCaptcha(@RequestBody CaptchaVerificationRequest request) {
        try {
            OtpSendResponse response = otpService.resendOtpWithCaptcha(request.getEmail(), request.getRecaptchaToken());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error resending OTP with CAPTCHA", e);
            return ResponseEntity.badRequest().body(new ApiResponse("Lỗi xác thực CAPTCHA: " + e.getMessage(), false));
        }
    }

    // DTO Classes
    @lombok.Data
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class SendOtpRequest {
        private String email;
    }

    @lombok.Data
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class VerifyOtpRequest {
        private String email;
        private String otp;
    }

    @lombok.Data
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class ApiResponse {
        private String message;
        private boolean success;
    }
}

