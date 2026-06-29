package com.electric.billing.module.price;

import com.electric.billing.common.R;
import com.electric.billing.entity.PriceConfig;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/price")
public class PriceController {

    private final PriceService priceService;

    public PriceController(PriceService priceService) {
        this.priceService = priceService;
    }

    @GetMapping("/list")
    public R<List<PriceConfig>> list() {
        return R.ok(priceService.listActive());
    }

    @PutMapping
    public R<PriceConfig> update(@RequestBody PriceConfig config) {
        return R.ok(priceService.update(config));
    }
}
