package com.electric.billing.module.meter;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.Meter;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface MeterMapper extends BaseMapper<Meter> {

    @Select("SELECT SEQ_METER_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
