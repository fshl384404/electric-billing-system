package com.electric.billing.module.bill;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.entity.Bill;
import com.electric.billing.entity.House;
import com.electric.billing.entity.Meter;
import com.electric.billing.module.house.HouseMapper;
import com.electric.billing.module.meter.MeterMapper;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class BillService {

    private final BillMapper billMapper;
    private final MeterMapper meterMapper;
    private final HouseMapper houseMapper;

    public BillService(BillMapper billMapper, MeterMapper meterMapper, HouseMapper houseMapper) {
        this.billMapper = billMapper;
        this.meterMapper = meterMapper;
        this.houseMapper = houseMapper;
    }

    /** 账单列表 — 居民看自己的，管理员/收费员看全部 */
    public Map<String, Object> listAll(int page, int pageSize, String status, String billMonth) {
        if (status != null && status.isBlank()) status = null;
        if (billMonth != null && billMonth.isBlank()) billMonth = null;

        LambdaQueryWrapper<Bill> wrapper = new LambdaQueryWrapper<Bill>()
                .eq(status != null, Bill::getStatus, status)
                .eq(billMonth != null, Bill::getBillMonth, billMonth)
                .orderByDesc(Bill::getBillMonth);

        if (AuthContext.isResident()) {
            List<Meter> meters = getResidentMeters();
            if (meters.isEmpty()) {
                Map<String, Object> empty = new LinkedHashMap<>();
                empty.put("records", List.of()); empty.put("total", 0L);
                empty.put("page", page); empty.put("pageSize", pageSize);
                return empty;
            }
            List<Long> meterIds = meters.stream().map(Meter::getMeterId).toList();
            wrapper.in(Bill::getMeterId, meterIds);
        }

        Map<String, Object> result = com.electric.billing.common.PageUtils.paginate(billMapper, wrapper, page, pageSize);
        @SuppressWarnings("unchecked")
        List<Bill> bills = (List<Bill>) result.get("records");
        fillHouseAddresses(bills);
        return result;
    }

    /** 账单详情 */
    public Bill getById(Long id) {
        Bill bill = billMapper.selectById(id);
        if (bill == null) {
            throw new BusinessException("账单不存在");
        }
        if (AuthContext.isResident()) {
            Meter meter = meterMapper.selectById(bill.getMeterId());
            House house = houseMapper.selectById(meter.getHouseId());
            if (!house.getUserId().equals(AuthContext.getCurrentUserId())) {
                throw new BusinessException(403, "无权查看");
            }
        }
        fillHouseAddresses(List.of(bill));
        return bill;
    }

    /** 批量填充住宅地址 — 2 次查询替代 N×2 次 (N+1 优化) */
    private void fillHouseAddresses(List<Bill> bills) {
        if (bills.isEmpty()) return;
        try {
            // 1. 收集所有 meterId → 批量查 Meter
            Set<Long> meterIds = new HashSet<>();
            for (Bill b : bills) meterIds.add(b.getMeterId());

            List<Meter> meters = meterMapper.selectBatchIds(meterIds);
            Map<Long, Meter> meterMap = new HashMap<>();
            for (Meter m : meters) meterMap.put(m.getMeterId(), m);

            // 2. 收集所有 houseId → 批量查 House
            Set<Long> houseIds = new HashSet<>();
            for (Meter m : meters) houseIds.add(m.getHouseId());

            List<House> houses = houseMapper.selectBatchIds(houseIds);
            Map<Long, House> houseMap = new HashMap<>();
            for (House h : houses) houseMap.put(h.getHouseId(), h);

            // 3. 一次遍历填充地址
            for (Bill b : bills) {
                Meter m = meterMap.get(b.getMeterId());
                if (m != null) {
                    House h = houseMap.get(m.getHouseId());
                    if (h != null) b.setHouseAddress(h.getAddress());
                }
            }
        } catch (Exception ignored) { /* 不影响主流程 */ }
    }

    /** 获取当前居民的所有电表 */
    private List<Meter> getResidentMeters() {
        List<House> houses = houseMapper.selectList(
                new LambdaQueryWrapper<House>()
                        .eq(House::getUserId, AuthContext.getCurrentUserId())
        );
        if (houses.isEmpty()) return new ArrayList<>();
        List<Long> houseIds = houses.stream().map(House::getHouseId).toList();
        return meterMapper.selectList(
                new LambdaQueryWrapper<Meter>().in(Meter::getHouseId, houseIds)
        );
    }
}
