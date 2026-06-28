<!-- ============================================================================
  民用电缴费系统 — 前端根组件

  当前阶段: 项目初始化，此页面用于验证前后端通信是否正常。
  后续开发时将替换为路由视图 (<RouterView />)。

  测试方法:
    1. 启动后端: cd backend && mvn spring-boot:run
    2. 启动前端: cd frontend && npm run dev
    3. 点击页面上的 "测试后端连接" 按钮
    4. 观察返回的 JSON 数据
============================================================================ -->

<script setup>
import { ref } from 'vue'
import { ping } from '@/api/ping'

// ===========================================================================
// 响应式状态
// ===========================================================================

/** 后端返回的数据（null = 尚未请求） */
const pingResult = ref(null)

/** 是否正在请求中 */
const loading = ref(false)

/** 错误消息（null = 无错误） */
const errorMsg = ref(null)

// ===========================================================================
// 方法
// ===========================================================================

/**
 * 发送 /api/ping 请求，验证前后端通信。
 *
 * 请求流程:
 *   浏览器 → Vite Dev Server (localhost:5173)
 *          → 匹配 /api/* 代理规则
 *          → 转发至 Spring Boot (localhost:8080/api/ping)
 *          → HealthController.ping() 处理
 *          → 返回 JSON
 */
async function testPing() {
  // 重置状态
  pingResult.value = null
  errorMsg.value = null
  loading.value = true

  try {
    const response = await ping()
    pingResult.value = response.data
    console.log('[Ping 成功]', response.data)
  } catch (error) {
    errorMsg.value = error.message || '未知错误'
    // 提供友好的排查提示
    if (error.code === 'ERR_NETWORK') {
      errorMsg.value = '无法连接到后端服务，请确认:'
        + '\n1. 后端已启动 (cd backend && mvn spring-boot:run)'
        + '\n2. 后端端口为 8080'
        + '\n3. Vite 代理配置正确'
    }
    console.error('[Ping 失败]', error)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="app-container">
    <!-- ================================================================ -->
    <!-- 头部 -->
    <!-- ================================================================ -->
    <header class="app-header">
      <h1>⚡ 民用电缴费系统</h1>
      <p class="subtitle">Electric Billing System — 前后端通信测试</p>
    </header>

    <main class="app-main">
      <!-- ============================================================== -->
      <!-- 技术栈卡片 -->
      <!-- ============================================================== -->
      <section class="tech-stack">
        <div class="card">
          <span class="card-icon">☕</span>
          <span class="card-label">后端</span>
          <code>Java 24 + Spring Boot 3.x + Maven</code>
        </div>
        <div class="card">
          <span class="card-icon">🗄️</span>
          <span class="card-label">数据库</span>
          <code>Oracle 11g</code>
        </div>
        <div class="card">
          <span class="card-icon">🎨</span>
          <span class="card-label">前端</span>
          <code>Vue 3 + Vite + Axios</code>
        </div>
      </section>

      <!-- ============================================================== -->
      <!-- 通信测试区域 -->
      <!-- ============================================================== -->
      <section class="ping-section">
        <h2>🔌 前后端通信测试</h2>
        <p class="ping-desc">
          点击下方按钮发送 <code>GET /api/ping</code> 请求，
          验证后端服务是否正常响应。
        </p>

        <button
          class="ping-btn"
          :disabled="loading"
          @click="testPing"
        >
          <span v-if="loading" class="spinner"></span>
          {{ loading ? '请求中...' : '测试后端连接' }}
        </button>

        <!-- 成功结果 -->
        <div v-if="pingResult" class="result-box success">
          <h3>✅ 连接成功</h3>
          <table>
            <tr v-for="(value, key) in pingResult" :key="key">
              <td class="key">{{ key }}</td>
              <td class="value">{{ value }}</td>
            </tr>
          </table>
        </div>

        <!-- 错误信息 -->
        <div v-if="errorMsg" class="result-box error">
          <h3>❌ 连接失败</h3>
          <pre>{{ errorMsg }}</pre>
        </div>
      </section>
    </main>

    <footer class="app-footer">
      <p>数据库课程设计 · 民用电缴费系统 · v1.0.0-SNAPSHOT</p>
    </footer>
  </div>
</template>

<style>
/* ==========================================================================
   全局样式
   ========================================================================== */

/* CSS 变量 — 统一管理颜色、圆角、间距 */
:root {
  --color-primary: #3b82f6;
  --color-primary-hover: #2563eb;
  --color-bg: #f8fafc;
  --color-surface: #ffffff;
  --color-text: #1e293b;
  --color-text-secondary: #64748b;
  --color-success: #10b981;
  --color-error: #ef4444;
  --color-border: #e2e8f0;
  --radius: 8px;
  --shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
    'Helvetica Neue', Arial, sans-serif;
  background: var(--color-bg);
  color: var(--color-text);
  line-height: 1.6;
}

/* ==========================================================================
   布局
   ========================================================================== */
.app-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-header {
  text-align: center;
  padding: 40px 20px 20px;
  background: linear-gradient(135deg, #1e3a5f, #3b82f6);
  color: white;
}

.app-header h1 {
  font-size: 28px;
  margin-bottom: 4px;
}

.subtitle {
  font-size: 14px;
  opacity: 0.85;
}

.app-main {
  flex: 1;
  max-width: 800px;
  margin: 0 auto;
  padding: 32px 20px;
  width: 100%;
}

.app-footer {
  text-align: center;
  padding: 20px;
  font-size: 13px;
  color: var(--color-text-secondary);
  border-top: 1px solid var(--color-border);
}

/* ==========================================================================
   技术栈卡片
   ========================================================================== */
.tech-stack {
  display: flex;
  gap: 16px;
  margin-bottom: 40px;
  flex-wrap: wrap;
  justify-content: center;
}

.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  padding: 16px 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  min-width: 180px;
  box-shadow: var(--shadow);
}

.card-icon {
  font-size: 28px;
}

.card-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--color-text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.card code {
  font-size: 13px;
  color: var(--color-primary);
  background: #eff6ff;
  padding: 2px 8px;
  border-radius: 4px;
}

/* ==========================================================================
   通信测试区域
   ========================================================================== */
.ping-section {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  padding: 32px;
  box-shadow: var(--shadow);
}

.ping-section h2 {
  font-size: 20px;
  margin-bottom: 8px;
}

.ping-desc {
  color: var(--color-text-secondary);
  font-size: 14px;
  margin-bottom: 20px;
}

.ping-desc code {
  background: #f1f5f9;
  padding: 1px 6px;
  border-radius: 3px;
  font-size: 13px;
}

.ping-btn {
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: var(--radius);
  padding: 12px 28px;
  font-size: 16px;
  cursor: pointer;
  transition: background 0.2s;
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.ping-btn:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.ping-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

/* 简易旋转动画 */
.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 结果展示框 */
.result-box {
  margin-top: 24px;
  border-radius: var(--radius);
  padding: 20px;
}

.result-box h3 {
  margin-bottom: 12px;
  font-size: 16px;
}

.result-box.success {
  background: #ecfdf5;
  border: 1px solid #6ee7b7;
}

.result-box.error {
  background: #fef2f2;
  border: 1px solid #fca5a5;
}

.result-box pre {
  white-space: pre-wrap;
  font-size: 13px;
  color: #991b1b;
}

/* 响应数据表格 */
table {
  width: 100%;
  border-collapse: collapse;
}

table td {
  padding: 6px 12px;
  border-bottom: 1px solid #d1fae5;
  font-size: 14px;
}

td.key {
  font-weight: 600;
  color: var(--color-text-secondary);
  width: 160px;
  white-space: nowrap;
}

td.value {
  color: var(--color-text);
  word-break: break-all;
}
</style>
