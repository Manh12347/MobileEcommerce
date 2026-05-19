package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.CreateProductItemRequest;
import com.example.ecommerce.dto.ProductItemDTO;
import com.example.ecommerce.dto.UpdateProductItemRequest;
import com.example.ecommerce.service.ProductItemService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/v1/api/product-items")
@CrossOrigin(origins = "*")
@Slf4j
public class ProductItemController {

    @Autowired
    private ProductItemService productItemService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ProductItemDTO>>> getAllProductItems() {
        try {
            List<ProductItemDTO> items = productItemService.getAllProductItems();
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách product items thành công", items));
        } catch (Exception e) {
            log.error("Lỗi khi lấy danh sách product items:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ProductItemDTO>> getProductItemById(@PathVariable Integer id) {
        try {
            ProductItemDTO item = productItemService.getProductItem(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy product item thành công", item));
        } catch (RuntimeException e) {
            log.warn("Không tìm thấy product item: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy product item:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/product/{productId}")
    public ResponseEntity<ApiResponse<List<ProductItemDTO>>> getProductItemsByProduct(@PathVariable Integer productId) {
        try {
            List<ProductItemDTO> items = productItemService.getProductItemsByProduct(productId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy product items theo sản phẩm thành công", items));
        } catch (Exception e) {
            log.error("Lỗi khi lấy product items theo sản phẩm:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ProductItemDTO>> createProductItem(
            @Valid @RequestBody CreateProductItemRequest request) {
        try {
            log.info("Tạo product item với stockQuantity: {}", request.getStockQuantity());
            ProductItemDTO item = productItemService.createProductItem(request);
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Tạo product item thành công với " + request.getStockQuantity() + " serials", item));
        } catch (RuntimeException e) {
            log.warn("Lỗi khi tạo product item: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi tạo product item:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<ProductItemDTO>> updateProductItem(
            @PathVariable Integer id,
            @RequestBody UpdateProductItemRequest request) {
        try {
            log.info("Cập nhật product item id: {}", id);
            ProductItemDTO item = productItemService.updateProductItem(id, request);
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật product item thành công", item));
        } catch (RuntimeException e) {
            log.warn("Lỗi khi cập nhật product item: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật product item:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<String>> deleteProductItem(@PathVariable Integer id) {
        try {
            productItemService.deleteProductItem(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Xóa product item thành công", null));
        } catch (RuntimeException e) {
            log.warn("Không thể xóa product item: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi xóa product item:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PostMapping("/{id}/add-stock")
    public ResponseEntity<ApiResponse<ProductItemDTO>> addStock(
            @PathVariable Integer id,
            @RequestParam int quantity) {
        try {
            log.info("Thêm stock cho product item id: {}, quantity: {}", id, quantity);
            ProductItemDTO item = productItemService.addStock(id, quantity);
            return ResponseEntity.ok(new ApiResponse<>(true, "Thêm " + quantity + " stock thành công", item));
        } catch (RuntimeException e) {
            log.warn("Lỗi khi thêm stock: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi thêm stock:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PostMapping("/{id}/reduce-stock")
    public ResponseEntity<ApiResponse<ProductItemDTO>> reduceStock(
            @PathVariable Integer id,
            @RequestParam int quantity) {
        try {
            log.info("Giảm stock cho product item id: {}, quantity: {}", id, quantity);
            ProductItemDTO item = productItemService.reduceStock(id, quantity);
            return ResponseEntity.ok(new ApiResponse<>(true, "Giảm " + quantity + " stock thành công", item));
        } catch (RuntimeException e) {
            log.warn("Lỗi khi giảm stock: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi giảm stock:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }
}
