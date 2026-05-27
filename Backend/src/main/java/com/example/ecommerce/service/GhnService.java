package com.example.ecommerce.service;

import com.example.ecommerce.config.GhnConfig;
import com.example.ecommerce.dto.GhnCreateOrderRequest;
import com.example.ecommerce.dto.GhnCreateOrderResponse;
import com.example.ecommerce.entity.Order;
import com.example.ecommerce.entity.OrderItem;
import com.example.ecommerce.entity.Profile;
import com.example.ecommerce.repository.OrderItemRepository;
import com.example.ecommerce.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class GhnService {

    private final GhnConfig ghnConfig;
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final RestTemplate restTemplate;

    /**
     * Tao don hang van chuyen tren Giao Hang Nhanh
     * Duoc goi sau khi thanh toan thanh cong (gencode match)
     */
    public GhnCreateOrderResponse createShippingOrder(Order order) {
        try {
            log.info("[GhnService] Creating GHN shipping order: orderId={}, orderCode={}",
                    order.getOrderId(), order.getOrderCode());

            GhnCreateOrderRequest request = buildRequest(order);
            String url = ghnConfig.getBaseUrl() + "/shiip/public-api/v2/shipping-order/create";

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("Token", ghnConfig.getToken());
            headers.set("ShopId", ghnConfig.getShopId());

            HttpEntity<GhnCreateOrderRequest> entity = new HttpEntity<>(request, headers);
            ResponseEntity<GhnCreateOrderResponse> response = restTemplate.exchange(
                    url,
                    HttpMethod.POST,
                    entity,
                    GhnCreateOrderResponse.class
            );

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                GhnCreateOrderResponse body = response.getBody();
                if (body.isSuccess()) {
                    log.info("[GhnService] ✅ GHN order created: orderId={}, ghnOrderCode={}, totalFee={}",
                            order.getOrderId(),
                            body.getData().getOrderCode(),
                            body.getData().getTotalFee());
                } else {
                    log.warn("[GhnService] ⚠️ GHN returned error: code={}, message={}",
                            body.getCode(), body.getMessage());
                }
                return body;
            }

            log.error("[GhnService] ❌ GHN request failed: status={}", response.getStatusCode());
            return GhnCreateOrderResponse.builder()
                    .code(-1)
                    .message("HTTP " + response.getStatusCode())
                    .build();

        } catch (Exception e) {
            log.error("[GhnService] ❌ Exception creating GHN order: orderId={}", order.getOrderId(), e);
            return GhnCreateOrderResponse.builder()
                    .code(-99)
                    .message(e.getMessage())
                    .build();
        }
    }

    /**
     * Goi GHN API bat dong bo (chay trong virtual thread rieng)
     * De webhook response nhanh, khong block
     */
    public void createShippingOrderAsync(Integer orderId) {
        Thread.ofVirtual().start(() -> {
            try {
                log.info("[GhnService] Async: Starting GHN order for orderId={}", orderId);
                Order order = orderRepository.findByIdWithAccountAndProfile(orderId).orElse(null);
                if (order == null) {
                    log.error("[GhnService] Async: ❌ Order not found: orderId={}", orderId);
                    return;
                }
                GhnCreateOrderResponse response = createShippingOrder(order);
                if (response.isSuccess()) {
                    log.info("[GhnService] Async: ✅ GHN order created: orderId={}, ghnOrderCode={}",
                            orderId, response.getData().getOrderCode());
                } else {
                    log.warn("[GhnService] Async: ⚠️ GHN failed: orderId={}, code={}, message={}",
                            orderId, response.getCode(), response.getMessage());
                }
            } catch (Exception e) {
                log.error("[GhnService] Async: ❌ GHN order failed: orderId={}", orderId, e);
            }
        });
    }

    private GhnCreateOrderRequest buildRequest(Order order) {
        List<OrderItem> items = orderItemRepository.findByOrderOrderId(order.getOrderId());

        // Buyer info — uu tien tu profile, fallback sang order fields
        String toName = order.getAccount().getEmail();
        String toPhone = "";
        String toAddress = "";
        String toWardName = "";
        String toDistrictName = "";
        String toProvinceName = "";

        Profile profile = order.getAccount().getProfile();
        if (profile != null) {
            if (profile.getFullName() != null) toName = profile.getFullName();
            if (profile.getPhone() != null && !profile.getPhone().isBlank()) toPhone = profile.getPhone();
            if (profile.getAddress() != null && !profile.getAddress().isBlank()) toAddress = profile.getAddress();
        }
        if ((toPhone == null || toPhone.isBlank()) && order.getPhone() != null) {
            toPhone = order.getPhone();
        }
        if ((toAddress == null || toAddress.isBlank()) && order.getShippingAddress() != null) {
            toAddress = order.getShippingAddress();
        }

        // Build GHN items
        List<GhnCreateOrderRequest.GhnOrderItem> ghnItems = items.stream()
                .map(item -> {
                    String productName = "San pham";
                    String sku = "";
                    if (item.getProductItem() != null) {
                        if (item.getProductItem().getProduct() != null) {
                            productName = item.getProductItem().getProduct().getName();
                        }
                        sku = item.getProductItem().getSku() != null ? item.getProductItem().getSku() : "";
                    }
                    return GhnCreateOrderRequest.GhnOrderItem.builder()
                            .name(productName)
                            .code(sku)
                            .quantity(item.getQuantity())
                            .price(item.getPrice().intValue())
                            .length(ghnConfig.getDefaultLength())
                            .width(ghnConfig.getDefaultWidth())
                            .height(ghnConfig.getDefaultHeight())
                            .weight(ghnConfig.getDefaultWeight())
                            .category(GhnCreateOrderRequest.GhnOrderItem.GhnCategory.builder()
                                    .level1("San pham")
                                    .build())
                            .build();
                })
                .collect(Collectors.toList());

        // Da thanh toan online roi → payment_type_id = 1 (nguoi ban tra phi van chuyen)
        // Neu chua thanh toan → payment_type_id = 2 va dat cod_amount = totalPrice
        boolean isPaid = "paid".equals(order.getPaymentStatus());
        int codAmount = isPaid ? 0 : order.getTotalPrice().intValue();

        return GhnCreateOrderRequest.builder()
                .paymentTypeId(isPaid ? 1 : 2)
                .note("Don hang: " + order.getOrderCode())
                .requiredNote("CHOTHUHANG")
                .returnPhone(ghnConfig.getReturnPhone())
                .returnAddress(ghnConfig.getReturnAddress())
                .clientOrderCode(order.getOrderCode())
                .fromName(ghnConfig.getFromName())
                .fromPhone(ghnConfig.getFromPhone())
                .fromAddress(ghnConfig.getFromAddress())
                .fromWardName(ghnConfig.getFromWardName())
                .fromDistrictName(ghnConfig.getFromDistrictName())
                .fromProvinceName(ghnConfig.getFromProvinceName())
                .toName(toName)
                .toPhone(toPhone)
                .toAddress(toAddress)
                .toWardName(toWardName)
                .toDistrictName(toDistrictName)
                .toProvinceName(toProvinceName)
                .codAmount(codAmount)
                .content("Don hang: " + order.getOrderCode())
                .weight(ghnConfig.getDefaultWeight())
                .length(ghnConfig.getDefaultLength())
                .width(ghnConfig.getDefaultWidth())
                .height(ghnConfig.getDefaultHeight())
                .pickStationId(null)
                .insuranceValue(order.getTotalPrice().intValue())
                .serviceTypeId(ghnConfig.getServiceTypeId())
                .pickShift(List.of(2))
                .codFailedAmount(2000)
                .items(ghnItems)
                .build();
    }
}
