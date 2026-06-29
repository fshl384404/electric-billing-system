package com.electric.billing.module.user;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.electric.billing.entity.SysUser;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface UserMapper extends BaseMapper<SysUser> {

    @Select("SELECT SEQ_USER_ID.NEXTVAL FROM DUAL")
    Long nextId();
}
