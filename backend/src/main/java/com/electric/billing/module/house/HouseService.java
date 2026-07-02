package com.electric.billing.module.house;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.*;
import com.electric.billing.module.alert.AlertMapper;
import com.electric.billing.module.bill.BillMapper;
import com.electric.billing.module.meter.MeterMapper;
import com.electric.billing.module.payment.PaymentMapper;
import com.electric.billing.module.reading.ReadingMapper;
import com.electric.billing.module.user.UserMapper;
import com.electric.billing.security.AuthContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Date;
import java.util.List;
import java.util.Map;

@Service
public class HouseService {

    private static final Logger log = LoggerFactory.getLogger(HouseService.class);

    private final HouseMapper houseMapper;
    private final MeterMapper meterMapper;
    private final ReadingMapper readingMapper;
    private final BillMapper billMapper;
    private final PaymentMapper paymentMapper;
    private final AlertMapper alertMapper;
    private final UserMapper userMapper;

    public HouseService(HouseMapper houseMapper, MeterMapper meterMapper,
                        ReadingMapper readingMapper, BillMapper billMapper,
                        PaymentMapper paymentMapper, AlertMapper alertMapper,
                        UserMapper userMapper) {
        this.houseMapper = houseMapper;
        this.meterMapper = meterMapper;
        this.readingMapper = readingMapper;
        this.billMapper = billMapper;
        this.paymentMapper = paymentMapper;
        this.alertMapper = alertMapper;
        this.userMapper = userMapper;
    }

    /** 房产列表 — 居民只能看自己的 */
    public Map<String, Object> listAll(int page, int pageSize) {
        LambdaQueryWrapper<House> wrapper = new LambdaQueryWrapper<House>()
                .orderByAsc(House::getHouseId);
        if (AuthContext.isResident()) {
            wrapper.eq(House::getUserId, AuthContext.getCurrentUserId());
        }
        return PageUtils.paginate(houseMapper, wrapper, page, pageSize);
    }

    /** 房产详情 */
    public House getById(Long id) {
        House house = houseMapper.selectById(id);
        if (house == null) {
            throw new BusinessException("房产不存在");
        }
        if (AuthContext.isResident() && !house.getUserId().equals(AuthContext.getCurrentUserId())) {
            throw new BusinessException(403, "无权查看");
        }
        return house;
    }

    /** 新增房产 — 仅 RESIDENT 角色可作为业主 */
    public House create(House house) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        if (house.getUserId() == null) {
            throw new BusinessException("业主ID不能为空");
        }
        // 校验业主角色必须为 RESIDENT
        SysUser owner = userMapper.selectById(house.getUserId());
        if (owner == null) {
            throw new BusinessException("业主不存在");
        }
        if (!"RESIDENT".equals(owner.getRole())) {
            throw new BusinessException("仅居民用户可作为业主，管理员和收费员不可拥有房产");
        }
        house.setHouseId(houseMapper.nextId());
        house.setCreatedAt(new Date());
        houseMapper.insert(house);
        return house;
    }

    /**
     * 删除房产 — 级联删除电表及其关联数据。
     * 依赖链: HOUSE → METER → READING / BILL → PAYMENT / ALERT
     */
    @Transactional
    public void delete(Long id) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        House house = houseMapper.selectById(id);
        if (house == null) {
            throw new BusinessException("房产不存在");
        }

        // 1. 查找该房产下所有电表
        List<Meter> meters = meterMapper.selectList(
                new LambdaQueryWrapper<Meter>().eq(Meter::getHouseId, id));

        for (Meter meter : meters) {
            Long meterId = meter.getMeterId();

            // 2. 删除该电表的抄表记录
            int rc = readingMapper.delete(
                    new LambdaQueryWrapper<MeterReading>().eq(MeterReading::getMeterId, meterId));
            log.info("Cascade delete {} readings for meter {}", rc, meterId);

            // 3. 删除该电表的账单 (先删关联的缴费和告警)
            List<Bill> bills = billMapper.selectList(
                    new LambdaQueryWrapper<Bill>().eq(Bill::getMeterId, meterId));
            for (Bill bill : bills) {
                // 删除关联缴费
                int pc = paymentMapper.delete(
                        new LambdaQueryWrapper<Payment>().eq(Payment::getBillId, bill.getBillId()));
                // 删除关联告警
                int ac = alertMapper.delete(
                        new LambdaQueryWrapper<Alert>().eq(Alert::getBillId, bill.getBillId()));
                if (pc > 0 || ac > 0) {
                    log.info("Cascade delete {} payments + {} alerts for bill {}", pc, ac, bill.getBillId());
                }
            }
            // 批量删除账单
            int bc = billMapper.delete(
                    new LambdaQueryWrapper<Bill>().eq(Bill::getMeterId, meterId));
            log.info("Cascade delete {} bills for meter {}", bc, meterId);

            // 4. 删除电表相关的告警 (不关联账单的)
            int ac2 = alertMapper.delete(
                    new LambdaQueryWrapper<Alert>().eq(Alert::getMeterId, meterId));
            if (ac2 > 0) log.info("Cascade delete {} alerts for meter {}", ac2, meterId);

            // 5. 删除电表
            meterMapper.deleteById(meterId);
            log.info("Deleted meter {}", meterId);
        }

        // 6. 删除房产
        houseMapper.deleteById(id);
        log.info("Deleted house {}: {}", id, house.getAddress());
    }

}
