package com.electric.billing.common;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 分页工具 — 基于 Oracle OFFSET...FETCH 语法
 */
public class PageUtils {

    /**
     * 执行分页查询，返回统一格式
     */
    public static <T> Map<String, Object> paginate(
            BaseMapper<T> mapper,
            LambdaQueryWrapper<T> wrapper,
            int page, int pageSize) {

        // 1. 计数
        long total = mapper.selectCount(wrapper);

        // 2. 分页查询 (Oracle 12c+)
        int offset = (page - 1) * pageSize;
        wrapper.last("OFFSET " + offset + " ROWS FETCH NEXT " + pageSize + " ROWS ONLY");
        List<T> records = mapper.selectList(wrapper);

        // 3. 组装返回
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("records", records);
        result.put("total", total);
        result.put("page", page);
        result.put("pageSize", pageSize);
        return result;
    }

    /** 默认每页 10 条 */
    public static <T> Map<String, Object> paginate(
            BaseMapper<T> mapper,
            LambdaQueryWrapper<T> wrapper,
            int page) {
        return paginate(mapper, wrapper, page, 10);
    }
}
