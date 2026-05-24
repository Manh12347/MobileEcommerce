package com.example.ecommerce.repository;

import com.example.ecommerce.entity.Brand;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BrandRepository extends JpaRepository<Brand, Integer> {
    Optional<Brand> findByBrandIdAndStatus(Integer brandId, String status);
    List<Brand> findByStatus(String status);
}
