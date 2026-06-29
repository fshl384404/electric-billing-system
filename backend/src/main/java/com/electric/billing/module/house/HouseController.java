package com.electric.billing.module.house;

import com.electric.billing.common.R;
import com.electric.billing.entity.House;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/house")
public class HouseController {

    private final HouseService houseService;
    public HouseController(HouseService houseService) { this.houseService = houseService; }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize) {
        return R.ok(houseService.listAll(page, pageSize));
    }

    @GetMapping("/{id}") public R<House> get(@PathVariable Long id) { return R.ok(houseService.getById(id)); }
    @PostMapping public R<House> create(@RequestBody House house) { return R.ok(houseService.create(house)); }
    @PutMapping public R<House> update(@RequestBody House house) { return R.ok(houseService.update(house)); }
    @DeleteMapping("/{id}") public R<?> delete(@PathVariable Long id) { houseService.delete(id); return R.ok(); }
}
