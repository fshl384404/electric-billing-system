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

import java.util.ArrayList;
import java.util.List;

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
    public List<Bill> listAll(String status, String billMonth) {
        // 空字符串视为 null，避免误过滤
        if (status != null && status.isBlank()) status = null;
        if (billMonth != null && billMonth.isBlank()) billMonth = null;

        LambdaQueryWrapper<Bill> wrapper = new LambdaQueryWrapper<Bill>()
                .eq(status != null, Bill::getStatus, status)
                .eq(billMonth != null, Bill::getBillMonth, billMonth)
                .orderByDesc(Bill::getBillMonth);

        if (AuthContext.isResident()) {
            List<Meter> meters = getResidentMeters();
            if (meters.isEmpty()) return new ArrayList<>();
            List<Long> meterIds = meters.stream().map(Meter::getMeterId).toList();
            wrapper.in(Bill::getMeterId, meterIds);
        }

        List<Bill> bills = billMapper.selectList(wrapper);
        // 填充住宅地址
        for (Bill bill : bills) {
            fillHouseAddress(bill);
        }
        return bills;
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
        fillHouseAddress(bill);
        return bill;
    }

    /** 通过 meter → house 填充账单的住宅地址 */
    private void fillHouseAddress(Bill bill) {
        try {
            Meter meter = meterMapper.selectById(bill.getMeterId());
            if (meter != null) {
                House house = houseMapper.selectById(meter.getHouseId());
                if (house != null) {
                    bill.setHouseAddress(house.getAddress());
                }
            }
        } catch (Exception ignored) { /* 地址查询失败不影响主流程 */ }
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
