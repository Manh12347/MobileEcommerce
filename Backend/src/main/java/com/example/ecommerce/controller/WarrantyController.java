package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.CreateWarrantyRequest;
import com.example.ecommerce.dto.UpdateWarrantyRequest;
import com.example.ecommerce.dto.WarrantyDTO;
import com.example.ecommerce.entity.SerialNumber;
import com.example.ecommerce.entity.Warranty;
import com.example.ecommerce.service.WarrantyService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/v1/api/warranties")
@CrossOrigin(origins = "*")
@Slf4j
public class WarrantyController {

    @Autowired
    private WarrantyService warrantyService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<WarrantyDTO>>> getAllWarranties(
            @RequestParam(required = false) String status) {
        try {
            List<Warranty> warranties = status != null && !status.isBlank()
                    ? warrantyService.getWarrantiesByStatus(status)
                    : warrantyService.getAllWarranties();

            List<WarrantyDTO> data = warranties.stream()
                    .map(this::toDTO)
                    .collect(Collectors.toList());

            return ResponseEntity.ok(new ApiResponse<>(true, "Get warranties successfully", data));
        } catch (Exception e) {
            log.error("Error getting warranties:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<WarrantyDTO>> getWarrantyById(@PathVariable Integer id) {
        try {
            Warranty warranty = warrantyService.getWarranty(id);
            if (warranty == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Warranty not found", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Get warranty successfully", toDTO(warranty)));
        } catch (Exception e) {
            log.error("Error getting warranty:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @GetMapping("/serial/{serialId}")
    public ResponseEntity<ApiResponse<WarrantyDTO>> getWarrantyBySerialId(@PathVariable Integer serialId) {
        try {
            Warranty warranty = warrantyService.getWarrantyBySerialId(serialId);
            if (warranty == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Warranty not found", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Get warranty by serial successfully", toDTO(warranty)));
        } catch (Exception e) {
            log.error("Error getting warranty by serial:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @PostMapping
    public ResponseEntity<ApiResponse<WarrantyDTO>> createWarranty(
            @Valid @RequestBody CreateWarrantyRequest request) {
        try {
            Warranty warranty = warrantyService.createWarranty(
                    request.getSerialId(),
                    request.getStartDate(),
                    request.getEndDate(),
                    request.getStatus()
            );
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Create warranty successfully", toDTO(warranty)));
        } catch (RuntimeException e) {
            log.warn("Error creating warranty: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Error creating warranty:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<WarrantyDTO>> updateWarranty(
            @PathVariable Integer id,
            @RequestBody UpdateWarrantyRequest request) {
        try {
            Warranty warranty = warrantyService.updateWarranty(
                    id,
                    request.getSerialId(),
                    request.getStartDate(),
                    request.getEndDate(),
                    request.getStatus()
            );
            if (warranty == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Warranty not found", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Update warranty successfully", toDTO(warranty)));
        } catch (RuntimeException e) {
            log.warn("Error updating warranty: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Error updating warranty:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    private WarrantyDTO toDTO(Warranty warranty) {
        SerialNumber serialNumber = warranty.getSerialNumber();
        Integer serialId = serialNumber != null ? serialNumber.getSerialId() : null;
        String serialCode = serialNumber != null ? serialNumber.getSerialCode() : null;

        return new WarrantyDTO(
                warranty.getWarrantyId(),
                serialId,
                serialCode,
                warranty.getStartDate(),
                warranty.getEndDate(),
                warranty.getStatus()
        );
    }
}
