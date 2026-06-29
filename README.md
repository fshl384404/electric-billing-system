# ⚡ 民用电缴费系统 — Electric Billing System

数据库课程设计项目，基于 **Java 24 + Oracle + Spring Boot 3.4 + Vue 3 + Element Plus** 构建的居民电费管理平台。

[![Java](https://img.shields.io/badge/Java-24-orange)](https://jdk.java.net/24/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.4.0-brightgreen)](https://spring.io/projects/spring-boot)
[![Vue](https://img.shields.io/badge/Vue-3.5-4fc08d)](https://vuejs.org/)
[![Oracle](https://img.shields.io/badge/Oracle-23ai%20Free-red)](https://www.oracle.com/database/free/)
[![License](https://img.shields.io/badge/License-Educational-blue)](LICENSE)

---

## 📋 目录

- [技术栈](#技术栈)
- [功能特性](#功能特性)
- [快速开始](#快速开始)
- [项目结构](#项目结构)
- [数据库设计亮点](#数据库设计亮点)
- [API 文档](#api-文档)
- [系统截图](#系统截图)
- [演示账号](#演示账号)
- [相关文档](#相关文档)

---

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| 后端语言 | Java | 24 |
| 后端框架 | Spring Boot | 3.4.0 |
| 持久层 | MyBatis-Plus | 3.5.9 |
| 安全 | JWT + BCrypt | jjwt 0.12.6 |
| 数据库 | Oracle | 23ai Free (兼容 11g+) |
| 构建工具 | Maven | 3.9+ |
| 前端框架 | Vue 3 (Composition API) | 3.5.38 |
| UI 组件库 | Element Plus | 最新 |
| 状态管理 | Pinia | 最新 |
| 路由 | Vue Router 4 | 最新 |
| 构建工具 | Vite | 8.1 |
| HTTP 客户端 | Axios | 1.18 |

---

## 功能特性

### 🏠 核心业务
- **多角色权限** — 管理员 / 收费员 / 居民，三级 RBAC + 数据隔离
- **房产电表管理** — 一宅一表，一户可多宅
- **智能抄表** — 存储过程每日模拟随机用电量（含季节/周末因子）
- **阶梯电价** — 三档计费 (0-200/201-400/400+ kWh)，自动分档计算
- **账单生成** — 月初自动批量生成，含阶梯明细
- **在线 + 线下缴费** — 居民在线支付，收费员线下代收录入
- **滞纳金** — 15 天宽限期后每日 0.1%，封顶为欠费本金

### 🔔 通知 & 异常检测
- **欠费提醒** — 逾期自动推送通知
- **断电预警** — 欠费 ≥ 28 天自动标记
- **用量异常** — 飙升至 200% 或骤降至 50% 历史均值时告警
- **读数倒转** — 抄表值异常倒退即时检测

### 🎫 工单系统
- 居民提交（账单疑问/电表故障/投诉/其他）
- 管理员/收费员回复后通知提交人
- 两步闭合流程（待处理 → 已回复）

---

## 快速开始

### 前置条件

- **JDK 24+** — [下载](https://jdk.java.net/24/)
- **Maven 3.9+** — `mvn --version`
- **Node.js 20+** — `node --version`
- **Oracle 数据库** — 23ai Free 推荐，兼容 11g+

### 1. 初始化数据库

```bash
# 连接到 Oracle (以 elec_billing 用户)
sqlplus elec_billing/elec_billing@localhost:1521/FREEPDB1

# 依次执行
@sql/01_create_tables.sql       # 11 张核心表
@sql/02_create_sequences.sql    # 11 个自增序列
@sql/03_create_triggers.sql     # 5 个业务触发器 + 11 个自增触发器
@sql/04_create_procedures.sql   # 5 个存储过程
@sql/05_create_views.sql        # 6 个业务视图
@sql/06_init_data.sql           # 种子数据 (13 用户, 12 房产, 12 电表)
@sql/07_test_scripts.sql        # 10 项集成测试 (可选)
```

### 2. 配置数据库连接

编辑 `backend/src/main/resources/application-dev.yml`:

```yaml
spring:
  datasource:
    url: jdbc:oracle:thin:@//localhost:1521/FREEPDB1
    username: elec_billing
    password: elec_billing
```

### 3. 启动后端

```bash
cd backend
mvn spring-boot:run
# 后端运行在 http://localhost:8080
# 验证: curl http://localhost:8080/api/ping
```

### 4. 启动前端

```bash
cd frontend
npm install
npm run dev
# 前端运行在 http://localhost:5173
# 浏览器自动打开登录页
```

### 5. 登录系统

| 角色 | 用户名 | 密码 |
|------|--------|------|
| 管理员 | `admin` | `admin123` |
| 收费员 | `collector01` | `col123` |
| 居民 | `resident01` | `res123` |

---

## 项目结构

```
electric-billing-system/
│
├── backend/                              # Spring Boot 后端
│   ├── pom.xml                           # Maven 依赖 (Spring Boot, MyBatis-Plus, JWT, Oracle)
│   └── src/main/
│       ├── java/com/electric/billing/
│       │   ├── ElectricBillingApplication.java   # 启动类
│       │   ├── common/                           # R响应, 全局异常, 业务异常
│       │   ├── config/                           # CORS 跨域配置
│       │   ├── controller/                       # 健康检查 (/api/ping)
│       │   ├── entity/                           # 11 个数据表实体
│       │   ├── security/                         # JWT 工具, 认证过滤器, 用户上下文
│       │   └── module/                           # 10 个业务模块
│       │       ├── auth/        # 登录/注册
│       │       ├── user/        # 用户管理
│       │       ├── house/       # 房产管理
│       │       ├── meter/       # 电表管理
│       │       ├── reading/     # 抄表记录
│       │       ├── bill/        # 账单查询
│       │       ├── payment/     # 缴费 (事务)
│       │       ├── notification/# 系统通知
│       │       ├── alert/       # 异常告警
│       │       ├── ticket/      # 工单+回复
│       │       └── price/       # 电价配置
│       └── resources/
│           ├── application.yml                 # 全局配置 + JWT 密钥
│           ├── application-dev.yml             # 开发环境数据库
│           └── application-prod.yml            # 生产环境模板
│
├── frontend/                             # Vue 3 前端
│   ├── vite.config.js                   # Vite 配置 + API 代理
│   └── src/
│       ├── main.js                      # 入口 (注册 Element Plus, Pinia, Router)
│       ├── App.vue                      # 根组件 (router-view)
│       ├── api/                         # 12 个 API 模块 (axios 封装)
│       ├── stores/auth.js              # Pinia 认证状态 (token/user/login)
│       ├── router/index.js             # 路由表 + beforeEach 角色守卫
│       ├── layouts/AdminLayout.vue     # 管理布局 (侧边栏+顶栏+内容区)
│       └── views/
│           ├── Login.vue               # 登录页
│           ├── admin/                  # 管理员/收费员页面 (9 个)
│           │   ├── Dashboard.vue       # 仪表盘
│           │   ├── UserList.vue        # 用户管理 (CRUD)
│           │   ├── HouseList.vue       # 房产管理
│           │   ├── MeterList.vue       # 电表管理
│           │   ├── BillList.vue        # 账单查询
│           │   ├── PaymentList.vue     # 缴费记录
│           │   ├── AlertList.vue       # 异常告警
│           │   ├── TicketList.vue      # 工单处理
│           │   └── PriceConfig.vue     # 电价配置
│           └── resident/              # 居民页面 (4 个)
│               ├── MyBills.vue        # 我的账单 + 在线缴费
│               ├── MyPayments.vue      # 我的缴费
│               ├── MyTickets.vue       # 我的工单
│               └── MyNotifications.vue # 我的通知
│
├── sql/                                  # Oracle 数据库脚本 (7 个文件)
│   ├── 01_create_tables.sql              # 11 张表 DDL + 索引 + 注释
│   ├── 02_create_sequences.sql           # 11 个序列
│   ├── 03_create_triggers.sql            # 16 个触发器 (业务+自增)
│   ├── 04_create_procedures.sql          # 5 个存储过程
│   ├── 05_create_views.sql              # 6 个业务视图
│   ├── 06_init_data.sql                 # 种子数据
│   └── 07_test_scripts.sql              # 10 项集成测试
│
└── .gitignore
```

---

## 数据库设计亮点

### 实体关系 (ER)

```
User ─1:N─→ House ─1:1─→ Meter ─1:N─→ MeterReading
  │                                      │
  │                                      ├─1:N─→ Bill ─1:N─→ Payment
  │                                      │
  ├─1:N─→ Notification                   └─1:N─→ Alert
  │
  └─1:N─→ Ticket ─1:N─→ TicketReply
```

### 触发器 (4 个业务触发器)

| 触发器 | 功能 | 触发时机 |
|--------|------|---------|
| `tr1_calc_daily_usage` | 自动计算日用电量，检测读数倒转 | BEFORE INSERT meter_reading |
| `tr2_arrears_notify` | 逾期自动推送欠费通知 | AFTER UPDATE bill (status→OVERDUE) |
| `tr3_payment_update_bill` | 缴费后自动更新账单状态为 PAID | AFTER INSERT payment |
| `tr4b_surge_plunge_detect` | 复合触发器：检测用量飙升(>200%)和骤降(<50%) | AFTER INSERT bill |

### 存储过程 (4 个核心 SP)

| 存储过程 | 功能 | 调度频率 |
|---------|------|---------|
| `sp_generate_monthly_bills` | 阶梯电价计算 + 批量生成账单 | 每月 1 号 |
| `sp_calc_late_fees` | 每日滞纳金计算 (0.1%/天) | 每日 |
| `sp_simulate_meter_reading` | 模拟智能电表日用电量 | 每日 |
| `sp_power_cutoff_warning` | 断电预警 (欠费≥28天) | 每日 |

### 视图 (6 个业务视图)

| 视图 | 说明 |
|------|------|
| `V_USER_BILLS` | 用户账单汇总 (含用户姓名+地址) |
| `V_METER_USAGE_SUMMARY` | 电表月度用电统计 |
| `V_PENDING_ALERTS` | 待处理告警列表 |
| `V_TICKET_DETAILS` | 工单详情 (含提交人+回复) |
| `V_REVENUE_SUMMARY` | 月度营收汇总 |
| `V_METER_DAILY_USAGE` | 日用电趋势 |

### 数据完整性保障

- **实体完整性**: 11 张表全部设有主键约束
- **参照完整性**: 14 个外键约束，级联策略
- **用户定义完整性**: 22 个 CHECK 约束 (角色/状态/渠道/类型等)
- **唯一性约束**: 用户名、电表编号、一宅一表 (UK on house_id)
- **索引优化**: 8 个复合索引覆盖高频查询路径

---

## API 文档

所有 API 遵循统一响应格式：

```json
{"code": 200, "message": "ok", "data": {...}}
```

| 模块 | 端点 | 方法 | 认证 | 说明 |
|------|------|------|------|------|
| Auth | `/api/auth/login` | POST | 无 | 登录获取 Token |
| Auth | `/api/auth/me` | GET | JWT | 当前用户信息 |
| User | `/api/user/list` | GET | ADMIN/COLLECTOR | 用户列表 |
| User | `/api/user/{id}` | GET | ADMIN/COLLECTOR | 用户详情 |
| User | `/api/user` | POST | ADMIN | 新增用户 |
| User | `/api/user` | PUT | ADMIN | 更新用户 |
| User | `/api/user/{id}/disable` | PUT | ADMIN | 禁用用户 |
| User | `/api/user/{id}/reset-password` | PUT | ADMIN | 重置密码 |
| House | `/api/house/list` | GET | JWT | 房产列表 |
| House | `/api/house/{id}` | GET | JWT | 房产详情 |
| House | `/api/house` | POST | ADMIN | 新增房产 |
| House | `/api/house` | PUT | ADMIN | 更新房产 |
| House | `/api/house/{id}` | DELETE | ADMIN | 删除房产 |
| Meter | `/api/meter/list` | GET | JWT | 电表列表 |
| Meter | `/api/meter` | POST | ADMIN | 新增电表 |
| Meter | `/api/meter/{id}/status` | PUT | ADMIN | 更新状态 |
| Reading | `/api/reading/list` | GET | JWT | 抄表记录 |
| Bill | `/api/bill/list` | GET | JWT | 账单列表 |
| Bill | `/api/bill/{id}` | GET | JWT | 账单详情 |
| Payment | `/api/payment` | POST | JWT | 缴费 (事务) |
| Payment | `/api/payment/list` | GET | JWT | 缴费记录 |
| Notification | `/api/notification/list` | GET | JWT | 通知列表 |
| Notification | `/api/notification/{id}/read` | PUT | JWT | 标记已读 |
| Alert | `/api/alert/list` | GET | ADMIN/COLLECTOR | 告警列表 |
| Alert | `/api/alert/{id}/handle` | PUT | ADMIN/COLLECTOR | 处理告警 |
| Ticket | `/api/ticket/list` | GET | JWT | 工单列表 |
| Ticket | `/api/ticket` | POST | RESIDENT | 提交工单 |
| Ticket | `/api/ticket/{id}/reply` | POST | ADMIN/COLLECTOR | 回复工单 |
| Price | `/api/price/list` | GET | JWT | 电价列表 |
| Price | `/api/price` | PUT | ADMIN | 修改电价 |

---

## License

本项目为数据库课程设计作业，仅供学习参考。
