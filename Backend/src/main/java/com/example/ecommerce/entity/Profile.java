package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "profiles")
@Getter @Setter
public class Profile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "profile_id")
    private Integer profileId;

    @OneToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "account_id")
    private Account account;

    private String fullName;
    private String phone;
    private String address;
    private String avatarUrl;

    private Integer provinceId;
    private String provinceName;
    private Integer districtId;
    private String districtName;
    private String wardCode;
    private String wardName;

    @Column(name = "created_on", updatable = false)
    private LocalDateTime createdOn;

    @PrePersist
    protected void onCreate() {
        createdOn = LocalDateTime.now();
    }
}
