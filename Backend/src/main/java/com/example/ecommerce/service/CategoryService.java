package com.example.ecommerce.service;

import com.example.ecommerce.entity.Category;
import com.example.ecommerce.repository.CategoryRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.Set;

@Service
@Transactional
public class CategoryService {

    private static final Set<String> VALID_STATUSES = Set.of("active", "disable");

    @Autowired
    private CategoryRepository categoryRepository;

    public Category createCategory(String name, String status) {
        Category category = new Category();
        category.setName(name);
        category.setStatus(normalizeStatus(status));
        return categoryRepository.save(category);
    }

    public Category getCategory(Integer categoryId) {
        return categoryRepository.findById(categoryId).orElse(null);
    }

    public List<Category> getAllCategories() {
        return categoryRepository.findAll();
    }

    public Category updateCategory(Integer categoryId, String name, String status) {
        Optional<Category> categoryOpt = categoryRepository.findById(categoryId);
        if (!categoryOpt.isPresent()) return null;

        Category category = categoryOpt.get();
        if (name != null) category.setName(name);
        if (status != null) category.setStatus(normalizeStatus(status));

        return categoryRepository.save(category);
    }

    public void toggleCategoryStatus(Integer categoryId) {
        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy category"));

        category.setStatus("disable".equals(category.getStatus()) ? "active" : "disable");
        categoryRepository.save(category);
    }

    private String normalizeStatus(String status) {
        if (status == null || status.isBlank()) {
            return "active";
        }

        String normalized = status.trim().toLowerCase();
        if (!VALID_STATUSES.contains(normalized)) {
            throw new RuntimeException("Status category chỉ chấp nhận 'active' hoặc 'disable'");
        }
        return normalized;
    }
}
