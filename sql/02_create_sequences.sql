-- ============================================================================
-- 民用电缴费系统 — 序列创建脚本
-- 兼容版本: Oracle 11g
-- 说明: 为每张主表创建自增序列，Oracle 11g 不支持 IDENTITY 列，用序列+触发器模拟
-- 执行顺序: 第 2 步，在建表之后、业务触发器之前执行
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

-- 清理旧序列
BEGIN
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name LIKE 'SEQ_%')
  LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

PROMPT ========== 旧序列已清理 ==========

-- ============================================================================
-- 序列定义规则：
--   START WITH 1001   — 从 1001 开始，为手动插入预留 1~1000 范围
--   INCREMENT BY 1    — 每次递增 1
--   NOCACHE           — 不缓存（课程设计环境，避免序列断层困惑）
--   NOCYCLE           — 不循环
-- ============================================================================

-- 用户序列
CREATE SEQUENCE seq_user_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 房产序列
CREATE SEQUENCE seq_house_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 电表序列
CREATE SEQUENCE seq_meter_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 抄表记录序列
CREATE SEQUENCE seq_reading_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 电价配置序列
CREATE SEQUENCE seq_price_config_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 账单序列
CREATE SEQUENCE seq_bill_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 缴费记录序列
CREATE SEQUENCE seq_payment_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 通知序列
CREATE SEQUENCE seq_notif_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 告警序列
CREATE SEQUENCE seq_alert_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 工单序列
CREATE SEQUENCE seq_ticket_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- 工单回复序列
CREATE SEQUENCE seq_reply_id
    START WITH 1001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

PROMPT ========== 11 个序列创建完毕 ==========
PROMPT
PROMPT 序列清单:
PROMPT   SEQ_USER_ID          → SYS_USER
PROMPT   SEQ_HOUSE_ID         → HOUSE
PROMPT   SEQ_METER_ID         → METER
PROMPT   SEQ_READING_ID       → METER_READING
PROMPT   SEQ_PRICE_CONFIG_ID  → PRICE_CONFIG
PROMPT   SEQ_BILL_ID          → BILL
PROMPT   SEQ_PAYMENT_ID       → PAYMENT
PROMPT   SEQ_NOTIF_ID         → NOTIFICATION
PROMPT   SEQ_ALERT_ID         → ALERT
PROMPT   SEQ_TICKET_ID        → TICKET
PROMPT   SEQ_REPLY_ID         → TICKET_REPLY
PROMPT
PROMPT ========== 02_create_sequences.sql 执行完毕 ==========
