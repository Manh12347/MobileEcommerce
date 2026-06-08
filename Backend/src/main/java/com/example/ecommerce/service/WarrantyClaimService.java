package com.example.ecommerce.service;

import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.SerialNumber;
import com.example.ecommerce.entity.WarrantyClaim;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.repository.SerialNumberRepository;
import com.example.ecommerce.repository.WarrantyClaimRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@Transactional
public class WarrantyClaimService {

    @Autowired
    private WarrantyClaimRepository warrantyClaimRepository;

    @Autowired
    private SerialNumberRepository serialNumberRepository;

    @Autowired
    private AccountRepository accountRepository;

    public WarrantyClaim createClaim(Integer serialId, Integer accountId, String issueDescription, String status) {
        SerialNumber serialNumber = serialNumberRepository.findById(serialId.longValue())
                .orElseThrow(() -> new RuntimeException("Serial number not found with id: " + serialId));

        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Account not found with id: " + accountId));

        WarrantyClaim claim = new WarrantyClaim();
        claim.setSerialNumber(serialNumber);
        claim.setAccount(account);
        claim.setIssueDescription(issueDescription);
        claim.setStatus(normalizeStatus(status));
        claim.setCreatedAt(LocalDateTime.now());

        return warrantyClaimRepository.save(claim);
    }

    public WarrantyClaim createClaimBySerialCode(String serialCode, Integer accountId, String issueDescription) {
        if (serialCode == null || serialCode.isBlank()) {
            throw new RuntimeException("Số serial không được để trống");
        }

        SerialNumber serialNumber = serialNumberRepository.findBySerialCode(serialCode.trim())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy serial: " + serialCode));

        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản với id: " + accountId));

        WarrantyClaim claim = new WarrantyClaim();
        claim.setSerialNumber(serialNumber);
        claim.setAccount(account);
        claim.setIssueDescription(issueDescription);
        claim.setStatus("pending");
        claim.setCreatedAt(LocalDateTime.now());

        return warrantyClaimRepository.save(claim);
    }

    public WarrantyClaim getClaim(Integer claimId) {
        return warrantyClaimRepository.findById(claimId).orElse(null);
    }

    public List<WarrantyClaim> getAllClaims() {
        return warrantyClaimRepository.findAll();
    }

    public List<WarrantyClaim> getAllClaimsWithProductAndSerial() {
        return warrantyClaimRepository.findAllWithProductAndSerial();
    }

    public List<WarrantyClaim> getClaimsBySerialId(Integer serialId) {
        return warrantyClaimRepository.findBySerialNumberSerialId(serialId);
    }

    public List<WarrantyClaim> getClaimsByAccountId(Integer accountId) {
        return warrantyClaimRepository.findByAccountAccountId(accountId);
    }

    public List<WarrantyClaim> getClaimsByStatus(String status) {
        return warrantyClaimRepository.findByStatus(status);
    }

    public List<WarrantyClaim> getClaimsByStatusWithProductAndSerial(String status) {
        return warrantyClaimRepository.findByStatusWithProductAndSerial(status);
    }

    public WarrantyClaim updateClaim(Integer claimId, Integer serialId, Integer accountId, String issueDescription, String status) {
        WarrantyClaim claim = warrantyClaimRepository.findById(claimId).orElse(null);
        if (claim == null) return null;

        if (serialId != null) {
            SerialNumber serialNumber = serialNumberRepository.findById(serialId.longValue())
                    .orElseThrow(() -> new RuntimeException("Serial number not found with id: " + serialId));
            claim.setSerialNumber(serialNumber);
        }

        if (accountId != null) {
            Account account = accountRepository.findById(accountId)
                    .orElseThrow(() -> new RuntimeException("Account not found with id: " + accountId));
            claim.setAccount(account);
        }

        if (issueDescription != null) claim.setIssueDescription(issueDescription);
        if (status != null) {
            String currentStatus = normalizeStatus(claim.getStatus());
            String nextStatus = normalizeStatus(status);

            if ("completed".equals(currentStatus) && !"completed".equals(nextStatus)) {
                throw new RuntimeException("Completed warranty claims cannot be changed");
            }

            claim.setStatus(nextStatus);
        }

        return warrantyClaimRepository.save(claim);
    }

    private String normalizeStatus(String status) {
        if (status == null || status.isBlank()) {
            return "pending";
        }

        String normalized = status.trim().toLowerCase();
        if ("processing".equals(normalized)) {
            return "pending";
        }
        if ("pending".equals(normalized) || "approved".equals(normalized)) {
            return normalized;
        }
        if ("canceled".equals(normalized) || "cancelled".equals(normalized)) {
            return "rejected";
        }
        if ("rejected".equals(normalized) || "completed".equals(normalized)) {
            return normalized;
        }

        throw new RuntimeException("Invalid warranty claim status: " + status);
    }
}
