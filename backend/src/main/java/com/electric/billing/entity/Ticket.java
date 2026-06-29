package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("TICKET")
public class Ticket {
    @TableId
    private Long ticketId;
    private Long userId;
    private String type;
    private String title;
    private String description;
    private String status;
    private Date createdAt;
    private Date repliedAt;
    private Long repliedBy;
}
