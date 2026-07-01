package com.electric.billing.module.reading;

import com.electric.billing.common.BusinessException;
import com.electric.billing.common.R;
import com.electric.billing.entity.MeterReading;
import com.electric.billing.security.AuthContext;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.util.Date;
import java.util.List;

@RestController
@RequestMapping("/api/reading")
public class ReadingController {

    private final ReadingService readingService;

    public ReadingController(ReadingService readingService) {
        this.readingService = readingService;
    }

    /** 抄表记录查询 */
    @GetMapping("/list")
    public R<List<MeterReading>> list(
            @RequestParam Long meterId,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") Date startDate,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") Date endDate) {
        return R.ok(readingService.listByMeter(meterId, startDate, endDate));
    }

    /** 人工录入抄表 (管理员/收费员) */
    @PostMapping
    public R<MeterReading> create(@RequestBody MeterReading reading) {
        if (!AuthContext.isAdmin() && !AuthContext.isCollector()) {
            throw new BusinessException(403, "仅管理员和收费员可录入抄表");
        }
        return R.ok(readingService.create(reading));
    }
}
