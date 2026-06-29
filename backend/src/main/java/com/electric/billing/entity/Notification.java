package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("NOTIFICATION")
public class Notification {
    @TableId
    private Long notifId;
    private Long userId;
    private String type;
    private String title;
    private String content;
    private Long relatedId;
    private String isRead;
    private Date createdAt;
}
