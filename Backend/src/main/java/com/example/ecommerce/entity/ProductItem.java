package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "product_items")
@Getter @Setter
public class ProductItem extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "product_item_id")
    private Integer productItemId;

    private String sku;
    private String description;
    private Integer stockQuantity;
    private String status;

    private java.math.BigDecimal price;
    private java.math.BigDecimal salePrice;

    // JSONB
    @Column(columnDefinition = "jsonb")
    private String specifications;

    @Column(columnDefinition = "jsonb")
    private String images;

    @Column(name = "main_image_url")
    private String mainImageUrl;

    // vector → tạm dùng float[]
    @Column(columnDefinition = "vector(1536)")
    private float[] embedding;

    @Column(name = "embedding_text")
    private String embeddingText;

    @ManyToOne
    @JoinColumn(name = "product_id")
    private Product product;
}
