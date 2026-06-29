package com.electric.billing.module.bill;

import com.electric.billing.common.R;
import com.electric.billing.entity.Bill;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/bill")
public class BillController {

    private final BillService billService;

    public BillController(BillService billService) {
        this.billService = billService;
    }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String billMonth) {
        return R.ok(billService.listAll(page, pageSize, status, billMonth));
    }

    @GetMapping("/{id}")
    public R<Bill> get(@PathVariable Long id) {
        return R.ok(billService.getById(id));
    }
}
