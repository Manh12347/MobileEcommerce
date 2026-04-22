package com.example.ecommerce.service;

import com.example.ecommerce.config.HookConfig;
import com.example.ecommerce.dto.BankTransactionDto;
import com.example.ecommerce.dto.TransactionProcessResult;
import com.example.ecommerce.entity.BankTransaction;
import com.example.ecommerce.entity.Order;
import com.example.ecommerce.repository.BankTransactionRepository;
import com.example.ecommerce.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class HooksService {
    private final BankTransactionRepository bankTransactionRepository;
    private final OrderRepository orderRepository;
    private final HookConfig hookConfig;

    /**
     * Thêm giao dịch ngân hàng vào DB
     */
    public void addTransactionAsync(BankTransaction transaction) {
        if (transaction == null) {
            throw new IllegalArgumentException("Transaction cannot be null");
        }
        bankTransactionRepository.save(transaction);
    }

    /**
     * Xử lý webhook từ SePay
     * 1. Kiểm tra trùng lặp
     * 2. Lưu vào DB
     * 3. Extract ORDER code từ description/content
     * 4. Tìm Order và update payment status
     */
    @Transactional
    public TransactionProcessResult processTransactionAsync(BankTransaction transaction) {
        if (transaction == null) {
            throw new IllegalArgumentException("Transaction cannot be null");
        }

        TransactionProcessResult result = new TransactionProcessResult();

        // 1️⃣ Kiểm tra xem transaction đã tồn tại chưa (tránh duplicate)
        log.info("[HooksService] Checking for duplicate transaction: refCode={}, amount={}, date={}", 
            transaction.getReferenceCode(), transaction.getTransferAmount(), transaction.getTransactionDate());

        // Lưu transaction vào DB
        transaction.setCreatedOn(LocalDateTime.now());
        bankTransactionRepository.save(transaction);
        result.setMessage("Transaction saved: " + transaction.getReferenceCode());

        log.info("[HooksService] ===== PROCESSING TRANSACTION =====");
        log.info("[HooksService] Transaction Code: {}", transaction.getCode());
        log.info("[HooksService] Amount: {}", transaction.getTransferAmount());
        log.info("[HooksService] Description: '{}'", transaction.getDescription());
        log.info("[HooksService] Content: '{}'", transaction.getContent());

        // 2️⃣ Extract ORDER code từ description hoặc content (16 ký tự hex)
        String orderCode = extractOrderCodeFromTransaction(transaction);
        log.info("[HooksService] Extracted orderCode: {}", orderCode != null ? orderCode : "NULL");

        if (orderCode == null) {
            log.warn("[HooksService] ❌ CRITICAL: No ORDER code found in transaction");
            result.setMessage(result.getMessage() + ". No ORDER code found");
            return result;
        }

        // 3️⃣ Tìm Order với mã này
        Optional<Order> orderOpt = orderRepository.findByOrderCode(orderCode);
        if (orderOpt.isEmpty()) {
            log.warn("[HooksService] ORDER code {} not found in database", orderCode);
            result.setMessage(result.getMessage() + ". ORDER code not found in database");
            return result;
        }

        Order order = orderOpt.get();
        log.info("[HooksService] ✅ Found order: orderId={}, orderCode={}", order.getOrderId(), order.getOrderCode());

        // 4️⃣ Kiểm tra số tiền (với tolerance)
        BigDecimal amountDifference = transaction.getTransferAmount().subtract(order.getTotalPrice()).abs();
        log.info("[HooksService] Amount check: Order={}, Transaction={}, Difference={}, Tolerance={}", 
            order.getTotalPrice(), transaction.getTransferAmount(), amountDifference, hookConfig.getAmountTolerance());

        if (amountDifference.compareTo(hookConfig.getAmountTolerance()) > 0) {
            log.warn("[HooksService] ❌ Amount mismatch - REJECTED");
            result.setMessage(result.getMessage() + ". Amount mismatch");
            result.setOrderId(order.getOrderId());
            return result;
        }

        // 5️⃣ Update order payment status
        order.setPaymentStatus("PAID");
        order.setStatus("CONFIRMED");
        order.setModifiedOn(LocalDateTime.now());
        orderRepository.save(order);

        log.info("[HooksService] ✅ Order payment confirmed: orderId={}, status={}, paymentStatus={}", 
            order.getOrderId(), order.getStatus(), order.getPaymentStatus());

        result.setMessage(result.getMessage() + ". Payment successful! Order " + order.getOrderId() + " confirmed");
        result.setOrderUpdated(true);
        result.setOrderId(order.getOrderId());

        return result;
    }

    /**
     * Extract ORDER code từ transaction (16 ký tự hex)
     */
    private String extractOrderCodeFromTransaction(BankTransaction transaction) {
        if (transaction.getContent() != null && !transaction.getContent().isBlank()) {
            String orderCode = extractOrderCodeFromString(transaction.getContent());
            if (orderCode != null) return orderCode;
        }

        if (transaction.getDescription() != null && !transaction.getDescription().isBlank()) {
            return extractOrderCodeFromString(transaction.getDescription());
        }

        return null;
    }

    /**
     * Extract ORDER code từ một chuỗi (16 ký tự hex)
     * Format: ORDER + 16 ký tự hex = 21 ký tự tổng
     * VD: ORDER1A2B3C4D5E6F7890
     */
    private String extractOrderCodeFromString(String input) {
        if (input == null || input.isBlank()) return null;

        // Regex: ORDER + 16 ký tự hex (a-f, 0-9)
        Pattern pattern = Pattern.compile("ORDER[A-F0-9]{16}", Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(input);

        if (matcher.find()) {
            String orderCode = matcher.group().toUpperCase();
            log.debug("[HooksService] Found ORDER code: {}", orderCode);
            return orderCode;
        }

        log.debug("[HooksService] No ORDER code pattern found in: {}", input);
        return null;
    }
}
