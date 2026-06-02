package com.example.ecommerce.controller;

import com.example.ecommerce.config.HookConfig;
import com.example.ecommerce.config.SepayConfig;
import com.example.ecommerce.dto.BankTransactionDto;
import com.example.ecommerce.dto.GhnCreateOrderResponse;
import com.example.ecommerce.dto.PaymentCacheInfo;
import com.example.ecommerce.dto.PaymentNotificationPayload;
import com.example.ecommerce.entity.BankTransaction;
import com.example.ecommerce.entity.Order;
import com.example.ecommerce.entity.Payment;
import com.example.ecommerce.hub.PaymentHub;
import com.example.ecommerce.repository.BankTransactionRepository;
import com.example.ecommerce.repository.OrderRepository;
import com.example.ecommerce.repository.PaymentRepository;
import com.example.ecommerce.service.GhnService;
import com.example.ecommerce.service.OrderService;
import com.example.ecommerce.service.PaymentRedisService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/v1/api/payment")
@RequiredArgsConstructor
@Slf4j
public class SepayWebhookController {

    private static final String GENCODE_PREFIX = "ORDER";
    private static final int GENCODE_DIGITS = 15;

    private final SepayConfig sepayConfig;
    private final HookConfig hookConfig;
    private final PaymentRedisService paymentRedisService;
    private final PaymentHub paymentHub;
    private final GhnService ghnService;
    private final OrderService orderService;
    private final BankTransactionRepository bankTransactionRepository;
    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;

    /**
     * Webhook endpoint nhận thông báo thanh toán từ SePay
     * Format: POST /v1/api/payment/webhook
     * Header: Authorization: Apikey <key>
     * Body: JSON BankTransactionDto
     *
     * Luồng:
     * 1. Validate API key
     * 2. Lưu bank_transaction (gencode nằm trong content/description)
     * 3. Extract gencode từ content → lookup Redis
     * 4. Nếu gencode match → update order payment_status = "paid"
     * 5. SignalR notification cho client
     * 6. Gọi GHN API tạo đơn vận chuyển
     */
    @PostMapping("/webhook")
    @Transactional
    public ResponseEntity<?> handleWebhook(
            @RequestBody BankTransactionDto dto,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {

        try {
            log.info("[SepayWebhook] ===== WEBHOOK RECEIVED =====");
            log.info("[SepayWebhook] Code={}, Amount={}, Content='{}', Description='{}'",
                    dto.getCode(), dto.getTransferamount(), dto.getContent(), dto.getDescription());

            // 1. Validate API key
            if (!validateApiKey(authHeader)) {
                log.warn("[SepayWebhook] ❌ Invalid API key");
                return ResponseEntity.ok(createResponse(false, "Invalid API key", null));
            }

            // 2. Idempotency: check đã xử lý chưa
            if (isAlreadyProcessed(dto)) {
                log.info("[SepayWebhook] ⏭️  Already processed: code={}", dto.getCode());
                return ResponseEntity.ok(createResponse(true, "Already processed", null));
            }

            // 3. Parse transaction date
            LocalDateTime transactionDate = parseTransactionDate(dto.getTransactiondate());

            // 4. Save bank_transaction (gencode nằm trong content)
            BankTransaction bankTx = mapToEntity(dto, transactionDate);
            bankTransactionRepository.save(bankTx);
            log.info("[SepayWebhook] ✅ Bank transaction saved: id={}, content='{}'",
                    bankTx.getTransactionId(), dto.getContent());

            // 5. Extract gencode từ content hoặc description
            String content = dto.getContent() != null ? dto.getContent().trim() : "";
            String description = dto.getDescription() != null ? dto.getDescription().trim() : "";
            String gencode = extractGencode(content, description);

            if (gencode == null) {
                log.warn("[SepayWebhook] ❌ No valid gencode found in content='{}', description='{}'",
                        content, description);
                return ResponseEntity.ok(createResponse(false, "No valid gencode found", null));
            }

            log.info("[SepayWebhook] ✅ Extracted gencode: {}", gencode);

            // 6. Lookup Redis cache
            Optional<PaymentCacheInfo> cachedInfo = paymentRedisService.getByGencode(gencode);
            if (cachedInfo.isEmpty()) {
                log.warn("[SepayWebhook] ❌ Gencode not found in Redis: {}. May have expired.", gencode);
                return ResponseEntity.ok(createResponse(false, "Gencode not found or expired", null));
            }

            PaymentCacheInfo orderInfo = cachedInfo.get();
            log.info("[SepayWebhook] ✅ Redis hit: orderId={}, expectedAmount={}, receivedAmount={}",
                    orderInfo.getOrderId(), orderInfo.getTotalAmount(), dto.getTransferamount());

            // 7. Verify amount
            BigDecimal tolerance = hookConfig.getAmountTolerance();
            BigDecimal diff = dto.getTransferamount().subtract(orderInfo.getTotalAmount()).abs();
            if (diff.compareTo(tolerance) > 0) {
                log.warn("[SepayWebhook] ❌ Amount mismatch: expected={}, received={}, diff={}",
                        orderInfo.getTotalAmount(), dto.getTransferamount(), diff);
                return ResponseEntity.ok(createResponse(false, "Amount mismatch", orderInfo.getOrderId()));
            }

            log.info("[SepayWebhook] ✅ Amount verified: {}", dto.getTransferamount());

            // 8. Update order payment status = "paid"
            Integer orderId = orderInfo.getOrderId();
            Optional<Order> orderOpt = orderRepository.findById(orderId);
            if (orderOpt.isEmpty()) {
                log.error("[SepayWebhook] ❌ Order not found: id={}", orderId);
                return ResponseEntity.ok(createResponse(false, "Order not found", orderId));
            }

            Order order = orderOpt.get();
            order.setPaymentStatus("paid");
            orderRepository.save(order);
            log.info("[SepayWebhook] ✅ Order payment_status updated to 'paid': orderId={}", orderId);

            // 9a. Allocate serials only after payment is confirmed
            orderService.confirmTransferPayment(orderId);
            log.info("[SepayWebhook] ✅ Transfer order serials allocated after payment confirmation: orderId={}", orderId);

            // 9. Create/update payment record
            updatePaymentRecord(orderId, gencode, dto.getTransferamount());

            // 10. Delete Redis cache (gencode chỉ dùng 1 lần)
            paymentRedisService.deleteByGencode(gencode, orderId);

            // 11. Send SignalR notification → client ngay sau khi chốt bán
            paymentHub.notifyPaymentSuccess(
                    gencode,
                    orderId,
                    orderInfo.getOrderCode(),
                    "paid",
                    "Thanh toán đơn hàng " + orderInfo.getOrderCode() + " thành công!"
            );

            // 12. Gọi GHN API tạo đơn vận chuyển (bất đồng bộ)
            ghnService.createShippingOrderAsync(orderId);

            log.info("[SepayWebhook] ✅ Payment confirmed + GHN order initiated: orderId={}, gencode={}, amount={}",
                    orderId, gencode, dto.getTransferamount());

            Map<String, Object> data = new HashMap<>();
            data.put("orderId", orderId);
            data.put("gencode", gencode);
            data.put("paymentStatus", "paid");
            return ResponseEntity.ok(createResponse(true, "Payment confirmed and GHN order created", data));

        } catch (Exception e) {
            log.error("[SepayWebhook] ❌ Unexpected error: ", e);
            return ResponseEntity.ok(createResponse(false, "Internal error: " + e.getMessage(), null));
        }
    }

    /**
     * Generate QR URL cho trang thanh toán
     * GET /v1/api/payment/qr?gencode=ORDER_xxx&amount=100000
     */
    @GetMapping("/qr")
    public ResponseEntity<?> getQrUrl(
            @RequestParam String gencode,
            @RequestParam BigDecimal amount) {

        if (gencode == null || gencode.isBlank() || amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            return ResponseEntity.ok(createResponse(false, "Invalid parameters", null));
        }

        try {
            String formattedAmount = amount.setScale(2).toPlainString();
            String bank = java.net.URLEncoder.encode(sepayConfig.getBankName(), java.nio.charset.StandardCharsets.UTF_8);
            String acc = java.net.URLEncoder.encode(sepayConfig.getAccountNumber(), java.nio.charset.StandardCharsets.UTF_8);
            String amt = java.net.URLEncoder.encode(formattedAmount, java.nio.charset.StandardCharsets.UTF_8);
            String desc = java.net.URLEncoder.encode(gencode, java.nio.charset.StandardCharsets.UTF_8);

            // Build URL matching template: acc, bank, amount, des, template, download
            String qrUrl = String.format(
                "https://qr.sepay.vn/img?acc=%s&bank=%s&amount=%s&des=%s&template=compact&download=false",
                acc, bank, amt, desc
            );

            Map<String, Object> data = new HashMap<>();
            data.put("qrUrl", qrUrl);
            data.put("gencode", gencode);
            data.put("amount", amount);
            data.put("accountNumber", sepayConfig.getAccountNumber());
            data.put("bankName", sepayConfig.getBankName());

            return ResponseEntity.ok(createResponse(true, "QR URL generated", data));
        } catch (Exception e) {
            log.error("[SepayWebhook] Failed to build qrUrl", e);
            return ResponseEntity.ok(createResponse(false, "Failed to build qrUrl", null));
        }
    }

    /**
     * Check payment status by gencode
     * GET /v1/api/payment/status/{gencode}
     */
    @GetMapping("/status/{gencode}")
    public ResponseEntity<?> getPaymentStatus(@PathVariable String gencode) {
        try {
            Optional<PaymentCacheInfo> cached = paymentRedisService.getByGencode(gencode);
            if (cached.isPresent()) {
                PaymentCacheInfo info = cached.get();
                Map<String, Object> data = new HashMap<>();
                data.put("gencode", gencode);
                data.put("status", info.getPaymentStatus());
                data.put("orderId", info.getOrderId());
                data.put("totalAmount", info.getTotalAmount());
                return ResponseEntity.ok(createResponse(true, "Pending", data));
            }

            // Cache hết hạn hoặc đã được xóa sau khi thành công → kiểm tra DB
            Optional<Payment> paymentOpt = paymentRepository.findByTransactionId(gencode);
            if (paymentOpt.isPresent()) {
                Payment p = paymentOpt.get();
                Map<String, Object> data = new HashMap<>();
                data.put("gencode", gencode);
                data.put("status", p.getStatus().equalsIgnoreCase("success") ? "paid" : p.getStatus());
                data.put("orderId", p.getOrder() != null ? p.getOrder().getOrderId() : null);
                data.put("totalAmount", p.getAmount());
                return ResponseEntity.ok(createResponse(true, "Success", data));
            }

            // Cache hết hạn và không có trong DB
            Map<String, Object> data = new HashMap<>();
            data.put("gencode", gencode);
            data.put("status", "expired_or_unknown");
            return ResponseEntity.ok(createResponse(false, "Gencode not found or expired", data));
        } catch (Exception e) {
            log.error("[SepayWebhook] Error checking status: gencode={}", gencode, e);
            return ResponseEntity.ok(createResponse(false, e.getMessage(), null));
        }
    }

    // ─────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────

    private boolean validateApiKey(String authHeader) {
        if (authHeader == null || authHeader.isBlank()) return false;
        String expectedKey = hookConfig.getApiKey();
        String receivedKey = authHeader.startsWith("Apikey ")
                ? authHeader.substring("Apikey ".length())
                : authHeader;
        return expectedKey.equals(receivedKey);
    }

    private boolean isAlreadyProcessed(BankTransactionDto dto) {
        if (dto.getCode() == null || dto.getCode().isBlank()) return false;
        return bankTransactionRepository.findByCode(dto.getCode()).isPresent();
    }

    private String extractGencode(String content, String description) {
        // Combine content + description to a single searchable string
        StringBuilder sb = new StringBuilder();
        if (content != null && !content.isBlank()) sb.append(content).append(' ');
        if (description != null && !description.isBlank()) sb.append(description);
        String source = sb.toString();
        if (source.isBlank()) return null;

        // Normalize for searching but keep original for digit extraction
        String upper = source.toUpperCase();

        int from = 0;
        while (true) {
            int idx = upper.indexOf(GENCODE_PREFIX, from);
            if (idx < 0) break;

            int scanStart = idx + GENCODE_PREFIX.length();
            StringBuilder digits = new StringBuilder();

            // Scan forward up to a window to collect digits; ignore hyphens/spaces
            int maxScan = Math.min(source.length(), scanStart + 60);
            for (int k = scanStart; k < maxScan; k++) {
                char ch = source.charAt(k);
                if (Character.isDigit(ch)) {
                    digits.append(ch);
                } else if (ch == '-' || ch == ' ' || ch == '\u00A0') {
                    // skip common separators (hyphen, space, non-breaking space)
                    continue;
                } else {
                    // if we've already collected some digits and hit another char, stop
                    if (digits.length() > 0) break;
                    // otherwise continue scanning (allow punctuation between ORDER and digits)
                }
                // stop early if we already have enough
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

    private LocalDateTime parseTransactionDate(String dateStr) {
        if (dateStr == null || dateStr.isBlank()) return LocalDateTime.now();
        String[] formats = {"yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy/MM/dd HH:mm:ss"};
        for (String format : formats) {
            try {
                return LocalDateTime.parse(dateStr, DateTimeFormatter.ofPattern(format));
            } catch (Exception ignored) {
            }
        }
        return LocalDateTime.now();
    }

    private BankTransaction mapToEntity(BankTransactionDto dto, LocalDateTime txDate) {
        BankTransaction entity = new BankTransaction();
        entity.setGateway(dto.getGateway() != null ? dto.getGateway() : "Sepay");
        entity.setTransactionDate(txDate);
        entity.setAccountNumber(dto.getAccountnumber() != null ? dto.getAccountnumber() : "");
        entity.setCode(dto.getCode());
        entity.setContent(dto.getContent() != null ? dto.getContent() : "");
        entity.setTransferType(dto.getTransfertype() != null ? dto.getTransfertype() : "");
        entity.setTransferAmount(dto.getTransferamount());
        entity.setAccumulated(dto.getAccumulated());
        entity.setSubaccount(dto.getSubaccount());
        entity.setReferenceCode(dto.getReferencecode() != null ? dto.getReferencecode() : "");
        entity.setDescription(dto.getDescription() != null ? dto.getDescription() : "");
        entity.setCreatedOn(LocalDateTime.now());
        return entity;
    }

    private void updatePaymentRecord(Integer orderId, String gencode, BigDecimal amount) {
        paymentRepository.findFirstByOrderOrderId(orderId).ifPresentOrElse(
                payment -> {
                    payment.setStatus("success");
                    payment.setTransactionId(gencode);
                    payment.setAmount(amount);
                    paymentRepository.save(payment);
                    log.info("[SepayWebhook] ✅ Payment record updated: paymentId={}, status=success", payment.getPaymentId());
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
                    log.info("[SepayWebhook] ✅ New payment record created: orderId={}", orderId);
                }
        );
    }

    private Map<String, Object> createResponse(boolean success, String message, Object data) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", success);
        response.put("message", message);
        if (data != null) response.put("data", data);
        return response;
    }
}
