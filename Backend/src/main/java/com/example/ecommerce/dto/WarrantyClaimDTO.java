package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WarrantyClaimDTO {
    private Integer claimId;
    private Integer serialId;
    private String serialCode;
    private String serialSeries;
    private Integer productId;
    private String productName;
    private Integer accountId;
    private String accountEmail;
    private String customerName;
    private String customerPhone;
    private String customerAddress;
    private String productSku;
    private String warrantyStartDate;
    private String warrantyEndDate;
    private String warrantyStatus;
    private String issueDescription;
    private String status;
    private String createdAt;
}
