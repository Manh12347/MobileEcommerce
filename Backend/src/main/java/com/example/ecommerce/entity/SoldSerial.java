package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "sold_serials")
@Getter @Setter
public class SoldSerial {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sold_serial_id")
    private Integer soldSerialId;

    @ManyToOne
    @JoinColumn(name = "order_item_id", nullable = false)
    private OrderItem orderItem;

    @ManyToOne
    @JoinColumn(name = "serial_id", nullable = false)
    private SerialNumber serialNumber;
}
