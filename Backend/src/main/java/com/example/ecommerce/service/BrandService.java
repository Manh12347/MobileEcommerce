package com.example.ecommerce.service;

import com.example.ecommerce.entity.Brand;
import com.example.ecommerce.repository.BrandRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class BrandService {

    @Autowired
    private BrandRepository brandRepository;

    public Brand createBrand(String name, String country) {
        Brand brand = new Brand();
        brand.setName(name);
        brand.setCountry(country);
        return brandRepository.save(brand);
    }

    public Brand getBrand(Integer brandId) {
        return brandRepository.findById(brandId).orElse(null);
    }

    public List<Brand> getAllBrands() {
        return brandRepository.findAll();
    }

    public Brand updateBrand(Integer brandId, String name, String country) {
        Optional<Brand> brandOpt = brandRepository.findById(brandId);
        if (!brandOpt.isPresent()) return null;

        Brand brand = brandOpt.get();
        if (name != null) brand.setName(name);
        if (country != null) brand.setCountry(country);

        return brandRepository.save(brand);
    }

    public void deleteBrand(Integer brandId) {
        brandRepository.deleteById(brandId);
    }
}
