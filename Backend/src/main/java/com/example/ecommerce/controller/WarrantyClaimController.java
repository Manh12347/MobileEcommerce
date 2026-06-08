package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.CreateWarrantyClaimBySerialRequest;
import com.example.ecommerce.dto.CreateWarrantyClaimRequest;
import com.example.ecommerce.dto.UpdateWarrantyClaimRequest;
import com.example.ecommerce.dto.WarrantyClaimDTO;
import com.example.ecommerce.dto.WarrantyClaimGroupDTO;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.Product;
import com.example.ecommerce.entity.ProductItem;
import com.example.ecommerce.entity.Profile;
import com.example.ecommerce.entity.SerialNumber;
import com.example.ecommerce.entity.Warranty;
import com.example.ecommerce.entity.WarrantyClaim;
import com.example.ecommerce.service.WarrantyClaimService;
import com.example.ecommerce.util.SecurityUtil;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/v1/api/warranty-claims")
@CrossOrigin(origins = "*")
@Slf4j
public class WarrantyClaimController {

    @Autowired
    private WarrantyClaimService warrantyClaimService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<WarrantyClaimDTO>>> getAllClaims(
            @RequestParam(required = false) String status) {
        try {
            List<WarrantyClaim> claims = status != null && !status.isBlank()
                    ? warrantyClaimService.getClaimsByStatus(status)
                    : warrantyClaimService.getAllClaims();

            List<WarrantyClaimDTO> data = claims.stream()
                    .map(this::toDTO)
                    .collect(Collectors.toList());

            return ResponseEntity.ok(new ApiResponse<>(true, "Get warranty claims successfully", data));
        } catch (Exception e) {
            log.error("Error getting warranty claims:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @GetMapping("/grouped")
    public ResponseEntity<ApiResponse<List<WarrantyClaimGroupDTO>>> getClaimsGroupedByProductAndSerialSeries(
            @RequestParam(required = false) String status) {
        try {
            List<WarrantyClaim> claims = status != null && !status.isBlank()
                    ? warrantyClaimService.getClaimsByStatusWithProductAndSerial(status)
                    : warrantyClaimService.getAllClaimsWithProductAndSerial();

            Map<String, List<WarrantyClaimDTO>> groupedClaims = claims.stream()
                    .map(this::toDTO)
                    .collect(Collectors.groupingBy(
                            claim -> groupKey(claim.getProductName(), claim.getSerialSeries()),
                            LinkedHashMap::new,
                            Collectors.toList()
                    ));

            List<WarrantyClaimGroupDTO> data = groupedClaims.values().stream()
                    .map(this::toGroupDTO)
                    .collect(Collectors.toList());

            return ResponseEntity.ok(new ApiResponse<>(true, "Get grouped warranty claims successfully", data));
        } catch (Exception e) {
            log.error("Error getting grouped warranty claims:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<WarrantyClaimDTO>> getClaimById(@PathVariable Integer id) {
        try {
            WarrantyClaim claim = warrantyClaimService.getClaim(id);
            if (claim == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Warranty claim not found", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Get warranty claim successfully", toDTO(claim)));
        } catch (Exception e) {
            log.error("Error getting warranty claim:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @GetMapping("/serial/{serialId}")
    public ResponseEntity<ApiResponse<List<WarrantyClaimDTO>>> getClaimsBySerialId(@PathVariable Integer serialId) {
        try {
            List<WarrantyClaimDTO> data = warrantyClaimService.getClaimsBySerialId(serialId).stream()
                    .map(this::toDTO)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Get warranty claims by serial successfully", data));
        } catch (Exception e) {
            log.error("Error getting warranty claims by serial:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @GetMapping("/account/{accountId}")
    public ResponseEntity<ApiResponse<List<WarrantyClaimDTO>>> getClaimsByAccountId(@PathVariable Integer accountId) {
        try {
            List<WarrantyClaimDTO> data = warrantyClaimService.getClaimsByAccountId(accountId).stream()
                    .map(this::toDTO)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Get warranty claims by account successfully", data));
        } catch (Exception e) {
            log.error("Error getting warranty claims by account:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @PostMapping
    public ResponseEntity<ApiResponse<WarrantyClaimDTO>> createClaim(
            @Valid @RequestBody CreateWarrantyClaimRequest request) {
        try {
            if (!SecurityUtil.isAdmin()) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(new ApiResponse<>(false, "Only admin can create warranty claims", null));
            }

            WarrantyClaim claim = warrantyClaimService.createClaim(
                    request.getSerialId(),
                    request.getAccountId(),
                    request.getIssueDescription(),
                    request.getStatus()
            );
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Create warranty claim successfully", toDTO(claim)));
        } catch (RuntimeException e) {
            log.warn("Error creating warranty claim: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Error creating warranty claim:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @PostMapping("/by-serial")
    public ResponseEntity<ApiResponse<WarrantyClaimDTO>> createClaimBySerial(
            @Valid @RequestBody CreateWarrantyClaimBySerialRequest request) {
        try {
            if (!SecurityUtil.isAdmin()) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(new ApiResponse<>(false, "Only admin can create warranty claims", null));
            }

            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Bạn cần đăng nhập để tạo phiếu bảo hành", null));
            }

            WarrantyClaim claim = warrantyClaimService.createClaimBySerialCode(
                    request.getSerialNumber(),
                    accountId,
                    request.getDescription()
            );
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Tạo phiếu bảo hành thành công", toDTO(claim)));
        } catch (RuntimeException e) {
            log.warn("Error creating warranty claim by serial: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Error creating warranty claim by serial:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi máy chủ: " + e.getMessage(), null));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<WarrantyClaimDTO>> updateClaim(
            @PathVariable Integer id,
            @RequestBody UpdateWarrantyClaimRequest request) {
        try {
            WarrantyClaim claim = warrantyClaimService.updateClaim(
                    id,
                    request.getSerialId(),
                    request.getAccountId(),
                    request.getIssueDescription(),
                    request.getStatus()
            );
            if (claim == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Warranty claim not found", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Update warranty claim successfully", toDTO(claim)));
        } catch (RuntimeException e) {
            log.warn("Error updating warranty claim: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Error updating warranty claim:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    private WarrantyClaimDTO toDTO(WarrantyClaim claim) {
        SerialNumber serialNumber = claim.getSerialNumber();
        Account account = claim.getAccount();
        Profile profile = account != null ? account.getProfile() : null;
        ProductItem productItem = serialNumber != null ? serialNumber.getProductItem() : null;
        Product product = productItem != null ? productItem.getProduct() : null;
        Warranty warranty = serialNumber != null ? serialNumber.getWarranty() : null;
        String serialCode = serialNumber != null ? serialNumber.getSerialCode() : null;
        String customerName = profile != null && profile.getFullName() != null && !profile.getFullName().isBlank()
                ? profile.getFullName()
                : account != null ? account.getEmail() : null;

        return new WarrantyClaimDTO(
                claim.getClaimId(),
                serialNumber != null ? serialNumber.getSerialId() : null,
                serialCode,
                toSerialSeries(serialCode),
                product != null ? product.getProductId() : null,
                product != null ? product.getName() : "Unknown product",
                account != null ? account.getAccountId() : null,
                account != null ? account.getEmail() : null,
                customerName,
                profile != null ? profile.getPhone() : null,
                profile != null ? profile.getAddress() : null,
                productItem != null ? productItem.getSku() : null,
                warranty != null && warranty.getStartDate() != null ? warranty.getStartDate().toString() : null,
                warranty != null && warranty.getEndDate() != null ? warranty.getEndDate().toString() : null,
                warranty != null ? warranty.getStatus() : null,
                claim.getIssueDescription(),
                normalizeStatus(claim.getStatus()),
                claim.getCreatedAt() != null ? claim.getCreatedAt().toString() : null
        );
    }

    private String normalizeStatus(String status) {
        if (status == null || status.isBlank()) {
            return "processing";
        }

        String normalized = status.trim().toLowerCase();
        if ("pending".equals(normalized) || "approved".equals(normalized) || "processing".equals(normalized)) {
            return "processing";
        }
        if ("rejected".equals(normalized) || "canceled".equals(normalized) || "cancelled".equals(normalized)) {
            return "cancelled";
        }
        if ("completed".equals(normalized)) {
            return "completed";
        }
        return normalized;
    }

    private WarrantyClaimGroupDTO toGroupDTO(List<WarrantyClaimDTO> claims) {
        WarrantyClaimDTO first = claims.get(0);
        Map<String, Long> statusCounts = claims.stream()
                .collect(Collectors.groupingBy(
                        claim -> claim.getStatus() != null ? claim.getStatus() : "unknown",
                        LinkedHashMap::new,
                        Collectors.counting()
                ));

        String latestCreatedAt = claims.stream()
                .map(WarrantyClaimDTO::getCreatedAt)
                .filter(value -> value != null && !value.isBlank())
                .max(String::compareTo)
                .orElse(null);

        return new WarrantyClaimGroupDTO(
                first.getProductName(),
                first.getSerialSeries(),
                claims.stream()
                        .map(WarrantyClaimDTO::getCustomerName)
                        .filter(value -> value != null && !value.isBlank())
                        .distinct()
                        .collect(Collectors.toList()),
                claims.stream()
                        .map(WarrantyClaimDTO::getCustomerPhone)
                        .filter(value -> value != null && !value.isBlank())
                        .distinct()
                        .collect(Collectors.toList()),
                first.getProductSku(),
                claims.stream()
                        .map(WarrantyClaimDTO::getWarrantyStartDate)
                        .filter(value -> value != null && !value.isBlank())
                        .min(String::compareTo)
                        .orElse(null),
                claims.stream()
                        .map(WarrantyClaimDTO::getWarrantyEndDate)
                        .filter(value -> value != null && !value.isBlank())
                        .max(String::compareTo)
                        .orElse(null),
                claims.size(),
                latestCreatedAt,
                statusCounts,
                claims
        );
    }

    private String groupKey(String productName, String serialSeries) {
        return (productName != null ? productName : "Unknown product")
                + "::"
                + (serialSeries != null ? serialSeries : "Unknown series");
    }

    private String toSerialSeries(String serialCode) {
        if (serialCode == null || serialCode.isBlank()) {
            return "Unknown series";
        }

        int lastDash = serialCode.lastIndexOf('-');
        if (lastDash > 0) {
            return serialCode.substring(0, lastDash);
        }

        int lastDigitIndex = serialCode.length() - 1;
        while (lastDigitIndex >= 0 && Character.isDigit(serialCode.charAt(lastDigitIndex))) {
            lastDigitIndex--;
        }

        return lastDigitIndex < serialCode.length() - 1 && lastDigitIndex > 0
                ? serialCode.substring(0, lastDigitIndex + 1)
                : serialCode;
    }
}
