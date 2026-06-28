-- ============================================================================
-- 民用电缴费系统 — 触发器脚本
-- 兼容版本: Oracle 11g
-- 说明: 包含两部分
--       第一部分: 11 个主键自增触发器（配合序列模拟 AUTO_INCREMENT）
--       第二部分: 4 个业务触发器 TR1~TR4
--
-- 执行顺序: 第 3 步，在建表和序列之后
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

-- 清理旧触发器
BEGIN
  FOR t IN (SELECT trigger_name FROM user_triggers
            WHERE trigger_name LIKE 'TRG_%' OR trigger_name LIKE 'TR_')
  LOOP
    EXECUTE IMMEDIATE 'DROP TRIGGER ' || t.trigger_name;
  END LOOP;
END;
/

PROMPT ========== 旧触发器已清理 ==========

-- ############################################################################
-- 第一部分: 主键自增触发器
-- 功能: 在 INSERT 前自动从对应序列取值赋给主键列
-- 命名规范: trg_<表名>_bi  (BI = Before Insert)
-- ############################################################################

-- ---------------------------------------------------------------------------
-- 1. 用户表自增触发器
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_user_bi
BEFORE INSERT ON sys_user
FOR EACH ROW
BEGIN
    -- 仅当应用程序未显式提供 user_id 时，才从序列获取
    IF :NEW.user_id IS NULL THEN
        SELECT seq_user_id.NEXTVAL INTO :NEW.user_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 2. 房产表自增触发器
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_house_bi
BEFORE INSERT ON house
FOR EACH ROW
BEGIN
    IF :NEW.house_id IS NULL THEN
        SELECT seq_house_id.NEXTVAL INTO :NEW.house_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 3. 电表表自增触发器
-- 额外功能: 自动将 initial_reading 同步到 last_reading（首次读数基准）
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_meter_bi
BEFORE INSERT ON meter
FOR EACH ROW
BEGIN
    -- 主键自增
    IF :NEW.meter_id IS NULL THEN
        SELECT seq_meter_id.NEXTVAL INTO :NEW.meter_id FROM DUAL;
    END IF;

    -- 初始化 last_reading = initial_reading，确保 TR1 计算时有基准值
    IF :NEW.last_reading IS NULL THEN
        :NEW.last_reading := :NEW.initial_reading;
    END IF;
    IF :NEW.last_reading_date IS NULL THEN
        :NEW.last_reading_date := :NEW.install_date;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 4. 抄表记录表自增触发器 (TR1 在下方的业务触发器部分)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_reading_bi
BEFORE INSERT ON meter_reading
FOR EACH ROW
BEGIN
    IF :NEW.reading_id IS NULL THEN
        SELECT seq_reading_id.NEXTVAL INTO :NEW.reading_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 5. 电价配置表自增触发器
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_price_config_bi
BEFORE INSERT ON price_config
FOR EACH ROW
BEGIN
    IF :NEW.config_id IS NULL THEN
        SELECT seq_price_config_id.NEXTVAL INTO :NEW.config_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 6. 账单表自增触发器 (TR4b 在下方的业务触发器部分)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bill_bi
BEFORE INSERT ON bill
FOR EACH ROW
BEGIN
    IF :NEW.bill_id IS NULL THEN
        SELECT seq_bill_id.NEXTVAL INTO :NEW.bill_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 7. 缴费记录表自增触发器 (TR3 在下方的业务触发器部分)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_payment_bi
BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
    IF :NEW.payment_id IS NULL THEN
        SELECT seq_payment_id.NEXTVAL INTO :NEW.payment_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 8. 通知表自增触发器
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_notif_bi
BEFORE INSERT ON notification
FOR EACH ROW
BEGIN
    IF :NEW.notif_id IS NULL THEN
        SELECT seq_notif_id.NEXTVAL INTO :NEW.notif_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 9. 告警表自增触发器
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_alert_bi
BEFORE INSERT ON alert
FOR EACH ROW
BEGIN
    IF :NEW.alert_id IS NULL THEN
        SELECT seq_alert_id.NEXTVAL INTO :NEW.alert_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 10. 工单表自增触发器
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ticket_bi
BEFORE INSERT ON ticket
FOR EACH ROW
BEGIN
    IF :NEW.ticket_id IS NULL THEN
        SELECT seq_ticket_id.NEXTVAL INTO :NEW.ticket_id FROM DUAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------------
-- 11. 工单回复表自增触发器
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_reply_bi
BEFORE INSERT ON ticket_reply
FOR EACH ROW
BEGIN
    IF :NEW.reply_id IS NULL THEN
        SELECT seq_reply_id.NEXTVAL INTO :NEW.reply_id FROM DUAL;
    END IF;
END;
/

PROMPT ========== 11 个自增触发器创建完毕 ==========


-- ############################################################################
-- 第二部分: 业务触发器 (TR1 ~ TR4)
-- ############################################################################

-- ============================================================================
-- TR1: 用电量自动计算触发器
-- 触发时机: BEFORE INSERT ON meter_reading（在自增触发器 trg_reading_bi 之后执行）
-- 核心逻辑:
--   1. 从 meter 表获取 last_reading（上一日累计读数）
--   2. 计算 :NEW.daily_usage = :NEW.reading_value - last_reading
--   3. 若 daily_usage < 0，在 remarks 中标记 'REVERSAL_DETECTED'（倒转检测）
--   4. 后续由 TR4a 将倒转记录正式写入 alert 表
--
-- 设计要点:
--   - 读取 meter 表（不同表）不会触发 ORA-04091 变异表错误
--   - "FOLLOWS trg_reading_bi" 确保自增触发器先执行，:NEW.reading_id 已赋值
-- ============================================================================
CREATE OR REPLACE TRIGGER tr1_calc_daily_usage
BEFORE INSERT ON meter_reading
FOR EACH ROW
FOLLOWS trg_reading_bi
DECLARE
    v_last_reading      meter.last_reading%TYPE;       -- 电表最近一次读数
    v_last_reading_date meter.last_reading_date%TYPE;  -- 最近一次读数日期
BEGIN
    -- 步骤1: 从 meter 表获取当前电表的最新读数快照
    --        meter.last_reading 由后置触发器 trg_meter_update_snapshot 维护
    SELECT last_reading, last_reading_date
    INTO   v_last_reading, v_last_reading_date
    FROM   meter
    WHERE  meter_id = :NEW.meter_id;

    -- 步骤2: 计算当日用电增量
    --        在有历史读数的前提下:
    --          daily_usage = 本次累计读数 - 上次累计读数
    --        无历史读数（电表刚安装）:
    --          daily_usage = 本次读数 - 初始读数 (因为 last_reading = initial_reading)
    :NEW.daily_usage := :NEW.reading_value - v_last_reading;

    -- 步骤3: 倒转检测 — 当日用电量为负，说明读数异常
    --        在 remarks 中留下标记，由 TR4b 正式创建告警记录
    IF :NEW.daily_usage < 0 THEN
        :NEW.remarks := 'REVERSAL_DETECTED: reading dropped from '
                     || TO_CHAR(v_last_reading) || ' to ' || TO_CHAR(:NEW.reading_value);
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- 极端情况: meter 表中无对应记录(不应发生，外键约束会先报错)
        :NEW.daily_usage := 0;
        :NEW.remarks := 'ERROR: meter not found';
    WHEN OTHERS THEN
        :NEW.daily_usage := 0;
        :NEW.remarks := 'ERROR: ' || SQLERRM;
END tr1_calc_daily_usage;
/

-- ============================================================================
-- 配套触发器: 电表读数快照更新
-- 触发时机: AFTER INSERT ON meter_reading
-- 功能: 每次插入抄表记录后，将最新读数同步回 meter 表的快照字段
--       这样 TR1 下次触发时可以直接从 meter.last_reading 获取基准值
-- ============================================================================
CREATE OR REPLACE TRIGGER trg_meter_update_snapshot
AFTER INSERT ON meter_reading
FOR EACH ROW
BEGIN
    -- 将本次抄表的读数写回 meter 表，作为下次计算的基准
    UPDATE meter
    SET last_reading      = :NEW.reading_value,
        last_reading_date = :NEW.reading_date
    WHERE meter_id = :NEW.meter_id;
END;
/

-- ============================================================================
-- TR2: 欠费通知自动生成触发器
-- 触发时机: AFTER UPDATE ON bill（当 status 字段更新为 'OVERDUE' 时）
-- 核心逻辑:
--   1. 检测 :NEW.status = 'OVERDUE' 且 :OLD.status <> 'OVERDUE'
--      （只有"刚变成"OVERDUE 时才触发，避免重复通知）
--   2. 查询该电表对应的业主（通过 meter → house → sys_user 链路）
--   3. 向 notification 表插入一条欠费提醒
--
-- 实际触发路径:
--   - 由 SP2（每日滞纳金计算）在更新 bill.status 为 'OVERDUE' 时触发
--   - 或应用程序直接将账单标记为逾期时触发
-- ============================================================================
CREATE OR REPLACE TRIGGER tr2_arrears_notify
AFTER UPDATE ON bill
FOR EACH ROW
DECLARE
    v_user_id   sys_user.user_id%TYPE;      -- 业主ID
    v_address   house.address%TYPE;         -- 房屋地址（用于通知内容）
    v_notif_id  notification.notif_id%TYPE; -- 检查是否已有同类通知
BEGIN
    -- 步骤1: 检查触发条件 — 仅当状态从非OVERDUE变为OVERDUE时触发
    IF :NEW.status = 'OVERDUE' AND NVL(:OLD.status, 'PENDING') <> 'OVERDUE' THEN

        -- 步骤2: 通过三表联查获取业主信息
        --        meter → house → sys_user
        SELECT u.user_id, h.address
        INTO   v_user_id, v_address
        FROM   meter m
        JOIN   house h ON m.house_id = h.house_id
        JOIN   sys_user u ON h.user_id = u.user_id
        WHERE  m.meter_id = :NEW.meter_id;

        -- 步骤3: 检查是否已存在同一账单的欠费通知（去重）
        SELECT COUNT(*) INTO v_notif_id
        FROM   notification
        WHERE  user_id    = v_user_id
          AND  type       = 'ARREARS'
          AND  related_id = :NEW.bill_id;

        -- 步骤4: 若无重复，插入欠费通知
        IF v_notif_id = 0 THEN
            INSERT INTO notification (
                user_id, type, title, content, related_id, is_read, created_at
            ) VALUES (
                v_user_id,
                'ARREARS',
                '电费欠费提醒',
                '您位于 ' || v_address || ' 的房产（电表号：'
                || :NEW.meter_id || '）' || :NEW.bill_month
                || ' 月电费账单已逾期。应缴金额：'
                || TO_CHAR(:NEW.total_amount, 'FM999990.00') || '元，'
                || '滞纳金：' || TO_CHAR(:NEW.late_fee, 'FM999990.00') || '元。'
                || '请尽快缴费，以免影响用电。',
                :NEW.bill_id,
                'N',
                SYSDATE
            );
        END IF;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- 找不到业主信息（数据完整性异常）
        DBMS_OUTPUT.PUT_LINE('TR2: 无法为账单 ' || :NEW.bill_id || ' 找到业主信息');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('TR2 异常: ' || SQLERRM);
END tr2_arrears_notify;
/

-- ============================================================================
-- TR3: 缴费后自动更新账单状态触发器
-- 触发时机: AFTER INSERT ON payment
-- 核心逻辑:
--   1. 根据 :NEW.bill_id 找到对应账单
--   2. 更新账单状态为 'PAID'，记录缴费日期
--   3. 向业主发送缴费确认通知
--
-- 事务控制说明:
--   此触发器与 INSERT payment 属于同一事务。
--   若更新 bill 或插入 notification 失败，整个插入回滚。
-- ============================================================================
CREATE OR REPLACE TRIGGER tr3_payment_update_bill
AFTER INSERT ON payment
FOR EACH ROW
DECLARE
    v_user_id    sys_user.user_id%TYPE;
    v_bill_month bill.bill_month%TYPE;
    v_amount     bill.total_amount%TYPE;
BEGIN
    -- 步骤1: 更新对应账单为已缴费状态
    --        同时记录实际缴费日期
    UPDATE bill
    SET status       = 'PAID',
        payment_date = :NEW.payment_time
    WHERE bill_id    = :NEW.bill_id;

    -- 步骤2: 获取账单信息用于通知内容
    SELECT b.bill_month, b.total_amount
    INTO   v_bill_month, v_amount
    FROM   bill b
    WHERE  b.bill_id = :NEW.bill_id;

    -- 步骤3: 向缴费人发送缴费成功通知
    INSERT INTO notification (
        user_id, type, title, content, related_id, is_read, created_at
    ) VALUES (
        :NEW.payer_id,
        'PAYMENT_CONFIRM',
        '缴费成功通知',
        '您已成功缴纳 ' || v_bill_month || ' 月电费 '
        || TO_CHAR(v_amount, 'FM999990.00') || '元。'
        || CASE WHEN :NEW.late_fee_paid > 0
               THEN '（含滞纳金 ' || TO_CHAR(:NEW.late_fee_paid, 'FM999990.00') || '元）'
               ELSE ''
          END
        || '感谢您的使用！',
        :NEW.bill_id,
        'N',
        SYSDATE
    );

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('TR3 异常: ' || SQLERRM);
        RAISE;  -- 抛出异常，使整个 INSERT payment 回滚
END tr3_payment_update_bill;
/

-- ============================================================================
-- TR4: 异常检测触发器
-- 分为两个独立触发器:
--   TR4a: 插入抄表记录后检测"读数倒转"（行级触发器，插入 alert）
--   TR4b: 插入账单后检测"用电飙升/骤降"（复合触发器，避免变异表问题）
-- ============================================================================

-- ---------------------------------------------------------------------------
-- TR4a: 抄表数据倒转检测
-- 触发时机: AFTER INSERT ON meter_reading
-- 核心逻辑:
--   - 检查 remarks 字段是否包含 'REVERSAL_DETECTED'（由 TR1 标记）
--   - 如是，则向 alert 表插入一条 REVERSAL 类型告警
--   - 同时向该电表的业主发送告警通知
--
-- 注意: 此触发器与 trg_meter_update_snapshot 同是 AFTER INSERT on meter_reading，
--       使用 FOLLOWS 子句确保先更新快照再检测异常（不依赖顺序，但更清晰）
-- ============================================================================
CREATE OR REPLACE TRIGGER tr4a_reversal_detect
AFTER INSERT ON meter_reading
FOR EACH ROW
DECLARE
    v_user_id   sys_user.user_id%TYPE;
    v_alert_id  NUMBER;
BEGIN
    -- 步骤1: 检查 TR1 是否在 remarks 中标记了倒转
    IF :NEW.remarks LIKE '%REVERSAL_DETECTED%' THEN

        -- 步骤2: 查找业主
        SELECT u.user_id INTO v_user_id
        FROM   meter m
        JOIN   house h ON m.house_id = h.house_id
        JOIN   sys_user u ON h.user_id = u.user_id
        WHERE  m.meter_id = :NEW.meter_id;

        -- 步骤3: 创建异常告警
        INSERT INTO alert (
            alert_id, meter_id, bill_id, type, level,
            description, status, handler_id, handled_at, created_at
        ) VALUES (
            seq_alert_id.NEXTVAL,
            :NEW.meter_id,
            NULL,                -- 倒转不关联特定账单
            'REVERSAL',
            'CRITICAL',          -- 倒转是严重异常
            :NEW.remarks,        -- 使用 TR1 写入的详细信息
            'PENDING',
            NULL,
            NULL,
            SYSDATE
        )
        RETURNING alert_id INTO v_alert_id;

        -- 步骤4: 通知业主
        INSERT INTO notification (
            user_id, type, title, content, related_id, is_read, created_at
        ) VALUES (
            v_user_id,
            'ANOMALY',
            '电表读数异常告警',
            '您的电表（ID: ' || :NEW.meter_id || '）在 '
            || TO_CHAR(:NEW.reading_date, 'YYYY-MM-DD')
            || ' 检测到读数倒转异常，请联系供电公司核查。',
            v_alert_id,
            'N',
            SYSDATE
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('TR4a: 找不到电表 ' || :NEW.meter_id || ' 的业主');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('TR4a 异常: ' || SQLERRM);
END tr4a_reversal_detect;
/

-- ---------------------------------------------------------------------------
-- TR4b: 用电量飙升/骤降检测（复合触发器）
-- 触发时机: AFTER INSERT ON bill
-- 为什么用复合触发器:
--   需要在 AFTER STATEMENT 阶段查询 bill 表计算历史月均值，
--   行级触发器中查询 bill 表会导致 ORA-04091 变异表错误。
--   Oracle 11g 的复合触发器 (COMPOUND TRIGGER) 可以完美解决此问题。
--
-- 复合触发器结构:
--   BEFORE STATEMENT  — 整个语句执行前（初始化）
--   BEFORE EACH ROW    — 每行插入前
--   AFTER EACH ROW     — 每行插入后【收集数据】
--   AFTER STATEMENT    — 整个语句执行后【处理数据，可安全查询 bill 表】
--
-- 核心逻辑:
--   1. AFTER EACH ROW: 收集所有新插入账单的 (bill_id, meter_id, total_usage, bill_month)
--   2. AFTER STATEMENT: 遍历收集到的账单
--      a) 查询该 meter 最近 6 个月的平均用电量
--      b) 对比本月用量:
--         - total_usage > avg * 2  → SURGE (飙升)
--         - total_usage < avg * 0.5 → PLUNGE (骤降)
--      c) 插入 alert 和 notification
-- ============================================================================
CREATE OR REPLACE TRIGGER tr4b_surge_plunge_detect
FOR INSERT ON bill
COMPOUND TRIGGER

    -- =========================================================================
    -- 声明部分: 定义数据结构用于跨阶段共享数据
    -- =========================================================================

    -- 定义单条账单记录类型
    TYPE bill_rec IS RECORD (
        bill_id    bill.bill_id%TYPE,
        meter_id   bill.meter_id%TYPE,
        total_usage bill.total_usage%TYPE,
        bill_month bill.bill_month%TYPE
    );

    -- 定义账单记录集合（变长数组）
    TYPE bill_tab IS TABLE OF bill_rec INDEX BY PLS_INTEGER;

    -- 用于在行级和语句级之间传递数据的全局变量
    v_bills    bill_tab;  -- 收集到的账单列表
    v_count    PLS_INTEGER := 0;  -- 计数器

    -- =========================================================================
    -- BEFORE STATEMENT: 语句级前置（初始化集合）
    -- =========================================================================
    BEFORE STATEMENT IS
    BEGIN
        v_count := 0;
        -- 清空集合（Oracle 复合触发器中无需显式清空，但良好的编程习惯）
        v_bills.DELETE;
    END BEFORE STATEMENT;

    -- =========================================================================
    -- AFTER EACH ROW: 行级后置（收集每行数据）
    -- =========================================================================
    AFTER EACH ROW IS
    BEGIN
        v_count := v_count + 1;
        -- 将新插入的账单信息存入集合
        v_bills(v_count).bill_id    := :NEW.bill_id;
        v_bills(v_count).meter_id   := :NEW.meter_id;
        v_bills(v_count).total_usage := :NEW.total_usage;
        v_bills(v_count).bill_month := :NEW.bill_month;
    END AFTER EACH ROW;

    -- =========================================================================
    -- AFTER STATEMENT: 语句级后置（执行异常检测）
    --   此时所有行已插入 bill 表，可以安全查询
    -- =========================================================================
    AFTER STATEMENT IS
        -- 历史月均用电量（游标变量）
        v_avg_usage  NUMBER(10,2);
        v_user_id    sys_user.user_id%TYPE;
        v_address    house.address%TYPE;
        v_alert_id   alert.alert_id%TYPE;
        v_notif_id   notification.notif_id%TYPE;
    BEGIN
        -- 遍历所有新插入的账单
        FOR i IN 1..v_count LOOP

            -- ---------------------------------------------------------------
            -- 步骤1: 计算该电表最近6个月的平均用电量
            --        排除本月（bill_month < 当前月），最多取6条
            -- ---------------------------------------------------------------
            BEGIN
                SELECT AVG(total_usage) INTO v_avg_usage
                FROM (
                    SELECT total_usage
                    FROM   bill
                    WHERE  meter_id   = v_bills(i).meter_id
                      AND  bill_month < v_bills(i).bill_month
                      AND  status     IN ('PAID', 'PENDING', 'OVERDUE')
                      -- 排除异常数据：用量为 0 的记录可能是数据问题
                      AND  total_usage > 0
                    ORDER BY bill_month DESC
                )
                WHERE ROWNUM <= 6;  -- Oracle 11g 不支持 FETCH FIRST，用 ROWNUM

                -- 如果聚合结果为 NULL（没有历史数据），跳过本次检测
                IF v_avg_usage IS NULL OR v_avg_usage = 0 THEN
                    CONTINUE;
                END IF;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- 没有历史账单，跳过（新装电表正常情况）
                    CONTINUE;
            END;

            -- ---------------------------------------------------------------
            -- 步骤2: 判断异常类型
            --   SURGE  (飙升): 本月 > 历史均值 × 2
            --   PLUNGE (骤降): 本月 < 历史均值 × 0.5
            -- ---------------------------------------------------------------
            IF v_bills(i).total_usage > v_avg_usage * 2 THEN

                -- 步骤3a: 飙升告警
                -- 查找业主信息
                BEGIN
                    SELECT u.user_id, h.address
                    INTO   v_user_id, v_address
                    FROM   meter m
                    JOIN   house h ON m.house_id = h.house_id
                    JOIN   sys_user u ON h.user_id = u.user_id
                    WHERE  m.meter_id = v_bills(i).meter_id;

                    -- 插入告警记录
                    INSERT INTO alert (
                        alert_id, meter_id, bill_id, type, level,
                        description, status, created_at
                    ) VALUES (
                        seq_alert_id.NEXTVAL,
                        v_bills(i).meter_id,
                        v_bills(i).bill_id,
                        'SURGE',
                        'WARN',
                        '用电量飙升异常：本月用电 '
                        || TO_CHAR(v_bills(i).total_usage, 'FM999990.00') || ' 度，'
                        || '近6个月均值 ' || TO_CHAR(v_avg_usage, 'FM999990.00') || ' 度，'
                        || '增幅 ' || TO_CHAR(ROUND((v_bills(i).total_usage/v_avg_usage - 1) * 100, 1))
                        || '%。地址: ' || v_address,
                        'PENDING',
                        SYSDATE
                    )
                    RETURNING alert_id INTO v_alert_id;

                    -- 通知业主
                    INSERT INTO notification (
                        user_id, type, title, content, related_id, is_read, created_at
                    ) VALUES (
                        v_user_id, 'ANOMALY',
                        '用电量飙升提醒',
                        '您位于 ' || v_address || ' 的房产本月用电量异常偏高（'
                        || TO_CHAR(v_bills(i).total_usage, 'FM999990.00') || '度），'
                        || '超过历史均值（' || TO_CHAR(v_avg_usage, 'FM999990.00')
                        || '度）的200%。请检查是否有漏电或异常用电情况。',
                        v_alert_id, 'N', SYSDATE
                    );

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        DBMS_OUTPUT.PUT_LINE('TR4b: 找不到电表 ' || v_bills(i).meter_id || ' 的业主');
                END;

            ELSIF v_bills(i).total_usage < v_avg_usage * 0.5 THEN

                -- 步骤3b: 骤降告警
                BEGIN
                    SELECT u.user_id, h.address
                    INTO   v_user_id, v_address
                    FROM   meter m
                    JOIN   house h ON m.house_id = h.house_id
                    JOIN   sys_user u ON h.user_id = u.user_id
                    WHERE  m.meter_id = v_bills(i).meter_id;

                    INSERT INTO alert (
                        alert_id, meter_id, bill_id, type, level,
                        description, status, created_at
                    ) VALUES (
                        seq_alert_id.NEXTVAL,
                        v_bills(i).meter_id,
                        v_bills(i).bill_id,
                        'PLUNGE',
                        'INFO',
                        '用电量骤降异常：本月用电 '
                        || TO_CHAR(v_bills(i).total_usage, 'FM999990.00') || ' 度，'
                        || '近6个月均值 ' || TO_CHAR(v_avg_usage, 'FM999990.00') || ' 度，'
                        || '降幅 ' || TO_CHAR(ROUND((1 - v_bills(i).total_usage/v_avg_usage) * 100, 1))
                        || '%。地址: ' || v_address,
                        'PENDING',
                        SYSDATE
                    )
                    RETURNING alert_id INTO v_alert_id;

                    INSERT INTO notification (
                        user_id, type, title, content, related_id, is_read, created_at
                    ) VALUES (
                        v_user_id, 'ANOMALY',
                        '用电量骤降提醒',
                        '您位于 ' || v_address || ' 的房产本月用电量异常偏低（'
                        || TO_CHAR(v_bills(i).total_usage, 'FM999990.00') || '度），'
                        || '不足历史均值（' || TO_CHAR(v_avg_usage, 'FM999990.00')
                        || '度）的50%。若房屋空置属正常，否则请检查电表是否故障。',
                        v_alert_id, 'N', SYSDATE
                    );

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        DBMS_OUTPUT.PUT_LINE('TR4b: 找不到电表 ' || v_bills(i).meter_id || ' 的业主');
                END;

            END IF;  -- 异常判断结束

        END LOOP;  -- 账单遍历结束

    END AFTER STATEMENT;

END tr4b_surge_plunge_detect;
/

PROMPT ========== 业务触发器创建完毕 ==========
PROMPT
PROMPT 触发器清单:
PROMPT   自增触发器 (11个):
PROMPT     trg_user_bi         - SYS_USER 主键自增
PROMPT     trg_house_bi        - HOUSE 主键自增
PROMPT     trg_meter_bi        - METER 主键自增 + 读数快照初始化
PROMPT     trg_reading_bi      - METER_READING 主键自增
PROMPT     trg_price_config_bi - PRICE_CONFIG 主键自增
PROMPT     trg_bill_bi         - BILL 主键自增
PROMPT     trg_payment_bi      - PAYMENT 主键自增
PROMPT     trg_notif_bi        - NOTIFICATION 主键自增
PROMPT     trg_alert_bi        - ALERT 主键自增
PROMPT     trg_ticket_bi       - TICKET 主键自增
PROMPT     trg_reply_bi        - TICKET_REPLY 主键自增
PROMPT
PROMPT   业务触发器 (5个):
PROMPT     TR1  tr1_calc_daily_usage      - 插入抄表记录: 自动计算日用电量
PROMPT          trg_meter_update_snapshot  - 插入抄表记录: 更新电表读数快照
PROMPT     TR2  tr2_arrears_notify        - 账单逾期: 自动生成欠费通知
PROMPT     TR3  tr3_payment_update_bill   - 缴费成功: 自动更新账单状态
PROMPT     TR4a tr4a_reversal_detect      - 抄表异常: 检测读数倒转
PROMPT     TR4b tr4b_surge_plunge_detect  - 账单生成: 检测用电飙升/骤降(复合触发器)
PROMPT
PROMPT ========== 03_create_triggers.sql 执行完毕 ==========
