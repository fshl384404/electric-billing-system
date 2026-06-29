package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("BILL")
public class Bill {
    @TableId
    private Long billId;
    private Long meterId;
    private String billMonth;
    private Double prevReading;
    private Double currReading;
    private Double totalUsage;
    private Double tier1Usage;
    private Double tier2Usage;
    private Double tier3Usage;
    private Double tier1Amount;
    private Double tier2Amount;
    private Double tier3Amount;
    private Double totalAmount;
    private Double lateFee;
    private String status;
    private Date dueDate;
    private Date paymentDate;
    private Date createdAt;

    // 非数据库字段 — 前端展示用
    @TableField(exist = false)
    private String houseAddress;
}
