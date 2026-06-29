package com.electric.billing.module.meter;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.Meter;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.Map;

@Service
public class MeterService {

    private final MeterMapper meterMapper;

    public MeterService(MeterMapper meterMapper) {
        this.meterMapper = meterMapper;
    }

    /** 电表列表 */
    public Map<String, Object> listAll(int page, int pageSize) {
        return PageUtils.paginate(meterMapper,
            new LambdaQueryWrapper<Meter>().orderByAsc(Meter::getMeterId), page, pageSize);
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

    /** 更新电表状态 (故障/拆除) */
    public void updateStatus(Long id, String status) {
        Meter meter = meterMapper.selectById(id);
        if (meter == null) {
            throw new BusinessException("电表不存在");
        }
        meter.setStatus(status);
        meterMapper.updateById(meter);
    }

    /** 删除电表 */
    public void delete(Long id) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        meterMapper.deleteById(id);
    }
}
