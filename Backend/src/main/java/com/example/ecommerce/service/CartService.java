package com.example.ecommerce.service;

import com.example.ecommerce.dto.AddCartItemRequest;
import com.example.ecommerce.dto.CartDTO;
import com.example.ecommerce.dto.CartItemDTO;
import com.example.ecommerce.dto.UpdateCartItemRequest;

public interface CartService {

    CartDTO getOrCreateCartForAccount(Integer accountId);

    CartDTO getCartForAccount(Integer accountId, Integer cartId);

    CartItemDTO addItemForAccount(Integer accountId, AddCartItemRequest request);

    CartItemDTO updateItemQuantityForAccount(Integer accountId, Integer cartItemId, UpdateCartItemRequest request);

    void removeItemForAccount(Integer accountId, Integer cartItemId);

    CartDTO clearCartForAccount(Integer accountId);
}
