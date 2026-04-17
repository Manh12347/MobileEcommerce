package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "warranty_claims")
@Getter @Setter
public class WarrantyClaim {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "claim_id")
    private Integer claimId;

    @ManyToOne
    @JoinColumn(name = "serial_id", nullable = false)
    private SerialNumber serialNumber;

    @ManyToOne
    @JoinColumn(name = "account_id", nullable = false)
    private Account account;

    @Column(name = "issue_description")
    private String issueDescription;

    @Column(name = "status")
    private String status; // pending, approved, rejected, completed

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}
