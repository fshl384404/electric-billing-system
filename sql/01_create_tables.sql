-- ============================================================================
-- 民用电缴费系统 — 数据库建表脚本
-- 兼容版本: Oracle 11g
-- 说明: 创建系统全部 11 张核心业务表，包含主键、外键、检查约束和注释
-- 执行顺序: 第 1 步，在所有脚本之前执行
-- ============================================================================

-- 设置 SQL*Plus 环境
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

-- 清理旧表（按依赖顺序逆序删除，避免外键约束报错）
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN (
              'TICKET_REPLY', 'TICKET', 'NOTIFICATION', 'ALERT',
              'PAYMENT', 'BILL', 'PRICE_CONFIG',
              'METER_READING', 'METER', 'HOUSE', 'SYS_USER'
            )
            ORDER BY table_name DESC)
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
END;
/

PROMPT ========== 旧表已清理 ==========

-- ============================================================================
-- 1. 系统用户表 (SYS_USER)
-- 存储管理员、收费员、居民三种角色的账户信息
-- ============================================================================
CREATE TABLE sys_user (
    user_id        NUMBER          NOT NULL,           -- 用户主键，由序列生成
    username       VARCHAR2(50)    NOT NULL,           -- 登录用户名，唯一
    password_hash  VARCHAR2(200)   NOT NULL,           -- 密码哈希（应用层使用 BCrypt 加密）
    real_name      VARCHAR2(100)   NOT NULL,           -- 真实姓名
    role           VARCHAR2(20)    NOT NULL,           -- 角色: ADMIN/COLLECTOR/RESIDENT
    phone          VARCHAR2(20),                       -- 手机号
    email          VARCHAR2(100),                      -- 电子邮箱
    id_card        VARCHAR2(18),                       -- 身份证号
    status         VARCHAR2(10)    DEFAULT 'ACTIVE'    -- 账户状态: ACTIVE(正常)/DISABLED(禁用)
                    NOT NULL,
    created_at     DATE            DEFAULT SYSDATE NOT NULL,  -- 创建时间
    updated_at     DATE,                                 -- 最后修改时间
    --
    CONSTRAINT pk_user PRIMARY KEY (user_id),
    CONSTRAINT uk_user_username UNIQUE (username),
    CONSTRAINT ck_user_role CHECK (role IN ('ADMIN', 'COLLECTOR', 'RESIDENT')),
    CONSTRAINT ck_user_status CHECK (status IN ('ACTIVE', 'DISABLED'))
);

COMMENT ON TABLE  sys_user IS '系统用户表';
COMMENT ON COLUMN sys_user.user_id       IS '用户主键ID';
COMMENT ON COLUMN sys_user.username      IS '登录用户名';
COMMENT ON COLUMN sys_user.password_hash IS '密码哈希值';
COMMENT ON COLUMN sys_user.real_name     IS '用户真实姓名';
COMMENT ON COLUMN sys_user.role          IS '角色: ADMIN(管理员)/COLLECTOR(收费员)/RESIDENT(居民)';
COMMENT ON COLUMN sys_user.phone         IS '手机号码';
COMMENT ON COLUMN sys_user.email         IS '电子邮箱';
COMMENT ON COLUMN sys_user.id_card       IS '身份证号';
COMMENT ON COLUMN sys_user.status        IS '账户状态: ACTIVE(正常)/DISABLED(禁用)';
COMMENT ON COLUMN sys_user.created_at    IS '账户创建时间';
COMMENT ON COLUMN sys_user.updated_at    IS '最后修改时间';

-- ============================================================================
-- 2. 房产表 (HOUSE)
-- 每个房产隶属于一个业主（居民），一个业主可拥有多个房产
-- ============================================================================
CREATE TABLE house (
    house_id       NUMBER          NOT NULL,           -- 房产主键
    user_id        NUMBER          NOT NULL,           -- 业主ID，外键→sys_user
    address        VARCHAR2(300)   NOT NULL,           -- 房屋地址（完整地址）
    area           NUMBER(8,2),                        -- 建筑面积(平方米)
    house_type     VARCHAR2(20)    DEFAULT 'RESIDENTIAL', -- 房产类型: RESIDENTIAL(住宅)/COMMERCIAL(商业)
    created_at     DATE            DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_house PRIMARY KEY (house_id),
    CONSTRAINT fk_house_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id),
    CONSTRAINT ck_house_type CHECK (house_type IN ('RESIDENTIAL', 'COMMERCIAL'))
);

COMMENT ON TABLE  house IS '房产信息表';
COMMENT ON COLUMN house.house_id   IS '房产主键ID';
COMMENT ON COLUMN house.user_id    IS '业主ID，外键关联sys_user';
COMMENT ON COLUMN house.address    IS '房屋完整地址';
COMMENT ON COLUMN house.area       IS '建筑面积(平方米)';
COMMENT ON COLUMN house.house_type IS '房产类型: RESIDENTIAL(住宅)/COMMERCIAL(商业)';

-- ============================================================================
-- 3. 电表表 (METER)
-- 一宅一表，每个房产安装一个电表。存储电表的基本信息与最新读数快照
-- ============================================================================
CREATE TABLE meter (
    meter_id           NUMBER         NOT NULL,        -- 电表主键
    house_id           NUMBER         NOT NULL,        -- 房产ID(UNIQUE保证一宅一表)
    meter_no           VARCHAR2(50)   NOT NULL,        -- 电表编号（业务编号，如 METER-2024-00001）
    model              VARCHAR2(100),                  -- 电表型号
    install_date       DATE           NOT NULL,        -- 安装日期
    initial_reading    NUMBER(12,2)   DEFAULT 0 NOT NULL, -- 初始读数（安装时表底）
    last_reading       NUMBER(12,2)   DEFAULT 0,       -- 最近一次读数快照（触发器自动维护）
    last_reading_date  DATE,                            -- 最近一次读数日期（触发器自动维护）
    status             VARCHAR2(20)   DEFAULT 'NORMAL' NOT NULL, -- 电表状态: NORMAL/FAULT/REMOVED
    created_at         DATE           DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_meter PRIMARY KEY (meter_id),
    CONSTRAINT fk_meter_house FOREIGN KEY (house_id) REFERENCES house(house_id),
    CONSTRAINT uk_meter_house UNIQUE (house_id),        -- 一宅一表约束
    CONSTRAINT uk_meter_no UNIQUE (meter_no),            -- 电表编号唯一
    CONSTRAINT ck_meter_status CHECK (status IN ('NORMAL', 'FAULT', 'REMOVED'))
);

COMMENT ON TABLE  meter IS '电表信息表';
COMMENT ON COLUMN meter.meter_id          IS '电表主键ID';
COMMENT ON COLUMN meter.house_id          IS '房产ID(唯一约束保证一宅一表)';
COMMENT ON COLUMN meter.meter_no          IS '电表业务编号';
COMMENT ON COLUMN meter.model             IS '电表型号';
COMMENT ON COLUMN meter.install_date      IS '电表安装日期';
COMMENT ON COLUMN meter.initial_reading   IS '安装时初始读数';
COMMENT ON COLUMN meter.last_reading      IS '最近一次读数快照(触发器自动更新)';
COMMENT ON COLUMN meter.last_reading_date IS '最近一次读数日期(触发器自动更新)';
COMMENT ON COLUMN meter.status            IS '电表状态: NORMAL(正常)/FAULT(故障)/REMOVED(已拆除)';

-- ============================================================================
-- 4. 抄表记录表 (METER_READING)
-- 每日抄表数据，由存储过程 SP3 自动生成。每条记录代表某电表某日的读数
-- ============================================================================
CREATE TABLE meter_reading (
    reading_id      NUMBER         NOT NULL,           -- 记录主键
    meter_id        NUMBER         NOT NULL,           -- 电表ID
    reading_date    DATE           NOT NULL,           -- 抄表日期
    reading_value   NUMBER(12,2)   NOT NULL,           -- 当日电表累计读数
    daily_usage     NUMBER(10,2)   DEFAULT 0,          -- 当日用电增量(触发器TR1自动计算)
    reading_type    VARCHAR2(20)   DEFAULT 'AUTO' NOT NULL, -- 抄表类型: AUTO(自动模拟)/MANUAL(人工录入)
    remarks         VARCHAR2(200),                     -- 备注（异常标记等，由TR1自动填写）
    created_at      DATE           DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_reading PRIMARY KEY (reading_id),
    CONSTRAINT fk_reading_meter FOREIGN KEY (meter_id) REFERENCES meter(meter_id),
    CONSTRAINT ck_reading_type CHECK (reading_type IN ('AUTO', 'MANUAL'))
);

COMMENT ON TABLE  meter_reading IS '抄表记录表';
COMMENT ON COLUMN meter_reading.reading_id    IS '记录主键ID';
COMMENT ON COLUMN meter_reading.meter_id      IS '电表ID';
COMMENT ON COLUMN meter_reading.reading_date  IS '抄表日期';
COMMENT ON COLUMN meter_reading.reading_value IS '电表累计读数(类似里程表)';
COMMENT ON COLUMN meter_reading.daily_usage   IS '当日用电增量(触发器自动计算)';
COMMENT ON COLUMN meter_reading.reading_type  IS '抄表类型: AUTO(自动)/MANUAL(人工)';
COMMENT ON COLUMN meter_reading.remarks       IS '备注信息(异常标记等)';

-- ============================================================================
-- 5. 电价配置表 (PRICE_CONFIG)
-- 存储阶梯电价参数，支持历史追溯。管理员可以新增配置版本
-- ============================================================================
CREATE TABLE price_config (
    config_id       NUMBER         NOT NULL,           -- 配置主键
    tier_no         NUMBER(1)      NOT NULL,           -- 档位编号: 1/2/3
    tier_name       VARCHAR2(50)   NOT NULL,           -- 档位名称: "第一档"/"第二档"/"第三档"
    lower_limit     NUMBER(10,2)   NOT NULL,           -- 该档电量下限(度)
    upper_limit     NUMBER(10,2),                      -- 该档电量上限(度)，第三档为NULL表示上不封顶
    unit_price      NUMBER(10,6)   NOT NULL,           -- 该档单价(元/度)
    effective_date  DATE           NOT NULL,           -- 生效日期
    is_active       CHAR(1)        DEFAULT 'Y' NOT NULL, -- 是否当前有效: Y/N
    updated_by      NUMBER,                            -- 修改人ID
    created_at      DATE           DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_price_config PRIMARY KEY (config_id),
    CONSTRAINT fk_price_user FOREIGN KEY (updated_by) REFERENCES sys_user(user_id),
    CONSTRAINT ck_price_tier CHECK (tier_no IN (1, 2, 3)),
    CONSTRAINT ck_price_active CHECK (is_active IN ('Y', 'N'))
);

COMMENT ON TABLE  price_config IS '电价配置表(支持历史版本)';
COMMENT ON COLUMN price_config.tier_no         IS '阶梯档位: 1/2/3';
COMMENT ON COLUMN price_config.lower_limit     IS '该档用电量下限(度)';
COMMENT ON COLUMN price_config.upper_limit     IS '该档用电量上限(度), NULL表示不封顶';
COMMENT ON COLUMN price_config.unit_price      IS '该档单价(元/度)';
COMMENT ON COLUMN price_config.effective_date  IS '价格生效日期';
COMMENT ON COLUMN price_config.is_active       IS '是否当前有效: Y/N';
COMMENT ON COLUMN price_config.updated_by      IS '修改人ID(管理员)';

-- ============================================================================
-- 6. 账单表 (BILL)
-- 每月为每个电表生成一份账单。存储用电量与电费明细
-- ============================================================================
CREATE TABLE bill (
    bill_id         NUMBER          NOT NULL,          -- 账单主键
    meter_id        NUMBER          NOT NULL,          -- 电表ID
    bill_month      VARCHAR2(6)     NOT NULL,          -- 账期: YYYYMM 格式 (如 202601)
    prev_reading    NUMBER(12,2)    NOT NULL,          -- 上期表底读数
    curr_reading    NUMBER(12,2)    NOT NULL,          -- 本期表底读数
    total_usage     NUMBER(10,2)    NOT NULL,          -- 本期总用电量(度)
    tier1_usage     NUMBER(10,2)    DEFAULT 0,         -- 第一档用量(度)
    tier2_usage     NUMBER(10,2)    DEFAULT 0,         -- 第二档用量(度)
    tier3_usage     NUMBER(10,2)    DEFAULT 0,         -- 第三档用量(度)
    tier1_amount    NUMBER(12,2)    DEFAULT 0,         -- 第一档费用(元)
    tier2_amount    NUMBER(12,2)    DEFAULT 0,         -- 第二档费用(元)
    tier3_amount    NUMBER(12,2)    DEFAULT 0,         -- 第三档费用(元)
    total_amount    NUMBER(12,2)    NOT NULL,          -- 电费合计(元)
    late_fee        NUMBER(12,2)    DEFAULT 0,         -- 滞纳金(元)
    status          VARCHAR2(20)    DEFAULT 'PENDING', -- 状态: PENDING(待缴)/PAID(已缴)/OVERDUE(欠费)
    due_date        DATE            NOT NULL,          -- 缴费截止日（出账日+15天）
    payment_date    DATE,                              -- 实际缴费日期
    created_at      DATE            DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_bill PRIMARY KEY (bill_id),
    CONSTRAINT fk_bill_meter FOREIGN KEY (meter_id) REFERENCES meter(meter_id),
    CONSTRAINT ck_bill_status CHECK (status IN ('PENDING', 'PAID', 'OVERDUE')),
    CONSTRAINT ck_bill_month CHECK (LENGTH(bill_month) = 6)
);

COMMENT ON TABLE  bill IS '电费账单表';
COMMENT ON COLUMN bill.bill_id       IS '账单主键ID';
COMMENT ON COLUMN bill.meter_id      IS '电表ID';
COMMENT ON COLUMN bill.bill_month    IS '账期, 格式YYYYMM';
COMMENT ON COLUMN bill.prev_reading  IS '上期表底读数';
COMMENT ON COLUMN bill.curr_reading  IS '本期表底读数';
COMMENT ON COLUMN bill.total_usage   IS '本期总用电量(度)';
COMMENT ON COLUMN bill.tier1_usage   IS '第一档用电量(0-200度区间)';
COMMENT ON COLUMN bill.tier2_usage   IS '第二档用电量(201-400度区间)';
COMMENT ON COLUMN bill.tier3_usage   IS '第三档用电量(400度以上区间)';
COMMENT ON COLUMN bill.tier1_amount  IS '第一档电费金额';
COMMENT ON COLUMN bill.tier2_amount  IS '第二档电费金额';
COMMENT ON COLUMN bill.tier3_amount  IS '第三档电费金额';
COMMENT ON COLUMN bill.total_amount  IS '电费合计(元)';
COMMENT ON COLUMN bill.late_fee      IS '滞纳金(元), 每日千分之一';
COMMENT ON COLUMN bill.status        IS 'PENDING(待缴)/PAID(已缴)/OVERDUE(欠费)';
COMMENT ON COLUMN bill.due_date      IS '缴费截止日(出账日+15天)';
COMMENT ON COLUMN bill.payment_date  IS '实际缴费日期';

-- ============================================================================
-- 7. 缴费记录表 (PAYMENT)
-- 存储每一笔缴费的详细信息，支持线上/线下两种渠道
-- ============================================================================
CREATE TABLE payment (
    payment_id      NUMBER          NOT NULL,          -- 缴费主键
    bill_id         NUMBER          NOT NULL,          -- 关联账单ID
    amount          NUMBER(12,2)    NOT NULL,          -- 实缴金额（含可能产生的滞纳金）
    late_fee_paid   NUMBER(12,2)    DEFAULT 0,         -- 本次缴纳的滞纳金金额
    channel         VARCHAR2(20)    NOT NULL,          -- 缴费渠道: ONLINE(线上)/OFFLINE(线下)
    payer_id        NUMBER          NOT NULL,          -- 缴费人ID(居民本人或代为缴费的收费员)
    collector_id    NUMBER,                            -- 收款人ID(仅线下缴费时有值)
    payment_time    DATE            DEFAULT SYSDATE NOT NULL, -- 缴费时间
    transaction_no  VARCHAR2(50),                      -- 交易流水号(模拟: TXN-YYYYMMDD-序号)
    created_at      DATE            DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_payment PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_bill FOREIGN KEY (bill_id) REFERENCES bill(bill_id),
    CONSTRAINT fk_payment_payer FOREIGN KEY (payer_id) REFERENCES sys_user(user_id),
    CONSTRAINT fk_payment_collector FOREIGN KEY (collector_id) REFERENCES sys_user(user_id),
    CONSTRAINT ck_payment_channel CHECK (channel IN ('ONLINE', 'OFFLINE'))
);

COMMENT ON TABLE  payment IS '缴费记录表';
COMMENT ON COLUMN payment.payment_id     IS '缴费记录主键ID';
COMMENT ON COLUMN payment.bill_id        IS '关联账单ID';
COMMENT ON COLUMN payment.amount         IS '实缴金额(含滞纳金)';
COMMENT ON COLUMN payment.late_fee_paid  IS '本次缴纳的滞纳金金额';
COMMENT ON COLUMN payment.channel        IS '缴费渠道: ONLINE(线上)/OFFLINE(线下)';
COMMENT ON COLUMN payment.payer_id       IS '缴费人ID(居民或代缴的收费员)';
COMMENT ON COLUMN payment.collector_id   IS '线下收款人ID(收费员)';
COMMENT ON COLUMN payment.payment_time   IS '缴费时间';
COMMENT ON COLUMN payment.transaction_no IS '交易流水号';

-- ============================================================================
-- 8. 系统通知表 (NOTIFICATION)
-- 存储推送至用户的所有系统消息
-- ============================================================================
CREATE TABLE notification (
    notif_id        NUMBER          NOT NULL,          -- 通知主键
    user_id         NUMBER          NOT NULL,          -- 接收通知的用户ID
    type            VARCHAR2(30)    NOT NULL,          -- 通知类型
    title           VARCHAR2(200)   NOT NULL,          -- 通知标题
    content         VARCHAR2(1000)  NOT NULL,          -- 通知内容
    related_id      NUMBER,                            -- 关联业务ID(账单ID/告警ID/工单ID)
    is_read         CHAR(1)         DEFAULT 'N' NOT NULL, -- 是否已读: Y/N
    created_at      DATE            DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_notification PRIMARY KEY (notif_id),
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id),
    CONSTRAINT ck_notif_type CHECK (type IN (
        'ARREARS',          -- 欠费提醒
        'CUTOFF_WARNING',   -- 断电预警
        'ANOMALY',          -- 异常告警通知
        'TICKET_REPLY',    -- 工单回复通知
        'PAYMENT_CONFIRM'  -- 缴费确认通知
    )),
    CONSTRAINT ck_notif_read CHECK (is_read IN ('Y', 'N'))
);

COMMENT ON TABLE  notification IS '系统通知表';
COMMENT ON COLUMN notification.notif_id   IS '通知主键ID';
COMMENT ON COLUMN notification.user_id    IS '接收通知的用户ID';
COMMENT ON COLUMN notification.type       IS '通知类型: ARREARS/CUTOFF_WARNING/ANOMALY/TICKET_REPLY/PAYMENT_CONFIRM';
COMMENT ON COLUMN notification.title      IS '通知标题';
COMMENT ON COLUMN notification.content    IS '通知内容';
COMMENT ON COLUMN notification.related_id IS '关联业务记录ID';
COMMENT ON COLUMN notification.is_read    IS '是否已读: Y/N';
COMMENT ON COLUMN notification.created_at IS '通知生成时间';

-- ============================================================================
-- 9. 异常告警表 (ALERT)
-- 存储系统自动检测到的异常事件
-- ============================================================================
CREATE TABLE alert (
    alert_id        NUMBER          NOT NULL,          -- 告警主键
    meter_id        NUMBER          NOT NULL,          -- 关联电表ID
    bill_id         NUMBER,                            -- 关联账单ID(用电量异常时关联)
    type            VARCHAR2(30)    NOT NULL,          -- 异常类型
    level           VARCHAR2(20)    NOT NULL,          -- 告警级别
    description     VARCHAR2(500)   NOT NULL,          -- 告警描述（含具体数据）
    status          VARCHAR2(20)    DEFAULT 'PENDING' NOT NULL, -- 处理状态
    handler_id      NUMBER,                            -- 处理人ID(管理员或收费员)
    handled_at      DATE,                              -- 处理时间
    created_at      DATE            DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_alert PRIMARY KEY (alert_id),
    CONSTRAINT fk_alert_meter FOREIGN KEY (meter_id) REFERENCES meter(meter_id),
    CONSTRAINT fk_alert_bill FOREIGN KEY (bill_id) REFERENCES bill(bill_id),
    CONSTRAINT fk_alert_handler FOREIGN KEY (handler_id) REFERENCES sys_user(user_id),
    CONSTRAINT ck_alert_type CHECK (type IN ('SURGE', 'PLUNGE', 'REVERSAL')),
    CONSTRAINT ck_alert_level CHECK (level IN ('INFO', 'WARN', 'CRITICAL')),
    CONSTRAINT ck_alert_status CHECK (status IN ('PENDING', 'HANDLED'))
);

COMMENT ON TABLE  alert IS '异常告警表';
COMMENT ON COLUMN alert.alert_id    IS '告警主键ID';
COMMENT ON COLUMN alert.meter_id    IS '关联电表ID';
COMMENT ON COLUMN alert.bill_id     IS '关联账单ID(用电量异常时)';
COMMENT ON COLUMN alert.type        IS '异常类型: SURGE(飙升)/PLUNGE(骤降)/REVERSAL(倒转)';
COMMENT ON COLUMN alert.level       IS '告警级别: INFO(信息)/WARN(警告)/CRITICAL(严重)';
COMMENT ON COLUMN alert.description IS '告警详细描述';
COMMENT ON COLUMN alert.status      IS '处理状态: PENDING(待处理)/HANDLED(已处理)';
COMMENT ON COLUMN alert.handler_id  IS '处理人ID';

-- ============================================================================
-- 10. 工单表 (TICKET)
-- 居民提交的服务工单
-- ============================================================================
CREATE TABLE ticket (
    ticket_id       NUMBER          NOT NULL,          -- 工单主键
    user_id         NUMBER          NOT NULL,          -- 提交人工单的居民ID
    type            VARCHAR2(30)    NOT NULL,          -- 工单类型
    title           VARCHAR2(200)   NOT NULL,          -- 工单标题
    description     VARCHAR2(1000)  NOT NULL,          -- 工单详细描述
    status          VARCHAR2(20)    DEFAULT 'PENDING' NOT NULL, -- 状态: PENDING(待处理)/REPLIED(已回复)
    created_at      DATE            DEFAULT SYSDATE NOT NULL,
    replied_at      DATE,                              -- 回复时间
    replied_by      NUMBER,                            -- 回复人ID
    --
    CONSTRAINT pk_ticket PRIMARY KEY (ticket_id),
    CONSTRAINT fk_ticket_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id),
    CONSTRAINT fk_ticket_replier FOREIGN KEY (replied_by) REFERENCES sys_user(user_id),
    CONSTRAINT ck_ticket_type CHECK (type IN ('BILL_INQUIRY', 'METER_FAULT', 'COMPLAINT', 'OTHER')),
    CONSTRAINT ck_ticket_status CHECK (status IN ('PENDING', 'REPLIED'))
);

COMMENT ON TABLE  ticket IS '工单表';
COMMENT ON COLUMN ticket.ticket_id   IS '工单主键ID';
COMMENT ON COLUMN ticket.user_id     IS '提交工单的居民ID';
COMMENT ON COLUMN ticket.type        IS '工单类型: BILL_INQUIRY(账单疑问)/METER_FAULT(电表故障)/COMPLAINT(投诉)/OTHER(其他)';
COMMENT ON COLUMN ticket.title       IS '工单标题';
COMMENT ON COLUMN ticket.description IS '工单详细描述';
COMMENT ON COLUMN ticket.status      IS '工单状态: PENDING(待处理)/REPLIED(已回复)';
COMMENT ON COLUMN ticket.replied_at  IS '回复时间';
COMMENT ON COLUMN ticket.replied_by  IS '回复人ID';

-- ============================================================================
-- 11. 工单回复表 (TICKET_REPLY)
-- 存储工单的回复内容
-- ============================================================================
CREATE TABLE ticket_reply (
    reply_id        NUMBER          NOT NULL,          -- 回复主键
    ticket_id       NUMBER          NOT NULL,          -- 关联工单ID
    replier_id      NUMBER          NOT NULL,          -- 回复人ID
    content         VARCHAR2(1000)  NOT NULL,          -- 回复内容
    created_at      DATE            DEFAULT SYSDATE NOT NULL,
    --
    CONSTRAINT pk_reply PRIMARY KEY (reply_id),
    CONSTRAINT fk_reply_ticket FOREIGN KEY (ticket_id) REFERENCES ticket(ticket_id),
    CONSTRAINT fk_reply_user FOREIGN KEY (replier_id) REFERENCES sys_user(user_id)
);

COMMENT ON TABLE  ticket_reply IS '工单回复表';
COMMENT ON COLUMN ticket_reply.reply_id   IS '回复主键ID';
COMMENT ON COLUMN ticket_reply.ticket_id  IS '关联工单ID';
COMMENT ON COLUMN ticket_reply.replier_id IS '回复人ID';
COMMENT ON COLUMN ticket_reply.content    IS '回复内容';
COMMENT ON COLUMN ticket_reply.created_at IS '回复时间';

-- ============================================================================
-- 创建索引 — 优化常用查询性能
-- ============================================================================

-- meter_reading: 按电表+日期查询（最频繁的查询路径）
CREATE INDEX idx_reading_meter_date ON meter_reading(meter_id, reading_date);

-- bill: 按电表+账期查询
CREATE INDEX idx_bill_meter_month ON bill(meter_id, bill_month);

-- bill: 按状态查询（欠费扫描、逾期统计）
CREATE INDEX idx_bill_status ON bill(status);

-- bill: 按缴费截止日查询（滞纳金计算）
CREATE INDEX idx_bill_due_date ON bill(due_date);

-- payment: 按账单查询（对账）
CREATE INDEX idx_payment_bill ON payment(bill_id);

-- notification: 按用户+已读状态查询
CREATE INDEX idx_notif_user_read ON notification(user_id, is_read);

-- alert: 按状态查询（待处理告警列表）
CREATE INDEX idx_alert_status ON alert(status);

-- ticket: 按状态查询
CREATE INDEX idx_ticket_status ON ticket(status);

PROMPT ========== 11 张核心表及索引创建完毕 ==========
PROMPT
PROMPT 表清单:
PROMPT   1. SYS_USER        - 系统用户
PROMPT   2. HOUSE           - 房产信息
PROMPT   3. METER           - 电表信息
PROMPT   4. METER_READING   - 抄表记录
PROMPT   5. PRICE_CONFIG    - 电价配置
PROMPT   6. BILL            - 电费账单
PROMPT   7. PAYMENT         - 缴费记录
PROMPT   8. NOTIFICATION    - 系统通知
PROMPT   9. ALERT           - 异常告警
PROMPT  10. TICKET          - 工单
PROMPT  11. TICKET_REPLY    - 工单回复
PROMPT
PROMPT ========== 01_create_tables.sql 执行完毕 ==========
