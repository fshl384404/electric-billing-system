package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("TICKET_REPLY")
public class TicketReply {
    @TableId
    private Long replyId;
    private Long ticketId;
    private Long replierId;
    private String content;
    private Date createdAt;
}
