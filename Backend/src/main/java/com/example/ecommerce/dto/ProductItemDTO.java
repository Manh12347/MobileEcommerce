package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductItemDTO {
    private Integer productItemId;
    private String sku;
    private String description;
    private Integer stockQuantity;
    private String status;
    private BigDecimal price;
    private BigDecimal salePrice;
    private String specifications;
    private String images;
    private String mainImageUrl;
    private String embeddingText;
    private Integer productId;
    private String productName;
    private List<SerialDTO> serials;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SerialDTO {
        private Integer serialId;
        private String serialCode;
        private String status;
        private LocalDateTime importDate;
    }
}
