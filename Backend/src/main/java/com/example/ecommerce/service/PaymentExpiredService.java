package com.example.ecommerce.service;

import com.example.ecommerce.dto.PaymentCacheInfo;
import com.example.ecommerce.entity.Cart;
import com.example.ecommerce.entity.CartItem;
import com.example.ecommerce.entity.Order;
import com.example.ecommerce.entity.ProductItem;
import com.example.ecommerce.repository.CartItemRepository;
import com.example.ecommerce.repository.CartRepository;
import com.example.ecommerce.repository.OrderItemRepository;
import com.example.ecommerce.repository.OrderRepository;
import com.example.ecommerce.repository.ProductItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentExpiredService {

    private static final String KEY_PATTERN_ORDER = "sepay:order:*";

    private final RedisTemplate<String, Object> redisTemplate;
    private final PaymentRedisService paymentRedisService;
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final ProductItemRepository productItemRepository;

    /**
     * Chay moi 30 giay, kiem tra Redis xem co don hang nao bi expired khong.
     * Redis tu dong xoa key sau TTL = 30 phut. Nhung Spring khong trigger event khi key bi xoa,
     * nen can poll thu cong.
     *
     * Cach hoat dong:
     * 1. Quet tat ca key "sepay:order:*" trong Redis
     * 2. Neu key con ton tai → kiem tra createdAt + expiresInMinutes
     * 3. Neu da qua 5 phut → tien hanh hoan hang
     */
    @Scheduled(fixedDelay = 30_000)
    public void checkExpiredPayments() {
        try {
            Set<String> keys = null;
            try {
                keys = redisTemplate.keys(KEY_PATTERN_ORDER);
            } catch (Exception e) {
                log.debug("[PaymentExpired] Redis offline. Checking localPaymentStore.");
                keys = paymentRedisService.getLocalKeys(KEY_PATTERN_ORDER);
            }
            if (keys == null || keys.isEmpty()) return;

            for (String key : keys) {
                processExpiredKey(key);
            }
        } catch (Exception e) {
            log.error("[PaymentExpired] Error checking expired payments", e);
        }
    }

    private void processExpiredKey(String key) {
        try {
            // Extract gencode from key: sepay:order:ORDER_xxxxxxxxxxxxxxx
            String gencode = key.replace("sepay:order:", "");
            Optional<PaymentCacheInfo> cachedOpt = paymentRedisService.getByGencode(gencode);

            if (cachedOpt.isEmpty()) {
                // Key da bi xoa boi Redis (het TTL) → don hang that bai
                handleMissingKey(gencode);
                return;
            }

            PaymentCacheInfo info = cachedOpt.get();
            LocalDateTime expiresAt = info.getCreatedAt().plusMinutes(info.getExpiresInMinutes());

            if (LocalDateTime.now().isAfter(expiresAt)) {
                log.info("[PaymentExpired] ⏰ Payment expired: gencode={}, orderId={}",
                        gencode, info.getOrderId());
                restoreCartAndCancelOrder(info, gencode);
            }
        } catch (Exception e) {
            log.error("[PaymentExpired] Error processing key={}", key, e);
        }
    }

    private void handleMissingKey(String gencode) {
        // Key da bi xoa khoi Redis nhung order van con trong DB
        // Lay orderId tu DB bang cach parse gencode (ORDER_xxxxxxxxxxxxxxx)
        log.info("[PaymentExpired] Key missing in Redis: gencode={}. Checking DB for order.", gencode);
        // gencode format: ORDER_xxxxxxxxxxxxxxx (15 digits)
        orderRepository.findAll().stream()
                .filter(o -> o.getPaymentStatus().equals("pending"))
                .filter(o -> {
                    // Neu la don chuyen khoan chua thanh toan trong 30 phut → huy
                    if (!"Transfer".equalsIgnoreCase(o.getPaymentMethod())) return false;
                    return true;
                })
                .findFirst()
                .ifPresent(order -> {
                    // Xac dinh don co bi timeout khong bang cach kiem tra thoi gian tao
                    log.info("[PaymentExpired] Found pending transfer order without Redis cache: orderId={}",
                            order.getOrderId());
                });
    }

    @Transactional
    public void restoreCartAndCancelOrder(PaymentCacheInfo info, String gencode) {
        try {
            // 1. Huy don hang trong DB
            Optional<Order> orderOpt = orderRepository.findById(info.getOrderId());
            if (orderOpt.isEmpty()) {
                log.warn("[PaymentExpired] Order not found: orderId={}", info.getOrderId());
                return;
            }

            Order order = orderOpt.get();
            if (!"pending".equals(order.getStatus()) || !"pending".equals(order.getPaymentStatus())) {
                log.info("[PaymentExpired] Order already processed: orderId={}, status={}, paymentStatus={}",
                        info.getOrderId(), order.getStatus(), order.getPaymentStatus());
                return;
            }

            // 2. Xoa order items
            orderItemRepository.findByOrderOrderId(info.getOrderId())
                    .forEach(orderItemRepository::delete);

            // 3. Xoa order
            orderRepository.delete(order);
            log.info("[PaymentExpired] ✅ Order cancelled: orderId={}, orderCode={}",
                    info.getOrderId(), info.getOrderCode());

            // 4. Hoan cart items
            if (info.getCartSnapshot() != null && !info.getCartSnapshot().isEmpty()) {
                restoreCartItems(info.getAccountId(), info.getCartSnapshot());
            }

            // 5. Xoa Redis cache
            paymentRedisService.deleteByGencode(gencode, info.getOrderId());

            log.info("[PaymentExpired] ✅ Cart restored for accountId={}: {} items",
                    info.getAccountId(),
                    info.getCartSnapshot() != null ? info.getCartSnapshot().size() : 0);

        } catch (Exception e) {
            log.error("[PaymentExpired] ❌ Failed to restore cart: orderId={}", info.getOrderId(), e);
        }
    }

    private void restoreCartItems(Integer accountId, java.util.List<PaymentCacheInfo.CartSnapshotItem> snapshot) {
        Cart cart = cartRepository.findAllByAccountAccountIdOrderByUpdatedOnDescCartIdDesc(accountId)
                .stream()
                .findFirst()
                .orElseGet(() -> {
                    Cart newCart = new Cart();
                    newCart.setAccount(new com.example.ecommerce.entity.Account());
                    newCart.getAccount().setAccountId(accountId);
                    newCart.setCreatedOn(LocalDateTime.now());
                    newCart.setUpdatedOn(LocalDateTime.now());
                    return cartRepository.save(newCart);
                });

        for (PaymentCacheInfo.CartSnapshotItem item : snapshot) {
            // Kiem tra xem item da ton tai trong cart chua
            cartItemRepository.findByCartCartIdAndProductItemProductItemId(
                    cart.getCartId(), item.getProductItemId()
            ).ifPresentOrElse(
                    existing -> {
                        // Tang so luong
                        existing.setQuantity(existing.getQuantity() + item.getQuantity());
                        cartItemRepository.save(existing);
                    },
                    () -> {
                        // Them moi
                        CartItem ci = new CartItem();
                        ci.setCart(cart);
                        ci.setProductItem(productItemRepository.getReferenceById(item.getProductItemId()));
                        ci.setQuantity(item.getQuantity());
                        ci.setPrice(item.getPrice());
                        cartItemRepository.save(ci);
                    }
            );
        }

        cart.setUpdatedOn(LocalDateTime.now());
        cartRepository.save(cart);
    }
}
