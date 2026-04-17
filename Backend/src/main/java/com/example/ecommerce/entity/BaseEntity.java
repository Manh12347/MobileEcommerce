package com.example.ecommerce.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@MappedSuperclass
@Getter
@Setter
public abstract class BaseEntity {

    @Column(name = "created_on")
    protected LocalDateTime createdOn;

    @Column(name = "modified_on")
    protected LocalDateTime modifiedOn;
}
