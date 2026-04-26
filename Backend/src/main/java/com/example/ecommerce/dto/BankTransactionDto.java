package com.example.ecommerce.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
@JsonIgnoreProperties(ignoreUnknown = true)
public class BankTransactionDto {
    private String gateway;
    
    @JsonProperty("transactiondate")
    @JsonAlias({"transactionDate", "TransactionDate"})
    private String transactiondate;
    
    @JsonProperty("accountnumber")
    private String accountnumber;
    
    @JsonProperty("subaccount")
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
