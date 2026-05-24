package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.ProfileDTO;
import com.example.ecommerce.dto.UpdateProfileRequest;
import com.example.ecommerce.service.ProfileService;
import com.example.ecommerce.util.SecurityUtil;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/api/profile")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
@Slf4j
public class ProfileController {

    private final ProfileService profileService;

    @GetMapping
    public ResponseEntity<ApiResponse<ProfileDTO>> getMyProfile() {
        try {
            Integer accountId = requireAccountId();
            ProfileDTO profile = profileService.getMyProfile(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy hồ sơ cá nhân thành công", profile));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy hồ sơ cá nhân:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping
    public ResponseEntity<ApiResponse<ProfileDTO>> updateMyProfile(@Valid @RequestBody UpdateProfileRequest request) {
        try {
            Integer accountId = requireAccountId();
            ProfileDTO profile = profileService.updateMyProfile(accountId, request);
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật hồ sơ cá nhân thành công", profile));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật hồ sơ cá nhân:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    private Integer requireAccountId() {
        Integer accountId = SecurityUtil.getCurrentAccountId();
        if (accountId == null) {
            throw new RuntimeException("Vui lòng đăng nhập để sử dụng hồ sơ cá nhân");
        }
        return accountId;
    }
}