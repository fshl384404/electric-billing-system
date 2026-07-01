package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;
import java.util.Date;

@Data
@TableName("METER_READING")
public class MeterReading {
    @TableId
    private Long readingId;
    private Long meterId;
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date readingDate;
    private Double readingValue;
    private Double dailyUsage;
    private String readingType;
    private String remarks;
    private Date createdAt;
}
