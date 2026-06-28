-- ============================================================================
-- 民用电缴费系统 — 视图脚本
-- 兼容版本: Oracle 11g
-- 说明: 创建 6 个核心业务视图，简化常用查询，供后端接口直接调用
-- 执行顺序: 第 5 步，在建表、序列、触发器、存储过程之后
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 300

-- 清理旧视图
BEGIN
  FOR v IN (SELECT view_name FROM user_views
            WHERE view_name LIKE 'V_%')
  LOOP
    EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
  END LOOP;
END;
/

PROMPT ========== 旧视图已清理 ==========

-- ============================================================================
-- 视图1: V_USER_BILLS — 用户账单视图
-- 用途: 居民查看自己名下所有房产的电费账单
-- 联表: bill → meter → house → sys_user
-- 包含: 业主信息、房屋地址、电表编号、账期、用电量、阶梯明细、缴费状态
-- ============================================================================
CREATE OR REPLACE VIEW v_user_bills AS
SELECT
    u.user_id,
    u.real_name     AS owner_name,
    u.phone         AS owner_phone,
    h.house_id,
    h.address       AS house_address,
    m.meter_id,
    m.meter_no,
    b.bill_id,
    b.bill_month,
    b.prev_reading,
    b.curr_reading,
    b.total_usage,
    b.tier1_usage,
    b.tier2_usage,
    b.tier3_usage,
    b.tier1_amount,
    b.tier2_amount,
    b.tier3_amount,
    b.total_amount,
    b.late_fee,
    b.total_amount + b.late_fee AS total_due,  -- 应缴总额（含滞纳金）
    b.status,
    b.due_date,
    b.payment_date,
    CASE
        WHEN b.status = 'PAID' THEN 0
        WHEN b.status = 'OVERDUE' THEN TRUNC(SYSDATE) - TRUNC(b.due_date)
        WHEN b.due_date >= TRUNC(SYSDATE) THEN 0
        ELSE TRUNC(SYSDATE) - TRUNC(b.due_date)
    END AS days_overdue,                        -- 逾期天数
    b.created_at
FROM
    bill b
    JOIN meter m ON b.meter_id = m.meter_id
    JOIN house h ON m.house_id = h.house_id
    JOIN sys_user u ON h.user_id = u.user_id
ORDER BY
    u.user_id, h.house_id, b.bill_month DESC;

COMMENT ON TABLE v_user_bills IS '用户账单视图: 居民查看名下所有房产的电费账单';

-- ============================================================================
-- 视图2: V_METER_USAGE_SUMMARY — 电表月度用电统计视图
-- 用途: 管理员/收费员查看各电表月度用电趋势
-- 联表: bill → meter → house
-- 包含: 当月用电量、同比变化率、环比变化率
-- ============================================================================
CREATE OR REPLACE VIEW v_meter_usage_summary AS
SELECT
    b.meter_id,
    m.meter_no,
    h.address,
    b.bill_month,
    b.total_usage,
    b.total_amount,
    b.late_fee,
    b.status,
    -- 环比变化率: (本月 - 上月) / 上月 × 100
    CASE
        WHEN LAG(b.total_usage) OVER (
            PARTITION BY b.meter_id ORDER BY b.bill_month
        ) IS NOT NULL
        AND LAG(b.total_usage) OVER (
            PARTITION BY b.meter_id ORDER BY b.bill_month
        ) > 0
        THEN ROUND(
            (b.total_usage - LAG(b.total_usage) OVER (
                PARTITION BY b.meter_id ORDER BY b.bill_month
            )) / LAG(b.total_usage) OVER (
                PARTITION BY b.meter_id ORDER BY b.bill_month
            ) * 100, 1
        )
        ELSE NULL
    END AS mom_change_pct,  -- Month-over-Month 环比
    -- 同比变化率: (本月 - 去年同月) / 去年同月 × 100
    CASE
        WHEN LAG(b.total_usage, 12) OVER (
            PARTITION BY b.meter_id ORDER BY b.bill_month
        ) IS NOT NULL
        AND LAG(b.total_usage, 12) OVER (
            PARTITION BY b.meter_id ORDER BY b.bill_month
        ) > 0
        THEN ROUND(
            (b.total_usage - LAG(b.total_usage, 12) OVER (
                PARTITION BY b.meter_id ORDER BY b.bill_month
            )) / LAG(b.total_usage, 12) OVER (
                PARTITION BY b.meter_id ORDER BY b.bill_month
            ) * 100, 1
        )
        ELSE NULL
    END AS yoy_change_pct,  -- Year-over-Year 同比
    b.created_at
FROM
    bill b
    JOIN meter m ON b.meter_id = m.meter_id
    JOIN house h ON m.house_id = h.house_id
ORDER BY
    b.meter_id, b.bill_month;

COMMENT ON TABLE v_meter_usage_summary IS '电表月度用电统计视图: 含环比/同比变化率';

-- ============================================================================
-- 视图3: V_PENDING_ALERTS — 待处理异常告警视图
-- 用途: 管理员/收费员查看所有未处理的异常告警
-- 联表: alert → meter → house → sys_user
-- 包含: 告警详情、电表信息、业主联系方式
-- ============================================================================
CREATE OR REPLACE VIEW v_pending_alerts AS
SELECT
    a.alert_id,
    a.type         AS alert_type,
    a.level        AS alert_level,
    a.description,
    a.status       AS alert_status,
    a.created_at   AS alert_time,
    m.meter_id,
    m.meter_no,
    h.address      AS house_address,
    u.user_id      AS owner_id,
    u.real_name    AS owner_name,
    u.phone        AS owner_phone,
    a.bill_id,
    b.bill_month,
    b.total_usage,
    b.total_amount
FROM
    alert a
    JOIN meter m ON a.meter_id = m.meter_id
    JOIN house h ON m.house_id = h.house_id
    JOIN sys_user u ON h.user_id = u.user_id
    LEFT JOIN bill b ON a.bill_id = b.bill_id
WHERE
    a.status = 'PENDING'
ORDER BY
    CASE a.level
        WHEN 'CRITICAL' THEN 1
        WHEN 'WARN' THEN 2
        WHEN 'INFO' THEN 3
    END,
    a.created_at DESC;

COMMENT ON TABLE v_pending_alerts IS '待处理异常告警视图: 按严重级别排序';

-- ============================================================================
-- 视图4: V_TICKET_DETAILS — 工单详情视图
-- 用途: 管理员/收费员查看工单及其回复
-- 联表: ticket → sys_user(提交人) → ticket_reply → sys_user(回复人)
-- 包含: 工单信息、提交人、回复内容、回复人
-- ============================================================================
CREATE OR REPLACE VIEW v_ticket_details AS
SELECT
    t.ticket_id,
    t.type         AS ticket_type,
    t.title,
    t.description,
    t.status       AS ticket_status,
    t.created_at   AS submit_time,
    t.replied_at   AS reply_time,
    submitter.user_id   AS submitter_id,
    submitter.real_name AS submitter_name,
    tr.reply_id,
    tr.content     AS reply_content,
    tr.created_at  AS reply_created_at,
    replier.user_id     AS replier_id,
    replier.real_name   AS replier_name
FROM
    ticket t
    JOIN sys_user submitter ON t.user_id = submitter.user_id
    LEFT JOIN ticket_reply tr ON t.ticket_id = tr.ticket_id
    LEFT JOIN sys_user replier ON tr.replier_id = replier.user_id
ORDER BY
    CASE t.status WHEN 'PENDING' THEN 0 ELSE 1 END,
    t.created_at DESC;

COMMENT ON TABLE v_ticket_details IS '工单详情视图: 含提交人、回复内容、回复人';

-- ============================================================================
-- 视图5: V_REVENUE_SUMMARY — 月度营收汇总视图
-- 用途: 管理员查看各月度的电费收入统计
-- 数据来源: payment 表（仅已缴费账单）
-- 包含: 已缴户数、电费收入、滞纳金收入、线上/线下占比
-- ============================================================================
CREATE OR REPLACE VIEW v_revenue_summary AS
SELECT
    SUBSTR(b.bill_month, 1, 4) AS year,
    SUBSTR(b.bill_month, 5, 2) AS month,
    b.bill_month,
    COUNT(DISTINCT b.bill_id)  AS total_bills,        -- 总账单数
    COUNT(DISTINCT CASE WHEN b.status = 'PAID' THEN b.bill_id END)
                                AS paid_bills,         -- 已缴账单数
    NVL(SUM(CASE WHEN b.status = 'PAID' THEN p.amount ELSE 0 END), 0)
                                AS total_revenue,      -- 总电费收入
    NVL(SUM(CASE WHEN b.status = 'PAID' THEN p.late_fee_paid ELSE 0 END), 0)
                                AS total_late_fee,     -- 总滞纳金收入
    NVL(SUM(CASE WHEN b.status = 'PAID' AND p.channel = 'ONLINE' THEN p.amount ELSE 0 END), 0)
                                AS online_revenue,     -- 线上收入
    NVL(SUM(CASE WHEN b.status = 'PAID' AND p.channel = 'OFFLINE' THEN p.amount ELSE 0 END), 0)
                                AS offline_revenue,    -- 线下收入
    COUNT(CASE WHEN b.status = 'OVERDUE' THEN 1 END)
                                AS overdue_bills,      -- 欠费账单数
    NVL(SUM(CASE WHEN b.status = 'OVERDUE' THEN b.total_amount + b.late_fee ELSE 0 END), 0)
                                AS outstanding_amount  -- 应收未收金额
FROM
    bill b
    LEFT JOIN payment p ON b.bill_id = p.bill_id
GROUP BY
    SUBSTR(b.bill_month, 1, 4),
    SUBSTR(b.bill_month, 5, 2),
    b.bill_month
ORDER BY
    b.bill_month DESC;

COMMENT ON TABLE v_revenue_summary IS '月度营收汇总视图: 电费+滞纳金+渠道占比';

-- ============================================================================
-- 视图6: V_METER_DAILY_USAGE — 电表每日用电趋势视图
-- 用途: 前端折线图展示某个电表的日用电趋势
-- 数据来源: meter_reading
-- 包含: 日期、日用电量、累计读数、7日移动平均
-- ============================================================================
CREATE OR REPLACE VIEW v_meter_daily_usage AS
SELECT
    mr.reading_id,
    mr.meter_id,
    m.meter_no,
    h.address       AS house_address,
    mr.reading_date,
    mr.reading_value,
    mr.daily_usage,
    mr.reading_type,
    mr.remarks,
    -- 7日移动平均: 平滑日用电波动，展示趋势
    ROUND(AVG(mr.daily_usage) OVER (
        PARTITION BY mr.meter_id
        ORDER BY mr.reading_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS ma_7day  -- Moving Average 7-day
FROM
    meter_reading mr
    JOIN meter m ON mr.meter_id = m.meter_id
    JOIN house h ON m.house_id = h.house_id
ORDER BY
    mr.meter_id, mr.reading_date;

COMMENT ON TABLE v_meter_daily_usage IS '电表日用电趋势视图: 含7日移动平均线';

PROMPT ========== 6 个业务视图创建完毕 ==========
PROMPT
PROMPT 视图清单:
PROMPT   V_USER_BILLS          - 用户账单视图 (居民查账单)
PROMPT   V_METER_USAGE_SUMMARY  - 电表月度统计视图 (含环比/同比)
PROMPT   V_PENDING_ALERTS       - 待处理告警视图 (按严重级别排序)
PROMPT   V_TICKET_DETAILS       - 工单详情视图 (含回复)
PROMPT   V_REVENUE_SUMMARY      - 月度营收汇总视图 (电费+渠道占比)
PROMPT   V_METER_DAILY_USAGE    - 日用电趋势视图 (含7日移动平均)
PROMPT
PROMPT ========== 05_create_views.sql 执行完毕 ==========
