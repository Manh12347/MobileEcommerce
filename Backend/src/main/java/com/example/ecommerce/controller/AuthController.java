package com.example.ecommerce.controller;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.exception.AuthenticationException;
import com.example.ecommerce.service.AuthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import lombok.extern.slf4j.Slf4j;

@RestController
@RequestMapping("/v1/api/auth")
@CrossOrigin(origins = "*")
@Slf4j
public class AuthController {

    @Autowired
    private AuthService authService;

    /**
     * Lightweight OAuth endpoint for mobile clients.
     * Android verifies the provider identity, then sends the basic user data here.
     */
    @PostMapping("/oauth")
    public ResponseEntity<ApiResponse<LoginResponse>> oauthLogin(@RequestBody OAuthLoginRequest request) {
        try {
            LoginResponse response = authService.oauthLogin(request);
            return withAccessTokenCookie(response);
        } catch (AuthenticationException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Server error during oauth login:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

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
            return withAccessTokenCookie(response);
        } catch (AuthenticationException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi server khi login:", e);
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
            log.error("Lỗi server khi register:", e);
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
            log.error("Lỗi server khi verify-otp:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

            private ResponseEntity<ApiResponse<LoginResponse>> withAccessTokenCookie(LoginResponse response) {
            ResponseCookie accessTokenCookie = ResponseCookie.from("accessToken", response.getAccessToken())
                .httpOnly(true)
                .path("/")
                .sameSite("Lax")
                .build();

            return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, accessTokenCookie.toString())
                .body(new ApiResponse<>(true, response.getMessage(), response));
            }
}
