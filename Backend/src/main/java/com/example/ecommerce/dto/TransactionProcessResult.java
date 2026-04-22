package com.example.ecommerce.dto;

import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class TransactionProcessResult {
    private String message;
    private boolean orderUpdated;
    private Integer orderId;

    public TransactionProcessResult() {
        this.message = "";
        this.orderUpdated = false;
    }
}
