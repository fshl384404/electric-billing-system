package com.electric.billing.module.price;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.entity.PriceConfig;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PriceService {

    private final PriceMapper priceMapper;

    public PriceService(PriceMapper priceMapper) {
        this.priceMapper = priceMapper;
    }

    /** 获取当前生效电价，可按客户类型筛选 */
    public List<PriceConfig> listActive(String customerType) {
        LambdaQueryWrapper<PriceConfig> wrapper =
                new LambdaQueryWrapper<PriceConfig>()
                        .eq(PriceConfig::getIsActive, "Y");
        if (customerType != null && !customerType.isBlank()) {
            wrapper.eq(PriceConfig::getCustomerType, customerType.toUpperCase());
        }
        wrapper.orderByAsc(PriceConfig::getCustomerType, PriceConfig::getTierNo);
        return priceMapper.selectList(wrapper);
    }

    /** 更新电价 (ADMIN) */
    public PriceConfig update(PriceConfig config) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可修改电价");
        }
        PriceConfig existing = priceMapper.selectById(config.getConfigId());
        if (existing == null) {
            throw new BusinessException("电价配置不存在");
        }
        config.setUpdatedBy(AuthContext.getCurrentUserId());
        priceMapper.updateById(config);
        return config;
    }
}
