package com.example.ecommerce.controller;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.Promotion;
import com.example.ecommerce.service.PromotionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/v1/api/promotions")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
@Slf4j
public class PromotionController {

    private final PromotionService promotionService;

    // ==================== CRUD ====================

    @PostMapping
    public ResponseEntity<ApiResponse<PromotionResponse>> create(@RequestBody CreatePromotionRequest request) {
        try {
            Promotion promotion = promotionService.createPromotion(request);
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Tạo promotion thành công", promotionService.toResponse(promotion)));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi tạo promotion:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<PromotionResponse>>> getAll() {
        try {
            List<PromotionResponse> list = promotionService.getAllPromotions().stream()
                    .map(promotionService::toResponse)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách promotion thành công", list));
        } catch (Exception e) {
            log.error("Lỗi khi lấy promotions:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/active")
    public ResponseEntity<ApiResponse<List<PromotionResponse>>> getActive() {
        try {
            List<PromotionResponse> list = promotionService.getActivePromotions().stream()
                    .map(promotionService::toResponse)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách promotion đang hoạt động thành công", list));
        } catch (Exception e) {
            log.error("Lỗi khi lấy active promotions:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<PromotionResponse>> getById(@PathVariable Integer id) {
        try {
            Promotion promotion = promotionService.getPromotion(id);
            if (promotion == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy promotion", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy promotion thành công", promotionService.toResponse(promotion)));
        } catch (Exception e) {
            log.error("Lỗi khi lấy promotion:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<PromotionResponse>> update(
            @PathVariable Integer id,
            @RequestBody UpdatePromotionRequest request) {
        try {
            Promotion promotion = promotionService.updatePromotion(id, request);
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật promotion thành công", promotionService.toResponse(promotion)));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật promotion:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<String>> delete(@PathVariable Integer id) {
        try {
            promotionService.deletePromotion(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Xóa promotion thành công", null));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi xóa promotion:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    // ==================== APPLY / REMOVE ====================

    @PostMapping("/apply")
    public ResponseEntity<ApiResponse<String>> apply(@RequestBody ApplyPromotionRequest request) {
        try {
            promotionService.applyPromotionToProduct(request.getProductId(), request.getPromotionId());
            return ResponseEntity.ok(new ApiResponse<>(true, "Áp dụng promotion cho sản phẩm thành công", null));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi apply promotion:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/apply")
    public ResponseEntity<ApiResponse<String>> remove(@RequestBody ApplyPromotionRequest request) {
        try {
            promotionService.removePromotionFromProduct(request.getProductId(), request.getPromotionId());
            return ResponseEntity.ok(new ApiResponse<>(true, "Gỡ promotion khỏi sản phẩm thành công", null));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi remove promotion:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    // ==================== GET PRODUCTS BY PROMOTION ====================

    @GetMapping("/{id}/products")
    public ResponseEntity<ApiResponse<List<PromotionProductDto>>> getProductsByPromotion(@PathVariable Integer id) {
        try {
            List<PromotionProductDto> products = promotionService.getProductsByPromotionId(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy sản phẩm theo promotion thành công", products));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy sản phẩm theo promotion:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }
}
