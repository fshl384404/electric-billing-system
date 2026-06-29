package com.electric.billing.module.house;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.House;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface HouseMapper extends BaseMapper<House> {

    @Select("SELECT SEQ_HOUSE_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
