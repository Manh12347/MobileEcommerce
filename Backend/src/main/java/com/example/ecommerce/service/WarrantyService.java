package com.example.ecommerce.service;

import com.example.ecommerce.entity.Warranty;
import com.example.ecommerce.entity.SerialNumber;
import com.example.ecommerce.repository.WarrantyRepository;
import com.example.ecommerce.repository.SerialNumberRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class WarrantyService {

    @Autowired
    private WarrantyRepository warrantyRepository;

    @Autowired
    private SerialNumberRepository serialNumberRepository;

    public Warranty createWarranty(Integer serialId, LocalDate startDate, LocalDate endDate) {
        Optional<SerialNumber> serialOpt = serialNumberRepository.findById(serialId.longValue());
        if (!serialOpt.isPresent()) return null;

        Warranty warranty = new Warranty();
        warranty.setSerialNumber(serialOpt.get());
        warranty.setStartDate(startDate);
        warranty.setEndDate(endDate);
        warranty.setStatus("active");

        return warrantyRepository.save(warranty);
    }

    public Warranty getWarranty(Integer warrantyId) {
        return warrantyRepository.findById(warrantyId).orElse(null);
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

    public void deleteWarranty(Integer warrantyId) {
        warrantyRepository.deleteById(warrantyId);
    }
}
