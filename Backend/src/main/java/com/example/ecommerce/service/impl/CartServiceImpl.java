package com.example.ecommerce.service.impl;

import com.example.ecommerce.dto.cart.*;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.Cart;
import com.example.ecommerce.entity.CartItem;
import com.example.ecommerce.entity.Product;
import com.example.ecommerce.entity.ProductItem;
import com.example.ecommerce.exception.CartNotFoundException;
import com.example.ecommerce.exception.InvalidQuantityException;
import com.example.ecommerce.exception.OutOfStockException;
import com.example.ecommerce.exception.ProductNotFoundException;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.repository.CartItemRepository;
import com.example.ecommerce.repository.CartRepository;
import com.example.ecommerce.repository.ProductItemRepository;
import com.example.ecommerce.service.CartService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional
public class CartServiceImpl implements CartService {

    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final ProductItemRepository productItemRepository;
    private final AccountRepository accountRepository;

    @Override
    public CartMessageResponse addToCart(AddCartRequest request) {
        ProductItem productItem = findProductVariantOrThrow(request.getProductVariantId());
        validateStock(productItem, request.getQuantity());

        Cart cart = getOrCreateCartForUser(request.getUserId());
        BigDecimal unitPrice = resolveEffectivePrice(productItem);

        Optional<CartItem> existing = cartItemRepository
                .findByCartCartIdAndProductItemProductItemId(cart.getCartId(), productItem.getProductItemId());

        if (existing.isPresent()) {
            CartItem item = existing.get();
            int newQuantity = item.getQuantity() + request.getQuantity();
            validateStock(productItem, newQuantity);
            item.setQuantity(newQuantity);
            cartItemRepository.save(item);
        } else {
            CartItem item = new CartItem();
            item.setCart(cart);
            item.setProductItem(productItem);
            item.setQuantity(request.getQuantity());
            item.setPrice(unitPrice);
            cartItemRepository.save(item);
        }

        touchCart(cart);
        return new CartMessageResponse("Added to cart successfully");
    }

    @Override
    @Transactional(readOnly = true)
    public CartResponse getCartByUser(Integer userId) {
        if (!accountRepository.existsById(userId)) {
            throw new CartNotFoundException("User not found: " + userId);
        }

        Optional<Cart> cartOpt = cartRepository.findByAccountAccountId(userId);
        if (cartOpt.isEmpty()) {
            return CartResponse.builder()
                    .userId(userId)
                    .items(List.of())
                    .totalAmount(BigDecimal.ZERO)
                    .discountAmount(BigDecimal.ZERO)
                    .finalAmount(BigDecimal.ZERO)
                    .build();
        }

        Cart cart = cartOpt.get();
        List<CartItem> items = cartItemRepository.findByCartIdWithDetails(cart.getCartId());
        return buildCartResponse(cart, items);
    }

    @Override
    public CartMessageResponse updateCart(UpdateCartRequest request) {
        CartItem item = cartItemRepository.findById(request.getCartItemId())
                .orElseThrow(() -> new CartNotFoundException("Cart item not found: " + request.getCartItemId()));

        if (request.getQuantity() <= 0) {
            cartItemRepository.delete(item);
            touchCart(item.getCart());
            return new CartMessageResponse("Cart updated successfully");
        }

        ProductItem productItem = item.getProductItem();
        validateStock(productItem, request.getQuantity());

        item.setQuantity(request.getQuantity());
        cartItemRepository.save(item);
        touchCart(item.getCart());

        return new CartMessageResponse("Cart updated successfully");
    }

    @Override
    public CartMessageResponse removeItem(Integer cartItemId) {
        CartItem item = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new CartNotFoundException("Cart item not found: " + cartItemId));

        Cart cart = item.getCart();
        cartItemRepository.delete(item);
        touchCart(cart);

        return new CartMessageResponse("Item removed successfully");
    }

    @Override
    public CartResponse syncCart(SyncCartRequest request) {
        Cart cart = getOrCreateCartForUser(request.getUserId());

        for (SyncCartItemRequest syncItem : request.getItems()) {
            ProductItem productItem = findProductVariantOrThrow(syncItem.getProductVariantId());

            Optional<CartItem> existing = cartItemRepository
                    .findByCartCartIdAndProductItemProductItemId(cart.getCartId(), productItem.getProductItemId());

            int targetQuantity = syncItem.getQuantity();
            if (existing.isPresent()) {
                targetQuantity = existing.get().getQuantity() + syncItem.getQuantity();
            }

            validateStock(productItem, targetQuantity);
            BigDecimal unitPrice = resolveEffectivePrice(productItem);

            if (existing.isPresent()) {
                CartItem item = existing.get();
                item.setQuantity(targetQuantity);
                item.setPrice(unitPrice);
                cartItemRepository.save(item);
            } else {
                CartItem item = new CartItem();
                item.setCart(cart);
                item.setProductItem(productItem);
                item.setQuantity(syncItem.getQuantity());
                item.setPrice(unitPrice);
                cartItemRepository.save(item);
            }
        }

        touchCart(cart);
        List<CartItem> items = cartItemRepository.findByCartIdWithDetails(cart.getCartId());
        return buildCartResponse(cart, items);
    }

    private Cart getOrCreateCartForUser(Integer userId) {
        Account account = accountRepository.findById(userId)
                .orElseThrow(() -> new CartNotFoundException("User not found: " + userId));

        return cartRepository.findByAccountAccountId(userId)
                .orElseGet(() -> {
                    Cart cart = new Cart();
                    cart.setAccount(account);
                    cart.setCreatedOn(LocalDateTime.now());
                    cart.setUpdatedOn(LocalDateTime.now());
                    return cartRepository.save(cart);
                });
    }

    private ProductItem findProductVariantOrThrow(Integer productVariantId) {
        return productItemRepository.findById(productVariantId)
                .orElseThrow(() -> new ProductNotFoundException(
                        "Product variant not found: " + productVariantId));
    }

    private void validateStock(ProductItem productItem, int requiredQuantity) {
        if (requiredQuantity <= 0) {
            throw new InvalidQuantityException("Quantity must be greater than 0");
        }
        Integer stock = productItem.getStockQuantity();
        if (stock == null || stock < requiredQuantity) {
            throw new OutOfStockException(
                    "Insufficient stock for variant " + productItem.getProductItemId()
                            + ". Available: " + (stock != null ? stock : 0)
                            + ", requested: " + requiredQuantity);
        }
    }

    private BigDecimal resolveEffectivePrice(ProductItem item) {
        if (item.getSalePrice() != null
                && item.getSalePrice().compareTo(BigDecimal.ZERO) > 0
                && (item.getPrice() == null || item.getSalePrice().compareTo(item.getPrice()) < 0)) {
            return item.getSalePrice();
        }
        return item.getPrice() != null ? item.getPrice() : BigDecimal.ZERO;
    }

    private BigDecimal resolveOriginalPrice(ProductItem item) {
        return item.getPrice() != null ? item.getPrice() : BigDecimal.ZERO;
    }

    private void touchCart(Cart cart) {
        cart.setUpdatedOn(LocalDateTime.now());
        cartRepository.save(cart);
    }

    private CartResponse buildCartResponse(Cart cart, List<CartItem> items) {
        List<CartItemResponse> itemResponses = new ArrayList<>();
        BigDecimal totalAmount = BigDecimal.ZERO;
        BigDecimal finalAmount = BigDecimal.ZERO;

        for (CartItem item : items) {
            ProductItem productItem = item.getProductItem();
            BigDecimal unitPrice = item.getPrice() != null ? item.getPrice() : BigDecimal.ZERO;
            BigDecimal originalPrice = resolveOriginalPrice(productItem);
            BigDecimal subtotal = unitPrice.multiply(BigDecimal.valueOf(item.getQuantity()));

            totalAmount = totalAmount.add(originalPrice.multiply(BigDecimal.valueOf(item.getQuantity())));
            finalAmount = finalAmount.add(subtotal);

            itemResponses.add(CartItemResponse.builder()
                    .cartItemId(item.getCartItemId())
                    .productVariantId(productItem.getProductItemId())
                    .productName(resolveProductName(productItem))
                    .image(productItem.getMainImageUrl())
                    .variant(resolveVariantLabel(productItem))
                    .price(unitPrice)
                    .quantity(item.getQuantity())
                    .subtotal(subtotal)
                    .build());
        }

        BigDecimal discountAmount = totalAmount.subtract(finalAmount);
        if (discountAmount.compareTo(BigDecimal.ZERO) < 0) {
            discountAmount = BigDecimal.ZERO;
            totalAmount = finalAmount;
        }

        return CartResponse.builder()
                .cartId(cart.getCartId())
                .userId(cart.getAccount().getAccountId())
                .items(itemResponses)
                .totalAmount(totalAmount)
                .discountAmount(discountAmount)
                .finalAmount(finalAmount)
                .build();
    }

    private String resolveProductName(ProductItem productItem) {
        Product product = productItem.getProduct();
        if (product != null && product.getName() != null) {
            return product.getName();
        }
        return productItem.getDescription() != null ? productItem.getDescription() : "Unknown Product";
    }

    private String resolveVariantLabel(ProductItem productItem) {
        if (productItem.getSku() != null && !productItem.getSku().isBlank()) {
            return productItem.getSku();
        }
        if (productItem.getDescription() != null && !productItem.getDescription().isBlank()) {
            return productItem.getDescription();
        }
        return "Default";
    }
}
