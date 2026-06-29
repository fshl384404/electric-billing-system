package com.electric.billing.module.price;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.PriceConfig;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface PriceMapper extends BaseMapper<PriceConfig> {

    @Select("SELECT SEQ_PRICE_CONFIG_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
