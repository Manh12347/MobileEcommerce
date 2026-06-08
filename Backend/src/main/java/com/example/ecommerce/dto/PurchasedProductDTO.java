package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PurchasedProductDTO {
    private Integer orderId;
    private String orderCode;
    private String orderStatus;
    private String createdOn;
    private Integer orderItemId;
    private Integer productItemId;
    private String sku;
    private String productName;
    private String mainImageUrl;
    private Integer quantity;
    private Integer serialId;
    private String serialCode;
    private String serialStatus;
    private String warrantyEndDate;
    private Boolean isWarrantyExpired;
    private String warrantyRemainingText;
}
