package com.example.ecommerce.dto;

import lombok.Data;
import java.util.List;

@Data
public class ApplyPromotionToItemsRequest {
    private List<Integer> productItemIds;
    private Integer promotionId;
}
