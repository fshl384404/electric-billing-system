package com.electric.billing.module.bill;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.Bill;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface BillMapper extends BaseMapper<Bill> {
}
