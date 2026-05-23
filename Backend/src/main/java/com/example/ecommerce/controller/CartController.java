package com.example.ecommerce.controller;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.service.CartService;
import com.example.ecommerce.util.SecurityUtil;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/api/cart")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
@Slf4j
public class CartController {

    private final CartService cartService;

    /**
     * GET /v1/api/cart - Lay hoac tao gio hang cua user dang dang nhap
     */
    @GetMapping
    public ResponseEntity<ApiResponse<CartDTO>> getMyCart() {
        try {
            Integer accountId = requireAccountId();
            CartDTO cart = cartService.getOrCreateCartForAccount(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy giỏ hàng thành công", cart));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy giỏ hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * GET /v1/api/cart/{cartId}
     */
    @GetMapping("/{cartId}")
    public ResponseEntity<ApiResponse<CartDTO>> getCartById(@PathVariable Integer cartId) {
        try {
            Integer accountId = requireAccountId();
            CartDTO cart = cartService.getCartForAccount(accountId, cartId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy giỏ hàng thành công", cart));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy giỏ hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * POST /v1/api/cart/items - Them san pham vao gio
     */
    @PostMapping("/items")
    public ResponseEntity<ApiResponse<CartItemDTO>> addItem(@Valid @RequestBody AddCartItemRequest request) {
        try {
            Integer accountId = requireAccountId();
            CartItemDTO item = cartService.addItemForAccount(accountId, request);
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Thêm vào giỏ hàng thành công", item));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi thêm vào giỏ hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * PUT /v1/api/cart/items/{cartItemId} - Cap nhat so luong
     */
    @PutMapping("/items/{cartItemId}")
    public ResponseEntity<ApiResponse<CartItemDTO>> updateItem(
            @PathVariable Integer cartItemId,
            @Valid @RequestBody UpdateCartItemRequest request) {
        try {
            Integer accountId = requireAccountId();
            CartItemDTO item = cartService.updateItemQuantityForAccount(accountId, cartItemId, request);
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật giỏ hàng thành công", item));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật giỏ hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * DELETE /v1/api/cart/items/{cartItemId} - Xoa mot san pham khoi gio
     */
    @DeleteMapping("/items/{cartItemId}")
    public ResponseEntity<ApiResponse<String>> removeItem(@PathVariable Integer cartItemId) {
        try {
            Integer accountId = requireAccountId();
            cartService.removeItemForAccount(accountId, cartItemId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Xóa sản phẩm khỏi giỏ hàng thành công", null));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi xóa khỏi giỏ hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    /**
     * DELETE /v1/api/cart - Xoa toan bo san pham trong gio
     */
    @DeleteMapping
    public ResponseEntity<ApiResponse<CartDTO>> clearCart() {
        try {
            Integer accountId = requireAccountId();
            CartDTO cart = cartService.clearCartForAccount(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Đã xóa toàn bộ giỏ hàng", cart));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi xóa giỏ hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    private Integer requireAccountId() {
        Integer accountId = SecurityUtil.getCurrentAccountId();
        if (accountId == null) {
            throw new RuntimeException("Vui lòng đăng nhập để sử dụng giỏ hàng");
        }
        return accountId;
    }
}
