package com.electric.billing.module.reading;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.entity.Meter;
import com.electric.billing.entity.MeterReading;
import com.electric.billing.module.meter.MeterMapper;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

@Service
public class ReadingService {

    private final ReadingMapper readingMapper;
    private final MeterMapper meterMapper;

    public ReadingService(ReadingMapper readingMapper, MeterMapper meterMapper) {
        this.readingMapper = readingMapper;
        this.meterMapper = meterMapper;
    }

    /** 按电表 + 日期范围查询抄表记录，按日期升序 */
    public List<MeterReading> listByMeter(Long meterId, Date startDate, Date endDate) {
        LambdaQueryWrapper<MeterReading> wrapper = new LambdaQueryWrapper<MeterReading>()
                .eq(MeterReading::getMeterId, meterId)
                .ge(startDate != null, MeterReading::getReadingDate, startDate)
                .le(endDate != null, MeterReading::getReadingDate, endDate)
                .orderByAsc(MeterReading::getReadingDate);
        return readingMapper.selectList(wrapper);
    }

    /** 人工录入抄表读数。日用量/倒转检测/电表快照由触发器自动处理 */
    public MeterReading create(MeterReading reading) {
        // 校验电表存在且正常
        Meter meter = meterMapper.selectById(reading.getMeterId());
        if (meter == null) {
            throw new BusinessException("电表不存在");
        }
        if (!"NORMAL".equals(meter.getStatus())) {
            throw new BusinessException("电表状态异常（" + meter.getStatus() + "），无法录入抄表");
        }

        // 校验读数
        if (reading.getReadingValue() == null || reading.getReadingValue() <= 0) {
            throw new BusinessException("抄表读数必须大于0");
        }

        // 校验日期
        if (reading.getReadingDate() == null) {
            reading.setReadingDate(new Date());
        }
        if (reading.getReadingDate().after(new Date())) {
            throw new BusinessException("抄表日期不能超过今天");
        }

        // 检查是否已有同日抄表记录
        Date d = reading.getReadingDate();
        java.util.Calendar cal = java.util.Calendar.getInstance();
        cal.setTime(d);
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0);
        cal.set(java.util.Calendar.MINUTE, 0);
        cal.set(java.util.Calendar.SECOND, 0);
        Date dayStart = cal.getTime();
        cal.add(java.util.Calendar.DAY_OF_MONTH, 1);
        Date dayEnd = cal.getTime();

        Long dupCount = readingMapper.selectCount(
            new LambdaQueryWrapper<MeterReading>()
                .eq(MeterReading::getMeterId, reading.getMeterId())
                .ge(MeterReading::getReadingDate, dayStart)
                .lt(MeterReading::getReadingDate, dayEnd)
        );
        if (dupCount > 0) {
            throw new BusinessException("该电表当日已有抄表记录，请勿重复录入");
        }

        // 显式从序列获取 ID（避免 MyBatis-Plus 传 NULL 导致 Oracle JDBC 报错）
        reading.setReadingId(readingMapper.nextId());
        reading.setReadingType("MANUAL");
        reading.setCreatedAt(new Date());
        // daily_usage 由 TR1 自动计算
        readingMapper.insert(reading);
        return reading;
    }
}
