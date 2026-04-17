package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "orders")
@Getter @Setter
public class Order extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_id")
    private Integer orderId;

    @Column(name = "order_code", unique = true)
    private String orderCode;

    private String status;

    @Column(name = "payment_status")
    private String paymentStatus;

    @Column(name = "payment_method")
    private String paymentMethod;

    private String shippingAddress;
    private String phone;

    private java.math.BigDecimal totalPrice;

    @ManyToOne
    @JoinColumn(name = "account_id")
    private Account account;
}
