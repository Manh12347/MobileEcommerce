package com.example.ecommerce.service;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.*;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.repository.CartRepository;
import com.example.ecommerce.repository.CartItemRepository;
import com.example.ecommerce.repository.ProductItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
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

    @Autowired
    private AccountRepository accountRepository;

    public CartDTO getOrCreateCartForAccount(Integer accountId) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản"));
        Cart cart = getOrCreateCart(account);
        return toDTO(cart);
    }

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

    public CartDTO getCartForAccount(Integer accountId, Integer cartId) {
        Cart cart = requireCartOwnedByAccount(cartId, accountId);
        return toDTO(cart);
    }

    public CartItemDTO addItemForAccount(Integer accountId, AddCartItemRequest request) {
        Cart cart = getOrCreateCart(
                accountRepository.findById(accountId)
                        .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản"))
        );

        ProductItem productItem = productItemRepository.findById(request.getProductItemId())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy sản phẩm"));

        Optional<CartItem> existing = cartItemRepository
                .findByCartCartIdAndProductItemProductItemId(cart.getCartId(), request.getProductItemId());

        CartItem cartItem;
        if (existing.isPresent()) {
            cartItem = existing.get();
            cartItem.setQuantity(cartItem.getQuantity() + request.getQuantity());
        } else {
            cartItem = new CartItem();
            cartItem.setCart(cart);
            cartItem.setProductItem(productItem);
            cartItem.setQuantity(request.getQuantity());
        }

        cart.setUpdatedOn(LocalDateTime.now());
        cartRepository.save(cart);
        return toItemDTO(cartItemRepository.save(cartItem));
    }

    public CartItemDTO updateItemQuantityForAccount(Integer accountId, Integer cartItemId, UpdateCartItemRequest request) {
        CartItem cartItem = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy sản phẩm trong giỏ hàng"));

        requireCartOwnedByAccount(cartItem.getCart().getCartId(), accountId);

        cartItem.setQuantity(request.getQuantity());
        Cart cart = cartItem.getCart();
        cart.setUpdatedOn(LocalDateTime.now());
        cartRepository.save(cart);

        return toItemDTO(cartItemRepository.save(cartItem));
    }

    public void removeItemForAccount(Integer accountId, Integer cartItemId) {
        CartItem cartItem = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy sản phẩm trong giỏ hàng"));

        requireCartOwnedByAccount(cartItem.getCart().getCartId(), accountId);
        cartItemRepository.deleteById(cartItemId);
    }

    public CartDTO clearCartForAccount(Integer accountId) {
        Cart cart = cartRepository.findByAccountAccountId(accountId)
                .orElseThrow(() -> new RuntimeException("Giỏ hàng trống"));

        List<CartItem> items = cartItemRepository.findByCartCartId(cart.getCartId());
        cartItemRepository.deleteAll(items);
        cart.setUpdatedOn(LocalDateTime.now());
        cartRepository.save(cart);

        return toDTO(cart);
    }

    private Cart requireCartOwnedByAccount(Integer cartId, Integer accountId) {
        Cart cart = cartRepository.findById(cartId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy giỏ hàng"));

        if (!cart.getAccount().getAccountId().equals(accountId)) {
            throw new RuntimeException("Không có quyền truy cập giỏ hàng này");
        }
        return cart;
    }

    private CartDTO toDTO(Cart cart) {
        List<CartItem> items = cartItemRepository.findByCartCartId(cart.getCartId());
        List<CartItemDTO> itemDTOs = items.stream().map(this::toItemDTO).toList();

        int totalItems = items.stream().mapToInt(CartItem::getQuantity).sum();
        BigDecimal totalAmount = itemDTOs.stream()
                .map(CartItemDTO::getLineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        CartDTO dto = new CartDTO();
        dto.setCartId(cart.getCartId());
        dto.setAccountId(cart.getAccount().getAccountId());
        dto.setCreatedOn(cart.getCreatedOn() != null ? cart.getCreatedOn().toString() : null);
        dto.setUpdatedOn(cart.getUpdatedOn() != null ? cart.getUpdatedOn().toString() : null);
        dto.setItems(itemDTOs);
        dto.setTotalItems(totalItems);
        dto.setTotalAmount(totalAmount);
        return dto;
    }

    private CartItemDTO toItemDTO(CartItem item) {
        ProductItem productItem = item.getProductItem();
        BigDecimal unitPrice = productItem.getSalePrice() != null
                ? productItem.getSalePrice()
                : productItem.getPrice();

        CartItemDTO dto = new CartItemDTO();
        dto.setCartItemId(item.getCartItemId());
        dto.setProductItemId(productItem.getProductItemId());
        dto.setQuantity(item.getQuantity());
        dto.setSku(productItem.getSku());
        dto.setPrice(productItem.getPrice());
        dto.setSalePrice(productItem.getSalePrice());
        dto.setMainImageUrl(productItem.getMainImageUrl());

        if (productItem.getProduct() != null) {
            dto.setProductName(productItem.getProduct().getName());
        }

        if (unitPrice != null) {
            dto.setLineTotal(unitPrice.multiply(BigDecimal.valueOf(item.getQuantity())));
        } else {
            dto.setLineTotal(BigDecimal.ZERO);
        }

        return dto;
    }
}
