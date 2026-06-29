package com.electric.billing.module.bill;

import com.electric.billing.common.R;
import com.electric.billing.entity.Bill;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/bill")
public class BillController {

    private final BillService billService;

    public BillController(BillService billService) {
        this.billService = billService;
    }

    @GetMapping("/list")
    public R<List<Bill>> list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String billMonth) {
        return R.ok(billService.listAll(status, billMonth));
    }

    @GetMapping("/{id}")
    public R<Bill> get(@PathVariable Long id) {
        return R.ok(billService.getById(id));
    }
}
