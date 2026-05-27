package com.example.ecommerce.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GhnCreateOrderRequest {

    @JsonProperty("payment_type_id")
    private int paymentTypeId; // 1: nguoi ban tra, 2: nguoi mua tra

    @JsonProperty("note")
    private String note;

    @JsonProperty("required_note")
    private String requiredNote; // CHOTHUHANG, CHOXEMHANGKHONGTHU, KHONGCHOXEMHANG

    @JsonProperty("return_phone")
    private String returnPhone;

    @JsonProperty("return_address")
    private String returnAddress;

    @JsonProperty("return_district_id")
    private Integer returnDistrictId;

    @JsonProperty("return_ward_code")
    private String returnWardCode;

    @JsonProperty("client_order_code")
    private String clientOrderCode;

    @JsonProperty("from_name")
    private String fromName;

    @JsonProperty("from_phone")
    private String fromPhone;

    @JsonProperty("from_address")
    private String fromAddress;

    @JsonProperty("from_ward_name")
    private String fromWardName;

    @JsonProperty("from_district_name")
    private String fromDistrictName;

    @JsonProperty("from_province_name")
    private String fromProvinceName;

    @JsonProperty("to_name")
    private String toName;

    @JsonProperty("to_phone")
    private String toPhone;

    @JsonProperty("to_address")
    private String toAddress;

    @JsonProperty("to_ward_name")
    private String toWardName;

    @JsonProperty("to_district_name")
    private String toDistrictName;

    @JsonProperty("to_province_name")
    private String toProvinceName;

    @JsonProperty("cod_amount")
    private int codAmount; // Tien thu ho, 0 neu da thanh toan online

    @JsonProperty("content")
    private String content;

    @JsonProperty("weight")
    private int weight; // gram

    @JsonProperty("length")
    private int length; // cm

    @JsonProperty("width")
    private int width; // cm

    @JsonProperty("height")
    private int height; // cm

    @JsonProperty("pick_station_id")
    private Integer pickStationId;

    @JsonProperty("deliver_station_id")
    private Integer deliverStationId;

    @JsonProperty("insurance_value")
    private int insuranceValue;

    @JsonProperty("service_type_id")
    private int serviceTypeId; // 2: hang nhe, 5: hang nang

    @JsonProperty("coupon")
    private String coupon;

    @JsonProperty("pickup_time")
    private Long pickupTime;

    @JsonProperty("pick_shift")
    private List<Integer> pickShift;

    @JsonProperty("cod_failed_amount")
    private int codFailedAmount;

    @JsonProperty("items")
    private List<GhnOrderItem> items;

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class GhnOrderItem {
        @JsonProperty("name")
        private String name;

        @JsonProperty("code")
        private String code;

        @JsonProperty("quantity")
        private int quantity;

        @JsonProperty("price")
        private int price;

        @JsonProperty("length")
        private int length;

        @JsonProperty("width")
        private int width;

        @JsonProperty("height")
        private int height;

        @JsonProperty("weight")
        private int weight;

        @JsonProperty("category")
        private GhnCategory category;

        @Getter
        @Setter
        @NoArgsConstructor
        @AllArgsConstructor
        @Builder
        public static class GhnCategory {
            @JsonProperty("level1")
            private String level1;
        }
    }
}
