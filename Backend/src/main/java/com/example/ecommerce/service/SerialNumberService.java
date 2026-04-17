package com.example.ecommerce.service;

import com.example.ecommerce.entity.SerialNumber;
import com.example.ecommerce.entity.ProductItem;
import com.example.ecommerce.repository.SerialNumberRepository;
import com.example.ecommerce.repository.ProductItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class SerialNumberService {

    @Autowired
    private SerialNumberRepository serialNumberRepository;

    @Autowired
    private ProductItemRepository productItemRepository;

    public SerialNumber createSerialNumber(Integer productItemId, String serialCode) {
        Optional<ProductItem> productItemOpt = productItemRepository.findById(productItemId);
        if (!productItemOpt.isPresent()) return null;

        SerialNumber serialNumber = new SerialNumber();
        serialNumber.setProductItem(productItemOpt.get());
        serialNumber.setSerialCode(serialCode);
        serialNumber.setStatus("in_stock");
        serialNumber.setImportDate(LocalDateTime.now());

        return serialNumberRepository.save(serialNumber);
    }

    public SerialNumber getSerialNumber(Integer serialId) {
        return serialNumberRepository.findById(serialId.longValue()).orElse(null);
    }

    public SerialNumber getSerialNumberByCode(String serialCode) {
        return serialNumberRepository.findBySerialCode(serialCode).orElse(null);
    }

    public List<SerialNumber> getSerialNumbersByProduct(Integer productItemId) {
        return serialNumberRepository.findByProductItemProductItemId(productItemId);
    }

    public List<SerialNumber> getSerialNumbersByStatus(String status) {
        return serialNumberRepository.findByStatus(status);
    }

    public SerialNumber updateStatus(Integer serialId, String status) {
        Optional<SerialNumber> serialOpt = serialNumberRepository.findById(serialId.longValue());
        if (!serialOpt.isPresent()) return null;

        SerialNumber serial = serialOpt.get();
        serial.setStatus(status);
        return serialNumberRepository.save(serial);
    }

    public void deleteSerialNumber(Integer serialId) {
        serialNumberRepository.deleteById(serialId.longValue());
    }
}
