package com.example.ecommerce.service;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.*;
import com.example.ecommerce.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import lombok.extern.slf4j.Slf4j;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Collectors;

import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Service
@Transactional
@Slf4j
public class OrderService {

    private static final Set<String> VALID_STATUSES = Set.of("pending", "shipping", "completed", "cancelled");
    private static final Map<String, Set<String>> STAFF_TRANSITIONS = Map.of(
            "pending", Set.of("shipping", "cancelled"),
            "shipping", Set.of("completed")
    );

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderItemRepository orderItemRepository;

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private CartRepository cartRepository;

    @Autowired
    private CartItemRepository cartItemRepository;

    @Autowired
    private ProductItemRepository productItemRepository;

    @Autowired
    private SerialNumberRepository serialNumberRepository;

    @Autowired
    private SoldSerialRepository soldSerialRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private PaymentRedisService paymentRedisService;

    @Autowired
    private GhnService ghnService;

    @Autowired
    private WarrantyRepository warrantyRepository;

    public OrderDTO checkout(Integer accountId, CreateOrderRequest request) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản"));

        List<CartItem> cartItems;
        Cart cart = null;
        if (request.getItems() != null && !request.getItems().isEmpty()) {
            cartItems = new ArrayList<>();
            for (CreateOrderRequest.CheckoutItem item : request.getItems()) {
                ProductItem productItem = productItemRepository.findById(item.getProductItemId())
                        .orElseThrow(() -> new RuntimeException("Không tìm thấy sản phẩm: " + item.getProductItemId()));

                CartItem cartItem = new CartItem();
                cartItem.setProductItem(productItem);
                cartItem.setQuantity(item.getQuantity());
                cartItem.setPrice(resolveUnitPrice(productItem));
                cartItems.add(cartItem);
            }
        } else {
            cart = cartRepository.findAllByAccountAccountIdOrderByUpdatedOnDescCartIdDesc(accountId)
                    .stream()
                    .findFirst()
                    .orElseThrow(() -> new RuntimeException("Giỏ hàng trống, không thể đặt hàng"));

            cartItems = cartItemRepository.findByCartCartId(cart.getCartId());
            if (cartItems.isEmpty()) {
                throw new RuntimeException("Giỏ hàng trống, không thể đặt hàng");
            }
        }

        for (CartItem cartItem : cartItems) {
            validateStock(cartItem.getProductItem().getProductItemId(), cartItem.getQuantity());
        }

        Order order = new Order();
        order.setAccount(account);
        order.setOrderCode(generateUniqueOrderCode());
        order.setShippingAddress(request.getShippingAddress());
        order.setPhone(request.getPhone());
        order.setProvinceId(request.getProvinceId());
        order.setDistrictId(request.getDistrictId());
        order.setWardCode(request.getWardCode());
        order.setProvinceName(request.getProvinceName());
        order.setDistrictName(request.getDistrictName());
        order.setWardName(request.getWardName());
        order.setShippingWardCode(request.getWardCode());
        order.setPaymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "COD");
        order.setStatus("pending");
        order.setPaymentStatus("pending");
        order.setTotalPrice(BigDecimal.ZERO);
        Order savedOrder = orderRepository.save(order);

        // Determine fulfillment flow early so allocation logic can use it
        boolean isTransfer = "Transfer".equalsIgnoreCase(savedOrder.getPaymentMethod());
        boolean isPickup = "Pickup".equalsIgnoreCase(savedOrder.getPaymentMethod());

        BigDecimal total = BigDecimal.ZERO;
        for (CartItem cartItem : cartItems) {
            ProductItem productItem = productItemRepository
                    .findByIdWithSerialsAndProduct(cartItem.getProductItem().getProductItemId())
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy sản phẩm"));

            BigDecimal unitPrice = resolveUnitPrice(productItem);

            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(savedOrder);
            orderItem.setProductItem(productItem);
            orderItem.setQuantity(cartItem.getQuantity());
            orderItem.setPrice(unitPrice);
            OrderItem savedItem = orderItemRepository.save(orderItem);

            if (!isTransfer) {
                allocateSerials(savedItem, productItem, cartItem.getQuantity());
            }
            total = total.add(unitPrice.multiply(BigDecimal.valueOf(cartItem.getQuantity())));
        }

        savedOrder.setTotalPrice(total);
        orderRepository.save(savedOrder);

        String gencode = null;

        if (isTransfer) {
            // Capture cart snapshot BEFORE clearing cart items (for cart restore on timeout)
            List<PaymentCacheInfo.CartSnapshotItem> cartSnapshot = cartItems.stream()
                    .map(ci -> PaymentCacheInfo.CartSnapshotItem.builder()
                            .productItemId(ci.getProductItem().getProductItemId())
                            .quantity(ci.getQuantity())
                            .price(ci.getPrice())
                            .build())
                    .collect(Collectors.toList());

            // Transfer: tao gencode + cache Redis voi 5 phut timeout
            gencode = generatePaymentGencode();
            PaymentCacheInfo cacheInfo = PaymentCacheInfo.builder()
                    .orderId(savedOrder.getOrderId())
                    .orderCode(savedOrder.getOrderCode())
                    .gencode(gencode)
                    .accountId(accountId)
                    .totalAmount(total)
                    .paymentStatus("pending")
                    .createdAt(LocalDateTime.now())
                    .expiresInMinutes(30)
                    .cartSnapshot(cartSnapshot)
                    .build();
            paymentRedisService.cacheOrderPaymentInfo(cacheInfo, 30);

            notificationService.createNotification(
                    account,
                    "Chờ thanh toán",
                    "Đơn hàng " + savedOrder.getOrderCode() + " đang chờ thanh toán chuyển khoản.",
                    "order"
            );
            } else if (isPickup) {
                // Pickup tại cửa hàng: hoàn tất ngay, không cần GHN hay Redis
                savedOrder.setPaymentStatus("paid");
                savedOrder.setStatus("completed");
                orderRepository.save(savedOrder);

                notificationService.createNotification(
                    account,
                    "Đặt hàng thành công",
                    "Đơn hàng " + savedOrder.getOrderCode() + " đã được xác nhận. Khách nhận tại cửa hàng.",
                    "order"
                );
        } else {
            // COD: xac nhan luon, khong can Redis
            savedOrder.setPaymentStatus("paid");
                savedOrder.setStatus("pending");
            orderRepository.save(savedOrder);

            notificationService.createNotification(
                    account,
                    "Đặt hàng thành công",
                    "Đơn hàng " + savedOrder.getOrderCode() + " đã được tạo và đang chờ xử lý.",
                    "order"
            );

                // COD cần tạo vận đơn GHN sau khi transaction commit để GHN đọc thấy order đã lưu
                scheduleGhnAfterCommit(savedOrder.getOrderId());
        }

        // Xoa cart items (da chuyen thanh order items roi)
        if (Boolean.TRUE.equals(request.getDirectBuy())) {
            // directBuy: khong xoa cart, chi xoa cac item da duoc chon
            // (cac item trong cartItems la fake objects, khong co trong DB)
        } else if (cart != null) {
            cartItemRepository.deleteAll(cartItems);
            cart.setUpdatedOn(LocalDateTime.now());
            cartRepository.save(cart);
        }

        logAudit(account, "CREATE_ORDER", savedOrder.getOrderId());

        OrderDTO dto = toOrderDTO(savedOrder);
        dto.setGencode(gencode);
        return dto;
    }

    public void confirmTransferPayment(Integer orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy đơn hàng"));

        if (!"Transfer".equalsIgnoreCase(order.getPaymentMethod())) {
            return;
        }

        if (!"paid".equals(order.getPaymentStatus())) {
            throw new RuntimeException("Đơn hàng chưa được xác nhận thanh toán");
        }

        List<SoldSerial> existingSoldSerials = soldSerialRepository.findByOrderIdWithSerial(orderId);
        if (!existingSoldSerials.isEmpty()) {
            return;
        }

        List<OrderItem> items = orderItemRepository.findByOrderOrderId(orderId);
        for (OrderItem item : items) {
            ProductItem productItem = productItemRepository
                    .findByIdWithSerialsAndProduct(item.getProductItem().getProductItemId())
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy sản phẩm"));

            allocateSerials(item, productItem, item.getQuantity());
        }

        // Gửi thông báo cho khách sau khi thanh toán chuyển khoản thành công
        notificationService.createNotification(
                order.getAccount(),
                "Thanh toán thành công",
                "Đơn hàng " + order.getOrderCode() + " đã được thanh toán thành công và đang được xử lý.",
                "order"
        );
    }

    public List<OrderSummaryDTO> getMyOrders(Integer accountId) {
        return orderRepository.findByAccountAccountIdOrderByCreatedOnDesc(accountId).stream()
                .map(this::toSummaryDTO)
                .collect(Collectors.toList());
    }

    public OrderDTO getOrderDetail(Integer accountId, Integer orderId) {
        Order order = requireOwnedOrder(orderId, accountId);
        return toOrderDTO(order);
    }

    public OrderDTO getOrderDetailByCode(Integer accountId, String orderCode) {
        Order order = orderRepository.findByOrderCode(orderCode)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy đơn hàng"));

        if (!order.getAccount().getAccountId().equals(accountId)) {
            throw new RuntimeException("Không có quyền xem đơn hàng này");
        }
        return toOrderDTO(order);
    }

    public OrderTrackDTO trackOrder(Integer accountId, String orderCode) {
        Order order = orderRepository.findByOrderCode(orderCode)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy đơn hàng"));

        if (!order.getAccount().getAccountId().equals(accountId)) {
            throw new RuntimeException("Không có quyền theo dõi đơn hàng này");
        }

        return buildTrackDTO(order);
    }

    public OrderDTO cancelOrder(Integer accountId, Integer orderId) {
        Order order = requireOwnedOrder(orderId, accountId);

        if (!"pending".equals(order.getStatus())) {
            throw new RuntimeException("Chỉ có thể hủy đơn hàng khi trạng thái là pending");
        }

        releaseInventory(order);
        order.setStatus("cancelled");
        orderRepository.save(order);

        notificationService.createNotification(
                order.getAccount(),
                "Đơn hàng đã hủy",
                "Đơn hàng " + order.getOrderCode() + " đã được hủy. Tồn kho đã được hoàn lại.",
                "order"
        );

        logAudit(order.getAccount(), "CANCEL_ORDER", order.getOrderId());
        return toOrderDTO(order);
    }

    private void scheduleGhnAfterCommit(Integer orderId) {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                ghnService.createShippingOrderAsync(orderId);
            }
        });
    }

    public List<OrderSummaryDTO> getAllOrdersForStaff(String status) {
        List<Order> orders;
        if (status != null && !status.isBlank()) {
            if (!VALID_STATUSES.contains(status)) {
                throw new RuntimeException("Trạng thái không hợp lệ");
            }
            orders = orderRepository.findByStatusOrderByCreatedOnDesc(status);
        } else {
            orders = orderRepository.findAllByOrderByCreatedOnDesc();
        }
        return orders.stream().map(this::toSummaryDTO).collect(Collectors.toList());
    }

    public DashboardStatsDTO getDashboardStats() {
        DashboardStatsDTO stats = new DashboardStatsDTO();
        stats.setTotalUsers(accountRepository.countByRole("customer"));
        stats.setTotalOrders(orderRepository.count());
        stats.setTotalProducts(productItemRepository.count());
        stats.setTotalRevenue(orderRepository.sumTotalPriceByPaymentStatus("paid"));
        stats.setPendingOrders(orderRepository.countByStatus("pending"));
        stats.setShippingOrders(orderRepository.countByStatus("shipping"));
        stats.setCompletedOrders(orderRepository.countByStatus("completed"));
        stats.setCancelledOrders(orderRepository.countByStatus("cancelled"));
        return stats;
    }

    public OrderDTO getOrderDetailForStaff(Integer orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy đơn hàng"));
        return toOrderDTO(order);
    }

    public OrderDTO updateOrderStatusByStaff(Integer staffAccountId, Integer orderId, UpdateOrderStatusRequest request) {
        Account staff = accountRepository.findById(staffAccountId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản"));
        requireStaffRole(staff);

        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy đơn hàng"));

        String newStatus = request.getStatus().toLowerCase();
        if (!VALID_STATUSES.contains(newStatus)) {
            throw new RuntimeException("Trạng thái không hợp lệ");
        }

        String currentStatus = order.getStatus();
        Set<String> allowed = STAFF_TRANSITIONS.getOrDefault(currentStatus, Set.of());
        if (!allowed.contains(newStatus)) {
            throw new RuntimeException("Không thể chuyển từ " + currentStatus + " sang " + newStatus);
        }

        if ("cancelled".equals(newStatus)) {
            releaseInventory(order);
        }

        order.setStatus(newStatus);
        orderRepository.save(order);

        String message = switch (newStatus) {
            case "shipping" -> "Đơn hàng " + order.getOrderCode() + " đã được xác nhận và đang giao.";
            case "completed" -> "Đơn hàng " + order.getOrderCode() + " đã giao thành công.";
            case "cancelled" -> "Đơn hàng " + order.getOrderCode() + " đã bị hủy bởi nhân viên.";
            default -> "Trạng thái đơn hàng " + order.getOrderCode() + " đã cập nhật.";
        };

        notificationService.createNotification(order.getAccount(), "Cập nhật đơn hàng", message, "order");
        logAudit(staff, "UPDATE_ORDER_STATUS", order.getOrderId());

        return toOrderDTO(order);
    }

    private void validateStock(Integer productItemId, int quantity) {
        ProductItem productItem = productItemRepository.findByIdWithSerialsAndProduct(productItemId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy sản phẩm: " + productItemId));

        long availableSerials = productItem.getSerials().stream()
                .filter(s -> "in_stock".equals(s.getStatus()))
                .count();

        if (productItem.getStockQuantity() == null || productItem.getStockQuantity() < quantity) {
            throw new RuntimeException("Sản phẩm " + productItem.getSku() + " không đủ tồn kho");
        }
        if (availableSerials < quantity) {
            throw new RuntimeException("Sản phẩm " + productItem.getSku() + " không đủ serial trong kho");
        }
    }

    private void allocateSerials(OrderItem orderItem, ProductItem productItem, int quantity) {
        List<SerialNumber> toAllocate = productItem.getSerials().stream()
                .filter(s -> "in_stock".equals(s.getStatus()))
                .limit(quantity)
                .collect(Collectors.toList());

        if (toAllocate.size() < quantity) {
            throw new RuntimeException("Không đủ serial để phân bổ cho " + productItem.getSku());
        }

        for (SerialNumber serial : toAllocate) {
            serial.setStatus("sold");
            serialNumberRepository.save(serial);

            SoldSerial soldSerial = new SoldSerial();
            soldSerial.setOrderItem(orderItem);
            soldSerial.setSerialNumber(serial);
            soldSerialRepository.save(soldSerial);
        }

        productItem.setStockQuantity(productItem.getStockQuantity() - quantity);
        productItemRepository.save(productItem);
    }

    private void releaseInventory(Order order) {
        List<SoldSerial> soldSerials = soldSerialRepository.findByOrderIdWithSerial(order.getOrderId());

        for (SoldSerial soldSerial : soldSerials) {
            SerialNumber serial = soldSerial.getSerialNumber();
            serial.setStatus("in_stock");
            serialNumberRepository.save(serial);
        }
        soldSerialRepository.deleteAll(soldSerials);

        List<OrderItem> items = orderItemRepository.findByOrderOrderId(order.getOrderId());
        for (OrderItem item : items) {
            ProductItem productItem = productItemRepository.findById(item.getProductItem().getProductItemId())
                    .orElse(null);
            if (productItem != null) {
                productItem.setStockQuantity(productItem.getStockQuantity() + item.getQuantity());
                productItemRepository.save(productItem);
            }
        }
    }

    private Order requireOwnedOrder(Integer orderId, Integer accountId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy đơn hàng"));

        if (!order.getAccount().getAccountId().equals(accountId)) {
            throw new RuntimeException("Không có quyền truy cập đơn hàng này");
        }
        return order;
    }

    private void requireStaffRole(Account account) {
        String role = account.getRole();
        if (!"staff".equals(role) && !"admin".equals(role)) {
            throw new RuntimeException("Chỉ nhân viên mới có quyền thực hiện thao tác này");
        }
    }

    private String generateUniqueOrderCode() {
        String code;
        do {
            code = "ORDER_" + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
                    + "_" + String.format("%04d", new Random().nextInt(10000));
        } while (orderRepository.findByOrderCode(code).isPresent());
        return code;
    }

    private String generatePaymentGencode() {
        String gencode;
        do {
            // Format: ORDER + 15 random digits (no underscore)
            long suffix = Math.abs(new Random().nextLong()) % 1_000_000_000_000_000L;
            gencode = "ORDER" + String.format("%015d", suffix);
        } while (paymentRedisService.exists(gencode));
        return gencode;
    }

    private BigDecimal resolveUnitPrice(ProductItem item) {
        if (item.getSalePrice() != null
                && item.getSalePrice().compareTo(BigDecimal.ZERO) > 0
                && (item.getPrice() == null || item.getSalePrice().compareTo(item.getPrice()) < 0)) {
            return item.getSalePrice();
        }
        return item.getPrice() != null ? item.getPrice() : BigDecimal.ZERO;
    }

    private OrderDTO toOrderDTO(Order order) {
        List<OrderItem> items = orderItemRepository.findByOrderOrderId(order.getOrderId());
        List<SoldSerial> allSoldSerials = soldSerialRepository.findByOrderIdWithSerial(order.getOrderId());

        Map<Integer, List<SoldSerial>> serialsByOrderItem = allSoldSerials.stream()
                .collect(Collectors.groupingBy(ss -> ss.getOrderItem().getOrderItemId()));

        List<OrderItemDTO> itemDTOs = items.stream()
                .map(item -> toOrderItemDTO(item, serialsByOrderItem.getOrDefault(item.getOrderItemId(), List.of())))
                .collect(Collectors.toList());

        OrderDTO dto = new OrderDTO();
        dto.setOrderId(order.getOrderId());
        dto.setOrderCode(order.getOrderCode());
        dto.setAccountId(order.getAccount().getAccountId());
        dto.setStatus(order.getStatus());
        dto.setPaymentStatus(order.getPaymentStatus());
        dto.setPaymentMethod(order.getPaymentMethod());
        dto.setShippingAddress(order.getShippingAddress());
        dto.setPhone(order.getPhone());
        dto.setProvinceId(order.getProvinceId());
        dto.setDistrictId(order.getDistrictId());
        dto.setWardCode(order.getWardCode());
        dto.setProvinceName(order.getProvinceName());
        dto.setDistrictName(order.getDistrictName());
        dto.setWardName(order.getWardName());
        dto.setTotalPrice(order.getTotalPrice());
        dto.setShippingFee(order.getShippingFee());
        dto.setCreatedOn(order.getCreatedOn() != null ? order.getCreatedOn().toString() : null);
        dto.setItems(itemDTOs);
        // Set customer name from linked account/profile when available
        String customerName = null;
        if (order.getAccount() != null) {
            if (order.getAccount().getProfile() != null) {
                customerName = order.getAccount().getProfile().getFullName();
            } else if (order.getAccount().getEmail() != null) {
                customerName = order.getAccount().getEmail();
            }
        }
        dto.setCustomerName(customerName);
        return dto;
    }

    private OrderItemDTO toOrderItemDTO(OrderItem item, List<SoldSerial> soldSerials) {
        ProductItem productItem = item.getProductItem();

        List<OrderSerialDTO> serialDTOs = soldSerials.stream()
                .map(ss -> new OrderSerialDTO(
                        ss.getSerialNumber().getSerialId(),
                        ss.getSerialNumber().getSerialCode(),
                        ss.getSerialNumber().getStatus()
                ))
                .collect(Collectors.toList());

        OrderItemDTO dto = new OrderItemDTO();
        dto.setOrderItemId(item.getOrderItemId());
        dto.setProductItemId(productItem.getProductItemId());
        dto.setSku(productItem.getSku());
        dto.setMainImageUrl(productItem.getMainImageUrl());
        dto.setQuantity(item.getQuantity());
        dto.setPrice(item.getPrice());
        dto.setLineTotal(item.getPrice().multiply(BigDecimal.valueOf(item.getQuantity())));
        dto.setSerials(serialDTOs);

        if (productItem.getProduct() != null) {
            dto.setProductName(productItem.getProduct().getName());
        }

        return dto;
    }

    private OrderSummaryDTO toSummaryDTO(Order order) {
        int itemCount = orderItemRepository.findByOrderOrderId(order.getOrderId()).stream()
                .mapToInt(OrderItem::getQuantity)
                .sum();

        OrderSummaryDTO dto = new OrderSummaryDTO();
        dto.setOrderId(order.getOrderId());
        dto.setOrderCode(order.getOrderCode());
        dto.setStatus(order.getStatus());
        dto.setPaymentStatus(order.getPaymentStatus());
        dto.setPaymentMethod(order.getPaymentMethod());
        dto.setTotalPrice(order.getTotalPrice());
        dto.setCreatedOn(order.getCreatedOn() != null ? order.getCreatedOn().toString() : null);
        dto.setItemCount(itemCount);

        // Populate customer info
        if (order.getAccount() != null) {
            String customerName = null;
            String email = order.getAccount().getEmail();
            if (order.getAccount().getProfile() != null) {
                customerName = order.getAccount().getProfile().getFullName();
            }
            if (customerName == null || customerName.isBlank()) {
                customerName = email;
            }
            dto.setCustomerName(customerName);
            dto.setEmail(email);
        }
        dto.setPhone(order.getPhone());
        dto.setShippingAddress(order.getShippingAddress());

        populateWarrantyInfo(order, dto);

        return dto;
    }

    private void populateWarrantyInfo(Order order, OrderSummaryDTO dto) {
        dto.setSerials(List.of());

        if (!"completed".equals(order.getStatus())) {
            dto.setWarrantyEndDate(null);
            dto.setIsWarrantyExpired(false);
            dto.setWarrantyRemainingText(null);
            return;
        }

        List<SoldSerial> soldSerials = soldSerialRepository.findByOrderIdWithSerial(order.getOrderId());
        
        if (soldSerials.isEmpty()) {
            dto.setWarrantyEndDate(null);
            dto.setIsWarrantyExpired(false);
            dto.setWarrantyRemainingText(null);
            return;
        }
        
        java.time.LocalDate maxEndDate = null;
        List<OrderSerialDTO> serialDTOs = soldSerials.stream()
                .map(ss -> ss.getSerialNumber())
                .filter(sn -> sn != null)
                .map(sn -> new OrderSerialDTO(
                        sn.getSerialId(),
                        sn.getSerialCode(),
                        sn.getStatus()
                ))
                .collect(Collectors.toList());
        dto.setSerials(serialDTOs);

        for (SoldSerial ss : soldSerials) {
            SerialNumber sn = ss.getSerialNumber();
            if (sn == null) continue;
            Warranty w = warrantyRepository.findBySerialNumber_SerialId(sn.getSerialId()).orElse(null);
            java.time.LocalDate endDate = null;
            if (w != null && w.getEndDate() != null) {
                endDate = w.getEndDate();
            } else {
                LocalDateTime orderDate = order.getCreatedOn() != null ? order.getCreatedOn() : LocalDateTime.now();
                endDate = orderDate.toLocalDate().plusMonths(12);
            }
            
            if (maxEndDate == null || endDate.isAfter(maxEndDate)) {
                maxEndDate = endDate;
            }
        }
        
        if (maxEndDate != null) {
            dto.setWarrantyEndDate(maxEndDate.toString());
            java.time.LocalDate today = java.time.LocalDate.now();
            boolean expired = maxEndDate.isBefore(today);
            dto.setIsWarrantyExpired(expired);
            
            if (expired) {
                dto.setWarrantyRemainingText("Hết hạn");
            } else {
                dto.setWarrantyRemainingText(formatRemainingTime(today, maxEndDate));
            }
        }
    }

    private String formatRemainingTime(java.time.LocalDate today, java.time.LocalDate endDate) {
        long days = java.time.temporal.ChronoUnit.DAYS.between(today, endDate);
        if (days <= 0) {
            return "Hết hạn";
        }
        if (days >= 365) {
            long years = days / 365;
            return "Còn " + years + " năm";
        }
        if (days >= 30) {
            long months = days / 30;
            return "Còn " + months + " tháng";
        }
        if (days >= 7) {
            long weeks = days / 7;
            return "Còn " + weeks + " tuần";
        }
        return "Còn " + days + " ngày";
    }

    private OrderTrackDTO buildTrackDTO(Order order) {
        String status = order.getStatus();
        List<OrderStatusStepDTO> timeline = List.of(
                step("pending", "Chờ xử lý", status),
                step("shipping", "Đang giao hàng", status),
                step("completed", "Hoàn thành", status)
        );

        String message = switch (status) {
            case "pending" -> "Đơn hàng đang chờ nhân viên xác nhận.";
            case "shipping" -> "Đơn hàng đang được vận chuyển.";
            case "completed" -> "Đơn hàng đã giao thành công.";
            case "cancelled" -> "Đơn hàng đã bị hủy.";
            default -> "Trạng thái đơn hàng: " + status;
        };

        OrderTrackDTO track = new OrderTrackDTO();
        track.setOrderId(order.getOrderId());
        track.setOrderCode(order.getOrderCode());
        track.setCurrentStatus(status);
        track.setStatusMessage(message);
        track.setTimeline(timeline);
        return track;
    }

    private OrderStatusStepDTO step(String stepStatus, String label, String currentStatus) {
        if ("cancelled".equals(currentStatus)) {
            return new OrderStatusStepDTO(stepStatus, label, "pending".equals(stepStatus), false);
        }
        int stepIdx = statusOrder(stepStatus);
        int currentIdx = statusOrder(currentStatus);
        return new OrderStatusStepDTO(
                stepStatus,
                label,
                currentIdx > stepIdx,
                stepStatus.equals(currentStatus)
        );
    }

    private int statusOrder(String status) {
        return switch (status) {
            case "pending" -> 1;
            case "shipping" -> 2;
            case "completed" -> 3;
            default -> 0;
        };
    }

    private void logAudit(Account account, String action, Integer entityId) {
        AuditLog log = new AuditLog();
        log.setAccount(account);
        log.setAction(action);
        log.setEntity("Order");
        log.setEntityId(entityId);
        log.setCreatedAt(LocalDateTime.now());
        auditLogRepository.save(log);
    }
}
