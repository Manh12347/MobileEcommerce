package com.example.ecommerce.service;

import com.example.ecommerce.entity.*;
import com.example.ecommerce.repository.ProductRepository;
import com.example.ecommerce.repository.ProductItemRepository;
import com.example.ecommerce.repository.CategoryRepository;
import com.example.ecommerce.repository.BrandRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class ProductService {

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private ProductItemRepository productItemRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private BrandRepository brandRepository;

    public Product createProduct(String name, Integer brandId, Integer categoryId, String status) {
        Product product = new Product();
        product.setName(name);
        product.setStatus(status != null ? status : "active");

        if (brandId != null) {
            Optional<Brand> brand = brandRepository.findById(brandId);
            brand.ifPresent(product::setBrand);
        }

        if (categoryId != null) {
            Optional<Category> category = categoryRepository.findById(categoryId);
            category.ifPresent(product::setCategory);
        }

        return productRepository.save(product);
    }

    public Product getProduct(Integer productId) {
        return productRepository.findById(productId).orElse(null);
    }

    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    public List<Product> getProductsByCategory(Integer categoryId) {
        return productRepository.findByCategoryCategoryId(categoryId);
    }

    public List<Product> getProductsByBrand(Integer brandId) {
        return productRepository.findByBrandBrandId(brandId);
    }

    public Product updateProduct(Integer productId, String name, Integer brandId, Integer categoryId, String status) {
        Optional<Product> productOpt = productRepository.findById(productId);
        if (!productOpt.isPresent()) return null;

        Product product = productOpt.get();
        if (name != null) product.setName(name);
        if (status != null) product.setStatus(status);

        if (brandId != null) {
            Optional<Brand> brand = brandRepository.findById(brandId);
            brand.ifPresent(product::setBrand);
        }

        if (categoryId != null) {
            Optional<Category> category = categoryRepository.findById(categoryId);
            category.ifPresent(product::setCategory);
        }

        return productRepository.save(product);
    }

    public void deleteProduct(Integer productId) {
        productRepository.deleteById(productId);
    }

    public ProductItem createProductItem(Integer productId, String sku, String description,
                                        Integer stockQuantity, String status, java.math.BigDecimal price,
                                        java.math.BigDecimal salePrice) {
        Optional<Product> productOpt = productRepository.findById(productId);
        if (!productOpt.isPresent()) return null;

        ProductItem item = new ProductItem();
        item.setProduct(productOpt.get());
        item.setSku(sku);
        item.setDescription(description);
        item.setStockQuantity(stockQuantity);
        item.setStatus(status != null ? status : "active");
        item.setPrice(price);
        item.setSalePrice(salePrice);

        return productItemRepository.save(item);
    }

    public ProductItem getProductItem(Integer productItemId) {
        return productItemRepository.findById(productItemId).orElse(null);
    }

    public List<ProductItem> getProductItemsByProduct(Integer productId) {
        return productItemRepository.findByProductProductId(productId);
    }

    public void updateStock(Integer productItemId, Integer newQuantity) {
        Optional<ProductItem> itemOpt = productItemRepository.findById(productItemId);
        if (itemOpt.isPresent()) {
            ProductItem item = itemOpt.get();
            item.setStockQuantity(newQuantity);
            productItemRepository.save(item);
        }
    }
}
