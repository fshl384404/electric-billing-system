package com.electric.billing.module.reading;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.MeterReading;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface ReadingMapper extends BaseMapper<MeterReading> {
}
