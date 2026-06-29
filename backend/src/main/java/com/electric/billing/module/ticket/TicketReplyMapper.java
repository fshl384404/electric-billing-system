package com.electric.billing.module.ticket;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.TicketReply;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface TicketReplyMapper extends BaseMapper<TicketReply> {

    @Select("SELECT SEQ_REPLY_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
