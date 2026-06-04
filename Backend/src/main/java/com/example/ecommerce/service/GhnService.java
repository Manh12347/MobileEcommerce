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
    private final NotificationService notificationService;

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
            // Set content type and accept headers
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setAccept(List.of(MediaType.APPLICATION_JSON));

            // Prefer standard Authorization Bearer if GHN supports it
            // headers.setBearerAuth(ghnConfig.getToken());

            // Fallback to existing Token header if required by GHN
            headers.set("Token", ghnConfig.getToken());

            // Ensure ShopId is always sent as a string
            headers.set("ShopId", String.valueOf(ghnConfig.getShopId()));

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
                    // Luu phi ship vao order
                    int totalFee = response.getData().getTotalFee();
                    if (totalFee > 0) {
                        order.setShippingFee(java.math.BigDecimal.valueOf(totalFee));
                        orderRepository.save(order);
                        log.info("[GhnService] Async: Saved shipping_fee={} for orderId={}", totalFee, orderId);
                    }
                    // Thong bao cho khach: don hang dang duoc giao
                    notificationService.createNotification(
                            order.getAccount(),
                            "Đơn hàng đang giao",
                            "Đơn hàng " + order.getOrderCode() + " đã được tạo vận đơn GHN và đang trên đường giao đến bạn.",
                            "order"
                    );
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

        if (order.getWardName() != null && !order.getWardName().isBlank()) {
            toWardName = order.getWardName();
        }
        if (order.getDistrictName() != null && !order.getDistrictName().isBlank()) {
            toDistrictName = order.getDistrictName();
        }
        if (order.getProvinceName() != null && !order.getProvinceName().isBlank()) {
            toProvinceName = order.getProvinceName();
        }

        toAddress = buildFullAddress(toAddress, toWardName, toDistrictName, toProvinceName);

        // Ward code: prefer order value, fall back to configured default (can be hardcoded in application.properties)
        String toWardCodeValue = order.getShippingWardCode();
        if (toWardCodeValue == null || toWardCodeValue.isBlank()) {
            toWardCodeValue = order.getWardCode();
        }
        if (toWardCodeValue == null || toWardCodeValue.isBlank()) {
            toWardCodeValue = ghnConfig.getDefaultToWardCode();
        }

        // Build GHN items
        List<GhnCreateOrderRequest.GhnOrderItem> ghnItems = items.stream()
                .map(item -> {
                    String productName = "San pham";
                    String sku = "";
                    String image = null;
                    if (item.getProductItem() != null) {
                        if (item.getProductItem().getProduct() != null) {
                            productName = item.getProductItem().getProduct().getName();
                        }
                        sku = item.getProductItem().getSku() != null ? item.getProductItem().getSku() : "";
                        image = item.getProductItem().getMainImageUrl();
                    }
                    return GhnCreateOrderRequest.GhnOrderItem.builder()
                            .name(productName)
                            .code(sku)
                            .image(image)
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

        boolean isCodPayment = "COD".equalsIgnoreCase(order.getPaymentMethod());
        int codAmount = isCodPayment ? order.getTotalPrice().intValue() : 0;

        return GhnCreateOrderRequest.builder()
            .paymentTypeId(isCodPayment ? 2 : 1)
            .note("Hàng kỹ thuật vận chuyển nhẹ nhàng")
            .requiredNote(resolveRequiredNote())
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
                .toWardCode(toWardCodeValue)
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

    private String buildFullAddress(String address, String wardName, String districtName, String provinceName) {
        List<String> parts = new java.util.ArrayList<>();
        if (address != null && !address.isBlank()) {
            parts.add(address.trim());
        }
        if (wardName != null && !wardName.isBlank()) {
            parts.add(wardName.trim());
        }
        if (districtName != null && !districtName.isBlank()) {
            parts.add(districtName.trim());
        }
        if (provinceName != null && !provinceName.isBlank()) {
            parts.add(provinceName.trim());
        }
        return String.join(", ", parts);
    }

    private String resolveRequiredNote() {
        String requiredNote = ghnConfig.getRequiredNote();
        return (requiredNote == null || requiredNote.isBlank()) ? "KHONGCHOXEMHANG" : requiredNote;
    }
}
