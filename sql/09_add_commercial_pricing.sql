-- ============================================================================
-- 民用电缴费系统 — 商用/民用双轨电价迁移脚本
-- 数据库版本: Oracle 11g+
-- 说明: 向 PRICE_CONFIG 新增 customer_type 字段，录入商用三档电价，重编译 SP1
-- 执行方式: 以 elec_billing 用户身份执行 sqlplus 运行本文件
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 300

PROMPT ========== 1. ALTER PRICE_CONFIG 新增 customer_type 字段 ==========

ALTER TABLE price_config ADD customer_type VARCHAR2(20) DEFAULT 'RESIDENTIAL' NOT NULL;

ALTER TABLE price_config ADD CONSTRAINT ck_price_customer_type
    CHECK (customer_type IN ('RESIDENTIAL', 'COMMERCIAL'));

COMMENT ON COLUMN price_config.customer_type IS '客户类型: RESIDENTIAL(民用)/COMMERCIAL(商用)';

-- 给已有数据打上民用标签
UPDATE price_config SET customer_type = 'RESIDENTIAL' WHERE customer_type IS NULL OR customer_type != 'RESIDENTIAL';

COMMIT;

PROMPT ========== 2. 录入商用三档电价 (config_id 从序列取) ==========

-- 商用第一档: 0-500 kWh, 0.78 元/kWh
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, updated_by, customer_type, created_at)
VALUES (seq_price_config_id.NEXTVAL, 1, '第一档(商用)', 0, 500, 0.78, DATE '2025-01-01', 'Y', 1, 'COMMERCIAL', SYSDATE);

-- 商用第二档: 501-1000 kWh, 0.95 元/kWh
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, updated_by, customer_type, created_at)
VALUES (seq_price_config_id.NEXTVAL, 2, '第二档(商用)', 501, 1000, 0.95, DATE '2025-01-01', 'Y', 1, 'COMMERCIAL', SYSDATE);

-- 商用第三档: 1000+ kWh, 1.25 元/kWh
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, updated_by, customer_type, created_at)
VALUES (seq_price_config_id.NEXTVAL, 3, '第三档(商用)', 1001, NULL, 1.25, DATE '2025-01-01', 'Y', 1, 'COMMERCIAL', SYSDATE);

COMMIT;

PROMPT ========== 3. 更新 SP1 — 按房产类型区分电价 ==========

CREATE OR REPLACE PROCEDURE sp_generate_monthly_bills(
    p_bill_month      IN VARCHAR2 DEFAULT NULL,
    p_commit_interval IN NUMBER   DEFAULT 100
) IS
    v_bill_month   VARCHAR2(6);

    -- 民用价格
    v_res_price1   price_config.unit_price%TYPE;
    v_res_price2   price_config.unit_price%TYPE;
    v_res_price3   price_config.unit_price%TYPE;
    v_res_limit1   price_config.upper_limit%TYPE;
    v_res_limit2   price_config.upper_limit%TYPE;

    -- 商用价格
    v_com_price1   price_config.unit_price%TYPE;
    v_com_price2   price_config.unit_price%TYPE;
    v_com_price3   price_config.unit_price%TYPE;
    v_com_limit1   price_config.upper_limit%TYPE;
    v_com_limit2   price_config.upper_limit%TYPE;

    -- 实际使用的价格&档位
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
        FROM   meter m
        JOIN   house h ON m.house_id = h.house_id
        WHERE  m.status = 'NORMAL'
        ORDER BY m.meter_id;

BEGIN
    DBMS_OUTPUT.PUT_LINE('===== SP1: 月度账单生成开始 (民用/商用双轨) =====');
    DBMS_OUTPUT.PUT_LINE('执行时间: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

    IF p_bill_month IS NULL THEN
        v_bill_month := TO_CHAR(ADD_MONTHS(SYSDATE, -1), 'YYYYMM');
    ELSE
        v_bill_month := p_bill_month;
    END IF;

    DBMS_OUTPUT.PUT_LINE('目标月份: ' || v_bill_month);
    v_last_month_start := TO_DATE(v_bill_month || '01', 'YYYYMMDD');
    v_last_month_end   := LAST_DAY(v_last_month_start);

    -- -------------------------------------------------------------------
    -- 获取民用电价 (customer_type='RESIDENTIAL')
    -- -------------------------------------------------------------------
    BEGIN
        SELECT unit_price INTO v_res_price1 FROM price_config
        WHERE tier_no = 1 AND is_active = 'Y' AND customer_type = 'RESIDENTIAL' AND ROWNUM = 1;
        SELECT unit_price INTO v_res_price2 FROM price_config
        WHERE tier_no = 2 AND is_active = 'Y' AND customer_type = 'RESIDENTIAL' AND ROWNUM = 1;
        SELECT unit_price INTO v_res_price3 FROM price_config
        WHERE tier_no = 3 AND is_active = 'Y' AND customer_type = 'RESIDENTIAL' AND ROWNUM = 1;
        SELECT upper_limit INTO v_res_limit1 FROM price_config
        WHERE tier_no = 1 AND is_active = 'Y' AND customer_type = 'RESIDENTIAL' AND ROWNUM = 1;
        SELECT upper_limit INTO v_res_limit2 FROM price_config
        WHERE tier_no = 2 AND is_active = 'Y' AND customer_type = 'RESIDENTIAL' AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('SP1 警告: 未找到民用电价配置');
            RAISE;
    END;

    -- -------------------------------------------------------------------
    -- 获取商用电价 (customer_type='COMMERCIAL')
    -- -------------------------------------------------------------------
    BEGIN
        SELECT unit_price INTO v_com_price1 FROM price_config
        WHERE tier_no = 1 AND is_active = 'Y' AND customer_type = 'COMMERCIAL' AND ROWNUM = 1;
        SELECT unit_price INTO v_com_price2 FROM price_config
        WHERE tier_no = 2 AND is_active = 'Y' AND customer_type = 'COMMERCIAL' AND ROWNUM = 1;
        SELECT unit_price INTO v_com_price3 FROM price_config
        WHERE tier_no = 3 AND is_active = 'Y' AND customer_type = 'COMMERCIAL' AND ROWNUM = 1;
        SELECT upper_limit INTO v_com_limit1 FROM price_config
        WHERE tier_no = 1 AND is_active = 'Y' AND customer_type = 'COMMERCIAL' AND ROWNUM = 1;
        SELECT upper_limit INTO v_com_limit2 FROM price_config
        WHERE tier_no = 2 AND is_active = 'Y' AND customer_type = 'COMMERCIAL' AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('SP1 警告: 未找到商用电价配置，商用账单将使用民用电价');
            v_com_price1 := v_res_price1; v_com_price2 := v_res_price2; v_com_price3 := v_res_price3;
            v_com_limit1 := v_res_limit1; v_com_limit2 := v_res_limit2;
    END;

    DBMS_OUTPUT.PUT_LINE('民用电价: 0-'||v_res_limit1||'度 '||v_res_price1||'元/度 | '
        ||v_res_limit1||'-'||v_res_limit2||'度 '||v_res_price2||'元/度 | '
        ||v_res_limit2||'度以上 '||v_res_price3||'元/度');
    DBMS_OUTPUT.PUT_LINE('商用电价: 0-'||v_com_limit1||'度 '||v_com_price1||'元/度 | '
        ||v_com_limit1||'-'||v_com_limit2||'度 '||v_com_price2||'元/度 | '
        ||v_com_limit2||'度以上 '||v_com_price3||'元/度');

    -- 遍历电表
    FOR rec IN c_meters LOOP
        -- 去重
        SELECT COUNT(*) INTO v_due_count FROM bill
        WHERE meter_id = rec.meter_id AND bill_month = v_bill_month;
        IF v_due_count > 0 THEN CONTINUE; END IF;

        -- 根据房产类型选择电价
        v_customer_type := rec.house_type;
        IF v_customer_type = 'COMMERCIAL' THEN
            v_price1 := v_com_price1; v_price2 := v_com_price2; v_price3 := v_com_price3;
            v_limit1 := v_com_limit1; v_limit2 := v_com_limit2;
        ELSE
            v_price1 := v_res_price1; v_price2 := v_res_price2; v_price3 := v_res_price3;
            v_limit1 := v_res_limit1; v_limit2 := v_res_limit2;
        END IF;

        -- 获取当期读数
        BEGIN
            SELECT reading_value INTO v_curr_reading FROM (
                SELECT reading_value FROM meter_reading
                WHERE meter_id = rec.meter_id AND reading_date <= v_last_month_end
                ORDER BY reading_date DESC
            ) WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN CONTINUE;
        END;

        -- 获取上期读数
        DECLARE
            v_prev_month_end DATE := LAST_DAY(ADD_MONTHS(v_last_month_start, -1));
        BEGIN
            SELECT reading_value INTO v_prev_reading FROM (
                SELECT reading_value FROM meter_reading
                WHERE meter_id = rec.meter_id AND reading_date <= v_prev_month_end
                ORDER BY reading_date DESC
            ) WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_prev_reading := rec.initial_reading;
        END;

        -- 用电量
        v_total_usage := v_curr_reading - v_prev_reading;
        IF v_total_usage < 0 THEN v_total_usage := 0; END IF;

        -- 阶梯计算
        v_tier1_usage := LEAST(v_total_usage, v_limit1);
        v_tier2_usage := GREATEST(0, LEAST(v_total_usage - v_limit1, v_limit2 - v_limit1));
        v_tier3_usage := GREATEST(0, v_total_usage - v_limit2);
        v_tier1_amount := ROUND(v_tier1_usage * v_price1, 2);
        v_tier2_amount := ROUND(v_tier2_usage * v_price2, 2);
        v_tier3_amount := ROUND(v_tier3_usage * v_price3, 2);
        v_total_amount := v_tier1_amount + v_tier2_amount + v_tier3_amount;
        v_due_date := TRUNC(SYSDATE) + 15;

        -- 插入账单
        INSERT INTO bill (
            bill_id, meter_id, bill_month,
            prev_reading, curr_reading, total_usage,
            tier1_usage, tier2_usage, tier3_usage,
            tier1_amount, tier2_amount, tier3_amount,
            total_amount, late_fee,
            status, due_date, created_at
        ) VALUES (
            seq_bill_id.NEXTVAL, rec.meter_id, v_bill_month,
            v_prev_reading, v_curr_reading, v_total_usage,
            v_tier1_usage, v_tier2_usage, v_tier3_usage,
            v_tier1_amount, v_tier2_amount, v_tier3_amount,
            v_total_amount,
            0,
            'PENDING', v_due_date, SYSDATE
        );

        v_count := v_count + 1;
        IF MOD(v_count, p_commit_interval) = 0 THEN COMMIT; END IF;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('===== SP1 完成: 生成 ' || v_count || ' 条账单 =====');
END sp_generate_monthly_bills;
/

PROMPT ========== 迁移完成 ==========
PROMPT   PRICE_CONFIG 新增 customer_type 字段
PROMPT   商用三档电价已录入 (0-500/501-1000/1000+ kWh)
PROMPT   SP1 已重编译为双轨计价
