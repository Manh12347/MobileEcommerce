package com.example.ecommerce.repository;

import com.example.ecommerce.entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OrderRepository extends JpaRepository<Order, Integer> {
    List<Order> findByAccountAccountIdOrderByCreatedOnDesc(Integer accountId);

    List<Order> findByStatusOrderByCreatedOnDesc(String status);

    List<Order> findAllByOrderByCreatedOnDesc();

    Optional<Order> findByOrderCode(String orderCode);
}
