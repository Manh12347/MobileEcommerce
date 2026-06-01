package com.example.ecommerce.service;

import com.example.ecommerce.dto.CreateProductItemRequest;
import com.example.ecommerce.dto.BrandDTO;
import com.example.ecommerce.dto.CategoryDTO;
import com.example.ecommerce.dto.ProductItemDTO;
import com.example.ecommerce.dto.ProductItemListDTO;
import com.example.ecommerce.dto.ProductItemVariantDto;
import com.example.ecommerce.dto.UpdateProductItemRequest;
import com.example.ecommerce.entity.ProductItem;
import com.example.ecommerce.entity.Product;
import com.example.ecommerce.entity.SerialNumber;
import com.example.ecommerce.repository.ProductItemRepository;
import com.example.ecommerce.repository.ProductRepository;
import com.example.ecommerce.repository.SerialNumberRepository;
import com.example.ecommerce.util.SerialUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@Transactional
public class ProductItemService {

    @Autowired
    private ProductItemRepository productItemRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private SerialNumberRepository serialNumberRepository;

    @Autowired
    private EmbeddingService embeddingService;

    /**
     * Ensures JSONB field value is properly formatted JSON
     */
    private String formatJsonbValue(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        
        String trimmed = value.trim();
        
        // Already valid JSON (object or array)
        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            return trimmed;
        }
        
        // Already a JSON string with quotes
        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length() > 1) {
            return trimmed;
        }
        
        // Boolean or null
        if (trimmed.equals("true") || trimmed.equals("false") || trimmed.equals("null")) {
            return trimmed;
        }
        
        // Try to parse as number
        try {
            Double.parseDouble(trimmed);
            return trimmed;
        } catch (NumberFormatException e) {
            // Not a number, wrap as string
        }
        
        // Plain string - escape and wrap as JSON string
        String escaped = trimmed
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
        
        return "\"" + escaped + "\"";
    }

    public ProductItemDTO createProductItem(CreateProductItemRequest request) {
        Optional<Product> productOpt = productRepository.findById(request.getProductId());
        if (!productOpt.isPresent()) {
            throw new RuntimeException("Không tìm thấy sản phẩm với id: " + request.getProductId());
        }

        ProductItem item = new ProductItem();
        item.setProduct(productOpt.get());
        item.setSku(request.getSku());
        item.setDescription(request.getDescription());
        item.setStockQuantity(request.getStockQuantity());
        item.setStatus(request.getStatus() != null ? request.getStatus() : "active");
        item.setPrice(request.getPrice());
        item.setSalePrice(request.getSalePrice());
        item.setSpecifications(request.getSpecifications());
        item.setImages(request.getImages());
        item.setMainImageUrl(request.getMainImageUrl());

        ProductItem savedItem = productItemRepository.save(item);

        List<SerialNumber> serials = generateSerials(savedItem, request.getStockQuantity());

        savedItem.setSerials(serials);

        // Call embedding API after transaction commits to ensure data is in DB
        final Integer productItemId = savedItem.getProductItemId();
        if (request.getDescription() != null && !request.getDescription().isEmpty()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    try {
                        embeddingService.createEmbedding(productItemId);
                    } catch (Exception e) {
                        // Log but don't fail the transaction
                    }
                }
            });
        }

        return toDTO(savedItem);
    }

    private List<SerialNumber> generateSerials(ProductItem productItem, int quantity) {
        List<SerialNumber> serials = new ArrayList<>();

        for (int i = 0; i < quantity; i++) {
            SerialNumber serial = new SerialNumber();
            serial.setProductItem(productItem);
            serial.setSerialCode(SerialUtil.generateFormattedSerial());
            serial.setStatus("in_stock");
            serial.setImportDate(LocalDateTime.now());
            serials.add(serial);
        }

        return serialNumberRepository.saveAll(serials);
    }

    public ProductItemDTO getProductItem(Integer productItemId) {
        ProductItem item = productItemRepository.findByIdWithSerialsAndProduct(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));
        return toDTO(item);
    }

    public ProductItemDTO getProductItemBySku(String sku) {
        if (sku == null || sku.trim().isEmpty()) {
            throw new RuntimeException("SKU không được bỏ trống");
        }

        ProductItem item = productItemRepository.findBySkuWithSerialsAndProduct(sku.trim())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với SKU: " + sku));
        return toDTO(item);
    }

    public List<ProductItemDTO> getProductItemsByProduct(Integer productId) {
        List<ProductItem> items = productItemRepository.findByProductProductIdWithSerialsAndProduct(productId);
        return items.stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<ProductItemDTO> getAllProductItems() {
        List<ProductItem> items = productItemRepository.findAllWithSerialsAndProduct();
        return items.stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public Page<ProductItemDTO> getAllProductItems(int page, int size) {
        Page<ProductItem> items = productItemRepository.findAll(PageRequest.of(Math.max(page - 1, 0), size, Sort.by(Sort.Direction.DESC, "productItemId")));
        return items.map(this::toDTO);
    }
    
    /**
     * Lấy danh sách product items cho list view - KHÔNG load serials
     * Performance tốt hơn nhiều so với getAllProductItems
     */
    public Page<ProductItemListDTO> getAllProductItemsForList(int page, int size) {
        return getAllProductItemsForList(page, size, null, null, null, null, null, null, "newest", "desc");
        }

        public Page<ProductItemListDTO> getAllProductItemsForList(
            int page,
            int size,
            Integer brandId,
            Integer categoryId,
            Integer productId,
            Integer productItemId,
            java.math.BigDecimal minPrice,
            java.math.BigDecimal maxPrice,
            String sortBy,
            String sortDir
        ) {
        Pageable pageable = PageRequest.of(Math.max(page - 1, 0), size);
        String normalizedSortBy = normalizeSortBy(sortBy);
        String normalizedSortDir = normalizeSortDir(sortDir);
        Page<Object[]> results = productItemRepository.findForListWithFilters(
                brandId,
            categoryId,
                productId,
            productItemId,
                minPrice,
                maxPrice,
            normalizedSortBy,
            normalizedSortDir,
            pageable
        );
        
        return results.map(row -> {
            ProductItemListDTO dto = new ProductItemListDTO();
            dto.setProductItemId(((Number) row[0]).intValue());
            dto.setSku((String) row[1]);
            dto.setStockQuantity(row[2] != null ? ((Number) row[2]).intValue() : 0);
            dto.setStatus((String) row[3]);
            dto.setPrice(row[4] != null ? new java.math.BigDecimal(row[4].toString()) : null);
            dto.setSalePrice(row[5] != null ? new java.math.BigDecimal(row[5].toString()) : null);
            dto.setCreatedAt(row[6] != null ? row[6].toString() : null);
            
            if (row[7] != null) {
                dto.setProductId(((Number) row[7]).intValue());
            }
            dto.setProductName((String) row[8]);
            dto.setSoldQuantity(0);
            dto.setDescription((String) row[9]);
            dto.setSpecifications(row[10] != null ? row[10].toString() : null);
            dto.setMainImageUrl((String) row[11]);

            if (row[12] != null) {
                dto.setBrand(new BrandDTO(
                        row[12] != null ? ((Number) row[12]).intValue() : null,
                        (String) row[13],
                        (String) row[14],
                        (String) row[15]
                ));
            }

            if (row[16] != null) {
                dto.setCategory(new CategoryDTO(
                        row[16] != null ? ((Number) row[16]).intValue() : null,
                        (String) row[17],
                        (String) row[18]
                ));
            }
            
            return dto;
        });
    }

    private String normalizeSortBy(String sortBy) {
        if (sortBy == null) {
            return "newest";
        }
        return switch (sortBy.trim().toLowerCase()) {
            case "price", "name", "newest" -> sortBy.trim().toLowerCase();
            default -> "newest";
        };
    }

    private String normalizeSortDir(String sortDir) {
        if (sortDir == null) {
            return "desc";
        }
        return "asc".equalsIgnoreCase(sortDir.trim()) ? "asc" : "desc";
    }

    public ProductItemDTO updateProductItem(Integer productItemId, UpdateProductItemRequest request) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        if (request.getSku() != null) item.setSku(request.getSku());
        if (request.getDescription() != null) item.setDescription(request.getDescription());
        if (request.getStatus() != null) item.setStatus(request.getStatus());
        if (request.getPrice() != null) item.setPrice(request.getPrice());
        if (request.getSalePrice() != null) item.setSalePrice(request.getSalePrice());
        if (request.getSpecifications() != null) item.setSpecifications(formatJsonbValue(request.getSpecifications()));
        if (request.getImages() != null) item.setImages(formatJsonbValue(request.getImages()));
        if (request.getMainImageUrl() != null) {
            String url = request.getMainImageUrl().trim();
            item.setMainImageUrl(url.isEmpty() ? null : url);
        }

        if (request.getStockQuantity() != null) {
            int currentStock = item.getStockQuantity();
            int newStock = request.getStockQuantity();

            if (newStock > currentStock) {
                int addQuantity = newStock - currentStock;
                generateSerials(item, addQuantity);
            } else if (newStock < currentStock) {
                int removeQuantity = currentStock - newStock;
                deleteSerials(item.getProductItemId(), removeQuantity);
            }

            item.setStockQuantity(newStock);
        }

        if (request.getDescription() != null && !request.getDescription().isEmpty()) {
            try {
                embeddingService.createEmbedding(productItemId);
            } catch (Exception e) {
            }
        }

        ProductItem updatedItem = productItemRepository.save(item);
        return toDTO(updatedItem);
    }

    private void deleteSerials(Integer productItemId, int quantity) {
        List<SerialNumber> inStockSerials = serialNumberRepository.findByProductItemProductItemId(productItemId)
                .stream()
                .filter(s -> "in_stock".equals(s.getStatus()))
                .limit(quantity)
                .collect(Collectors.toList());

        serialNumberRepository.deleteAll(inStockSerials);
    }

    public void deleteProductItem(Integer productItemId) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        List<SerialNumber> serials = serialNumberRepository.findByProductItemProductItemId(productItemId);
        
        // Xóa các serial không phải sold
        List<SerialNumber> serialsToDelete = serials.stream()
                .filter(s -> !"sold".equals(s.getStatus()))
                .collect(Collectors.toList());
        
        if (!serialsToDelete.isEmpty()) {
            serialNumberRepository.deleteAll(serialsToDelete);
        }
        
        productItemRepository.delete(item);
    }

    public void toggleProductItemStatus(Integer productItemId) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        item.setStatus("disable".equals(item.getStatus()) ? "active" : "disable");
        productItemRepository.save(item);
    }

    public void discontinueProductItem(Integer productItemId) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        item.setStatus("discontinued");
        productItemRepository.save(item);
    }

    public ProductItemDTO addStock(Integer productItemId, int quantity) {
        ProductItem item = productItemRepository.findByIdWithSerialsAndProduct(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        int newStock = item.getStockQuantity() + quantity;
        item.setStockQuantity(newStock);
        productItemRepository.save(item);

        List<SerialNumber> newSerials = generateSerials(item, quantity);
        item.getSerials().addAll(newSerials);

        return toDTO(item);
    }

    public ProductItemDTO reduceStock(Integer productItemId, int quantity) {
        ProductItem item = productItemRepository.findByIdWithSerialsAndProduct(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        if (item.getStockQuantity() < quantity) {
            throw new RuntimeException("Số lượng tồn kho không đủ để giảm");
        }

        int newStock = item.getStockQuantity() - quantity;
        item.setStockQuantity(newStock);

        List<SerialNumber> serialsToDelete = item.getSerials().stream()
                .filter(s -> "in_stock".equals(s.getStatus()))
                .limit(quantity)
                .collect(Collectors.toList());
        serialNumberRepository.deleteAll(serialsToDelete);
        item.getSerials().removeAll(serialsToDelete);

        productItemRepository.save(item);

        return toDTO(item);
    }

    /**
     * Lấy danh sách sản phẩm đang giảm giá (có sale_price)
     */
    public Page<ProductItemListDTO> getDiscountedItems(int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(page - 1, 0), size);
        Page<Object[]> results = productItemRepository.findDiscountedItems(pageable);

        return results.map(row -> {
            ProductItemListDTO dto = new ProductItemListDTO();
            dto.setProductItemId(((Number) row[0]).intValue());
            dto.setSku((String) row[1]);
            dto.setStockQuantity(row[2] != null ? ((Number) row[2]).intValue() : 0);
            dto.setStatus((String) row[3]);
            dto.setPrice(row[4] != null ? new java.math.BigDecimal(row[4].toString()) : null);
            dto.setSalePrice(row[5] != null ? new java.math.BigDecimal(row[5].toString()) : null);
            dto.setCreatedAt(row[6] != null ? row[6].toString() : null);

            if (row[7] != null) {
                dto.setProductId(((Number) row[7]).intValue());
            }
            dto.setProductName((String) row[8]);
            dto.setSoldQuantity(0);
            dto.setDescription((String) row[9]);
            dto.setSpecifications(row[10] != null ? row[10].toString() : null);
            dto.setMainImageUrl((String) row[11]);

            return dto;
        });
    }

    /**
     * Tắt giảm giá cho một product item (xóa sale_price)
     */
    public ProductItemDTO disableDiscount(Integer productItemId) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        item.setSalePrice(null);
        productItemRepository.save(item);

        return toDTO(item);
    }

    private ProductItemDTO toDTO(ProductItem item) {
        ProductItemDTO dto = new ProductItemDTO();
        dto.setProductItemId(item.getProductItemId());
        dto.setSku(item.getSku());
        dto.setDescription(item.getDescription());
        dto.setStockQuantity(item.getStockQuantity());
        dto.setStatus(item.getStatus());
        dto.setPrice(item.getPrice());
        dto.setSalePrice(item.getSalePrice());
        dto.setSpecifications(item.getSpecifications());
        dto.setImages(item.getImages());
        dto.setMainImageUrl(item.getMainImageUrl());
        dto.setEmbeddingText(item.getEmbeddingText());

        if (item.getProduct() != null) {
            dto.setProductId(item.getProduct().getProductId());
            dto.setProductName(item.getProduct().getName());
        }

        if (item.getCreatedOn() != null) dto.setCreatedAt(item.getCreatedOn().toString());

        List<ProductItemDTO.SerialDTO> serialDTOs = item.getSerials().stream()
                .map(s -> new ProductItemDTO.SerialDTO(
                        s.getSerialId(),
                        s.getSerialCode(),
                        s.getStatus(),
                        s.getImportDate() != null ? s.getImportDate().toString() : null
                ))
                .collect(Collectors.toList());
        dto.setSerials(serialDTOs);

        return dto;
    }

    public List<ProductItemVariantDto> getVariantsByProduct(Integer productId) {
        List<ProductItem> items = productItemRepository.findByProductIdWithProduct(productId);
        return items.stream().map(item -> {
            ProductItemVariantDto dto = new ProductItemVariantDto();
            dto.setProductItemId(item.getProductItemId());
            dto.setSku(item.getSku());
            dto.setDescription(item.getDescription());
            dto.setStockQuantity(item.getStockQuantity());
            dto.setStatus(item.getStatus());
            dto.setPrice(item.getPrice());
            dto.setSalePrice(item.getSalePrice());
            dto.setImages(item.getImages());
            dto.setMainImageUrl(item.getMainImageUrl());
            return dto;
        }).toList();
    }
}
