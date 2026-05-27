package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.CreateProductItemRequest;
import com.example.ecommerce.dto.ProductItemDTO;
import com.example.ecommerce.dto.ProductItemListDTO;
import com.example.ecommerce.dto.ProductItemVariantDto;
import com.example.ecommerce.dto.UpdateProductItemRequest;
import com.example.ecommerce.service.ProductItemService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.data.domain.Page;

import java.util.List;

@RestController
@RequestMapping("/v1/api/product-items")
@CrossOrigin(origins = "*")
@Slf4j
public class ProductItemController {

    @Autowired
    private ProductItemService productItemService;

    @GetMapping
    public ResponseEntity<ApiResponse<Page<ProductItemDTO>>> getAllProductItems(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        try {
            Page<ProductItemDTO> items = productItemService.getAllProductItems(page, size);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách product items thành công", items));
        } catch (Exception e) {
            log.error("Lỗi khi lấy danh sách product items:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }
    
    /**
     * Lấy danh sách product items cho dashboard - KHÔNG có serials
     * Performance tốt hơn nhiều
     */
    @GetMapping("/list")
    public ResponseEntity<ApiResponse<Page<ProductItemListDTO>>> getAllProductItemsList(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        try {
            Page<ProductItemListDTO> items = productItemService.getAllProductItemsForList(page, size);
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

    /**
     * Lấy biến thể nhẹ (không serials) cho dialog khuyến mãi - nhanh hơn nhiều
     */
    @GetMapping("/variants/{productId}")
    public ResponseEntity<ApiResponse<List<ProductItemVariantDto>>> getVariantsByProduct(@PathVariable Integer productId) {
        try {
            List<ProductItemVariantDto> items = productItemService.getVariantsByProduct(productId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy biến thể thành công", items));
        } catch (Exception e) {
            log.error("Lỗi khi lấy biến thể:", e);
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

    @PutMapping("/{id}/toggle-status")
    public ResponseEntity<ApiResponse<String>> toggleProductItemStatus(@PathVariable Integer id) {
        try {
            productItemService.toggleProductItemStatus(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật trạng thái thành công", null));
        } catch (RuntimeException e) {
            log.warn("Không thể cập nhật trạng thái: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật trạng thái:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping("/{id}/discontinue")
    public ResponseEntity<ApiResponse<String>> discontinueProductItem(@PathVariable Integer id) {
        try {
            productItemService.discontinueProductItem(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Biến thể đã được ngừng bán", null));
        } catch (RuntimeException e) {
            log.warn("Không thể ngừng bán: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi ngừng bán:", e);
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

    /**
     * Lấy danh sách sản phẩm đang giảm giá
     */
    @GetMapping("/discounted")
    public ResponseEntity<ApiResponse<Page<ProductItemListDTO>>> getDiscountedItems(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        try {
            Page<ProductItemListDTO> items = productItemService.getDiscountedItems(page, size);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách sản phẩm giảm giá thành công", items));
        } catch (Exception e) {
            log.error("Lỗi khi lấy sản phẩm giảm giá:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * Tắt giảm giá của một sản phẩm (xóa sale_price)
     */
    @PutMapping("/{id}/disable-discount")
    public ResponseEntity<ApiResponse<ProductItemDTO>> disableDiscount(@PathVariable Integer id) {
        try {
            ProductItemDTO item = productItemService.disableDiscount(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Đã tắt giảm giá cho sản phẩm", item));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi tắt giảm giá:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }
}
