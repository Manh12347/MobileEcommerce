package com.example.ecommerce.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class BankTransactionDto {
    private String gateway;
    
    @JsonProperty("transactiondate")
    private String transactiondate;
    
    @JsonProperty("accountnumber")
    private String accountnumber;
    
    private String subaccount;
    private String code;
    private String content;
    
    @JsonProperty("transfertype")
    private String transfertype;
    
    @JsonProperty("transferamount")
    private BigDecimal transferamount;
    
    private BigDecimal accumulated;
    
    @JsonProperty("referencecode")
    private String referencecode;
    
    private String description;
}
