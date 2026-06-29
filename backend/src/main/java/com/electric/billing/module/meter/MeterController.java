package com.electric.billing.module.meter;

import com.electric.billing.common.R;
import com.electric.billing.entity.Meter;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/meter")
public class MeterController {

    private final MeterService meterService;
    public MeterController(MeterService meterService) { this.meterService = meterService; }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize) {
        return R.ok(meterService.listAll(page, pageSize));
    }

    @GetMapping("/{id}") public R<Meter> get(@PathVariable Long id) { return R.ok(meterService.getById(id)); }
    @PostMapping public R<Meter> create(@RequestBody Meter meter) { return R.ok(meterService.create(meter)); }
    @PutMapping("/{id}/status") public R<?> updateStatus(@PathVariable Long id, @RequestBody Map<String, String> body) { meterService.updateStatus(id, body.get("status")); return R.ok(); }
    @DeleteMapping("/{id}") public R<?> delete(@PathVariable Long id) { meterService.delete(id); return R.ok(); }
}
