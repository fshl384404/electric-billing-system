package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("PAYMENT")
public class Payment {
    @TableId
    private Long paymentId;
    private Long billId;
    private Double amount;
    private Double lateFeePaid;
    private String channel;
    private Long payerId;
    private Long collectorId;
    private Date paymentTime;
    private String transactionNo;
    private Date createdAt;
}
