-- ============================================================================
-- 民用电缴费系统 — 存储过程脚本
-- 兼容版本: Oracle 11g
-- 说明: 包含 4 个核心存储过程 SP1~SP4，以及 1 个测试辅助过程
-- 执行顺序: 第 4 步，在建表、序列、触发器之后
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 300

PROMPT ========== 开始创建存储过程 ==========

-- ============================================================================
-- SP1: 月初批量生成账单
-- 功能描述:
--   每月 1 号凌晨执行（由数据库调度任务或应用层定时触发）。
--   遍历所有在用(NORMAL)电表，计算上月用电量，应用阶梯电价，生成账单。
--
-- 执行流程:
--   1. 确定上月账期（例如当前是 2026-06-01，则账期为 202605）
--   2. 查询当前有效电价配置（is_active = 'Y'）
--   3. 遍历所有 NORMAL 状态电表:
--      a) 查找上月最后一条抄表记录 → curr_reading
--      b) 查找上上月最后一条抄表记录 → prev_reading
--         （若无，则使用 meter.initial_reading）
--      c) 计算 total_usage = curr_reading - prev_reading
--      d) 按阶梯计算电费
--      e) 检查是否已存在该月账单（幂等性: 重复执行不生成重复账单）
--      f) 插入 bill 记录
--   4. 输出执行日志
--
-- 参数:
--   p_bill_month IN VARCHAR2(6)  — 可选，指定账期(YYYYMM)。默认自动计算上月。
--   p_commit_interval IN NUMBER  — 每处理N个电表提交一次
-- ============================================================================
CREATE OR REPLACE 
/

PROMPT SP1 (sp_generate_monthly_bills) 创建完毕 ?


-- ============================================================================
-- SP2: 每日滞纳金计算
-- 功能描述:
--   每天凌晨执行。扫描所有未缴费账单，对超过宽限期（15天）的账单计算滞纳金。
--   同时更新逾期账单状态为 OVERDUE（此操作会触发 TR2 生成欠费通知）。
--
-- 滞纳金规则:
--   - 宽限期: 15天（出账日至 due_date）
--   - 超过 due_date 仍未缴费 = 逾期
--   - 滞纳金 = total_amount × 0.001 × (当前日期 - due_date)
--   - 每日累计，但不超过本金（业务合理性约束）
--
-- 执行流程:
--   1. 扫描 status IN ('PENDING', 'OVERDUE') 且 due_date < SYSDATE 的账单
--   2. 对每条账单:
--      a) 计算逾期天数 = TRUNC(SYSDATE) - TRUNC(due_date)
--      b) 更新 late_fee = total_amount × 0.001 × 逾期天数（滞纳金不超过本金）
--      c) 若 status = 'PENDING' 且已逾期 → 更新为 'OVERDUE'（触发 TR2 欠费通知）
--   3. 提交
--
-- 参数: 无
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_calc_late_fees IS

    -- 游标: 所有未缴费且已过期的账单
    CURSOR c_overdue_bills IS
        SELECT bill_id, meter_id, total_amount, late_fee, status,
               due_date, bill_month
        FROM   bill
        WHERE  status IN ('PENDING', 'OVERDUE')
          AND  due_date < TRUNC(SYSDATE) -- 已过截止日
        ORDER BY bill_id;

    v_days_overdue  NUMBER;          -- 逾期天数
    v_new_late_fee  bill.late_fee%TYPE;  -- 新的滞纳金
    v_updated       NUMBER := 0;     -- 更新计数

BEGIN
    DBMS_OUTPUT.PUT_LINE('===== SP2: 滞纳金计算开始 =====');
    DBMS_OUTPUT.PUT_LINE('执行时间: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

    -- 遍历所有过期未缴账单
    FOR rec IN c_overdue_bills LOOP

        -- -------------------------------------------------------------------
        -- 步骤1: 计算逾期天数
        --   天数从 due_date 次日开始算起
        --   例如 due_date = 1月15日，今天是1月20日 → 逾期5天
        -- -------------------------------------------------------------------
        v_days_overdue := TRUNC(SYSDATE) - TRUNC(rec.due_date);

        IF v_days_overdue <= 0 THEN
            CONTINUE;  -- 虽然游标已过滤，但做防御性检查
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤2: 计算滞纳金
        --   公式: 滞纳金 = 电费本金 × 0.001 × 逾期天数
        --   滞纳金总额不超过电费本金（业务合理性约束）
        -- -------------------------------------------------------------------
        v_new_late_fee := ROUND(rec.total_amount * 0.001 * v_days_overdue, 2);

        -- 滞纳金上限 = 电费本金
        IF v_new_late_fee > rec.total_amount THEN
            v_new_late_fee := rec.total_amount;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤3: 更新账单
        --   若状态还是 PENDING → 更新为 OVERDUE
        --   （此 UPDATE 会触发 TR2 tr2_arrears_notify，自动生成欠费通知）
        -- -------------------------------------------------------------------
        IF rec.status = 'PENDING' THEN
            -- 状态变更 + 滞纳金更新
            UPDATE bill
            SET status   = 'OVERDUE',
                late_fee = v_new_late_fee
            WHERE bill_id = rec.bill_id;
        ELSE
            -- 仅更新滞纳金（状态已是 OVERDUE）
            UPDATE bill
            SET late_fee = v_new_late_fee
            WHERE bill_id = rec.bill_id
              AND late_fee <> v_new_late_fee;  -- 仅在金额变化时更新
        END IF;

        v_updated := v_updated + 1;

    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('===== SP2 执行完成 =====');
    DBMS_OUTPUT.PUT_LINE('更新账单数: ' || v_updated);
    DBMS_OUTPUT.PUT_LINE('当前日期: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('========================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('SP2 执行失败，已回滚: ' || SQLERRM);
        RAISE;
END sp_calc_late_fees;
/

PROMPT SP2 (sp_calc_late_fees) 创建完毕 ?


-- ============================================================================
-- SP3: 模拟智能电表读数
-- 功能描述:
--   每天凌晨 2:00 执行。为每个在用(NORMAL)电表生成一条当日抄表记录。
--   通过随机函数模拟真实的日用电量波动，体现智能电表自动抄表。
--
-- 随机规则:
--   - 基础用电: 5 ~ 15 度/天（模拟日常家庭用电）
--   - 季节性波动: 冬季(12-2月)和夏季(6-8月) × 1.5（空调/取暖）
--   - 休息日波动: 周末 × 1.2（在家时间更长）
--   - 最终用电量 = 基础 × 季节系数 × 周末系数
--   - 添加 ±20% 的随机抖动
--
-- 设计要点:
--   - 检查当天是否已生成读数（幂等性: 防止重复执行导致重复数据）
--   - 每条记录使用 seq_reading_id.NEXTVAL 显式提供 reading_id
--   - 插入后会依次触发:
--       TR1 (计算 daily_usage, 检测倒转)
--       trg_meter_update_snapshot (更新 meter.last_reading)
--       TR4a (若倒转, 生成告警)
--
-- 参数:
--   p_reading_date IN DATE — 可选，指定抄表日期。默认当天。
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_simulate_meter_reading(
    p_reading_date IN DATE DEFAULT NULL
) IS
    v_reading_date  DATE;
    v_reading_value meter_reading.reading_value%TYPE;
    v_base_usage    NUMBER(10,2);  -- 基础用电量
    v_season_factor NUMBER(4,2);   -- 季节系数
    v_weekend_factor NUMBER(4,2);  -- 周末系数
    v_jitter         NUMBER(4,2);  -- 随机抖动
    v_final_usage   NUMBER(10,2);  -- 最终日用电量
    v_last_reading  meter.last_reading%TYPE;
    v_count         NUMBER := 0;
    v_exists        NUMBER;

    -- 游标: 所有正常电表
    CURSOR c_meters IS
        SELECT m.meter_id, m.meter_no, m.last_reading, m.last_reading_date
        FROM   meter m
        WHERE  m.status = 'NORMAL'
        ORDER BY m.meter_id;

BEGIN
    -- -----------------------------------------------------------------------
    -- 步骤1: 确定抄表日期
    -- -----------------------------------------------------------------------
    IF p_reading_date IS NULL THEN
        v_reading_date := TRUNC(SYSDATE);
    ELSE
        v_reading_date := TRUNC(p_reading_date);
    END IF;

    -- 日期不能是未来日期（对于生产环境）
    IF v_reading_date > TRUNC(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('SP3 警告: 抄表日期 ' || TO_CHAR(v_reading_date, 'YYYY-MM-DD')
                          || ' 是未来日期，将使用当天日期');
        v_reading_date := TRUNC(SYSDATE);
    END IF;

    DBMS_OUTPUT.PUT_LINE('===== SP3: 智能电表读数模拟开始 =====');
    DBMS_OUTPUT.PUT_LINE('执行时间: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('抄表日期: ' || TO_CHAR(v_reading_date, 'YYYY-MM-DD'));

    -- -----------------------------------------------------------------------
    -- 步骤2: 计算季节系数
    --   冬季(12,1,2): 1.5  |  夏季(6,7,8): 1.5  |  春秋: 1.0
    -- -----------------------------------------------------------------------
    DECLARE
        v_month NUMBER := TO_NUMBER(TO_CHAR(v_reading_date, 'MM'));
    BEGIN
        IF v_month IN (12, 1, 2) THEN
            v_season_factor := 1.5;  -- 冬季取暖
        ELSIF v_month IN (6, 7, 8) THEN
            v_season_factor := 1.5;  -- 夏季空调
        ELSE
            v_season_factor := 1.0;  -- 春秋季正常
        END IF;
    END;

    -- -----------------------------------------------------------------------
    -- 步骤3: 计算周末系数
    --   周六/周日: 1.2  |  工作日: 1.0
    -- -----------------------------------------------------------------------
    DECLARE
        v_day NUMBER := TO_NUMBER(TO_CHAR(v_reading_date, 'D'));
    BEGIN
        -- Oracle 中: 1=周日, 7=周六
        IF v_day IN (1, 7) THEN
            v_weekend_factor := 1.2;
        ELSE
            v_weekend_factor := 1.0;
        END IF;
    END;

    -- -----------------------------------------------------------------------
    -- 步骤4: 遍历每个电表，生成当日读数
    -- -----------------------------------------------------------------------
    FOR rec IN c_meters LOOP

        -- 检查今天是否已有读数（幂等性）
        SELECT COUNT(*) INTO v_exists
        FROM meter_reading
        WHERE meter_id = rec.meter_id
          AND reading_date = v_reading_date;

        IF v_exists > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  电表 ' || rec.meter_no || ' 在 '
                || TO_CHAR(v_reading_date, 'YYYY-MM-DD') || ' 已有读数，跳过');
            CONTINUE;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤4a: 生成随机日用电量
        --
        --   DBMS_RANDOM.VALUE(low, high): 返回 [low, high) 之间的随机数
        --   基础用电: 3 ~ 12 度
        --   × 季节系数 × 周末系数
        --   × (0.8 ~ 1.2) 随机抖动
        -- -------------------------------------------------------------------
        v_base_usage := DBMS_RANDOM.VALUE(3, 12);
        v_jitter     := DBMS_RANDOM.VALUE(0.8, 1.2);
        v_final_usage := ROUND(v_base_usage * v_season_factor * v_weekend_factor * v_jitter, 2);

        -- 用电量不能为负或为0
        IF v_final_usage <= 0 THEN
            v_final_usage := 1.0;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤4b: 计算新的累计读数
        --   新累计读数 = 上次累计读数 + 今日用电增量
        -- -------------------------------------------------------------------
        v_last_reading := NVL(rec.last_reading, 0);
        v_reading_value := v_last_reading + v_final_usage;

        -- -------------------------------------------------------------------
        -- 步骤4c: 插入抄表记录
        --
        --   触发器链:
        --     trg_reading_bi (自增) → TR1 (计算daily_usage/检测倒转)
        --     → trg_meter_update_snapshot (更新meter.last_reading)
        --     → TR4a (若倒转则创建告警)
        -- -------------------------------------------------------------------
        BEGIN
            INSERT INTO meter_reading (
                reading_id, meter_id, reading_date,
                reading_value, daily_usage,
                reading_type, created_at
            ) VALUES (
                seq_reading_id.NEXTVAL,
                rec.meter_id,
                v_reading_date,
                v_reading_value,
                NULL,            -- daily_usage 由 TR1 自动计算
                'AUTO',          -- 标记为自动模拟
                SYSDATE
            );

            v_count := v_count + 1;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  SP3 插入失败: 电表 ' || rec.meter_no
                    || ' - ' || SQLERRM);
        END;

    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('===== SP3 执行完成 =====');
    DBMS_OUTPUT.PUT_LINE('抄表日期: ' || TO_CHAR(v_reading_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('季节系数: ' || v_season_factor || ' | 周末系数: ' || v_weekend_factor);
    DBMS_OUTPUT.PUT_LINE('生成读数: ' || v_count || ' 条');
    DBMS_OUTPUT.PUT_LINE('========================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('SP3 执行失败，已回滚: ' || SQLERRM);
        RAISE;
END sp_simulate_meter_reading;
/

PROMPT SP3 (sp_simulate_meter_reading) 创建完毕 ?


-- ============================================================================
-- SP4: 欠费断电预警
-- 功能描述:
--   每天凌晨 0:30 执行。扫描欠费超过28天的账单，向业主发送断电预警通知。
--
-- 执行流程:
--   1. 扫描 status = 'OVERDUE' 且 due_date + 28 天 ≤ SYSDATE 的账单
--   2. 通过 meter → house → sys_user 链路找到业主
--   3. 检查是否已发送过同一账单的断电预警（去重）
--   4. 插入 CUTOFF_WARNING 类型通知
--
-- 参数: 无
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_power_cutoff_warning IS

    -- 游标: 欠费超过28天的账单
    CURSOR c_cutoff_bills IS
        SELECT b.bill_id, b.meter_id, b.bill_month, b.total_amount,
               b.late_fee, b.due_date,
               TRUNC(SYSDATE) - TRUNC(b.due_date) AS days_overdue
        FROM   bill b
        WHERE  b.status = 'OVERDUE'
          AND  b.due_date + 28 <= TRUNC(SYSDATE)  -- 逾期 ≥ 28 天
        ORDER BY b.bill_id;

    v_user_id    sys_user.user_id%TYPE;
    v_address    house.address%TYPE;
    v_exists     NUMBER;
    v_count      NUMBER := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('===== SP4: 断电预警扫描开始 =====');
    DBMS_OUTPUT.PUT_LINE('执行时间: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

    FOR rec IN c_cutoff_bills LOOP

        -- -------------------------------------------------------------------
        -- 步骤1: 查找业主信息
        --   通过 电表 → 房产 → 用户 三表联查
        -- -------------------------------------------------------------------
        BEGIN
            SELECT u.user_id, h.address
            INTO   v_user_id, v_address
            FROM   meter m
            JOIN   house h ON m.house_id = h.house_id
            JOIN   sys_user u ON h.user_id = u.user_id
            WHERE  m.meter_id = rec.meter_id;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('  SP4: 电表 ' || rec.meter_id || ' 找不到业主，跳过');
                CONTINUE;
        END;

        -- -------------------------------------------------------------------
        -- 步骤2: 检查是否已发送过断电预警（去重）
        --   同一账单 + 同一用户 + 断电预警类型
        -- -------------------------------------------------------------------
        SELECT COUNT(*) INTO v_exists
        FROM notification
        WHERE user_id    = v_user_id
          AND type       = 'CUTOFF_WARNING'
          AND related_id = rec.bill_id;

        IF v_exists > 0 THEN
            -- 已发送过，跳过
            CONTINUE;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤3: 插入断电预警通知
        -- -------------------------------------------------------------------
        INSERT INTO notification (
            user_id, type, title, content, related_id, is_read, created_at
        ) VALUES (
            v_user_id,
            'CUTOFF_WARNING',
            '断电预警通知',
            '尊敬的业主，您位于 ' || v_address
            || ' 的房产（电表ID: ' || rec.meter_id || '）'
            || rec.bill_month || ' 月电费账单已逾期 '
            || rec.days_overdue || ' 天。'
            || '应缴电费：' || TO_CHAR(rec.total_amount, 'FM999990.00') || '元，'
            || '滞纳金：' || TO_CHAR(rec.late_fee, 'FM999990.00') || '元。'
            || '根据规定，逾期超过30天将可能被中断供电。'
            || '请尽快缴费以避免停电。',
            rec.bill_id,
            'N',
            SYSDATE
        );

        v_count := v_count + 1;

    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('===== SP4 执行完成 =====');
    DBMS_OUTPUT.PUT_LINE('生成断电预警: ' || v_count || ' 条');
    DBMS_OUTPUT.PUT_LINE('========================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('SP4 执行失败，已回滚: ' || SQLERRM);
        RAISE;
END sp_power_cutoff_warning;
/

PROMPT SP4 (sp_power_cutoff_warning) 创建完毕 ?


-- ============================================================================
-- 测试辅助过程: 批量生成历史抄表数据
-- 功能描述:
--   用于测试环境批量填充历史抄表记录。
--   对指定日期范围内的每一天，为所有在用(NORMAL)电表生成模拟读数。
--   内部循环调用 SP3 的单日生成逻辑。
--
-- 参数:
--   p_start_date IN DATE — 开始日期（含）
--   p_end_date   IN DATE — 结束日期（含）
--
-- 使用示例:
--   -- 生成 2026年1月1日 到 2026年2月28日 的历史数据
--   EXEC sp_test_backfill_readings(DATE '2026-01-01', DATE '2026-02-28');
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_test_backfill_readings(
    p_start_date IN DATE,
    p_end_date   IN DATE
) IS
    v_date DATE;
    v_days NUMBER;
BEGIN
    v_days := TRUNC(p_end_date) - TRUNC(p_start_date) + 1;

    DBMS_OUTPUT.PUT_LINE('===== 测试辅助: 批量生成历史抄表数据 =====');
    DBMS_OUTPUT.PUT_LINE('日期范围: ' || TO_CHAR(p_start_date, 'YYYY-MM-DD')
                      || ' ~ ' || TO_CHAR(p_end_date, 'YYYY-MM-DD')
                      || ' (' || v_days || ' 天)');

    v_date := TRUNC(p_start_date);

    -- 逐日循环，调用 SP3 为每天生成读数
    WHILE v_date <= TRUNC(p_end_date) LOOP
        DBMS_OUTPUT.PUT_LINE('  处理日期: ' || TO_CHAR(v_date, 'YYYY-MM-DD'));

        -- 调用 SP3 的抄表逻辑（指定日期）
        sp_simulate_meter_reading(v_date);

        v_date := v_date + 1;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('===== 批量历史数据生成完毕 =====');
    DBMS_OUTPUT.PUT_LINE('总计生成天数: ' || v_days);
END sp_test_backfill_readings;
/

PROMPT 测试辅助过程 (sp_test_backfill_readings) 创建完毕 ?


PROMPT
PROMPT ========== 存储过程创建汇总 ==========
PROMPT   SP1 sp_generate_monthly_bills  - 月初批量生成账单 (阶梯电价)
PROMPT   SP2 sp_calc_late_fees          - 每日滞纳金计算
PROMPT   SP3 sp_simulate_meter_reading  - 模拟智能电表读数
PROMPT   SP4 sp_power_cutoff_warning    - 欠费断电预警
PROMPT   辅助 sp_test_backfill_readings  - 测试用: 批量生成历史抄表数据
PROMPT ========== 04_create_procedures.sql 执行完毕 ==========CREATE OR REPLACE PROCEDURE sp_generate_monthly_bills(
    p_bill_month      IN VARCHAR2 DEFAULT NULL,
    p_commit_interval IN NUMBER   DEFAULT 100
) IS
    v_bill_month   VARCHAR2(6);
    v_res_price1   price_config.unit_price%TYPE;
    v_res_price2   price_config.unit_price%TYPE;
    v_res_price3   price_config.unit_price%TYPE;
    v_res_limit1   price_config.upper_limit%TYPE;
    v_res_limit2   price_config.upper_limit%TYPE;
    v_com_price1   price_config.unit_price%TYPE;
    v_com_price2   price_config.unit_price%TYPE;
    v_com_price3   price_config.unit_price%TYPE;
    v_com_limit1   price_config.upper_limit%TYPE;
    v_com_limit2   price_config.upper_limit%TYPE;
    v_price1       price_config.unit_price%TYPE;
    v_price2       price_config.unit_price%TYPE;
    v_price3       price_config.unit_price%TYPE;
    v_limit1       price_config.upper_limit%TYPE;
    v_limit2       price_config.upper_limit%TYPE;
    v_prev_reading meter_reading.reading_value%TYPE;
    v_curr_reading meter_reading.reading_value%TYPE;
    v_total_usage  NUMBER(10,2);
    v_tier1_usage  NUMBER(10,2);
    v_tier2_usage  NUMBER(10,2);
    v_tier3_usage  NUMBER(10,2);
    v_tier1_amount NUMBER(12,2);
    v_tier2_amount NUMBER(12,2);
    v_tier3_amount NUMBER(12,2);
    v_total_amount NUMBER(12,2);
    v_due_date     DATE;
    v_count        NUMBER := 0;
    v_due_count    NUMBER;
    v_last_month_start DATE;
    v_last_month_end   DATE;
    v_customer_type house.house_type%TYPE;
    CURSOR c_meters IS
        SELECT m.meter_id, m.meter_no, m.initial_reading, h.house_type
        FROM meter m JOIN house h ON m.house_id = h.house_id
        WHERE m.status = 'NORMAL' ORDER BY m.meter_id;
BEGIN
    IF p_bill_month IS NULL THEN
        v_bill_month := TO_CHAR(ADD_MONTHS(SYSDATE, -1), 'YYYYMM');
    ELSE
        v_bill_month := p_bill_month;
    END IF;
    v_last_month_start := TO_DATE(v_bill_month || '01', 'YYYYMMDD');
    v_last_month_end   := LAST_DAY(v_last_month_start);

    BEGIN
        SELECT unit_price INTO v_res_price1 FROM price_config WHERE tier_no=1 AND is_active='Y' AND customer_type='RESIDENTIAL' AND ROWNUM=1;
        SELECT unit_price INTO v_res_price2 FROM price_config WHERE tier_no=2 AND is_active='Y' AND customer_type='RESIDENTIAL' AND ROWNUM=1;
        SELECT unit_price INTO v_res_price3 FROM price_config WHERE tier_no=3 AND is_active='Y' AND customer_type='RESIDENTIAL' AND ROWNUM=1;
        SELECT upper_limit INTO v_res_limit1 FROM price_config WHERE tier_no=1 AND is_active='Y' AND customer_type='RESIDENTIAL' AND ROWNUM=1;
        SELECT upper_limit INTO v_res_limit2 FROM price_config WHERE tier_no=2 AND is_active='Y' AND customer_type='RESIDENTIAL' AND ROWNUM=1;
    EXCEPTION WHEN NO_DATA_FOUND THEN RAISE;
    END;

    BEGIN
        SELECT unit_price INTO v_com_price1 FROM price_config WHERE tier_no=1 AND is_active='Y' AND customer_type='COMMERCIAL' AND ROWNUM=1;
        SELECT unit_price INTO v_com_price2 FROM price_config WHERE tier_no=2 AND is_active='Y' AND customer_type='COMMERCIAL' AND ROWNUM=1;
        SELECT unit_price INTO v_com_price3 FROM price_config WHERE tier_no=3 AND is_active='Y' AND customer_type='COMMERCIAL' AND ROWNUM=1;
        SELECT upper_limit INTO v_com_limit1 FROM price_config WHERE tier_no=1 AND is_active='Y' AND customer_type='COMMERCIAL' AND ROWNUM=1;
        SELECT upper_limit INTO v_com_limit2 FROM price_config WHERE tier_no=2 AND is_active='Y' AND customer_type='COMMERCIAL' AND ROWNUM=1;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        v_com_price1 := v_res_price1; v_com_price2 := v_res_price2; v_com_price3 := v_res_price3;
        v_com_limit1 := v_res_limit1; v_com_limit2 := v_res_limit2;
    END;

    FOR rec IN c_meters LOOP
        SELECT COUNT(*) INTO v_due_count FROM bill WHERE meter_id = rec.meter_id AND bill_month = v_bill_month;
        IF v_due_count > 0 THEN CONTINUE; END IF;

        IF rec.house_type = 'COMMERCIAL' THEN
            v_price1 := v_com_price1; v_price2 := v_com_price2; v_price3 := v_com_price3;
            v_limit1 := v_com_limit1; v_limit2 := v_com_limit2;
        ELSE
            v_price1 := v_res_price1; v_price2 := v_res_price2; v_price3 := v_res_price3;
            v_limit1 := v_res_limit1; v_limit2 := v_res_limit2;
        END IF;

        BEGIN
            SELECT reading_value INTO v_curr_reading FROM (
                SELECT reading_value FROM meter_reading
                WHERE meter_id = rec.meter_id AND reading_date <= v_last_month_end
                ORDER BY reading_date DESC
            ) WHERE ROWNUM = 1;
        EXCEPTION WHEN NO_DATA_FOUND THEN CONTINUE;
        END;

        DECLARE
            v_prev_month_end DATE := LAST_DAY(ADD_MONTHS(v_last_month_start, -1));
        BEGIN
            SELECT reading_value INTO v_prev_reading FROM (
                SELECT reading_value FROM meter_reading
                WHERE meter_id = rec.meter_id AND reading_date <= v_prev_month_end
                ORDER BY reading_date DESC
            ) WHERE ROWNUM = 1;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            v_prev_reading := rec.initial_reading;
        END;

        v_total_usage := v_curr_reading - v_prev_reading;
        IF v_total_usage < 0 THEN v_total_usage := 0; END IF;

        v_tier1_usage := LEAST(v_total_usage, v_limit1);
        v_tier2_usage := GREATEST(0, LEAST(v_total_usage - v_limit1, v_limit2 - v_limit1));
        v_tier3_usage := GREATEST(0, v_total_usage - v_limit2);
        v_tier1_amount := ROUND(v_tier1_usage * v_price1, 2);
        v_tier2_amount := ROUND(v_tier2_usage * v_price2, 2);
        v_tier3_amount := ROUND(v_tier3_usage * v_price3, 2);
        v_total_amount := v_tier1_amount + v_tier2_amount + v_tier3_amount;
        v_due_date := TRUNC(SYSDATE) + 15;

        INSERT INTO bill (bill_id, meter_id, bill_month, prev_reading, curr_reading, total_usage,
            tier1_usage, tier2_usage, tier3_usage, tier1_amount, tier2_amount, tier3_amount,
            total_amount, late_fee, status, due_date, created_at)
        VALUES (seq_bill_id.NEXTVAL, rec.meter_id, v_bill_month, v_prev_reading, v_curr_reading,
            v_total_usage, v_tier1_usage, v_tier2_usage, v_tier3_usage,
            v_tier1_amount, v_tier2_amount, v_tier3_amount, v_total_amount,
            0, 'PENDING', v_due_date, SYSDATE);

        v_count := v_count + 1;
        IF MOD(v_count, p_commit_interval) = 0 THEN COMMIT; END IF;
    END LOOP;
    COMMIT;
END sp_generate_monthly_bills;
/- ============================================================================
-- 民用电缴费系统 — 存储过程脚本
-- 兼容版本: Oracle 11g
-- 说明: 包含 4 个核心存储过程 SP1~SP4，以及 1 个测试辅助过程
-- 执行顺序: 第 4 步，在建表、序列、触发器之后
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 300

PROMPT ========== 开始创建存储过程 ==========

-- ============================================================================
-- SP1: 月初批量生成账单
-- 功能描述:
--   每月 1 号凌晨执行（由数据库调度任务或应用层定时触发）。
--   遍历所有在用(NORMAL)电表，计算上月用电量，应用阶梯电价，生成账单。
--
-- 执行流程:
--   1. 确定上月账期（例如当前是 2026-06-01，则账期为 202605）
--   2. 查询当前有效电价配置（is_active = 'Y'）
--   3. 遍历所有 NORMAL 状态电表:
--      a) 查找上月最后一条抄表记录 → curr_reading
--      b) 查找上上月最后一条抄表记录 → prev_reading
--         （若无，则使用 meter.initial_reading）
--      c) 计算 total_usage = curr_reading - prev_reading
--      d) 按阶梯计算电费
--      e) 检查是否已存在该月账单（幂等性: 重复执行不生成重复账单）
--      f) 插入 bill 记录
--   4. 输出执行日志
--
-- 参数:
--   p_bill_month IN VARCHAR2(6)  — 可选，指定账期(YYYYMM)。默认自动计算上月。
--   p_commit_interval IN NUMBER  — 每处理N个电表提交一次
-- ============================================================================
CREATE OR REPLACE 
/

PROMPT SP1 (sp_generate_monthly_bills) 创建完毕 ?


-- ============================================================================
-- SP2: 每日滞纳金计算
-- 功能描述:
--   每天凌晨执行。扫描所有未缴费账单，对超过宽限期（15天）的账单计算滞纳金。
--   同时更新逾期账单状态为 OVERDUE（此操作会触发 TR2 生成欠费通知）。
--
-- 滞纳金规则:
--   - 宽限期: 15天（出账日至 due_date）
--   - 超过 due_date 仍未缴费 = 逾期
--   - 滞纳金 = total_amount × 0.001 × (当前日期 - due_date)
--   - 每日累计，但不超过本金（业务合理性约束）
--
-- 执行流程:
--   1. 扫描 status IN ('PENDING', 'OVERDUE') 且 due_date < SYSDATE 的账单
--   2. 对每条账单:
--      a) 计算逾期天数 = TRUNC(SYSDATE) - TRUNC(due_date)
--      b) 更新 late_fee = total_amount × 0.001 × 逾期天数（滞纳金不超过本金）
--      c) 若 status = 'PENDING' 且已逾期 → 更新为 'OVERDUE'（触发 TR2 欠费通知）
--   3. 提交
--
-- 参数: 无
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_calc_late_fees IS

    -- 游标: 所有未缴费且已过期的账单
    CURSOR c_overdue_bills IS
        SELECT bill_id, meter_id, total_amount, late_fee, status,
               due_date, bill_month
        FROM   bill
        WHERE  status IN ('PENDING', 'OVERDUE')
          AND  due_date < TRUNC(SYSDATE) -- 已过截止日
        ORDER BY bill_id;

    v_days_overdue  NUMBER;          -- 逾期天数
    v_new_late_fee  bill.late_fee%TYPE;  -- 新的滞纳金
    v_updated       NUMBER := 0;     -- 更新计数

BEGIN
    DBMS_OUTPUT.PUT_LINE('===== SP2: 滞纳金计算开始 =====');
    DBMS_OUTPUT.PUT_LINE('执行时间: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

    -- 遍历所有过期未缴账单
    FOR rec IN c_overdue_bills LOOP

        -- -------------------------------------------------------------------
        -- 步骤1: 计算逾期天数
        --   天数从 due_date 次日开始算起
        --   例如 due_date = 1月15日，今天是1月20日 → 逾期5天
        -- -------------------------------------------------------------------
        v_days_overdue := TRUNC(SYSDATE) - TRUNC(rec.due_date);

        IF v_days_overdue <= 0 THEN
            CONTINUE;  -- 虽然游标已过滤，但做防御性检查
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤2: 计算滞纳金
        --   公式: 滞纳金 = 电费本金 × 0.001 × 逾期天数
        --   滞纳金总额不超过电费本金（业务合理性约束）
        -- -------------------------------------------------------------------
        v_new_late_fee := ROUND(rec.total_amount * 0.001 * v_days_overdue, 2);

        -- 滞纳金上限 = 电费本金
        IF v_new_late_fee > rec.total_amount THEN
            v_new_late_fee := rec.total_amount;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤3: 更新账单
        --   若状态还是 PENDING → 更新为 OVERDUE
        --   （此 UPDATE 会触发 TR2 tr2_arrears_notify，自动生成欠费通知）
        -- -------------------------------------------------------------------
        IF rec.status = 'PENDING' THEN
            -- 状态变更 + 滞纳金更新
            UPDATE bill
            SET status   = 'OVERDUE',
                late_fee = v_new_late_fee
            WHERE bill_id = rec.bill_id;
        ELSE
            -- 仅更新滞纳金（状态已是 OVERDUE）
            UPDATE bill
            SET late_fee = v_new_late_fee
            WHERE bill_id = rec.bill_id
              AND late_fee <> v_new_late_fee;  -- 仅在金额变化时更新
        END IF;

        v_updated := v_updated + 1;

    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('===== SP2 执行完成 =====');
    DBMS_OUTPUT.PUT_LINE('更新账单数: ' || v_updated);
    DBMS_OUTPUT.PUT_LINE('当前日期: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('========================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('SP2 执行失败，已回滚: ' || SQLERRM);
        RAISE;
END sp_calc_late_fees;
/

PROMPT SP2 (sp_calc_late_fees) 创建完毕 ?


-- ============================================================================
-- SP3: 模拟智能电表读数
-- 功能描述:
--   每天凌晨 2:00 执行。为每个在用(NORMAL)电表生成一条当日抄表记录。
--   通过随机函数模拟真实的日用电量波动，体现智能电表自动抄表。
--
-- 随机规则:
--   - 基础用电: 5 ~ 15 度/天（模拟日常家庭用电）
--   - 季节性波动: 冬季(12-2月)和夏季(6-8月) × 1.5（空调/取暖）
--   - 休息日波动: 周末 × 1.2（在家时间更长）
--   - 最终用电量 = 基础 × 季节系数 × 周末系数
--   - 添加 ±20% 的随机抖动
--
-- 设计要点:
--   - 检查当天是否已生成读数（幂等性: 防止重复执行导致重复数据）
--   - 每条记录使用 seq_reading_id.NEXTVAL 显式提供 reading_id
--   - 插入后会依次触发:
--       TR1 (计算 daily_usage, 检测倒转)
--       trg_meter_update_snapshot (更新 meter.last_reading)
--       TR4a (若倒转, 生成告警)
--
-- 参数:
--   p_reading_date IN DATE — 可选，指定抄表日期。默认当天。
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_simulate_meter_reading(
    p_reading_date IN DATE DEFAULT NULL
) IS
    v_reading_date  DATE;
    v_reading_value meter_reading.reading_value%TYPE;
    v_base_usage    NUMBER(10,2);  -- 基础用电量
    v_season_factor NUMBER(4,2);   -- 季节系数
    v_weekend_factor NUMBER(4,2);  -- 周末系数
    v_jitter         NUMBER(4,2);  -- 随机抖动
    v_final_usage   NUMBER(10,2);  -- 最终日用电量
    v_last_reading  meter.last_reading%TYPE;
    v_count         NUMBER := 0;
    v_exists        NUMBER;

    -- 游标: 所有正常电表
    CURSOR c_meters IS
        SELECT m.meter_id, m.meter_no, m.last_reading, m.last_reading_date
        FROM   meter m
        WHERE  m.status = 'NORMAL'
        ORDER BY m.meter_id;

BEGIN
    -- -----------------------------------------------------------------------
    -- 步骤1: 确定抄表日期
    -- -----------------------------------------------------------------------
    IF p_reading_date IS NULL THEN
        v_reading_date := TRUNC(SYSDATE);
    ELSE
        v_reading_date := TRUNC(p_reading_date);
    END IF;

    -- 日期不能是未来日期（对于生产环境）
    IF v_reading_date > TRUNC(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('SP3 警告: 抄表日期 ' || TO_CHAR(v_reading_date, 'YYYY-MM-DD')
                          || ' 是未来日期，将使用当天日期');
        v_reading_date := TRUNC(SYSDATE);
    END IF;

    DBMS_OUTPUT.PUT_LINE('===== SP3: 智能电表读数模拟开始 =====');
    DBMS_OUTPUT.PUT_LINE('执行时间: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('抄表日期: ' || TO_CHAR(v_reading_date, 'YYYY-MM-DD'));

    -- -----------------------------------------------------------------------
    -- 步骤2: 计算季节系数
    --   冬季(12,1,2): 1.5  |  夏季(6,7,8): 1.5  |  春秋: 1.0
    -- -----------------------------------------------------------------------
    DECLARE
        v_month NUMBER := TO_NUMBER(TO_CHAR(v_reading_date, 'MM'));
    BEGIN
        IF v_month IN (12, 1, 2) THEN
            v_season_factor := 1.5;  -- 冬季取暖
        ELSIF v_month IN (6, 7, 8) THEN
            v_season_factor := 1.5;  -- 夏季空调
        ELSE
            v_season_factor := 1.0;  -- 春秋季正常
        END IF;
    END;

    -- -----------------------------------------------------------------------
    -- 步骤3: 计算周末系数
    --   周六/周日: 1.2  |  工作日: 1.0
    -- -----------------------------------------------------------------------
    DECLARE
        v_day NUMBER := TO_NUMBER(TO_CHAR(v_reading_date, 'D'));
    BEGIN
        -- Oracle 中: 1=周日, 7=周六
        IF v_day IN (1, 7) THEN
            v_weekend_factor := 1.2;
        ELSE
            v_weekend_factor := 1.0;
        END IF;
    END;

    -- -----------------------------------------------------------------------
    -- 步骤4: 遍历每个电表，生成当日读数
    -- -----------------------------------------------------------------------
    FOR rec IN c_meters LOOP

        -- 检查今天是否已有读数（幂等性）
        SELECT COUNT(*) INTO v_exists
        FROM meter_reading
        WHERE meter_id = rec.meter_id
          AND reading_date = v_reading_date;

        IF v_exists > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  电表 ' || rec.meter_no || ' 在 '
                || TO_CHAR(v_reading_date, 'YYYY-MM-DD') || ' 已有读数，跳过');
            CONTINUE;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤4a: 生成随机日用电量
        --
        --   DBMS_RANDOM.VALUE(low, high): 返回 [low, high) 之间的随机数
        --   基础用电: 3 ~ 12 度
        --   × 季节系数 × 周末系数
        --   × (0.8 ~ 1.2) 随机抖动
        -- -------------------------------------------------------------------
        v_base_usage := DBMS_RANDOM.VALUE(3, 12);
        v_jitter     := DBMS_RANDOM.VALUE(0.8, 1.2);
        v_final_usage := ROUND(v_base_usage * v_season_factor * v_weekend_factor * v_jitter, 2);

        -- 用电量不能为负或为0
        IF v_final_usage <= 0 THEN
            v_final_usage := 1.0;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤4b: 计算新的累计读数
        --   新累计读数 = 上次累计读数 + 今日用电增量
        -- -------------------------------------------------------------------
        v_last_reading := NVL(rec.last_reading, 0);
        v_reading_value := v_last_reading + v_final_usage;

        -- -------------------------------------------------------------------
        -- 步骤4c: 插入抄表记录
        --
        --   触发器链:
        --     trg_reading_bi (自增) → TR1 (计算daily_usage/检测倒转)
        --     → trg_meter_update_snapshot (更新meter.last_reading)
        --     → TR4a (若倒转则创建告警)
        -- -------------------------------------------------------------------
        BEGIN
            INSERT INTO meter_reading (
                reading_id, meter_id, reading_date,
                reading_value, daily_usage,
                reading_type, created_at
            ) VALUES (
                seq_reading_id.NEXTVAL,
                rec.meter_id,
                v_reading_date,
                v_reading_value,
                NULL,            -- daily_usage 由 TR1 自动计算
                'AUTO',          -- 标记为自动模拟
                SYSDATE
            );

            v_count := v_count + 1;

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  SP3 插入失败: 电表 ' || rec.meter_no
                    || ' - ' || SQLERRM);
        END;

    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('===== SP3 执行完成 =====');
    DBMS_OUTPUT.PUT_LINE('抄表日期: ' || TO_CHAR(v_reading_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('季节系数: ' || v_season_factor || ' | 周末系数: ' || v_weekend_factor);
    DBMS_OUTPUT.PUT_LINE('生成读数: ' || v_count || ' 条');
    DBMS_OUTPUT.PUT_LINE('========================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('SP3 执行失败，已回滚: ' || SQLERRM);
        RAISE;
END sp_simulate_meter_reading;
/

PROMPT SP3 (sp_simulate_meter_reading) 创建完毕 ?


-- ============================================================================
-- SP4: 欠费断电预警
-- 功能描述:
--   每天凌晨 0:30 执行。扫描欠费超过28天的账单，向业主发送断电预警通知。
--
-- 执行流程:
--   1. 扫描 status = 'OVERDUE' 且 due_date + 28 天 ≤ SYSDATE 的账单
--   2. 通过 meter → house → sys_user 链路找到业主
--   3. 检查是否已发送过同一账单的断电预警（去重）
--   4. 插入 CUTOFF_WARNING 类型通知
--
-- 参数: 无
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_power_cutoff_warning IS

    -- 游标: 欠费超过28天的账单
    CURSOR c_cutoff_bills IS
        SELECT b.bill_id, b.meter_id, b.bill_month, b.total_amount,
               b.late_fee, b.due_date,
               TRUNC(SYSDATE) - TRUNC(b.due_date) AS days_overdue
        FROM   bill b
        WHERE  b.status = 'OVERDUE'
          AND  b.due_date + 28 <= TRUNC(SYSDATE)  -- 逾期 ≥ 28 天
        ORDER BY b.bill_id;

    v_user_id    sys_user.user_id%TYPE;
    v_address    house.address%TYPE;
    v_exists     NUMBER;
    v_count      NUMBER := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('===== SP4: 断电预警扫描开始 =====');
    DBMS_OUTPUT.PUT_LINE('执行时间: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

    FOR rec IN c_cutoff_bills LOOP

        -- -------------------------------------------------------------------
        -- 步骤1: 查找业主信息
        --   通过 电表 → 房产 → 用户 三表联查
        -- -------------------------------------------------------------------
        BEGIN
            SELECT u.user_id, h.address
            INTO   v_user_id, v_address
            FROM   meter m
            JOIN   house h ON m.house_id = h.house_id
            JOIN   sys_user u ON h.user_id = u.user_id
            WHERE  m.meter_id = rec.meter_id;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('  SP4: 电表 ' || rec.meter_id || ' 找不到业主，跳过');
                CONTINUE;
        END;

        -- -------------------------------------------------------------------
        -- 步骤2: 检查是否已发送过断电预警（去重）
        --   同一账单 + 同一用户 + 断电预警类型
        -- -------------------------------------------------------------------
        SELECT COUNT(*) INTO v_exists
        FROM notification
        WHERE user_id    = v_user_id
          AND type       = 'CUTOFF_WARNING'
          AND related_id = rec.bill_id;

        IF v_exists > 0 THEN
            -- 已发送过，跳过
            CONTINUE;
        END IF;

        -- -------------------------------------------------------------------
        -- 步骤3: 插入断电预警通知
        -- -------------------------------------------------------------------
        INSERT INTO notification (
            user_id, type, title, content, related_id, is_read, created_at
        ) VALUES (
            v_user_id,
            'CUTOFF_WARNING',
            '断电预警通知',
            '尊敬的业主，您位于 ' || v_address
            || ' 的房产（电表ID: ' || rec.meter_id || '）'
            || rec.bill_month || ' 月电费账单已逾期 '
            || rec.days_overdue || ' 天。'
            || '应缴电费：' || TO_CHAR(rec.total_amount, 'FM999990.00') || '元，'
            || '滞纳金：' || TO_CHAR(rec.late_fee, 'FM999990.00') || '元。'
            || '根据规定，逾期超过30天将可能被中断供电。'
            || '请尽快缴费以避免停电。',
            rec.bill_id,
            'N',
            SYSDATE
        );

        v_count := v_count + 1;

    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('===== SP4 执行完成 =====');
    DBMS_OUTPUT.PUT_LINE('生成断电预警: ' || v_count || ' 条');
    DBMS_OUTPUT.PUT_LINE('========================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('SP4 执行失败，已回滚: ' || SQLERRM);
        RAISE;
END sp_power_cutoff_warning;
/

PROMPT SP4 (sp_power_cutoff_warning) 创建完毕 ?


-- ============================================================================
-- 测试辅助过程: 批量生成历史抄表数据
-- 功能描述:
--   用于测试环境批量填充历史抄表记录。
--   对指定日期范围内的每一天，为所有在用(NORMAL)电表生成模拟读数。
--   内部循环调用 SP3 的单日生成逻辑。
--
-- 参数:
--   p_start_date IN DATE — 开始日期（含）
--   p_end_date   IN DATE — 结束日期（含）
--
-- 使用示例:
--   -- 生成 2026年1月1日 到 2026年2月28日 的历史数据
--   EXEC sp_test_backfill_readings(DATE '2026-01-01', DATE '2026-02-28');
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_test_backfill_readings(
    p_start_date IN DATE,
    p_end_date   IN DATE
) IS
    v_date DATE;
    v_days NUMBER;
BEGIN
    v_days := TRUNC(p_end_date) - TRUNC(p_start_date) + 1;

    DBMS_OUTPUT.PUT_LINE('===== 测试辅助: 批量生成历史抄表数据 =====');
    DBMS_OUTPUT.PUT_LINE('日期范围: ' || TO_CHAR(p_start_date, 'YYYY-MM-DD')
                      || ' ~ ' || TO_CHAR(p_end_date, 'YYYY-MM-DD')
                      || ' (' || v_days || ' 天)');

    v_date := TRUNC(p_start_date);

    -- 逐日循环，调用 SP3 为每天生成读数
    WHILE v_date <= TRUNC(p_end_date) LOOP
        DBMS_OUTPUT.PUT_LINE('  处理日期: ' || TO_CHAR(v_date, 'YYYY-MM-DD'));

        -- 调用 SP3 的抄表逻辑（指定日期）
        sp_simulate_meter_reading(v_date);

        v_date := v_date + 1;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('===== 批量历史数据生成完毕 =====');
    DBMS_OUTPUT.PUT_LINE('总计生成天数: ' || v_days);
END sp_test_backfill_readings;
/

PROMPT 测试辅助过程 (sp_test_backfill_readings) 创建完毕 ?


PROMPT
PROMPT ========== 存储过程创建汇总 ==========
PROMPT   SP1 sp_generate_monthly_bills  - 月初批量生成账单 (阶梯电价)
PROMPT   SP2 sp_calc_late_fees          - 每日滞纳金计算
PROMPT   SP3 sp_simulate_meter_reading  - 模拟智能电表读数
PROMPT   SP4 sp_power_cutoff_warning    - 欠费断电预警
PROMPT   辅助 sp_test_backfill_readings  - 测试用: 批量生成历史抄表数据
PROMPT ========== 04_create_procedures.sql 执行完毕 ==========
