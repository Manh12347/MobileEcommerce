package com.example.ecommerce.repository;

import com.example.ecommerce.entity.Cart;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CartRepository extends JpaRepository<Cart, Integer> {
    List<Cart> findAllByAccountAccountIdOrderByUpdatedOnDescCartIdDesc(Integer accountId);
}
