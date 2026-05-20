package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.cart.*;
import com.example.ecommerce.service.CartService;
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

    @PostMapping("/add")
    public ResponseEntity<ApiResponse<CartMessageResponse>> addToCart(
            @Valid @RequestBody AddCartRequest request) {
        CartMessageResponse response = cartService.addToCart(request);
        return ResponseEntity.ok(new ApiResponse<>(true, response.getMessage(), response));
    }

    @GetMapping("/{userId}")
    public ResponseEntity<ApiResponse<CartResponse>> getCartByUser(@PathVariable Integer userId) {
        CartResponse response = cartService.getCartByUser(userId);
        return ResponseEntity.ok(new ApiResponse<>(true, "Cart retrieved successfully", response));
    }

    @PutMapping("/update")
    public ResponseEntity<ApiResponse<CartMessageResponse>> updateCart(
            @Valid @RequestBody UpdateCartRequest request) {
        CartMessageResponse response = cartService.updateCart(request);
        return ResponseEntity.ok(new ApiResponse<>(true, response.getMessage(), response));
    }

    @DeleteMapping("/remove/{cartItemId}")
    public ResponseEntity<ApiResponse<CartMessageResponse>> removeItem(@PathVariable Integer cartItemId) {
        CartMessageResponse response = cartService.removeItem(cartItemId);
        return ResponseEntity.ok(new ApiResponse<>(true, response.getMessage(), response));
    }

    @PostMapping("/sync")
    public ResponseEntity<ApiResponse<CartResponse>> syncCart(@Valid @RequestBody SyncCartRequest request) {
        CartResponse response = cartService.syncCart(request);
        return ResponseEntity.status(HttpStatus.OK)
                .body(new ApiResponse<>(true, "Cart synced successfully", response));
    }
}
