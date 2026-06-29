package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("SYS_USER")
public class SysUser {
    @TableId
    private Long userId;
    private String username;
    private String passwordHash;
    private String realName;
    private String role;
    private String phone;
    private String email;
    private String idCard;
    private String status;
    private Date createdAt;
    private Date updatedAt;
}
