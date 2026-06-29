package com.electric.billing.module.auth;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.SysUser;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface AuthMapper extends BaseMapper<SysUser> {

    @Select("SELECT SEQ_USER_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
