package com.electric.billing.module.price;

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

    /** 获取当前生效电价 (is_active='Y') */
    public List<PriceConfig> listActive() {
        return priceMapper.selectList(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<PriceConfig>()
                        .eq(PriceConfig::getIsActive, "Y")
                        .orderByAsc(PriceConfig::getTierNo)
        );
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
