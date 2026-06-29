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
        LambdaQueryWrapper<Bill> wrapper = new LambdaQueryWrapper<Bill>()
                .eq(status != null, Bill::getStatus, status)
                .eq(billMonth != null, Bill::getBillMonth, billMonth)
                .orderByDesc(Bill::getBillMonth);

        if (AuthContext.isResident()) {
            // 先查居民的所有电表 ID
            List<Meter> meters = getResidentMeters();
            if (meters.isEmpty()) return new ArrayList<>();
            List<Long> meterIds = meters.stream().map(Meter::getMeterId).toList();
            wrapper.in(Bill::getMeterId, meterIds);
        }

        return billMapper.selectList(wrapper);
    }

    /** 账单详情 */
    public Bill getById(Long id) {
        Bill bill = billMapper.selectById(id);
        if (bill == null) {
            throw new BusinessException("账单不存在");
        }
        // 居民校验归属
        if (AuthContext.isResident()) {
            Meter meter = meterMapper.selectById(bill.getMeterId());
            House house = houseMapper.selectById(meter.getHouseId());
            if (!house.getUserId().equals(AuthContext.getCurrentUserId())) {
                throw new BusinessException(403, "无权查看");
            }
        }
        return bill;
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
