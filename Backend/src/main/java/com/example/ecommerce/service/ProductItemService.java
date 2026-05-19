package com.example.ecommerce.service;

import com.example.ecommerce.dto.CreateProductItemRequest;
import com.example.ecommerce.dto.ProductItemDTO;
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

        if (request.getDescription() != null && !request.getDescription().isEmpty()) {
            try {
                embeddingService.createEmbedding(savedItem.getProductItemId());
            } catch (Exception e) {
            }
        }

        return toDTO(savedItem, serials);
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
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        List<SerialNumber> serials = serialNumberRepository.findByProductItemProductItemId(productItemId);
        return toDTO(item, serials);
    }

    public List<ProductItemDTO> getProductItemsByProduct(Integer productId) {
        List<ProductItem> items = productItemRepository.findByProductProductId(productId);
        return items.stream()
                .map(item -> {
                    List<SerialNumber> serials = serialNumberRepository.findByProductItemProductItemId(item.getProductItemId());
                    return toDTO(item, serials);
                })
                .collect(Collectors.toList());
    }

    public List<ProductItemDTO> getAllProductItems() {
        List<ProductItem> items = productItemRepository.findAll();
        return items.stream()
                .map(item -> {
                    List<SerialNumber> serials = serialNumberRepository.findByProductItemProductItemId(item.getProductItemId());
                    return toDTO(item, serials);
                })
                .collect(Collectors.toList());
    }

    public ProductItemDTO updateProductItem(Integer productItemId, UpdateProductItemRequest request) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        if (request.getSku() != null) item.setSku(request.getSku());
        if (request.getDescription() != null) item.setDescription(request.getDescription());
        if (request.getStatus() != null) item.setStatus(request.getStatus());
        if (request.getPrice() != null) item.setPrice(request.getPrice());
        if (request.getSalePrice() != null) item.setSalePrice(request.getSalePrice());
        if (request.getSpecifications() != null) item.setSpecifications(request.getSpecifications());
        if (request.getImages() != null) item.setImages(request.getImages());
        if (request.getMainImageUrl() != null) item.setMainImageUrl(request.getMainImageUrl());

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
        List<SerialNumber> serials = serialNumberRepository.findByProductItemProductItemId(productItemId);

        return toDTO(updatedItem, serials);
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

    public ProductItemDTO addStock(Integer productItemId, int quantity) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        int newStock = item.getStockQuantity() + quantity;
        item.setStockQuantity(newStock);
        productItemRepository.save(item);

        generateSerials(item, quantity);

        List<SerialNumber> serials = serialNumberRepository.findByProductItemProductItemId(productItemId);
        return toDTO(item, serials);
    }

    public ProductItemDTO reduceStock(Integer productItemId, int quantity) {
        ProductItem item = productItemRepository.findById(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy product item với id: " + productItemId));

        if (item.getStockQuantity() < quantity) {
            throw new RuntimeException("Số lượng tồn kho không đủ để giảm");
        }

        int newStock = item.getStockQuantity() - quantity;
        item.setStockQuantity(newStock);
        productItemRepository.save(item);

        deleteSerials(productItemId, quantity);

        List<SerialNumber> serials = serialNumberRepository.findByProductItemProductItemId(productItemId);
        return toDTO(item, serials);
    }

    private ProductItemDTO toDTO(ProductItem item, List<SerialNumber> serials) {
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

        if (item.getCreatedOn() != null) dto.setCreatedAt(item.getCreatedOn());

        List<ProductItemDTO.SerialDTO> serialDTOs = serials.stream()
                .map(s -> new ProductItemDTO.SerialDTO(
                        s.getSerialId(),
                        s.getSerialCode(),
                        s.getStatus(),
                        s.getImportDate()
                ))
                .collect(Collectors.toList());
        dto.setSerials(serialDTOs);

        return dto;
    }
}
