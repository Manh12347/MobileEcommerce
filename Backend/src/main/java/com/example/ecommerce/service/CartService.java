package com.example.ecommerce.service;

import com.example.ecommerce.entity.*;
import com.example.ecommerce.repository.CartRepository;
import com.example.ecommerce.repository.CartItemRepository;
import com.example.ecommerce.repository.ProductItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class CartService {

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private CartItemRepository cartItemRepository;

    @Autowired
    private ProductItemRepository productItemRepository;

    public Cart getOrCreateCart(Account account) {
        Optional<Cart> existingCart = cartRepository.findByAccountAccountId(account.getAccountId());
        if (existingCart.isPresent()) {
            return existingCart.get();
        }
        Cart cart = new Cart();
        cart.setAccount(account);
        cart.setCreatedOn(LocalDateTime.now());
        cart.setUpdatedOn(LocalDateTime.now());
        return cartRepository.save(cart);
    }

    public Cart getCart(Integer cartId) {
        return cartRepository.findById(cartId).orElse(null);
    }

    public CartItem addItemToCart(Integer cartId, Integer productItemId, Integer quantity) {
        Cart cart = cartRepository.findById(cartId).orElse(null);
        if (cart == null) return null;

        ProductItem productItem = productItemRepository.findById(productItemId).orElse(null);
        if (productItem == null) return null;

        CartItem cartItem = new CartItem();
        cartItem.setCart(cart);
        cartItem.setProductItem(productItem);
        cartItem.setQuantity(quantity);

        cart.setUpdatedOn(LocalDateTime.now());
        cartRepository.save(cart);

        return cartItemRepository.save(cartItem);
    }

    public void removeItemFromCart(Integer cartItemId) {
        cartItemRepository.deleteById(cartItemId);
    }

    public List<CartItem> getCartItems(Integer cartId) {
        return cartItemRepository.findByCartCartId(cartId);
    }

    public void clearCart(Integer cartId) {
        Cart cart = cartRepository.findById(cartId).orElse(null);
        if (cart != null) {
            List<CartItem> items = cartItemRepository.findByCartCartId(cartId);
            cartItemRepository.deleteAll(items);
        }
    }

    public void deleteCart(Integer cartId) {
        cartRepository.deleteById(cartId);
    }
}
