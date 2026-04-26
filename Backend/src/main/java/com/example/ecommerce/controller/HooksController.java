package com.example.ecommerce.controller;

import com.example.ecommerce.config.HookConfig;
import com.example.ecommerce.dto.BankTransactionDto;
import com.example.ecommerce.dto.TransactionProcessResult;
import com.example.ecommerce.entity.BankTransaction;
import com.example.ecommerce.service.HooksService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/hooks")
@RequiredArgsConstructor
@Slf4j
public class HooksController {
    private final HooksService hooksService;
    private final HookConfig hookConfig;

    /**
     * Webhook endpoint to receive bank transactions from SePay
     * Format: POST /hooks/transaction
     * Header: Authorization: Apikey <API_KEY>
     * Body: JSON BankTransactionDto
     */
    @PostMapping("/transaction")
    public ResponseEntity<?> receiveTransaction(
            @RequestBody BankTransactionDto dto,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        // ✅ NEVER return 500 - Always return 200 OK for webhook
        // SePay sẽ retry nếu nhận 500, gây duplicate transactions
        
        try {
            log.info("[HooksController] ===== WEBHOOK RECEIVED =====");
            log.info("[HooksController] Timestamp: {}", LocalDateTime.now());
            log.info("[HooksController] Code: {}, Amount: {}, Description: '{}', Content: '{}'", 
                dto.getCode(), dto.getTransferamount(), dto.getDescription(), dto.getContent());

            // 1️⃣ Validate DTO is not null
            if (dto == null) {
                log.warn("[HooksController] ❌ DTO is null");
                return ResponseEntity.ok(createErrorResponse(false, "Invalid request: DTO is null"));
            }

            // 2️⃣ Validate API key (simple match, no format required)
            if (authHeader == null || authHeader.isBlank()) {
                log.warn("[HooksController] ❌ Authorization header missing");
                return ResponseEntity.ok(createErrorResponse(false, "Authorization header missing"));
            }

            if (!authHeader.equals(hookConfig.getApiKey())) {
                log.warn("[HooksController] ❌ Invalid API key");
                return ResponseEntity.ok(createErrorResponse(false, "Invalid API key"));
            }

            log.info("[HooksController] ✅ API key validated");

            // 3️⃣ Parse transaction date
            LocalDateTime transactionDate = parseTransactionDate(dto.getTransactiondate());
            log.info("[HooksController] ✅ Parsed transaction date: {}", transactionDate);

            // 4️⃣ Map DTO to Entity
            BankTransaction entity = new BankTransaction();
            entity.setGateway(dto.getGateway() != null ? dto.getGateway() : "Sepay");
            entity.setTransactionDate(transactionDate);
            entity.setAccountNumber(dto.getAccountnumber() != null ? dto.getAccountnumber() : "");
            entity.setCode(dto.getCode());
            entity.setContent(dto.getContent() != null ? dto.getContent() : "");
            entity.setTransferType(dto.getTransfertype() != null ? dto.getTransfertype() : "");
            entity.setTransferAmount(dto.getTransferamount());
            entity.setAccumulated(dto.getAccumulated());
            entity.setSubaccount(dto.getSubaccount());
            entity.setReferenceCode(dto.getReferencecode() != null ? dto.getReferencecode() : "");
            entity.setDescription(dto.getDescription() != null ? dto.getDescription() : "");

            log.info("[HooksController] ✅ Mapped entity: RefCode={}, Amount={}, Date={}", 
                entity.getReferenceCode(), entity.getTransferAmount(), entity.getTransactionDate());

            // 5️⃣ Process transaction
            TransactionProcessResult result = hooksService.processTransactionAsync(entity);

            log.info("[HooksController] ✅ Process result: Message={}, OrderUpdated={}, OrderId={}", 
                result.getMessage(), result.isOrderUpdated(), result.getOrderId());

            // 6️⃣ Always return 200 OK
            return ResponseEntity.ok(createSuccessResponse(result));

        } catch (Exception e) {
            log.error("[HooksController] ❌ Exception occurred: ", e);
            // Still return 200 OK even on exception
            return ResponseEntity.ok(createErrorResponse(false, "Exception: " + e.getMessage()));
        }
    }

    }
     * Parse transaction date from multiple formats
     */
    private LocalDateTime parseTransactionDate(String dateStr) {
        if (dateStr == null || dateStr.isBlank()) {
            log.warn("[HooksController] Transaction date is null, using current time");
            return LocalDateTime.now();
        }

        String[] formats = {
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss"
        };

        for (String format : formats) {
            try {
                return LocalDateTime.parse(dateStr, DateTimeFormatter.ofPattern(format));
            } catch (Exception e) {
                // Try next format
            }
        }

        log.warn("[HooksController] Failed to parse date: {}, using current time", dateStr);
        return LocalDateTime.now();
    }

    /**
     * Create success response
     */
    private Map<String, Object> createSuccessResponse(TransactionProcessResult result) {
        Map<String, Object> response = new HashMap<>();
        response.put("message", result.getMessage());
        response.put("processed", result.isOrderUpdated());
        response.put("orderId", result.getOrderId());
        return response;
    }

    /**
     * Create error response
     */
    private Map<String, Object> createErrorResponse(boolean processed, String message) {
        Map<String, Object> response = new HashMap<>();
        response.put("message", message);
        response.put("processed", processed);
        return response;
    }
}
