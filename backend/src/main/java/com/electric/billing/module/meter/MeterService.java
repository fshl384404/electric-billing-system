package com.electric.billing.module.meter;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.*;
import com.electric.billing.module.alert.AlertMapper;
import com.electric.billing.module.bill.BillMapper;
import com.electric.billing.module.payment.PaymentMapper;
import com.electric.billing.module.reading.ReadingMapper;
import com.electric.billing.security.AuthContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;
import java.util.Map;

@Service
public class MeterService {

    private static final Logger log = LoggerFactory.getLogger(MeterService.class);

    private final MeterMapper meterMapper;
    private final ReadingMapper readingMapper;
    private final BillMapper billMapper;
    private final PaymentMapper paymentMapper;
    private final AlertMapper alertMapper;

    public MeterService(MeterMapper meterMapper, ReadingMapper readingMapper,
                        BillMapper billMapper, PaymentMapper paymentMapper,
                        AlertMapper alertMapper) {
        this.meterMapper = meterMapper;
        this.readingMapper = readingMapper;
        this.billMapper = billMapper;
        this.paymentMapper = paymentMapper;
        this.alertMapper = alertMapper;
    }

    /** 电表列表 */
    public Map<String, Object> listAll(int page, int pageSize) {
        return PageUtils.paginate(meterMapper,
            new LambdaQueryWrapper<Meter>().orderByAsc(Meter::getMeterId), page, pageSize);
    }

    /** 电表详情 */
    public Meter getById(Long id) {
        Meter meter = meterMapper.selectById(id);
        if (meter == null) {
            throw new BusinessException("电表不存在");
        }
        return meter;
    }

    /** 新增电表 (ADMIN) — 一宅一表校验 */
    public Meter create(Meter meter) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        // 一宅一表校验
        Long count = meterMapper.selectCount(
                new LambdaQueryWrapper<Meter>().eq(Meter::getHouseId, meter.getHouseId())
        );
        if (count > 0) {
            throw new BusinessException("该房产已绑定电表，每户只能安装一个电表");
        }
        meter.setMeterId(meterMapper.nextId());
        if (meter.getStatus() == null) meter.setStatus("NORMAL");
        meter.setCreatedAt(new Date());
        meterMapper.insert(meter);
        return meter;
    }

    /** 更新电表状态 (故障/拆除) */
    public void updateStatus(Long id, String status) {
        Meter meter = meterMapper.selectById(id);
        if (meter == null) {
            throw new BusinessException("电表不存在");
        }
        meter.setStatus(status);
        meterMapper.updateById(meter);
    }

    /**
     * 删除电表 — 级联删除抄表记录、账单、缴费、告警。
     * 依赖链: METER → READING / BILL → PAYMENT / ALERT
     */
    public void delete(Long id) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        Meter meter = meterMapper.selectById(id);
        if (meter == null) {
            throw new BusinessException("电表不存在");
        }

        // 1. 删除抄表记录
        int rc = readingMapper.delete(
                new LambdaQueryWrapper<MeterReading>().eq(MeterReading::getMeterId, id));
        log.info("Deleted {} readings for meter {}", rc, id);

        // 2. 删除账单 (先删关联的缴费和告警)
        List<Bill> bills = billMapper.selectList(
                new LambdaQueryWrapper<Bill>().eq(Bill::getMeterId, id));
        for (Bill bill : bills) {
            paymentMapper.delete(
                    new LambdaQueryWrapper<Payment>().eq(Payment::getBillId, bill.getBillId()));
            alertMapper.delete(
                    new LambdaQueryWrapper<Alert>().eq(Alert::getBillId, bill.getBillId()));
        }
        int bc = billMapper.delete(
                new LambdaQueryWrapper<Bill>().eq(Bill::getMeterId, id));
        log.info("Deleted {} bills for meter {}", bc, id);

        // 3. 删除电表直接关联的告警
        int ac = alertMapper.delete(
                new LambdaQueryWrapper<Alert>().eq(Alert::getMeterId, id));
        if (ac > 0) log.info("Deleted {} alerts for meter {}", ac, id);

        // 4. 删除电表
        meterMapper.deleteById(id);
        log.info("Deleted meter {} (meterNo={})", id, meter.getMeterNo());
    }
}
