package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "serial_numbers")
@Getter @Setter
public class SerialNumber {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "serial_id")
    private Integer serialId;

    @ManyToOne
    @JoinColumn(name = "product_item_id", nullable = false)
    private ProductItem productItem;

    @Column(name = "serial_code", unique = true, nullable = false)
    private String serialCode;

    @Column(name = "status")
    private String status; // in_stock, sold, warranty, returned

    @Column(name = "import_date")
    private LocalDateTime importDate = LocalDateTime.now();
}
