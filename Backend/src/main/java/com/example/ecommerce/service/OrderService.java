package com.example.ecommerce.service;

import com.example.ecommerce.entity.*;
import com.example.ecommerce.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@Transactional
public class OrderService {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderItemRepository orderItemRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    public Order createOrder(Account account, String shippingAddress, String phone, String paymentMethod) {
        Order order = new Order();
        order.setAccount(account);
        order.setOrderCode(UUID.randomUUID().toString().substring(0, 20));
        order.setShippingAddress(shippingAddress);
        order.setPhone(phone);
        order.setPaymentMethod(paymentMethod);
        order.setStatus("pending");
        order.setPaymentStatus("pending");
        order.setTotalPrice(BigDecimal.ZERO);

        Order savedOrder = orderRepository.save(order);

        // Log action
        AuditLog log = new AuditLog();
        log.setAccount(account);
        log.setAction("CREATE_ORDER");
        log.setEntity("Order");
        log.setEntityId(savedOrder.getOrderId());
        log.setCreatedAt(LocalDateTime.now());
        auditLogRepository.save(log);

        return savedOrder;
    }

    public Order getOrder(Integer orderId) {
        return orderRepository.findById(orderId).orElse(null);
    }

    public List<Order> getOrdersByAccount(Integer accountId) {
        return orderRepository.findByAccountAccountId(accountId);
    }

    public Order addItemToOrder(Integer orderId, ProductItem productItem, Integer quantity, BigDecimal price) {
        Order order = orderRepository.findById(orderId).orElse(null);
        if (order == null) return null;

        OrderItem orderItem = new OrderItem();
        orderItem.setOrder(order);
        orderItem.setProductItem(productItem);
        orderItem.setQuantity(quantity);
        orderItem.setPrice(price);

        orderItemRepository.save(orderItem);

        // Update total price
        List<OrderItem> items = orderItemRepository.findByOrderOrderId(orderId);
        BigDecimal total = items.stream()
                .map(item -> item.getPrice().multiply(new BigDecimal(item.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        order.setTotalPrice(total);

        return orderRepository.save(order);
    }

    public Order updateOrderStatus(Integer orderId, String status) {
        Order order = orderRepository.findById(orderId).orElse(null);
        if (order != null) {
            order.setStatus(status);
            return orderRepository.save(order);
        }
        return null;
    }

    public Order updatePaymentStatus(Integer orderId, String paymentStatus) {
        Order order = orderRepository.findById(orderId).orElse(null);
        if (order != null) {
            order.setPaymentStatus(paymentStatus);
            return orderRepository.save(order);
        }
        return null;
    }

    public List<OrderItem> getOrderItems(Integer orderId) {
        return orderItemRepository.findByOrderOrderId(orderId);
    }
}
