package com.electric.billing.module.reading;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.MeterReading;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface ReadingMapper extends BaseMapper<MeterReading> {

    @Select("SELECT SEQ_READING_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
