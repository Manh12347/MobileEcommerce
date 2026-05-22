package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.io.Serializable;

@Embeddable
@Getter @Setter
public class ProductPromotionId implements Serializable {
    private Integer productId;
    private Integer promotionId;
}
