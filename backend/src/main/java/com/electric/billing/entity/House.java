package com.electric.billing.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.util.Date;

@Data
@TableName("HOUSE")
public class House {
    @TableId
    private Long houseId;
    private Long userId;
    private String address;
    private Double area;
    private String houseType;
    private Date createdAt;
}
