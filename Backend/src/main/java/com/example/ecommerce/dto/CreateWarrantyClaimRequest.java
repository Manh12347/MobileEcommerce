package com.example.ecommerce.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateWarrantyClaimRequest {

    @NotNull(message = "Serial ID is required")
    private Integer serialId;

    @NotNull(message = "Account ID is required")
    private Integer accountId;

    private String issueDescription;
    private String status;
}
