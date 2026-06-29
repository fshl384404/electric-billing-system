package com.electric.billing.module.reading;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.entity.MeterReading;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

@Service
public class ReadingService {

    private final ReadingMapper readingMapper;

    public ReadingService(ReadingMapper readingMapper) {
        this.readingMapper = readingMapper;
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
}
