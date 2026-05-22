package com.example.ecommerce.repository;

import com.example.ecommerce.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Integer> {
    List<Notification> findByAccountAccountIdOrderByCreatedOnDesc(Integer accountId);
    List<Notification> findByAccountAccountIdAndIsReadFalse(Integer accountId);
}
