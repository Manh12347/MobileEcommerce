package com.example.ecommerce.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateWarrantyRequest {

    @NotNull(message = "Serial ID is required")
    private Integer serialId;

    private LocalDate startDate;
    private LocalDate endDate;
    private String status;
}
