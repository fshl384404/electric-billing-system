package com.electric.billing.module.payment;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.*;
import com.electric.billing.module.bill.BillMapper;
import com.electric.billing.module.meter.MeterMapper;
import com.electric.billing.module.house.HouseMapper;
import com.electric.billing.entity.Notification;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Map;

@Service
public class PaymentService {

    private final PaymentMapper paymentMapper;
    private final BillMapper billMapper;
    private final MeterMapper meterMapper;
    private final HouseMapper houseMapper;
    private final com.electric.billing.module.notification.NotifMapper notifMapper;

    public PaymentService(PaymentMapper paymentMapper, BillMapper billMapper,
                          MeterMapper meterMapper, HouseMapper houseMapper,
                          com.electric.billing.module.notification.NotifMapper notifMapper) {
        this.paymentMapper = paymentMapper;
        this.billMapper = billMapper;
        this.meterMapper = meterMapper;
        this.houseMapper = houseMapper;
        this.notifMapper = notifMapper;
    }

    /**
     * 缴费 — 事务原子操作: insert payment → update bill → insert notification
     */
    @Transactional
    public Payment pay(Payment payment) {
        // 1. 校验账单
        Bill bill = billMapper.selectById(payment.getBillId());
        if (bill == null) {
            throw new BusinessException("账单不存在");
        }
        if ("PAID".equals(bill.getStatus())) {
            throw new BusinessException("该账单已缴费");
        }

        // 2. 线上缴费：校验缴费人是否为账单所属居民
        if ("ONLINE".equals(payment.getChannel())) {
            if (!AuthContext.isResident() && !AuthContext.isAdmin()) {
                throw new BusinessException("仅居民可进行线上缴费");
            }
            // 校验缴费人是否拥有该电表
            if (AuthContext.isResident()) {
                Meter meter = meterMapper.selectById(bill.getMeterId());
                House house = houseMapper.selectById(meter.getHouseId());
                if (!house.getUserId().equals(AuthContext.getCurrentUserId())) {
                    throw new BusinessException(403, "无权为此账单缴费");
                }
            }
            payment.setPayerId(AuthContext.getCurrentUserId());
        }

        // 3. 线下缴费：收款人必须为收费员
        if ("OFFLINE".equals(payment.getChannel())) {
            if (!AuthContext.isAdmin() && !AuthContext.isCollector()) {
                throw new BusinessException("仅管理员/收费员可录入线下缴费");
            }
            if (payment.getPayerId() == null) {
                throw new BusinessException("线下缴费需指定缴费人");
            }
            payment.setCollectorId(AuthContext.getCurrentUserId());
        }

        // 4. 生成流水号
        String txnNo = "TXN-" + new SimpleDateFormat("yyyyMMdd").format(new Date())
                + "-" + String.format("%06d", (int)(Math.random() * 1000000));
        payment.setTransactionNo(txnNo);

        // 5. 滞纳金：如果已逾期，自动计算
        if ("OVERDUE".equals(bill.getStatus()) && bill.getLateFee() > 0) {
            payment.setLateFeePaid(bill.getLateFee());
            payment.setAmount(payment.getAmount() + bill.getLateFee());
        } else {
            payment.setLateFeePaid(0.0);
        }

        // 6. 设置缴费时间
        payment.setPaymentTime(new Date());
        payment.setPaymentId(paymentMapper.nextId());
        payment.setCreatedAt(new Date());
        paymentMapper.insert(payment);

        // 7. 更新账单状态
        bill.setStatus("PAID");
        bill.setPaymentDate(new Date());
        billMapper.updateById(bill);

        // 8. 发送缴费确认通知
        Notification notif = new Notification();
        notif.setNotifId(notifMapper.nextId());
        notif.setUserId(payment.getPayerId());
        notif.setType("PAYMENT_CONFIRM");
        notif.setTitle("缴费成功");
        notif.setContent("您的账单 " + bill.getBillMonth()
                + " 已缴费成功，金额: " + payment.getAmount() + " 元");
        notif.setRelatedId(bill.getBillId());
        notif.setIsRead("N");
        notif.setCreatedAt(new Date());
        notifMapper.insert(notif);

        return payment;
    }

    /** 缴费记录列表 — 居民只看自己的，管理员看全部或按账单筛选 */
    public Map<String, Object> listByBill(int page, int pageSize, Long billId) {
        LambdaQueryWrapper<Payment> wrapper = new LambdaQueryWrapper<Payment>()
                .orderByDesc(Payment::getPaymentTime);
        if (billId != null) {
            wrapper.eq(Payment::getBillId, billId);
        } else if (AuthContext.isResident()) {
            // 居民：只看自己的缴费记录（通过 payer_id）
            wrapper.eq(Payment::getPayerId, AuthContext.getCurrentUserId());
        }
        return PageUtils.paginate(paymentMapper, wrapper, page, pageSize);
    }

    /** 缴费详情 */
    public Payment getById(Long id) {
        Payment payment = paymentMapper.selectById(id);
        if (payment == null) {
            throw new BusinessException("缴费记录不存在");
        }
        return payment;
    }
}
