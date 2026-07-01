package com.electric.billing.module.chat;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.entity.*;
import com.electric.billing.module.bill.BillMapper;
import com.electric.billing.module.house.HouseMapper;
import com.electric.billing.module.meter.MeterMapper;
import com.electric.billing.module.payment.PaymentMapper;
import com.electric.billing.module.price.PriceMapper;
import com.electric.billing.module.reading.ReadingMapper;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Function Calling 工具执行器
 * 根据 userId 查询该用户的个人数据，进行数据隔离
 */
@Component
public class ToolExecutor {

    private final BillMapper billMapper;
    private final PaymentMapper paymentMapper;
    private final MeterMapper meterMapper;
    private final ReadingMapper readingMapper;
    private final HouseMapper houseMapper;
    private final PriceMapper priceMapper;

    public ToolExecutor(BillMapper billMapper, PaymentMapper paymentMapper,
                        MeterMapper meterMapper, ReadingMapper readingMapper,
                        HouseMapper houseMapper, PriceMapper priceMapper) {
        this.billMapper = billMapper;
        this.paymentMapper = paymentMapper;
        this.meterMapper = meterMapper;
        this.readingMapper = readingMapper;
        this.houseMapper = houseMapper;
        this.priceMapper = priceMapper;
    }

    /**
     * 执行工具调用，返回格式化后的结果文本
     */
    public String execute(String toolName, Map<String, Object> args, Long userId) {
        return switch (toolName) {
            case "get_my_bills" -> getMyBills(userId, args);
            case "get_my_payments" -> getMyPayments(userId, args);
            case "get_my_meter_readings" -> getMyMeterReadings(userId, args);
            case "get_price_tiers" -> getPriceTiers();
            case "get_my_houses" -> getMyHouses(userId);
            default -> "未知工具: " + toolName;
        };
    }

    /** 查询当前用户的账单。支持按月份过滤 (args.billMonth=YYYYMM) */
    private String getMyBills(Long userId, Map<String, Object> args) {
        LambdaQueryWrapper<Bill> wrapper = new LambdaQueryWrapper<>();
        List<Long> meterIds = getUserMeterIds(userId);
        if (meterIds.isEmpty()) return "未找到您的电表信息。";

        wrapper.in(Bill::getMeterId, meterIds)
               .orderByDesc(Bill::getBillMonth);

        // 按指定月份过滤 (args 可能为 null)
        String targetMonth = args != null ? (String) args.get("billMonth") : null;
        if (targetMonth != null && !targetMonth.isBlank()) {
            wrapper.eq(Bill::getBillMonth, targetMonth);
        }

        List<Bill> bills = billMapper.selectList(wrapper);
        // 限制返回最近 20 条，覆盖多房产多月场景
        if (bills.size() > 20) bills = bills.subList(0, 20);

        if (bills.isEmpty()) {
            return targetMonth != null
                ? "未找到您 " + targetMonth + " 月份的账单记录。"
                : "暂无账单记录。";
        }

        fillAddresses(bills);

        String label = targetMonth != null
            ? "您 " + targetMonth + " 月份的账单"
            : "您的最近账单";
        StringBuilder sb = new StringBuilder(label + ":\n");
        for (Bill b : bills) {
            sb.append(String.format("- [%s] 用量: %.0fkWh, 金额: %.2f元, 滞纳金: %.2f元, 状态: %s, 地址: %s\n",
                b.getBillMonth(), b.getTotalUsage(), b.getTotalAmount(),
                b.getLateFee() != null ? b.getLateFee() : 0,
                statusLabel(b.getStatus()), b.getHouseAddress()));
        }
        return sb.toString();
    }

    /** 查询当前用户的缴费记录 */
    private String getMyPayments(Long userId, Map<String, Object> args) {
        LambdaQueryWrapper<Payment> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Payment::getPayerId, userId)
               .orderByDesc(Payment::getPaymentTime);
        List<Payment> payments = paymentMapper.selectList(wrapper);
        if (payments.size() > 2) payments = payments.subList(0, 2);

        if (payments.isEmpty()) return "暂无缴费记录。";

        StringBuilder sb = new StringBuilder("您的最近缴费记录:\n");
        for (Payment p : payments) {
            sb.append(String.format("- 金额: %.2f元, 渠道: %s, 时间: %s\n",
                p.getAmount(),
                "OFFLINE".equals(p.getChannel()) ? "线下" : "在线",
                p.getPaymentTime()));
        }
        return sb.toString();
    }

    /** 查询当前用户电表的最近读数 */
    private String getMyMeterReadings(Long userId, Map<String, Object> args) {
        List<Long> meterIds = getUserMeterIds(userId);
        if (meterIds.isEmpty()) return "未找到您的电表信息。";

        LambdaQueryWrapper<MeterReading> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(MeterReading::getMeterId, meterIds)
               .orderByDesc(MeterReading::getReadingDate);
        List<MeterReading> readings = readingMapper.selectList(wrapper);
        if (readings.size() > 5) readings = readings.subList(0, 5);

        if (readings.isEmpty()) return "暂无抄表记录。";

        StringBuilder sb = new StringBuilder("您的最近抄表记录:\n");
        for (MeterReading r : readings) {
            sb.append(String.format("- 日期: %s, 读数: %.1f, 日用量: %.1fkWh\n",
                r.getReadingDate(), r.getReadingValue(),
                r.getDailyUsage() != null ? r.getDailyUsage() : 0));
        }
        return sb.toString();
    }

    /** 查询当前电价配置 */
    private String getPriceTiers() {
        List<PriceConfig> prices = priceMapper.selectList(
            new LambdaQueryWrapper<PriceConfig>()
                .eq(PriceConfig::getIsActive, "Y")
                .orderByAsc(PriceConfig::getTierNo)
        );
        if (prices.isEmpty()) return "暂无电价配置信息。";

        StringBuilder sb = new StringBuilder("当前阶梯电价:\n");
        for (PriceConfig p : prices) {
            sb.append(String.format("- 第%d档 (%s): %.0f-%.0f kWh, %.2f 元/kWh\n",
                p.getTierNo(), p.getTierName(),
                p.getLowerLimit(), p.getUpperLimit() != null ? p.getUpperLimit() : 99999,
                p.getUnitPrice()));
        }
        return sb.toString();
    }

    /** 查询当前用户的房产信息 */
    private String getMyHouses(Long userId) {
        List<House> houses = houseMapper.selectList(
            new LambdaQueryWrapper<House>().eq(House::getUserId, userId)
        );
        if (houses.isEmpty()) return "未找到您的房产信息。";

        StringBuilder sb = new StringBuilder("您的房产信息:\n");
        for (House h : houses) {
            sb.append(String.format("- %s, 面积: %.1f㎡\n",
                h.getAddress(), h.getArea() != null ? h.getArea() : 0));
        }
        return sb.toString();
    }

    // ---- 辅助方法 ----

    /** 获取用户的所有电表 ID */
    private List<Long> getUserMeterIds(Long userId) {
        List<House> houses = houseMapper.selectList(
            new LambdaQueryWrapper<House>().eq(House::getUserId, userId)
        );
        if (houses.isEmpty()) return List.of();

        List<Long> houseIds = houses.stream().map(House::getHouseId).toList();
        List<Meter> meters = meterMapper.selectList(
            new LambdaQueryWrapper<Meter>().in(Meter::getHouseId, houseIds)
        );
        return meters.stream().map(Meter::getMeterId).collect(Collectors.toList());
    }

    /** 批量填充账单的住宅地址 */
    private void fillAddresses(List<Bill> bills) {
        Set<Long> meterIds = bills.stream().map(Bill::getMeterId).collect(Collectors.toSet());
        if (meterIds.isEmpty()) return;

        List<Meter> meters = meterMapper.selectBatchIds(meterIds);
        Map<Long, Long> meterHouseMap = meters.stream()
            .collect(Collectors.toMap(Meter::getMeterId, Meter::getHouseId));

        Set<Long> houseIds = new HashSet<>(meterHouseMap.values());
        List<House> houses = houseMapper.selectBatchIds(houseIds);
        Map<Long, String> addrMap = houses.stream()
            .collect(Collectors.toMap(House::getHouseId, House::getAddress));

        for (Bill b : bills) {
            Long hid = meterHouseMap.get(b.getMeterId());
            b.setHouseAddress(hid != null ? addrMap.getOrDefault(hid, "未知") : "未知");
        }
    }

    private String statusLabel(String status) {
        return switch (status) {
            case "PENDING" -> "待缴";
            case "PAID" -> "已缴";
            case "OVERDUE" -> "逾期";
            default -> status;
        };
    }
}
