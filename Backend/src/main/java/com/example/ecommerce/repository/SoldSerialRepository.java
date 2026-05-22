package com.example.ecommerce.repository;

import com.example.ecommerce.entity.SoldSerial;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SoldSerialRepository extends JpaRepository<SoldSerial, Integer> {
}
