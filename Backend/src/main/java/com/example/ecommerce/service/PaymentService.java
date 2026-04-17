package com.example.ecommerce.service;

import com.example.ecommerce.entity.Payment;
import com.example.ecommerce.entity.Order;
import com.example.ecommerce.repository.PaymentRepository;
import com.example.ecommerce.repository.OrderRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class PaymentService {

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private OrderRepository orderRepository;

    public Payment createPayment(Integer orderId, BigDecimal amount, String method) {
        Optional<Order> orderOpt = orderRepository.findById(orderId);
        if (!orderOpt.isPresent()) return null;

        Payment payment = new Payment();
        payment.setOrder(orderOpt.get());
        payment.setAmount(amount);
        payment.setMethod(method);
        payment.setStatus("pending");
        payment.setCreatedAt(LocalDateTime.now());

        return paymentRepository.save(payment);
    }

    public Payment getPayment(Integer paymentId) {
        return paymentRepository.findById(paymentId).orElse(null);
    }

    public List<Payment> getPaymentsByOrder(Integer orderId) {
        return paymentRepository.findByOrderOrderId(orderId);
    }

    public Payment updatePaymentStatus(Integer paymentId, String status) {
        Optional<Payment> paymentOpt = paymentRepository.findById(paymentId);
        if (!paymentOpt.isPresent()) return null;

        Payment payment = paymentOpt.get();
        payment.setStatus(status);
        return paymentRepository.save(payment);
    }

    public Payment recordTransaction(Integer paymentId, String transactionId) {
        Optional<Payment> paymentOpt = paymentRepository.findById(paymentId);
        if (!paymentOpt.isPresent()) return null;

        Payment payment = paymentOpt.get();
        payment.setTransactionId(transactionId);
        return paymentRepository.save(payment);
    }

    public Payment getPaymentByTransactionId(String transactionId) {
        return paymentRepository.findByTransactionId(transactionId).orElse(null);
    }
}
