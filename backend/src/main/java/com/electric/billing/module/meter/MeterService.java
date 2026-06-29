package com.electric.billing.module.meter;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.entity.Meter;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

@Service
public class MeterService {

    private final MeterMapper meterMapper;

    public MeterService(MeterMapper meterMapper) {
        this.meterMapper = meterMapper;
    }

    /** 电表列表 */
    public List<Meter> listAll() {
        return meterMapper.selectList(null);
    }

    /** 电表详情 */
    public Meter getById(Long id) {
        Meter meter = meterMapper.selectById(id);
        if (meter == null) {
            throw new BusinessException("电表不存在");
        }
        return meter;
    }

    /** 新增电表 (ADMIN) — 一宅一表校验 */
    public Meter create(Meter meter) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        // 一宅一表校验
        Long count = meterMapper.selectCount(
                new LambdaQueryWrapper<Meter>().eq(Meter::getHouseId, meter.getHouseId())
        );
        if (count > 0) {
            throw new BusinessException("该房产已绑定电表，每户只能安装一个电表");
        }
        meter.setMeterId(meterMapper.nextId());
        if (meter.getStatus() == null) meter.setStatus("NORMAL");
        meter.setCreatedAt(new Date());
        meterMapper.insert(meter);
        return meter;
    }

    /** 更新电表信息 */
    public Meter update(Meter meter) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        Meter existing = meterMapper.selectById(meter.getMeterId());
        if (existing == null) {
            throw new BusinessException("电表不存在");
        }
        meter.setCreatedAt(existing.getCreatedAt());
        meterMapper.updateById(meter);
        return meter;
    }

    /** 更新电表状态 (故障/拆除) */
    public void updateStatus(Long id, String status) {
        Meter meter = meterMapper.selectById(id);
        if (meter == null) {
            throw new BusinessException("电表不存在");
        }
        meter.setStatus(status);
        meterMapper.updateById(meter);
    }
}
