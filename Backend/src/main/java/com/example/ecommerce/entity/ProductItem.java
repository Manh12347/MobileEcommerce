package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import com.example.ecommerce.util.JsonbConverter;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "product_items")
@Getter @Setter
public class ProductItem extends BaseCreatedEntity {

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

    // JSONB - tự động convert String -> JSON khi save
    @Convert(converter = JsonbConverter.class)
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private String specifications;

    @Convert(converter = JsonbConverter.class)
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private String images;

    @Column(name = "main_image_url")
    private String mainImageUrl;

    // vector type không được Hibernate support tốt - bỏ qua khi load từ DB
    @Transient
    private float[] embedding;

    @Column(name = "embedding_text")
    private String embeddingText;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "product_id")
    private Product product;

    @OneToMany(mappedBy = "productItem", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<SerialNumber> serials = new ArrayList<>();
}
