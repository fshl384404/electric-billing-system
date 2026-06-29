package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;
import java.util.Date;

@Data
@TableName("METER")
public class Meter {
    @TableId
    private Long meterId;
    private Long houseId;
    private String meterNo;
    private String model;
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date installDate;
    private Double initialReading;
    private Double lastReading;
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date lastReadingDate;
    private String status;
    private Date createdAt;
}
