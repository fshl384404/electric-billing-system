package com.electric.billing.module.alert;

import com.electric.billing.common.R;
import com.electric.billing.entity.Alert;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/alert")
public class AlertController {

    private final AlertService alertService;
    public AlertController(AlertService alertService) { this.alertService = alertService; }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(required = false) String status) {
        return R.ok(alertService.listAll(page, pageSize, status));
    }

    @PutMapping("/{id}/handle") public R<?> handle(@PathVariable Long id) { alertService.handle(id); return R.ok(); }
}
