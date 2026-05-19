package com.example.ecommerce.controller;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.Brand;
import com.example.ecommerce.entity.Category;
import com.example.ecommerce.entity.Product;
import com.example.ecommerce.service.BrandService;
import com.example.ecommerce.service.CategoryService;
import com.example.ecommerce.service.ProductService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/v1/api/catalogs")
@CrossOrigin(origins = "*")
@Slf4j
public class CatalogController {

    @Autowired
    private BrandService brandService;

    @Autowired
    private CategoryService categoryService;

    @Autowired
    private ProductService productService;

    // ========================
    // BRAND CRUD
    // ========================

    @GetMapping("/brands")
    public ResponseEntity<ApiResponse<List<BrandDTO>>> getAllBrands() {
        try {
            List<BrandDTO> brands = brandService.getAllBrands().stream()
                    .map(this::toBrandDTO)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách brand thành công", brands));
        } catch (Exception e) {
            log.error("Lỗi khi lấy danh sách brand:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/brands/{id}")
    public ResponseEntity<ApiResponse<BrandDTO>> getBrandById(@PathVariable Integer id) {
        try {
            Brand brand = brandService.getBrand(id);
            if (brand == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy brand", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy brand thành công", toBrandDTO(brand)));
        } catch (Exception e) {
            log.error("Lỗi khi lấy brand:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PostMapping("/brands")
    public ResponseEntity<ApiResponse<BrandDTO>> createBrand(@Valid @RequestBody CreateBrandRequest request) {
        try {
            Brand brand = brandService.createBrand(request.getName(), request.getCountry());
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Tạo brand thành công", toBrandDTO(brand)));
        } catch (Exception e) {
            log.error("Lỗi khi tạo brand:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping("/brands/{id}")
    public ResponseEntity<ApiResponse<BrandDTO>> updateBrand(
            @PathVariable Integer id,
            @RequestBody UpdateBrandRequest request) {
        try {
            Brand brand = brandService.updateBrand(id, request.getName(), request.getCountry());
            if (brand == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy brand", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật brand thành công", toBrandDTO(brand)));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật brand:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/brands/{id}")
    public ResponseEntity<ApiResponse<String>> deleteBrand(@PathVariable Integer id) {
        try {
            brandService.deleteBrand(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Xóa brand thành công", null));
        } catch (RuntimeException e) {
            log.warn("Không thể xóa brand: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi xóa brand:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    // ========================
    // CATEGORY CRUD
    // ========================

    @GetMapping("/categories")
    public ResponseEntity<ApiResponse<List<CategoryDTO>>> getAllCategories() {
        try {
            List<CategoryDTO> categories = categoryService.getAllCategories().stream()
                    .map(this::toCategoryDTO)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách category thành công", categories));
        } catch (Exception e) {
            log.error("Lỗi khi lấy danh sách category:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/categories/{id}")
    public ResponseEntity<ApiResponse<CategoryDTO>> getCategoryById(@PathVariable Integer id) {
        try {
            Category category = categoryService.getCategory(id);
            if (category == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy category", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy category thành công", toCategoryDTO(category)));
        } catch (Exception e) {
            log.error("Lỗi khi lấy category:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PostMapping("/categories")
    public ResponseEntity<ApiResponse<CategoryDTO>> createCategory(@Valid @RequestBody CreateCategoryRequest request) {
        try {
            Category category = categoryService.createCategory(request.getName());
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Tạo category thành công", toCategoryDTO(category)));
        } catch (Exception e) {
            log.error("Lỗi khi tạo category:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping("/categories/{id}")
    public ResponseEntity<ApiResponse<CategoryDTO>> updateCategory(
            @PathVariable Integer id,
            @RequestBody UpdateCategoryRequest request) {
        try {
            Category category = categoryService.updateCategory(id, request.getName());
            if (category == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy category", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật category thành công", toCategoryDTO(category)));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật category:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/categories/{id}")
    public ResponseEntity<ApiResponse<String>> deleteCategory(@PathVariable Integer id) {
        try {
            categoryService.deleteCategory(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Xóa category thành công", null));
        } catch (RuntimeException e) {
            log.warn("Không thể xóa category: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi xóa category:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    // ========================
    // PRODUCT CRUD
    // ========================

    @GetMapping("/products")
    public ResponseEntity<ApiResponse<List<ProductDTO>>> getAllProducts() {
        try {
            List<ProductDTO> products = productService.getAllProducts().stream()
                    .map(this::toProductDTO)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách sản phẩm thành công", products));
        } catch (Exception e) {
            log.error("Lỗi khi lấy danh sách sản phẩm:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/products/{id}")
    public ResponseEntity<ApiResponse<ProductDTO>> getProductById(@PathVariable Integer id) {
        try {
            Product product = productService.getProduct(id);
            if (product == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy sản phẩm", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy sản phẩm thành công", toProductDTO(product)));
        } catch (Exception e) {
            log.error("Lỗi khi lấy sản phẩm:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PostMapping("/products")
    public ResponseEntity<ApiResponse<ProductDTO>> createProduct(@Valid @RequestBody CreateProductRequest request) {
        try {
            Product product = productService.createProduct(
                    request.getName(),
                    request.getBrandId(),
                    request.getCategoryId(),
                    request.getStatus()
            );
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Tạo sản phẩm thành công", toProductDTO(product)));
        } catch (Exception e) {
            log.error("Lỗi khi tạo sản phẩm:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping("/products/{id}")
    public ResponseEntity<ApiResponse<ProductDTO>> updateProduct(
            @PathVariable Integer id,
            @RequestBody UpdateProductRequest request) {
        try {
            Product product = productService.updateProduct(
                    id,
                    request.getName(),
                    request.getBrandId(),
                    request.getCategoryId(),
                    request.getStatus()
            );
            if (product == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy sản phẩm", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật sản phẩm thành công", toProductDTO(product)));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật sản phẩm:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/products/{id}")
    public ResponseEntity<ApiResponse<String>> deleteProduct(@PathVariable Integer id) {
        try {
            productService.deleteProduct(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Xóa sản phẩm thành công", null));
        } catch (RuntimeException e) {
            log.warn("Không thể xóa sản phẩm: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi xóa sản phẩm:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/products/category/{categoryId}")
    public ResponseEntity<ApiResponse<List<ProductDTO>>> getProductsByCategory(@PathVariable Integer categoryId) {
        try {
            List<ProductDTO> products = productService.getProductsByCategory(categoryId).stream()
                    .map(this::toProductDTO)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy sản phẩm theo category thành công", products));
        } catch (Exception e) {
            log.error("Lỗi khi lấy sản phẩm theo category:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/products/brand/{brandId}")
    public ResponseEntity<ApiResponse<List<ProductDTO>>> getProductsByBrand(@PathVariable Integer brandId) {
        try {
            List<ProductDTO> products = productService.getProductsByBrand(brandId).stream()
                    .map(this::toProductDTO)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy sản phẩm theo brand thành công", products));
        } catch (Exception e) {
            log.error("Lỗi khi lấy sản phẩm theo brand:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    // ========================
    // MAPPERS
    // ========================

    private BrandDTO toBrandDTO(Brand brand) {
        return new BrandDTO(brand.getBrandId(), brand.getName(), brand.getCountry());
    }

    private CategoryDTO toCategoryDTO(Category category) {
        return new CategoryDTO(category.getCategoryId(), category.getName());
    }

    private ProductDTO toProductDTO(Product product) {
        BrandDTO brandDTO = null;
        CategoryDTO categoryDTO = null;

        if (product.getBrand() != null) {
            brandDTO = toBrandDTO(product.getBrand());
        }
        if (product.getCategory() != null) {
            categoryDTO = toCategoryDTO(product.getCategory());
        }

        return new ProductDTO(product.getProductId(), product.getName(), product.getStatus(), brandDTO, categoryDTO);
    }
}
