# 民用电缴费系统 — 数据库课程设计报告

> **学号:** ________  
> **姓名:** ________  
> **班级:** ________  
> **指导教师:** ________  
> **日期:** 2026 年 6 月

---

## 一、设计目标

### 1.1 课程设计目的

本课程设计旨在综合运用《数据库原理及应用》课程所学知识，完成一个完整的数据库应用系统开发。具体目标包括：

1. **需求分析能力** — 能够从业务场景出发，识别实体、属性、联系，产出规范的需求规格说明书
2. **数据库设计能力** — 能够完成概念结构设计（ER 图）、逻辑结构设计（关系模式）、物理结构设计（表/索引/约束）
3. **高级数据库对象** — 能够设计并实现触发器、存储过程、视图，体现数据库编程能力
4. **完整性保障** — 综合运用主键、外键、CHECK 约束、唯一约束保障数据完整性
5. **事务控制** — 在复杂业务操作中运用事务保障 ACID 特性

### 1.2 技术选型依据

| 技术 | 选型理由 |
|------|---------|
| **Oracle** | 课程指定数据库，支持 PL/SQL 编程（触发器/存储过程/复合触发器），事务管理成熟 |
| **Java 24 + Spring Boot 3.4** | 主流企业级后端框架，自动配置、声明式事务、依赖注入 |
| **MyBatis-Plus** | 持久层框架，BaseMapper 简化单表 CRUD，Lambda 表达式防 SQL 注入 |
| **Vue 3 + Element Plus** | 响应式前端框架，丰富的企业级 UI 组件，适合管理后台 |

---

## 二、问题描述

### 2.1 实际业务背景

传统居民电费管理存在以下问题：

- **抄表效率低** — 人工抄表周期长，数据易出错
- **计费不透明** — 居民无法直观看到阶梯电价分档明细
- **缴费不便** — 线下缴费依赖收费窗口，无线上自助渠道
- **异常发现滞后** — 用电异常（偷电/电表故障）往往要下个抄表周期才能发现
- **欠费管理被动** — 没有自动化催缴和断电预警机制

### 2.2 系统解决方案

本系统模拟一个现代化的居民用电缴费平台，通过：

- **智能电表 ** — 存储过程每日自动模拟用电数据
- **阶梯计价 ** — 月末自动分档计算，账单含三档明细
- **多角色协作** — 居民在线缴费 + 收费员线下录入 + 管理员全局管控
- **自动化监控** — 触发器实时检测用量异常 + 定时任务推送欠费/断电预警
- **工单客服** — 居民在线提交疑问，管理员/收费员回复

---

## 三、需求分析

### 3.1 角色定义

| 角色 | 编码 | 职责 |
|------|------|------|
| 管理员 | ADMIN | 管理用户/房产/电表/电价，查看报表，回复工单，处理告警 |
| 收费员 | COLLECTOR | 查看所有账单，线下缴费录入，处理异常告警，回复工单 |
| 居民 | RESIDENT | 查看自有账单，在线缴费，提交工单，查看通知 |

### 3.2 功能矩阵 (12 功能 × 3 角色)

| 功能 | ADMIN | COLLECTOR | RESIDENT |
|------|:-----:|:---------:|:--------:|
| 用户管理 (CRUD) | ✅ | ❌ | ❌ |
| 房产管理 (CRUD) | ✅ | ❌ | ❌ |
| 电表管理 (CRUD) | ✅ | ❌ | ❌ |
| 查看全部账单 | ✅ | ✅ | ❌ |
| 查看自己的账单 | ✅ | ✅ | ✅ |
| 在线缴费 | ✅ | ✅ | ✅ |
| 线下缴费录入 | ✅ | ✅ | ❌ |
| 查看缴费记录 | ✅ | ✅ | ✅ |
| 处理异常告警 | ✅ | ✅ | ❌ |
| 配置电价参数 | ✅ | ❌ | ❌ |
| 查看通知 | ✅ | ✅ | ✅ |
| 工单提交/回复 | ✅ 回复 | ✅ 回复 | ✅ 提交 |

### 3.3 核心业务规则

**阶梯电价算法：**

```
月用电量 = 本期读数 - 上期读数

电费 = MIN(用电量, 200) × 0.50                          -- 第一档
     + MAX(0, MIN(用电量 - 200, 200)) × 0.55            -- 第二档
     + MAX(0, 用电量 - 400) × 0.80                      -- 第三档
```

**滞纳金规则：**
- 出账后 15 天为宽限期
- 超过宽限期每日收取欠费金额的 0.1%
- 欠费 ≥ 28 天自动生成断电预警

**异常检测规则：**
- 电量飙升: 本月用电量 > 历史月均值的 200%
- 电量骤降: 本月用电量 < 历史月均值的 50%
- 读数倒转: 本期读数 < 上期读数

---

## 四、概要设计

### 4.1 ER 图

```
                    ┌─────────────┐
                    │  SYS_USER   │
                    │─────────────│
                    │ PK user_id  │
                    │ username    │
                    │ password    │
                    │ real_name   │
                    │ role        │
                    └──┬───┬───┬──┘
                       │   │   │
           ┌───────────┘   │   └──────────────┐
           │ 1             │ 1                │ 1
           │               │                  │
      ┌────▼────┐   ┌─────▼──────┐   ┌───────▼────────┐
      │  HOUSE  │   │NOTIFICATION│   │    TICKET      │
      │─────────│   │────────────│   │────────────────│
      │PK house │   │PK notif_id │   │PK ticket_id    │
      │FK user  │   │FK user_id  │   │FK user_id      │
      │address  │   │type        │   │type,title      │
      └────┬────┘   │content     │   │status          │
           │ 1      └────────────┘   └───────┬────────┘
           │                                  │ 1
      ┌────▼────┐                    ┌────────▼────────┐
      │  METER  │                    │  TICKET_REPLY   │
      │─────────│                    │─────────────────│
      │PK meter │                    │PK reply_id      │
      │FK house │←── UK (一宅一表)    │FK ticket_id     │
      │meter_no │                    │FK replier_id    │
      │status   │                    │content          │
      └────┬────┘                    └─────────────────┘
           │ 1
           │
      ┌────▼──────┐
      │METER_     │
      │READING    │
      │───────────│
      │PK reading │
      │FK meter   │
      │daily_usage│
      └────┬──────┘
           │ 1
           │
    ┌──────┴──────┐
    │             │
┌───▼───┐   ┌────▼─────┐
│  BILL │   │  ALERT   │
│───────│   │──────────│
│PK bill│   │PK alert  │
│FKmeter│   │FK meter  │
│total  │   │FK bill   │
│status │   │type      │
└───┬───┘   │level     │
    │ 1     └──────────┘
    │
┌───▼──────┐
│ PAYMENT  │
│──────────│
│PK payment│
│FK bill   │
│channel   │
└──────────┘
```

### 4.2 系统架构图

```
┌─────────────────────────────────────────────────┐
│              Browser (Vue 3 SPA)                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │  Login   │ │  Admin   │ │ Resident │        │
│  │   Page   │ │  Layout  │ │  Layout  │        │
│  └──────────┘ └──────────┘ └──────────┘        │
│        │              │              │           │
│        └──────────────┼──────────────┘           │
│                       │ Axios + JWT Header       │
└───────────────────────┼─────────────────────────┘
                        │ HTTP / JSON
┌───────────────────────┼─────────────────────────┐
│           Spring Boot Backend (:8080)            │
│  ┌────────────────────┼──────────────────────┐  │
│  │        JwtAuthFilter (Bearer Token)        │  │
│  └────────────────────┼──────────────────────┘  │
│  ┌────────┐ ┌────────┐┌─────────┐┌─────────┐  │
│  │  Auth  │ │  User  ││  Bill   ││ Ticket  │  │
│  │Module  │ │ Module ││ Module  ││ Module  │  │
│  └───┬────┘ └───┬────┘└────┬────┘└────┬────┘  │
│      └──────────┼──────────┼──────────┘         │
│                 │ MyBatis-Plus                   │
└─────────────────┼───────────────────────────────┘
                  │ JDBC
┌─────────────────┼───────────────────────────────┐
│          Oracle Database (:1521)                 │
│  ┌──────────────────────────────────────────┐   │
│  │  11 Tables │ 16 Triggers │ 5 Procedures │   │
│  │  6 Views   │ 11 Sequences│ 14 FK + 22 CK│   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

---

## 五、详细设计

### 5.1 数据库核心表结构

**11 张表:**

| 表名 | 说明 | 主键 | 外键 | 核心字段 |
|------|------|------|------|---------|
| SYS_USER | 系统用户 | user_id | — | username, password_hash, role, status |
| HOUSE | 房产 | house_id | user_id | address, area, house_type |
| METER | 电表 | meter_id | house_id (UK) | meter_no, last_reading, status |
| METER_READING | 抄表记录 | reading_id | meter_id | reading_date, reading_value, daily_usage |
| PRICE_CONFIG | 电价配置 | config_id | updated_by | tier_no, unit_price, is_active |
| BILL | 账单 | bill_id | meter_id | bill_month, total_usage, tier1/2/3, status |
| PAYMENT | 缴费记录 | payment_id | bill_id, payer_id, collector_id | amount, channel, transaction_no |
| NOTIFICATION | 通知 | notif_id | user_id | type, title, content, is_read |
| ALERT | 异常告警 | alert_id | meter_id, bill_id, handler_id | type, alert_level, status |
| TICKET | 工单 | ticket_id | user_id, replied_by | type, title, description, status |
| TICKET_REPLY | 工单回复 | reply_id | ticket_id, replier_id | content |

**范式分析：** 所有表均满足 3NF（每个非主属性完全函数依赖于主键，不存在传递依赖）。

### 5.2 触发器实现 (关键代码)

**TR1 — 日用电量计算 + 倒转检测：**

```sql
CREATE OR REPLACE TRIGGER tr1_calc_daily_usage
BEFORE INSERT ON meter_reading
FOR EACH ROW
DECLARE
    v_prev_reading NUMBER(12,2);
BEGIN
    -- 获取最近一次读数
    SELECT last_reading INTO v_prev_reading
    FROM meter WHERE meter_id = :NEW.meter_id;

    -- 读数倒转检测
    IF :NEW.reading_value < v_prev_reading THEN
        :NEW.daily_usage := 0;
        :NEW.remarks := 'REVERSAL: curr=' || :NEW.reading_value
                     || ' < prev=' || v_prev_reading;
    ELSE
        :NEW.daily_usage := :NEW.reading_value - v_prev_reading;
    END IF;
END;
```

**TR4b — 复合触发器检测用量飙升/骤降：**

```sql
CREATE OR REPLACE TRIGGER tr4b_surge_plunge_detect
FOR INSERT ON bill
COMPOUND TRIGGER
    TYPE t_avg_usage IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_avg_usage t_avg_usage;

    AFTER EACH ROW IS
    BEGIN
        -- 计算该电表历史月均用电量
        SELECT AVG(total_usage) INTO v_avg_usage(:NEW.meter_id)
        FROM bill WHERE meter_id = :NEW.meter_id
          AND bill_month < :NEW.bill_month;

        -- 飙升检测 (>200%)
        IF :NEW.total_usage > v_avg_usage(:NEW.meter_id) * 2 THEN
            INSERT INTO alert (...) VALUES (...);
        END IF;

        -- 骤降检测 (<50%)
        IF :NEW.total_usage < v_avg_usage(:NEW.meter_id) * 0.5 THEN
            INSERT INTO alert (...) VALUES (...);
        END IF;
    END AFTER EACH ROW;
END;
```

### 5.3 存储过程实现 (关键代码)

**SP1 — 阶梯电价月末生成账单：**

```sql
CREATE OR REPLACE PROCEDURE sp_generate_monthly_bills(
    p_bill_month IN VARCHAR2
) IS
    v_total_usage NUMBER;
    v_tier1_usage NUMBER; v_tier2_usage NUMBER; v_tier3_usage NUMBER;
    v_price1 NUMBER; v_price2 NUMBER; v_price3 NUMBER;
BEGIN
    -- 读取三档电价
    SELECT unit_price INTO v_price1 FROM price_config
        WHERE tier_no=1 AND is_active='Y';
    SELECT unit_price INTO v_price2 FROM price_config
        WHERE tier_no=2 AND is_active='Y';
    SELECT unit_price INTO v_price3 FROM price_config
        WHERE tier_no=3 AND is_active='Y';

    FOR meter_rec IN (SELECT * FROM meter WHERE status='NORMAL') LOOP
        -- 计算月用电量
        SELECT SUM(daily_usage) INTO v_total_usage ...;

        -- 分档计算
        v_tier1_usage := LEAST(v_total_usage, 200);
        v_tier2_usage := GREATEST(0, LEAST(v_total_usage-200, 200));
        v_tier3_usage := GREATEST(0, v_total_usage-400);

        -- 插入账单
        INSERT INTO bill(bill_id, meter_id, bill_month,
            total_usage, tier1_usage, tier2_usage, tier3_usage,
            tier1_amount, tier2_amount, tier3_amount,
            total_amount, due_date, status)
        VALUES (...);
    END LOOP;
END;
```

### 5.4 事务控制 (后端 Java)

**缴费事务 — 三操作原子执行：**

```java
@Transactional
public Payment pay(Payment payment) {
    // 1. 校验账单 (状态、归属权限)
    Bill bill = billMapper.selectById(payment.getBillId());
    if ("PAID".equals(bill.getStatus())) {
        throw new BusinessException("该账单已缴费");
    }

    // 2. 插入缴费记录
    payment.setPaymentId(paymentMapper.nextId());
    payment.setTransactionNo(generateTxnNo());
    paymentMapper.insert(payment);

    // 3. 更新账单状态
    bill.setStatus("PAID");
    bill.setPaymentDate(new Date());
    billMapper.updateById(bill);

    // 4. 发送缴费确认通知
    Notification notif = new Notification();
    notif.setType("PAYMENT_CONFIRM");
    notif.setUserId(payment.getPayerId());
    notifMapper.insert(notif);

    return payment;  // 任一操作失败则整体回滚
}
```

### 5.5 JWT 认证 + RBAC 实现

```java
// JWT 过滤器 — 请求拦截
@Component
public class JwtAuthFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(...) {
        // 提取 Bearer Token → 验证 → 写入 ThreadLocal 上下文
        String token = authHeader.substring(7);
        if (!jwtUtils.validateToken(token)) {
            writeAuthError(response, 401, "Token 无效或已过期");
            return;
        }
        AuthContext.set(userId, username, role);
        chain.doFilter(request, response);
    }
}

// 服务层权限检查
private void checkAdminOnly() {
    if (!AuthContext.isAdmin()) {
        throw new BusinessException(403, "仅管理员可操作");
    }
}
```

---

## 六、软件说明书

### 6.1 使用说明

**管理员操作流程：**
1. 登录 → 仪表盘查看系统概览
2. 用户管理 → 新增收费员/居民，分配账号
3. 房产管理 → 录入房产信息，绑定业主
4. 电表管理 → 为房产安装电表（系统会自动校验一宅一表）
5. 电价配置 → 设置或调整三档阶梯电价
6. 告警处理 → 查看异常告警列表，逐一标记处理
7. 工单回复 → 展开居民提交的工单，输入回复

**居民操作流程：**
1. 登录 → 进入"我的账单"
2. 查看账单详情（含阶梯明细）
3. 点击"缴费" → 确认金额 → 在线支付
4. 提交工单 → 选择类型 → 填写描述
5. 查看通知 → 标记已读

### 6.2 注意事项

1. **数据库连接** — 首次启动前确保 Oracle 实例运行中，`FREEPDB1` PDB 已注册到 Listener
2. **编码问题** — SQL 脚本为 GBK 编码（兼容 SQL*Plus 中文 Windows），Java/Vue 使用 UTF-8
3. **密码安全** — 系统首次登录时自动将明文密码升级为 BCrypt 哈希，无需手动干预
4. **端口占用** — 后端 8080，前端 5173，确保无冲突
5. **事务操作** — 缴费和工单回复使用 `@Transactional`，请勿手动提交/回滚

---

## 七、测试报告

### 7.1 测试策略

采用**自底向上**的测试策略：

1. **SQL 层** — SQL*Plus 执行 10 项集成测试脚本（覆盖建表→模拟→计费→缴费→检测全流程）
2. **API 层** — curl + Python 断言，71 项用例覆盖 12 个模块
3. **前端层** — 手动浏览 14 个页面，验证渲染和交互
4. **安全层** — JWT 无 token/无效 token、RBAC 越权测试

### 7.2 调试过程及解决的关键问题

| # | 问题 | 原因 | 解决方案 |
|---|------|------|---------|
| 1 | `ORA-01756` 引号未终止 | SQL 文件编为 GBK 但 SQL*Plus 按 UTF-8 解释 | PowerShell 转码全部 .sql 为 GBK |
| 2 | `ORA-03050` LEVEL 为保留字 | Oracle 不允许列名为 LEVEL | 全局替换 `level` → `alert_level` |
| 3 | 账单 total_amount 为 NULL | 读取 price_config WHERE tier_no=3 的 upper_limit 为 NULL | 分别读取三档价格，v_price2 从 tier_no=2 获取 |
| 4 | SP2-0734 PROMPT 行续接符 | PROMPT 末尾 `---` 被 SQL*Plus 解释为续行 | 替换为 `===` |
| 5 | 1 月账单全部为 0 | meter.last_reading 有 DEFAULT 0，触发器 IF NULL 永不成立 | 改为 DEFAULT NULL |
| 6 | JWT Filter 异常返回 500 页面 | Filter 抛出的异常不在 DispatcherServlet 管辖范围 | Filter 内直接 write JSON，不抛异常 |
| 7 | 用户创建缺密码 → NPE 500 | BCryptPasswordEncoder.encode(null) 抛 NPE | Service 层添加 null 校验返回 400 |

### 7.3 最终测试结果

| 测试层 | 用例数 | 通过 | 失败 | 通过率 |
|--------|--------|------|------|--------|
| SQL 集成测试 | 10 | 10 | 0 | 100% |
| API 功能测试 | 19 | 19 | 0 | 100% |
| API 边界测试 | 22 | 22 | 0 | 100% |
| 前端页面测试 | 14 | 14 | 0 | 100% |
| 安全测试 | 6 | 6 | 0 | 100% |
| **合计** | **71** | **71** | **0** | **100%** |

**测试数据量：**
- 13 个用户（1 admin + 2 collectors + 10 residents）
- 12 个房产 + 12 个电表
- 709 条抄表记录（模拟 60 天智能电表数据）
- 24 条账单（2 个月计费周期）
- 3 条缴费记录 + 15 条通知 + 1 条告警

---

## 八、课程设计总结

### 8.1 收获与体会

1. **数据库设计完整流程** — 从需求分析→ER 图→关系模式→DDL→触发器→存储过程→视图，完整实践了数据库设计方法论
2. **完整性约束的重要性** — 22 个 CHECK 约束和 14 个外键在开发早期拦截了大量脏数据，体会到"约束即文档"
3. **触发器的适用场景** — 日用电量计算、读数倒转检测等数据派生的场景非常适合用触发器实现，避免了应用层遗漏
4. **事务边界设计** — 缴费和工单回复的原子操作需要用 `@Transactional` 显式声明，否则会导致数据不一致
5. **前后端协作** — 统一响应格式 `R<T>` 极大地降低了前后端联调成本，异常信息从后端直达前端展示

### 8.2 存在的不足

1. **并发测试未覆盖** — 未模拟多用户同时缴费的并发场景，Oracle 的默认读提交隔离级别能否满足需要验证
2. **缺少 API 文档自动生成** — 未集成 Swagger/SpringDoc，目前 API 文档为手动维护
3. **存储过程未做异常处理** — PL/SQL 中的 `WHEN OTHERS` 处理不够细致

### 8.3 课程建议

建议课程中增加对 **数据库性能优化**（执行计划分析、索引优化）和 **高并发事务控制**（悲观锁/乐观锁、MVCC）的实践环节。
