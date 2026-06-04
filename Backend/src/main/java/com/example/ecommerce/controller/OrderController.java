package com.example.ecommerce.controller;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.service.OrderService;
import com.example.ecommerce.util.SecurityUtil;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/v1/api/orders")
@CrossOrigin(origins = "*")
@Slf4j
public class OrderController {

    @Autowired
    private OrderService orderService;

    @PostMapping("/checkout")
    public ResponseEntity<ApiResponse<OrderDTO>> checkout(@Valid @RequestBody CreateOrderRequest request) {
        try {
            Integer accountId = requireAccountId();
            OrderDTO order = orderService.checkout(accountId, request);
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new ApiResponse<>(true, "Đặt hàng thành công", order));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi đặt hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/staff")
    public ResponseEntity<ApiResponse<List<OrderSummaryDTO>>> getAllOrdersForStaff(
            @RequestParam(required = false) String status) {
        try {
            requireStaff();
            List<OrderSummaryDTO> orders = orderService.getAllOrdersForStaff(status);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách đơn hàng thành công", orders));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy danh sách đơn hàng (staff):", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/staff/{orderId}")
    public ResponseEntity<ApiResponse<OrderDTO>> getOrderDetailForStaff(@PathVariable Integer orderId) {
        try {
            requireStaff();
            OrderDTO order = orderService.getOrderDetailForStaff(orderId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy chi tiết đơn hàng thành công", order));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy chi tiết đơn hàng (staff):", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PutMapping("/staff/{orderId}/status")
    public ResponseEntity<ApiResponse<OrderDTO>> updateOrderStatus(
            @PathVariable Integer orderId,
            @Valid @RequestBody UpdateOrderStatusRequest request) {
        try {
            Integer accountId = requireAccountId();
            requireStaff();
            OrderDTO order = orderService.updateOrderStatusByStaff(accountId, orderId, request);
            return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật trạng thái đơn hàng thành công", order));
        } catch (RuntimeException e) {
            HttpStatus httpStatus = e.getMessage().contains("nhân viên")
                    ? HttpStatus.FORBIDDEN : HttpStatus.BAD_REQUEST;
            return ResponseEntity.status(httpStatus)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi cập nhật trạng thái đơn hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/track/{orderCode}")
    public ResponseEntity<ApiResponse<OrderTrackDTO>> trackOrder(@PathVariable String orderCode) {
        try {
            Integer accountId = requireAccountId();
            OrderTrackDTO track = orderService.trackOrder(accountId, orderCode);
            return ResponseEntity.ok(new ApiResponse<>(true, "Theo dõi đơn hàng thành công", track));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi theo dõi đơn hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<OrderSummaryDTO>>> getMyOrders() {
        try {
            Integer accountId = requireAccountId();
            List<OrderSummaryDTO> orders = orderService.getMyOrders(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách đơn hàng thành công", orders));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy danh sách đơn hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/{orderId}")
    public ResponseEntity<ApiResponse<OrderDTO>> getOrderDetail(@PathVariable Integer orderId) {
        try {
            Integer accountId = requireAccountId();
            OrderDTO order = orderService.getOrderDetail(accountId, orderId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy chi tiết đơn hàng thành công", order));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy chi tiết đơn hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @PostMapping("/{orderId}/cancel")
    public ResponseEntity<ApiResponse<OrderDTO>> cancelOrder(@PathVariable Integer orderId) {
        try {
            Integer accountId = requireAccountId();
            OrderDTO order = orderService.cancelOrder(accountId, orderId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Hủy đơn hàng thành công", order));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi hủy đơn hàng:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    @GetMapping("/staff/stats")
    public ResponseEntity<ApiResponse<DashboardStatsDTO>> getDashboardStats() {
        try {
            requireStaff();
            DashboardStatsDTO stats = orderService.getDashboardStats();
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy thống kê thành công", stats));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(new ApiResponse<>(false, e.getMessage(), null));
        } catch (Exception e) {
            log.error("Lỗi khi lấy thống kê dashboard:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi server: " + e.getMessage(), null));
        }
    }

    private Integer requireAccountId() {
        Integer accountId = SecurityUtil.getCurrentAccountId();
        if (accountId == null) {
            throw new RuntimeException("Vui lòng đăng nhập");
        }
        return accountId;
    }

    private void requireStaff() {
        if (!SecurityUtil.isStaff()) {
            throw new RuntimeException("Chỉ nhân viên mới có quyền thực hiện thao tác này");
        }
    }
}
