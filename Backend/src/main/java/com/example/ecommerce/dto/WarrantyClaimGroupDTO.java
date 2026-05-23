package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WarrantyClaimGroupDTO {
    private String productName;
    private String serialSeries;
    private List<String> customerNames;
    private List<String> customerPhones;
    private String productSku;
    private String earliestWarrantyStartDate;
    private String latestWarrantyEndDate;
    private Integer claimCount;
    private String latestCreatedAt;
    private Map<String, Long> statusCounts;
    private List<WarrantyClaimDTO> claims;
}
