package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "bank_transactions")
@Getter @Setter
public class BankTransaction extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "transaction_id")
    private Long transactionId;

    private String gateway;

    @Column(name = "transaction_date")
    private LocalDateTime transactionDate;

    @Column(name = "account_number")
    private String accountNumber;

    private String code;

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(name = "transfer_type")
    private String transferType;

    @Column(name = "transfer_amount")
    private BigDecimal transferAmount;

    private BigDecimal accumulated;

    private String subaccount;

    @Column(name = "reference_code")
    private String referenceCode;

    @Column(columnDefinition = "TEXT")
    private String description;
}
