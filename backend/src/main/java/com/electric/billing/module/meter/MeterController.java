package com.electric.billing.module.meter;

import com.electric.billing.common.R;
import com.electric.billing.entity.Meter;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/meter")
public class MeterController {

    private final MeterService meterService;

    public MeterController(MeterService meterService) {
        this.meterService = meterService;
    }

    @GetMapping("/list")
    public R<List<Meter>> list() {
        return R.ok(meterService.listAll());
    }

    @GetMapping("/{id}")
    public R<Meter> get(@PathVariable Long id) {
        return R.ok(meterService.getById(id));
    }

    @PostMapping
    public R<Meter> create(@RequestBody Meter meter) {
        return R.ok(meterService.create(meter));
    }

    @PutMapping
    public R<Meter> update(@RequestBody Meter meter) {
        return R.ok(meterService.update(meter));
    }

    @PutMapping("/{id}/status")
    public R<?> updateStatus(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String status = body.get("status");
        if (status == null) {
            return R.fail("状态不能为空");
        }
        meterService.updateStatus(id, status);
        return R.ok();
    }
}
