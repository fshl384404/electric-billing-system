# ⚡ 民用电缴费系统 — Electric Billing System

数据库课程设计项目，基于 Java 24 + Oracle + Spring Boot 3.x + Vue 3 构建的居民电费管理平台。

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| 后端语言 | Java | 24 |
| 后端框架 | Spring Boot | 3.4.x |
| 持久层 | MyBatis-Plus | 3.5.x |
| 数据库 | Oracle | 11g+ |
| 构建工具 | Maven | 3.9+ |
| 前端框架 | Vue 3 | 3.x |
| 构建工具 | Vite | 6.x |
| HTTP 客户端 | Axios | 1.x |

## 项目结构

```
electric-billing-system/
├── backend/                          # Spring Boot 后端
│   ├── pom.xml                       # Maven 依赖配置
│   └── src/main/
│       ├── java/com/electric/billing/
│       │   ├── ElectricBillingApplication.java  # Spring Boot 启动类
│       │   ├── config/
│       │   │   └── CorsConfig.java             # CORS 跨域配置
│       │   └── controller/
│       │       └── HealthController.java       # 健康检查 & 通信测试
│       └── resources/
│           ├── application.yml                 # 全局配置
│           ├── application-dev.yml             # 开发环境（本地 Oracle）
│           └── application-prod.yml            # 生产环境模板
│
├── frontend/                         # Vue 3 前端
│   ├── vite.config.js               # Vite 构建 & 代理配置
│   ├── src/
│   │   ├── App.vue                  # 根组件（通信测试页面）
│   │   ├── main.js                  # 应用入口
│   │   └── api/
│   │       └── ping.js              # 后端通信 API 封装
│   └── index.html                   # HTML 入口
│
├── sql/                              # Oracle 数据库脚本
│   ├── 01_create_tables.sql          # 11 张核心表 DDL
│   ├── 02_create_sequences.sql       # 自增序列
│   ├── 03_create_triggers.sql        # TR1~TR4 业务触发器
│   ├── 04_create_procedures.sql      # SP1~SP4 存储过程
│   ├── 05_create_views.sql           # 6 个业务视图
│   ├── 06_init_data.sql              # 种子数据（用户/房产/电表/电价）
│   └── 07_test_scripts.sql           # 集成测试（10 项测试）
│
├── .gitignore
└── README.md
```

## 快速开始

### 前置条件

- JDK 24+
- Maven 3.9+
- Node.js 20+
- Oracle 11g+ 数据库实例运行中

### 1. 初始化数据库

用 SQL*Plus 或 DataGrip 连接到 Oracle，依次执行：

```sql
@sql/01_create_tables.sql
@sql/02_create_sequences.sql
@sql/03_create_triggers.sql
@sql/04_create_procedures.sql
@sql/05_create_views.sql
@sql/06_init_data.sql
```

> 注意：执行前请先创建一个专用用户（如 `electric_billing`），并修改 `application-dev.yml` 中的数据库连接信息。

### 2. 启动后端

```bash
cd backend

# 安装依赖（首次运行）
mvn clean compile

# 启动应用（默认 dev profile，端口 8080）
mvn spring-boot:run
```

验证: 浏览器访问 http://localhost:8080/api/ping

### 3. 启动前端

```bash
cd frontend

# 安装依赖（首次运行）
npm install

# 启动开发服务器（默认端口 5173）
npm run dev
```

浏览器会自动打开 http://localhost:5173，点击 **"测试后端连接"** 按钮验证前后端通信。

### 4. 运行集成测试

```sql
@sql/07_test_scripts.sql
```

## 演示账号

| 角色 | 用户名 | 密码 |
|------|--------|------|
| 管理员 | `admin` | `admin123` |
| 收费员 | `collector01` | `col123` |
| 居民 | `resident01` | `res123` |

## 核心功能

- 电表管理 — 12 个模拟电表，支持一宅一表
- 智能抄表 — 存储过程每日模拟随机用电量
- 阶梯电价 — 三档计费（0-200/201-400/400+ 度）
- 账单生成 — 月初自动批量生成账单
- 在线缴费 — 支持线上支付 + 线下收费员代收
- 滞纳金 — 超过宽限期每日 0.1%
- 异常检测 — 用量飙升/骤降/读数倒转
- 欠费通知 — 自动推送 + 断电预警
- 工单系统 — 居民提交 → 收费员回复

## 相关文档

- [需求规格说明书](memory/srs-residential-electricity-payment-system.md) — 完整业务规则

## License

本项目为数据库课程设计作业，仅供学习参考。
