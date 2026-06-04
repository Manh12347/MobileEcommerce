package com.example.ecommerce.service;

import com.example.ecommerce.entity.Warranty;
import com.example.ecommerce.entity.SerialNumber;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.ProductItem;
import com.example.ecommerce.entity.Product;
import com.example.ecommerce.repository.WarrantyRepository;
import com.example.ecommerce.repository.SerialNumberRepository;
import com.example.ecommerce.repository.SoldSerialRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class WarrantyService {

    @Autowired
    private WarrantyRepository warrantyRepository;

    @Autowired
    private SerialNumberRepository serialNumberRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private SoldSerialRepository soldSerialRepository;

    public Warranty createWarranty(Integer serialId, LocalDate startDate, LocalDate endDate) {
        Optional<SerialNumber> serialOpt = serialNumberRepository.findById(serialId.longValue());
        if (!serialOpt.isPresent()) {
            throw new RuntimeException("Serial number not found with id: " + serialId);
        }

        if (warrantyRepository.findBySerialNumber_SerialId(serialId).isPresent()) {
            throw new RuntimeException("Warranty already exists for serial id: " + serialId);
        }

        Warranty warranty = new Warranty();
        warranty.setSerialNumber(serialOpt.get());
        warranty.setStartDate(startDate);
        warranty.setEndDate(endDate);
        warranty.setStatus("active");

        return warrantyRepository.save(warranty);
    }

    public Warranty createWarranty(Integer serialId, LocalDate startDate, LocalDate endDate, String status) {
        Optional<SerialNumber> serialOpt = serialNumberRepository.findById(serialId.longValue());
        if (!serialOpt.isPresent()) {
            throw new RuntimeException("Serial number not found with id: " + serialId);
        }

        if (warrantyRepository.findBySerialNumber_SerialId(serialId).isPresent()) {
            throw new RuntimeException("Warranty already exists for serial id: " + serialId);
        }

        Warranty warranty = new Warranty();
        warranty.setSerialNumber(serialOpt.get());
        warranty.setStartDate(startDate);
        warranty.setEndDate(endDate);
        warranty.setStatus("active");

        Warranty saved = warrantyRepository.save(warranty);

        // Send notification to the customer (if serial was already sold)
        try {
            List<Account> owners = soldSerialRepository.findBySerialIdWithOwner(serialId)
                    .stream()
                    .map(ss -> ss.getOrderItem().getOrder().getAccount())
                    .distinct()
                    .toList();

            ProductItem productItem = serialOpt.get().getProductItem();
            Product product = productItem != null ? productItem.getProduct() : null;
            String productName = product != null ? product.getName() : "sản phẩm";
            String serialCode = serialOpt.get().getSerialCode();
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM/yyyy");
            String period = fmt.format(startDate) + " - " + fmt.format(endDate);

            for (Account owner : owners) {
                notificationService.createNotification(
                        owner,
                        "Phiếu bảo hành mới",
                        "Phiếu bảo hành cho " + productName + " (Serial: " + serialCode + ") đã được tạo. Thời hạn: " + period + ".",
                        "system"
                );
            }
        } catch (Exception e) {
            // Don't fail warranty creation if notification fails
        }

        if (status != null && !status.isBlank()) {
            saved.setStatus(status);
            return warrantyRepository.save(saved);
        }
        return saved;
    }

    public Warranty getWarranty(Integer warrantyId) {
        return warrantyRepository.findById(warrantyId).orElse(null);
    }

    public List<Warranty> getAllWarranties() {
        return warrantyRepository.findAll();
    }

    public Warranty getWarrantyBySerialId(Integer serialId) {
        return warrantyRepository.findBySerialNumber_SerialId(serialId).orElse(null);
    }

    public List<Warranty> getWarrantiesByStatus(String status) {
        return warrantyRepository.findByStatus(status);
    }

    public Warranty updateStatus(Integer warrantyId, String status) {
        Optional<Warranty> warrantyOpt = warrantyRepository.findById(warrantyId);
        if (!warrantyOpt.isPresent()) return null;

        Warranty warranty = warrantyOpt.get();
        warranty.setStatus(status);
        return warrantyRepository.save(warranty);
    }

    public Warranty updateWarranty(Integer warrantyId, Integer serialId, LocalDate startDate, LocalDate endDate, String status) {
        Optional<Warranty> warrantyOpt = warrantyRepository.findById(warrantyId);
        if (!warrantyOpt.isPresent()) return null;

        Warranty warranty = warrantyOpt.get();

        if (serialId != null) {
            Optional<SerialNumber> serialOpt = serialNumberRepository.findById(serialId.longValue());
            if (!serialOpt.isPresent()) {
                throw new RuntimeException("Serial number not found with id: " + serialId);
            }

            Optional<Warranty> existingWarranty = warrantyRepository.findBySerialNumber_SerialId(serialId);
            if (existingWarranty.isPresent() && !existingWarranty.get().getWarrantyId().equals(warrantyId)) {
                throw new RuntimeException("Warranty already exists for serial id: " + serialId);
            }

            warranty.setSerialNumber(serialOpt.get());
        }

        if (startDate != null) warranty.setStartDate(startDate);
        if (endDate != null) warranty.setEndDate(endDate);
        if (status != null) warranty.setStatus(status);

        return warrantyRepository.save(warranty);
    }

    public void deleteWarranty(Integer warrantyId) {
        warrantyRepository.deleteById(warrantyId);
    }
}
