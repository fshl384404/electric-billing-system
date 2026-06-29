package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("PRICE_CONFIG")
public class PriceConfig {
    @TableId
    private Long configId;
    private Integer tierNo;
    private String tierName;
    private Double lowerLimit;
    private Double upperLimit;
    private Double unitPrice;
    private Date effectiveDate;
    private String isActive;
    private Long updatedBy;
    private Date createdAt;
}
