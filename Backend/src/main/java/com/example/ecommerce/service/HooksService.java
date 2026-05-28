package com.example.ecommerce.service;

import com.example.ecommerce.config.HookConfig;
import com.example.ecommerce.dto.PaymentCacheInfo;
import com.example.ecommerce.dto.TransactionProcessResult;
import com.example.ecommerce.entity.BankTransaction;
import com.example.ecommerce.entity.Order;
import com.example.ecommerce.entity.Payment;
import com.example.ecommerce.hub.PaymentHub;
import com.example.ecommerce.repository.BankTransactionRepository;
import com.example.ecommerce.repository.OrderRepository;
import com.example.ecommerce.repository.PaymentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class HooksService {

    private static final String GENCODE_PREFIX = "ORDER";
    private static final int GENCODE_DIGITS = 15;

    private final BankTransactionRepository bankTransactionRepository;
    private final PaymentRedisService paymentRedisService;
    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final OrderService orderService;
    private final PaymentHub paymentHub;
    private final GhnService ghnService;
    private final HookConfig hookConfig;

    /**
     * Xu ly webhook tu SePay.
     * 1. Kiem tra trung lap (idempotency)
     * 2. Luu bank_transaction vao DB
     * 3. Extract gencode tu description/content
     * 4. Lookup Redis cache
     * 5. Xac nhan thanh toan: cap nhat order, cap phat serial, gui thong bao SignalR
     */
    @Transactional
    public TransactionProcessResult processTransactionAsync(BankTransaction transaction) {
        if (transaction == null) {
            throw new IllegalArgumentException("Transaction cannot be null");
        }

        TransactionProcessResult result = new TransactionProcessResult();
        result.setMessage("Transaction saved successfully");
        result.setOrderUpdated(false);

        // 1. Idempotency: neu da xu ly roi thi skip
        if (transaction.getCode() != null && !transaction.getCode().isBlank()) {
            if (bankTransactionRepository.findByCode(transaction.getCode()).isPresent()) {
                log.info("[HooksService] Already processed: code={}", transaction.getCode());
                result.setMessage("Already processed");
                return result;
            }
        }

        // 2. Luu transaction vao DB
        transaction.setCreatedOn(LocalDateTime.now());
        bankTransactionRepository.save(transaction);
        log.info("[HooksService] Bank transaction saved: code={}, amount={}, content='{}'",
                transaction.getCode(), transaction.getTransferAmount(), transaction.getContent());

        // 3. Extract gencode tu content hoac description
        String content = transaction.getContent() != null ? transaction.getContent().trim() : "";
        String description = transaction.getDescription() != null ? transaction.getDescription().trim() : "";
        String gencode = extractGencode(content, description);

        if (gencode == null) {
            log.warn("[HooksService] No valid gencode found in content='{}', description='{}'", content, description);
            result.setMessage("No valid gencode found in transaction content");
            return result;
        }

        log.info("[HooksService] Extracted gencode: {}", gencode);

        // 4. Lookup Redis cache
        Optional<PaymentCacheInfo> cachedInfo = paymentRedisService.getByGencode(gencode);
        if (cachedInfo.isEmpty()) {
            log.warn("[HooksService] Gencode not found in Redis: {}. May have expired or already processed.", gencode);
            result.setMessage("Gencode not found or expired");
            return result;
        }

        PaymentCacheInfo orderInfo = cachedInfo.get();
        log.info("[HooksService] Redis hit: orderId={}, expectedAmount={}, receivedAmount={}",
                orderInfo.getOrderId(), orderInfo.getTotalAmount(), transaction.getTransferAmount());

        // 5. Verify amount (with tolerance)
        BigDecimal tolerance = hookConfig.getAmountTolerance();
        BigDecimal diff = transaction.getTransferAmount().subtract(orderInfo.getTotalAmount()).abs();
        if (diff.compareTo(tolerance) > 0) {
            log.warn("[HooksService] Amount mismatch: expected={}, received={}, diff={}, tolerance={}",
                    orderInfo.getTotalAmount(), transaction.getTransferAmount(), diff, tolerance);
            result.setMessage("Amount mismatch");
            return result;
        }

        log.info("[HooksService] Amount verified: {}", transaction.getTransferAmount());

        // 6. Update order payment status = "paid"
        Integer orderId = orderInfo.getOrderId();
        Optional<Order> orderOpt = orderRepository.findById(orderId);
        if (orderOpt.isEmpty()) {
            log.error("[HooksService] Order not found: id={}", orderId);
            result.setMessage("Order not found");
            return result;
        }

        Order order = orderOpt.get();
        order.setPaymentStatus("paid");
        orderRepository.save(order);
        log.info("[HooksService] Order payment_status updated to 'paid': orderId={}", orderId);

        // 7. Cap phat serial (chi sau khi xac nhan thanh toan)
        try {
            orderService.confirmTransferPayment(orderId);
            log.info("[HooksService] Transfer order serials allocated: orderId={}", orderId);
        } catch (Exception e) {
            log.warn("[HooksService] Serial allocation error (may already be done): orderId={}, error={}",
                    orderId, e.getMessage());
        }

        // 8. Update/Create payment record
        updatePaymentRecord(orderId, gencode, transaction.getTransferAmount());

        // 9. Xoa Redis cache
        paymentRedisService.deleteByGencode(gencode, orderId);

        // 10. Gui SignalR notification
        paymentHub.notifyPaymentSuccess(
                gencode,
                orderId,
                orderInfo.getOrderCode(),
                "paid",
                "Thanh toan don hang " + orderInfo.getOrderCode() + " thanh cong!"
        );

        // 11. Tao don van chuyen GHN (bat dong bo)
        try {
              scheduleGhnAfterCommit(orderId);
        } catch (Exception e) {
            log.warn("[HooksService] GHN order creation failed (non-critical): orderId={}, error={}",
                    orderId, e.getMessage());
        }

        log.info("[HooksService] Payment confirmed: orderId={}, gencode={}, amount={}",
                orderId, gencode, transaction.getTransferAmount());

        result.setMessage("Payment confirmed successfully");
        result.setOrderUpdated(true);
        result.setOrderId(orderId);
        return result;
    }

    /**
     * Extract gencode tu chuoi content hoac description.
     * Tim chuoi bat dau bang "ORDER" va theo sau la 15 chu so.
     */
    private String extractGencode(String content, String description) {
        StringBuilder sb = new StringBuilder();
        if (content != null && !content.isBlank()) sb.append(content).append(' ');
        if (description != null && !description.isBlank()) sb.append(description);
        String source = sb.toString();
        if (source.isBlank()) return null;

        String upper = source.toUpperCase();
        int from = 0;

        while (true) {
            int idx = upper.indexOf(GENCODE_PREFIX, from);
            if (idx < 0) break;

            int scanStart = idx + GENCODE_PREFIX.length();
            StringBuilder digits = new StringBuilder();

            int maxScan = Math.min(source.length(), scanStart + 60);
            for (int k = scanStart; k < maxScan; k++) {
                char ch = source.charAt(k);
                if (Character.isDigit(ch)) {
                    digits.append(ch);
                } else if (ch == '-' || ch == ' ' || ch == '\u00A0') {
                    continue;
                } else {
                    if (digits.length() > 0) break;
                }
                if (digits.length() >= GENCODE_DIGITS) break;
            }

            if (digits.length() >= GENCODE_DIGITS) {
                String found = digits.substring(0, GENCODE_DIGITS);
                return GENCODE_PREFIX + found;
            }

            from = scanStart;
        }

        return null;
    }

    private void updatePaymentRecord(Integer orderId, String gencode, BigDecimal amount) {
        paymentRepository.findFirstByOrderOrderId(orderId).ifPresentOrElse(
                payment -> {
                    payment.setStatus("success");
                    payment.setTransactionId(gencode);
                    payment.setAmount(amount);
                    paymentRepository.save(payment);
                    log.info("[HooksService] Payment record updated: paymentId={}", payment.getPaymentId());
                },
                () -> {
                    Payment newPayment = new Payment();
                    newPayment.setOrder(orderRepository.findById(orderId).orElse(null));
                    newPayment.setAmount(amount);
                    newPayment.setMethod("Sepay");
                    newPayment.setStatus("success");
                    newPayment.setTransactionId(gencode);
                    newPayment.setCreatedAt(LocalDateTime.now());
                    paymentRepository.save(newPayment);
                    log.info("[HooksService] New payment record created: orderId={}", orderId);
                }
        );
    }

    private void scheduleGhnAfterCommit(Integer orderId) {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                ghnService.createShippingOrderAsync(orderId);
            }
        });
    }
}
