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
    @JsonAlias({"gateway", "Gateway"})
    private String gateway;
    
    @JsonProperty("transactiondate")
    @JsonAlias({"transactionDate", "TransactionDate"})
    private String transactiondate;
    
    @JsonProperty("accountnumber")
    @JsonAlias({"accountNumber", "AccountNumber"})
    private String accountnumber;
    
    @JsonProperty("subaccount")
    @JsonAlias({"subAccount", "SubAccount"})
    private String subaccount;
    
    @JsonAlias({"code", "Code"})
    private String code;
    
    @JsonAlias({"content", "Content"})
    private String content;
    
    @JsonProperty("transfertype")
    @JsonAlias({"transferType", "TransferType"})
    private String transfertype;
    
    @JsonProperty("transferamount")
    @JsonAlias({"transferAmount", "TransferAmount"})
    private BigDecimal transferamount;
    
    @JsonAlias({"accumulated", "Accumulated"})
    private BigDecimal accumulated;
    
    @JsonProperty("referencecode")
    @JsonAlias({"referenceCode", "ReferenceCode"})
    private String referencecode;
    
    @JsonAlias({"description", "Description"})
    private String description;
}
