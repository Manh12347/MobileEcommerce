package com.example.ecommerce.service.impl;

import com.example.ecommerce.dto.AddCartItemRequest;
import com.example.ecommerce.dto.CartDTO;
import com.example.ecommerce.dto.CartItemDTO;
import com.example.ecommerce.dto.UpdateCartItemRequest;
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
    public CartDTO getOrCreateCartForAccount(Integer accountId) {
        Cart cart = getOrCreateCart(accountId);
        return toDTO(cart);
    }

    @Override
    @Transactional(readOnly = true)
    public CartDTO getCartForAccount(Integer accountId, Integer cartId) {
        Cart cart = requireCartOwnedByAccount(cartId, accountId);
        return toDTO(cart);
    }

    @Override
    public CartItemDTO addItemForAccount(Integer accountId, AddCartItemRequest request) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new CartNotFoundException("User not found: " + accountId));

        ProductItem productItem = findProductItemOrThrow(request.getProductItemId());
        validateStock(productItem, request.getQuantity());

        Cart cart = getOrCreateCart(account);
        BigDecimal unitPrice = resolveEffectivePrice(productItem);

        Optional<CartItem> existing = cartItemRepository
                .findByCartCartIdAndProductItemProductItemId(cart.getCartId(), productItem.getProductItemId());

        CartItem cartItem;
        if (existing.isPresent()) {
            cartItem = existing.get();
            int newQuantity = cartItem.getQuantity() + request.getQuantity();
            validateStock(productItem, newQuantity);
            cartItem.setQuantity(newQuantity);
            cartItem.setPrice(unitPrice);
        } else {
            cartItem = new CartItem();
            cartItem.setCart(cart);
            cartItem.setProductItem(productItem);
            cartItem.setQuantity(request.getQuantity());
            cartItem.setPrice(unitPrice);
        }

        cartItemRepository.save(cartItem);
        touchCart(cart);
        return toItemDTO(cartItem);
    }

    @Override
    public CartItemDTO updateItemQuantityForAccount(Integer accountId, Integer cartItemId, UpdateCartItemRequest request) {
        CartItem cartItem = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new CartNotFoundException("Cart item not found: " + cartItemId));

        requireCartOwnedByAccount(cartItem.getCart().getCartId(), accountId);

        ProductItem productItem = cartItem.getProductItem();
        validateStock(productItem, request.getQuantity());

        cartItem.setQuantity(request.getQuantity());
        if (cartItem.getPrice() == null) {
            cartItem.setPrice(resolveEffectivePrice(productItem));
        }

        cartItemRepository.save(cartItem);
        touchCart(cartItem.getCart());
        return toItemDTO(cartItem);
    }

    @Override
    public void removeItemForAccount(Integer accountId, Integer cartItemId) {
        CartItem cartItem = cartItemRepository.findById(cartItemId)
                .orElseThrow(() -> new CartNotFoundException("Cart item not found: " + cartItemId));

        requireCartOwnedByAccount(cartItem.getCart().getCartId(), accountId);
        Cart cart = cartItem.getCart();
        cartItemRepository.delete(cartItem);
        touchCart(cart);
    }

    @Override
    public CartDTO clearCartForAccount(Integer accountId) {
        Cart cart = findLatestCart(accountId)
                .orElseThrow(() -> new CartNotFoundException("Giỏ hàng trống"));

        List<CartItem> items = cartItemRepository.findByCartCartId(cart.getCartId());
        cartItemRepository.deleteAll(items);
        touchCart(cart);

        return toDTO(cart);
    }

    private Cart getOrCreateCart(Integer accountId) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new CartNotFoundException("User not found: " + accountId));

        return getOrCreateCart(account);
    }

    private Cart getOrCreateCart(Account account) {
        return findLatestCart(account.getAccountId())
                .orElseGet(() -> {
                    Cart cart = new Cart();
                    cart.setAccount(account);
                    cart.setCreatedOn(LocalDateTime.now());
                    cart.setUpdatedOn(LocalDateTime.now());
                    return cartRepository.save(cart);
                });
    }

    private Optional<Cart> findLatestCart(Integer accountId) {
        return cartRepository.findAllByAccountAccountIdOrderByUpdatedOnDescCartIdDesc(accountId)
                .stream()
                .findFirst();
    }

    private ProductItem findProductItemOrThrow(Integer productItemId) {
        return productItemRepository.findById(productItemId)
                .orElseThrow(() -> new ProductNotFoundException("Product item not found: " + productItemId));
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

    private void touchCart(Cart cart) {
        cart.setUpdatedOn(LocalDateTime.now());
        cartRepository.save(cart);
    }

    private Cart requireCartOwnedByAccount(Integer cartId, Integer accountId) {
        Cart cart = cartRepository.findById(cartId)
                .orElseThrow(() -> new CartNotFoundException("Không tìm thấy giỏ hàng"));

        if (!cart.getAccount().getAccountId().equals(accountId)) {
            throw new RuntimeException("Không có quyền truy cập giỏ hàng này");
        }
        return cart;
    }

    private CartDTO toDTO(Cart cart) {
        List<CartItem> items = cartItemRepository.findByCartIdWithDetails(cart.getCartId());
        List<CartItemDTO> itemDTOs = items.stream().map(this::toItemDTO).toList();

        int totalItems = items.stream().mapToInt(CartItem::getQuantity).sum();
        BigDecimal totalAmount = itemDTOs.stream()
                .map(item -> item.getLineTotal() != null ? item.getLineTotal() : BigDecimal.ZERO)
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
        BigDecimal unitPrice = item.getPrice() != null
                ? item.getPrice()
                : resolveEffectivePrice(productItem);

        CartItemDTO dto = new CartItemDTO();
        dto.setCartItemId(item.getCartItemId());
        dto.setProductItemId(productItem.getProductItemId());
        dto.setQuantity(item.getQuantity());
        dto.setSku(productItem.getSku());
        dto.setProductName(resolveProductName(productItem));
        dto.setMainImageUrl(productItem.getMainImageUrl());
        dto.setPrice(productItem.getPrice());
        dto.setSalePrice(productItem.getSalePrice());
        dto.setLineTotal(unitPrice.multiply(BigDecimal.valueOf(item.getQuantity())));
        return dto;
    }

    private String resolveProductName(ProductItem productItem) {
        Product product = productItem.getProduct();
        if (product != null && product.getName() != null) {
            return product.getName();
        }
        return productItem.getDescription() != null ? productItem.getDescription() : "Unknown Product";
    }
}
