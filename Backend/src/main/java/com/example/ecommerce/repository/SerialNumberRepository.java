package com.example.ecommerce.repository;

import com.example.ecommerce.entity.SerialNumber;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SerialNumberRepository extends JpaRepository<SerialNumber, Long> {
    Optional<SerialNumber> findBySerialCode(String serialCode);
    List<SerialNumber> findByProductItemProductItemId(Integer productItemId);
    List<SerialNumber> findByStatus(String status);
}
