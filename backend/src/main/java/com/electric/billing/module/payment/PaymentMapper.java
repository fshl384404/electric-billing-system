package com.electric.billing.module.payment;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.Payment;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface PaymentMapper extends BaseMapper<Payment> {

    @Select("SELECT SEQ_PAYMENT_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
