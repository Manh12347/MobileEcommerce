package com.example.ecommerce.repository;

import com.example.ecommerce.entity.Warranty;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WarrantyRepository extends JpaRepository<Warranty, Integer> {
    Optional<Warranty> findBySerialNumber_SerialId(Integer serialId);
    List<Warranty> findByStatus(String status);
}
