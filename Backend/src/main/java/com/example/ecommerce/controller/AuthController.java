package com.example.ecommerce.controller;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.exception.AuthenticationException;
import com.example.ecommerce.service.AuthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired
    private AuthService authService;

    /**
     * Login endpoint
     * POST /v1/api/auth/login
     * 
     * Checks:
     * - Email exists
     * - Account status (active/locked/disabled/pending)
     * - Email confirmed
     * - Password correct
     * - Failed login attempts (lock after 5 attempts)
     * - 2FA enabled flag
     */
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(@RequestBody LoginRequest loginRequest) {
        try {
            LoginResponse response = authService.login(loginRequest);
            return ResponseEntity.ok(new ApiResponse<>(true, "Đăng nhập thành công", response));
        } catch (AuthenticationException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Register endpoint
     * POST /v1/api/auth/register
     * 
     * Request body: { email, password }
     * Response: { accountId, email, message }
     * Sends 6-digit OTP to email
     */
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<RegisterResponse>> register(@RequestBody RegisterRequest registerRequest) {
        try {
            RegisterResponse response = authService.register(registerRequest);
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, response.getMessage(), response));
        } catch (AuthenticationException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Verify OTP endpoint
     * POST /v1/api/auth/verify-otp
     * 
     * Request body: { email, otp }
     * Activates account after OTP verification
     */
    @PostMapping("/verify-otp")
    public ResponseEntity<ApiResponse<String>> verifyOtp(@RequestBody VerifyOtpRequest verifyOtpRequest) {
        try {
            ApiResponse<String> response = authService.verifyOtp(verifyOtpRequest);
            return ResponseEntity.ok(response);
        } catch (AuthenticationException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Resend OTP endpoint
     * POST /v1/api/auth/resend-otp
     * 
     * Request body: { email }
     * Resends OTP to email for verification
     * Rate limited: 1-5 attempts without CAPTCHA, 6-10 require CAPTCHA
     */
    @PostMapping("/resend-otp")
    public ResponseEntity<ApiResponse<OtpSendResponse>> resendOtp(@RequestBody java.util.Map<String, String> request) {
        try {
            String email = request.get("email");
            OtpSendResponse response = authService.resendOtp(email);
            return ResponseEntity.ok(new ApiResponse<>(true, response.getMessage(), response));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Resend OTP with CAPTCHA verification endpoint
     * POST /v1/api/auth/resend-otp-captcha
     * 
     * Request body: { email, recaptchaToken }
     * Used when rate limit requires CAPTCHA verification
     */
    @PostMapping("/resend-otp-captcha")
    public ResponseEntity<ApiResponse<OtpSendResponse>> resendOtpWithCaptcha(@RequestBody CaptchaVerificationRequest request) {
        try {
            OtpSendResponse response = authService.resendOtpWithCaptcha(request.getEmail(), request.getRecaptchaToken());
            return ResponseEntity.ok(new ApiResponse<>(true, response.getMessage(), response));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }
}
