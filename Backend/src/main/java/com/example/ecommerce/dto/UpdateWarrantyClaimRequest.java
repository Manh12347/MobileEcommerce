package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateWarrantyClaimRequest {
    private Integer serialId;
    private Integer accountId;
    private String issueDescription;
    private String status;
}
