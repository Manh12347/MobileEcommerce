package com.example.ecommerce.service;

import com.example.ecommerce.config.HookConfig;
import com.example.ecommerce.dto.TransactionProcessResult;
import com.example.ecommerce.entity.BankTransaction;
import com.example.ecommerce.repository.BankTransactionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class HooksService {
    private final BankTransactionRepository bankTransactionRepository;

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

        // Lưu transaction vào DB
        transaction.setCreatedOn(LocalDateTime.now());
        bankTransactionRepository.save(transaction);

        result.setMessage("Transaction saved successfully");
        result.setOrderUpdated(false);

        return result;
    }
}
