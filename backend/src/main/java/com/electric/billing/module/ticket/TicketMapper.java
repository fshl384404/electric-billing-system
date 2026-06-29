package com.electric.billing.module.ticket;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.Ticket;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface TicketMapper extends BaseMapper<Ticket> {

    @Select("SELECT SEQ_TICKET_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
