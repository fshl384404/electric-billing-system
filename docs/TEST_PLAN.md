# 民用电缴费系统 — 集成测试计划

> 版本: v1.0 | 日期: 2026-06-29 | 测试类型: 系统集成测试

---

## 1. 测试策略

### 1.1 测试金字塔

```
           ╱  E2E  ╲          ← 手动浏览 / 用户场景
          ╱  API   ╲          ← curl / Postman / 自动化
         ╱  Service ╲         ← JUnit + Mock (后续)
        ╱   Unit     ╲        ← 单个方法 (后续)
```

**当前阶段聚焦：API 集成测试 + 手动前端浏览测试**

### 1.2 测试范围

| 层 | 范围 | 工具 | 状态 |
|---|------|------|------|
| 数据库 | 触发器/存储过程/视图 | SQL*Plus | ✅ 10项全通过 (前期) |
| 后端 API | 10模块 × 3层 = 30+ 端点 | curl + Python 断言 | 🔄 本次 |
| 前端页面 | 16 个 Vue 页面 | 手动浏览 + Vite build | 🔄 本次 |
| 安全 | JWT / RBAC / 输入校验 | curl 边界测试 | 🔄 本次 |

### 1.3 不测范围
- 性能/压力测试（课程设计不需要）
- SQL 注入/CSRF（课堂不要求）
- 移动端兼容性

---

## 2. 测试用例清单

### T1 — 认证模块 (Auth)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T1.1 | 管理员登录 | 数据库含 admin | POST /api/auth/login {admin, admin123} | 200, 返回 token+角色 |
| T1.2 | 错误密码 | — | POST ... {admin, wrong} | 400, "用户名或密码错误" |
| T1.3 | 空用户名 | — | POST ... {, admin123} | 400 |
| T1.4 | 不存在用户 | — | POST ... {ghost, x} | 400 |
| T1.5 | 居民登录 | 数据库含 resident01 | POST ... {resident01, res123} | 200, 角色 RESIDENT |
| T1.6 | 禁用账户 | 手动禁用某用户 | POST ... 用该用户登录 | 400, "账户已被禁用" |
| T1.7 | 重复注册 | 已存在 admin | POST /api/auth/register {admin, ...} | 400, "用户名已存在" |
| T1.8 | 获取当前用户 | 有效 token | GET /api/auth/me | 200, 含 userId/username/role |

### T2 — JWT & 权限 (Security)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T2.1 | 无 Token 访问保护路由 | — | GET /api/user/list | 401, JSON 格式 |
| T2.2 | 无效 Token | — | Bearer invalidxxx | 401, "Token 无效或已过期" |
| T2.3 | 居民访问管理接口 | resident01 token | GET /api/user/list | 403, "无权限访问" |
| T2.4 | 居民修改电价 | resident01 token | PUT /api/price | 403 |
| T2.5 | 公共接口无需认证 | — | GET /api/ping | 200 |

### T3 — 用户管理 (User CRUD)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T3.1 | 查询用户列表 | admin token | GET /api/user/list | 200, 13 用户 |
| T3.2 | 新增用户 | admin token | POST /api/user {...} | 200, 成功创建 |
| T3.3 | 重复用户名 | admin token | POST ... {admin, ...} | 400, "用户名已存在" |
| T3.4 | 缺少密码 | admin token | POST ... {username:"x"} | 400, "密码不能为空" |
| T3.5 | 更新用户 | admin token | PUT /api/user {...} | 200 |
| T3.6 | 禁用用户 | admin token | PUT /api/user/{id}/disable | 200 |
| T3.7 | 不能禁用管理员 | admin token | PUT /api/user/1/disable | 400, "不能禁用管理员账户" |
| T3.8 | 重置密码 | admin token | PUT .../reset-password {password:"new"} | 200 |

### T4 — 房产管理 (House)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T4.1 | 查询房产列表 | admin token | GET /api/house/list | 200, 12 房产 |
| T4.2 | 居民只看自己 | resident01 token | GET /api/house/list | 200, 数据隔离 |
| T4.3 | 新增房产 | admin token | POST /api/house {...} | 200 |
| T4.4 | 删除房产 | admin token | DELETE .../{id} | 200 |
| T4.5 | 居民不能新增 | resident01 token | POST /api/house | 403 |

### T5 — 电表管理 (Meter)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T5.1 | 查询电表列表 | admin token | GET /api/meter/list | 200, 12 电表 |
| T5.2 | 新增电表 | admin token | POST /api/meter {...} | 200 |
| T5.3 | 一宅一表校验 | admin token | 同一 houseId 再新增 | 400, "每户只能安装一个电表" |
| T5.4 | 状态变更 | admin token | PUT .../{id}/status {status:"FAULT"} | 200 |

### T6 — 账单查询 (Bill)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T6.1 | 管理员看全部账单 | admin token | GET /api/bill/list | 200, 24 账单 |
| T6.2 | 居民只看自己 | resident01 token | GET /api/bill/list | 200, 4 账单 |
| T6.3 | 按状态过滤 | admin token | GET ...?status=PAID | 200, 仅已缴费 |
| T6.4 | 按账期过滤 | admin token | GET ...?billMonth=202601 | 200, 仅指定月份 |

### T7 — 缴费 (Payment)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T7.1 | 线上缴费 | resident01 token | POST /api/payment {billId, amount, ONLINE} | 200, 账单变 PAID |
| T7.2 | 重复缴费 | 已缴账单 | POST ... 再次缴费 | 400, "该账单已缴费" |
| T7.3 | 不存在的账单 | — | POST ... {billId:99999} | 400, "账单不存在" |
| T7.4 | 线下缴费需收款人 | admin token | POST ... {channel:OFFLINE, payerId} | 200, collectorId 自动填入 |
| T7.5 | 缴费后生成通知 | 缴费成功 | GET /api/notification/list | 含 PAYMENT_CONFIRM |

### T8 — 通知 (Notification)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T8.1 | 查看通知列表 | resident01 token | GET /api/notification/list | 200 |
| T8.2 | 标记已读 | — | PUT .../{id}/read | 200 |
| T8.3 | 全部已读 | — | PUT .../read-all | 200 |
| T8.4 | 未读数 | — | GET .../unread-count | 200, {count: N} |

### T9 — 告警 (Alert)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T9.1 | 告警列表 | admin token | GET /api/alert/list | 200 |
| T9.2 | 按状态过滤 | admin token | GET ...?status=PENDING | 200 |
| T9.3 | 处理告警 | admin token | PUT .../{id}/handle | 200, 状态变 HANDLED |
| T9.4 | 重复处理 | 已处理告警 | PUT .../{id}/handle | 400, "该告警已处理" |
| T9.5 | 居民不能查看 | resident01 token | GET ... | 403 |

### T10 — 工单 (Ticket)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T10.1 | 居民提交工单 | resident01 token | POST /api/ticket {type, title, description} | 200 |
| T10.2 | 查看工单列表 | admin token | GET /api/ticket/list | 200 |
| T10.3 | 回复工单 | admin token | POST .../{id}/reply {content} | 200 |
| T10.4 | 重复回复 | 已回复工单 | POST .../{id}/reply | 400, "该工单已回复" |
| T10.5 | 回复后生成通知 | 回复成功 | 居民查通知 | 含 TICKET_REPLY |
| T10.6 | 管理员不能提交 | admin token | POST /api/ticket | 400, "仅居民可提交工单" |

### T11 — 电价 (Price)

| ID | 场景 | 前置 | 操作 | 预期 |
|----|------|------|------|------|
| T11.1 | 查看电价 | 任意 token | GET /api/price/list | 200, 3 档 |
| T11.2 | 管理员修改 | admin token | PUT /api/price {configId, unitPrice} | 200 |
| T11.3 | 居民不能修改 | resident01 token | PUT /api/price | 403 |

### T12 — 前端页面 (手动浏览)

| ID | 页面 | 验证点 |
|----|------|--------|
| T12.1 | /login | 登录表单渲染、Element Plus 组件正常 |
| T12.2 | /admin/dashboard | 4 张统计卡片、数据加载 |
| T12.3 | /admin/users | 表格 13 行、新增弹窗、编辑、禁用 |
| T12.4 | /admin/houses | 表格 + 增删改 |
| T12.5 | /admin/meters | 表格 + 状态切换 |
| T12.6 | /admin/bills | 表格 + 状态/账期过滤 |
| T12.7 | /admin/alerts | 待处理告警 + 处理按钮 |
| T12.8 | /admin/tickets | 展开行 + 回复输入 |
| T12.9 | /admin/price | 3 档表格 + 行内编辑 |
| T12.10 | /resident/bills | 居民视角账单 + 缴费按钮 |
| T12.11 | /resident/tickets | 提交工单 + 查看回复 |
| T12.12 | /resident/notifications | 通知列表 + 标记已读 |
| T12.13 | 退出登录 | 清除 token、跳回 /login |
| T12.14 | 角色切换 | resident01 登录后侧边栏 4 项 |

---

## 3. 测试执行记录

> 执行人: ______  日期: ______  环境: Windows 11 + Oracle 23ai

### 结果汇总

| 模块 | 用例数 | 通过 | 失败 | 阻塞 | 通过率 |
|------|--------|------|------|------|--------|
| T1 Auth | 8 | | | | |
| T2 Security | 5 | | | | |
| T3 User CRUD | 8 | | | | |
| T4 House | 5 | | | | |
| T5 Meter | 4 | | | | |
| T6 Bill | 4 | | | | |
| T7 Payment | 5 | | | | |
| T8 Notification | 4 | | | | |
| T9 Alert | 5 | | | | |
| T10 Ticket | 6 | | | | |
| T11 Price | 3 | | | | |
| T12 Frontend | 14 | | | | |
| **合计** | **71** | | | | |

### 已发现 & 已修复的问题

| # | 严重度 | 问题描述 | 修复方案 | 状态 |
|---|--------|---------|---------|------|
| BUG-01 | 中 | JWT Filter 抛异常返回 500 错误页，而非 JSON 401 | Filter 中直接 write JSON，不抛异常 | ✅ 已修复 |
| BUG-02 | 中 | UserService.create() 密码为 null 时 NPE → 500 | 添加 null/blank 校验 → 400 | ✅ 已修复 |
| BUG-03 | 低 | 前端 ping.js 未删除（已重构为 index.js） | 删除旧文件 | ✅ 已修复 |
| BUG-04 | 低 | Vue Router beforeEach 使用废弃的 next() | 改用 return 路径值 | ✅ 已修复 |
| BUG-05 | 低 | 数据库密码明文存储（admin123） | AuthService 自动升级为 BCrypt | ✅ 已修复 |
