package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "accounts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Account extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "account_id")
    private Integer accountId;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "email_confirm")
    private Boolean emailConfirm;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    private String role;

    @Column(name = "is_2fa_enabled")
    private Boolean is2faEnabled;

    @Column(name = "twofa_secret")
    private String twofaSecret;

    @Column(name = "twofa_recovery_codes")
    private String twofaRecoveryCodes;

    private String status;

    @Column(name = "failed_login_attempts")
    private Integer failedLoginAttempts;

    @Column(name = "last_failed_login")
    private java.time.LocalDateTime lastFailedLogin;
}
