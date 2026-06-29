package com.electric.billing.module.notification;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.Notification;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface NotifMapper extends BaseMapper<Notification> {

    @Select("SELECT SEQ_NOTIF_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
