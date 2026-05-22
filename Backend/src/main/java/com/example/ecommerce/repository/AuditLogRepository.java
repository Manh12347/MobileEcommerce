package com.example.ecommerce.repository;

import com.example.ecommerce.entity.AuditLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Integer> {
    List<AuditLog> findByAccountAccountIdOrderByCreatedAtDesc(Integer accountId);
    List<AuditLog> findByEntityOrderByCreatedAtDesc(String entity);
}
