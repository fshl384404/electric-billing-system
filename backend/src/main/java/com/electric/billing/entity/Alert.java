package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("ALERT")
public class Alert {
    @TableId
    private Long alertId;
    private Long meterId;
    private Long billId;
    private String type;
    private String alertLevel;
    private String description;
    private String status;
    private Long handlerId;
    private Date handledAt;
    private Date createdAt;
}
