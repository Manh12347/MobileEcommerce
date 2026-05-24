package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.LoginResponse;
import com.example.ecommerce.dto.TwoFactorSetupResponse;
import com.example.ecommerce.dto.TwoFactorVerifyRequest;
import com.example.ecommerce.service.TwoFactorService;
import com.example.ecommerce.util.SecurityUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/api/auth/2fa")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
@Slf4j
public class TwoFactorController {

    private final TwoFactorService twoFactorService;

    /**
     * Setup 2FA - generate secret and QR code
     * POST /v1/api/auth/2fa/setup
     * Requires JWT authentication
     */
    @PostMapping("/setup")
    public ResponseEntity<ApiResponse<TwoFactorSetupResponse>> setup2FA() {
        try {
            Integer accountId = requireAccountId();
            TwoFactorSetupResponse response = twoFactorService.setup2FA(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Tạo mã QR thành công", response));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi setup 2FA", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Enable 2FA - verify code then activate
     * POST /v1/api/auth/2fa/enable
     * Body: { "code": "123456" }
     * Requires JWT authentication
     */
    @PostMapping("/enable")
    public ResponseEntity<ApiResponse<String>> enable2FA(@RequestBody Enable2FARequest request) {
        try {
            Integer accountId = requireAccountId();
            twoFactorService.enable2FA(accountId, request.getCode());
            return ResponseEntity.ok(new ApiResponse<>(true, "Bật 2FA thành công", null));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi bật 2FA", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Disable 2FA - verify code then deactivate
     * POST /v1/api/auth/2fa/disable
     * Body: { "code": "123456" }
     * Requires JWT authentication
     */
    @PostMapping("/disable")
    public ResponseEntity<ApiResponse<String>> disable2FA(@RequestBody Enable2FARequest request) {
        try {
            Integer accountId = requireAccountId();
            twoFactorService.disable2FA(accountId, request.getCode());
            return ResponseEntity.ok(new ApiResponse<>(true, "Tắt 2FA thành công", null));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi tắt 2FA", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Verify 2FA code during login flow
     * POST /v1/api/auth/2fa/verify
     * Body: { "pendingToken": "uuid", "code": "123456" }
     * Public endpoint (no JWT required)
     */
    @PostMapping("/verify")
    public ResponseEntity<ApiResponse<LoginResponse>> verifyLogin2FA(@RequestBody TwoFactorVerifyRequest request) {
        try {
            LoginResponse response = twoFactorService.verifyLogin2FA(request.getPendingToken(), request.getCode());
            return ResponseEntity.ok(new ApiResponse<>(true, "Xác thực 2FA thành công", response));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi verify 2FA login", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    private Integer requireAccountId() {
        Integer accountId = SecurityUtil.getCurrentAccountId();
        if (accountId == null) {
            throw new RuntimeException("Vui lòng đăng nhập để sử dụng chức năng này");
        }
        return accountId;
    }

    @lombok.Data
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class Enable2FARequest {
        private String code;
    }
}
