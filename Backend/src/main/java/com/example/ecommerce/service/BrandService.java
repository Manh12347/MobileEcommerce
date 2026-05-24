package com.example.ecommerce.service;

import com.example.ecommerce.entity.Brand;
import com.example.ecommerce.repository.BrandRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.Set;

@Service
@Transactional
public class BrandService {

    private static final Set<String> VALID_STATUSES = Set.of("active", "disable");

    @Autowired
    private BrandRepository brandRepository;

    public Brand createBrand(String name, String country, String status) {
        Brand brand = new Brand();
        brand.setName(name);
        brand.setCountry(country);
        brand.setStatus(normalizeStatus(status));
        return brandRepository.save(brand);
    }

    public Brand getBrand(Integer brandId) {
        return brandRepository.findById(brandId).orElse(null);
    }

    public List<Brand> getAllBrands() {
        return brandRepository.findAll();
    }

    public Brand updateBrand(Integer brandId, String name, String country, String status) {
        Optional<Brand> brandOpt = brandRepository.findById(brandId);
        if (!brandOpt.isPresent()) return null;

        Brand brand = brandOpt.get();
        if (name != null) brand.setName(name);
        if (country != null) brand.setCountry(country);
        if (status != null) brand.setStatus(normalizeStatus(status));

        return brandRepository.save(brand);
    }

    public void toggleBrandStatus(Integer brandId) {
        Brand brand = brandRepository.findById(brandId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy brand"));

        brand.setStatus("disable".equals(brand.getStatus()) ? "active" : "disable");
        brandRepository.save(brand);
    }

    private String normalizeStatus(String status) {
        if (status == null || status.isBlank()) {
            return "active";
        }

        String normalized = status.trim().toLowerCase();
        if (!VALID_STATUSES.contains(normalized)) {
            throw new RuntimeException("Status brand chỉ chấp nhận 'active' hoặc 'disable'");
        }
        return normalized;
    }
}
