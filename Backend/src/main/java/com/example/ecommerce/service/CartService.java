package com.example.ecommerce.service;

import com.example.ecommerce.dto.cart.*;

public interface CartService {

    CartMessageResponse addToCart(AddCartRequest request);

    CartResponse getCartByUser(Integer userId);

    CartMessageResponse updateCart(UpdateCartRequest request);

    CartMessageResponse removeItem(Integer cartItemId);

    CartResponse syncCart(SyncCartRequest request);
}
