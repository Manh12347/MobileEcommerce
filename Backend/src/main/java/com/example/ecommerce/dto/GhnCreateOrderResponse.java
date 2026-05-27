package com.example.ecommerce.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GhnCreateOrderResponse {

    @JsonProperty("code")
    private int code;

    @JsonProperty("message")
    private String message;

    @JsonProperty("data")
    private GhnOrderData data;

    public boolean isSuccess() {
        return code == 200;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class GhnOrderData {
        @JsonProperty("order_code")
        private String orderCode;

        @JsonProperty("sort_code")
        private String sortCode;

        @JsonProperty("trans_type")
        private String transType;

        @JsonProperty("ward_encode")
        private String wardEncode;

        @JsonProperty("district_encode")
        private String districtEncode;

        @JsonProperty("fee")
        private GhnFee fee;

        @JsonProperty("total_fee")
        private int totalFee;

        @JsonProperty("expected_delivery_time")
        private String expectedDeliveryTime;

        @JsonProperty("message_display")
        private String messageDisplay;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class GhnFee {
        @JsonProperty("main_service")
        private int mainService;

        @JsonProperty("insurance")
        private int insurance;

        @JsonProperty("station_do")
        private int stationDo;

        @JsonProperty("station_pu")
        private int stationPu;

        @JsonProperty("return")
        private int returnFee;

        @JsonProperty("r2s")
        private int r2s;

        @JsonProperty("coupon")
        private int coupon;

        @JsonProperty("cod_failed_fee")
        private int codFailedFee;
    }
}
