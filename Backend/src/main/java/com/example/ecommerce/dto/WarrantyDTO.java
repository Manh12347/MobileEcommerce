package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WarrantyDTO {
    private Integer warrantyId;
    private Integer serialId;
    private String serialCode;
    private LocalDate startDate;
    private LocalDate endDate;
    private String status;
}
