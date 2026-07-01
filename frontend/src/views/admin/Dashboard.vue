<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><DataAnalysis /></el-icon> 系统仪表盘</h2>

    <!-- 统计卡片 -->
    <el-row :gutter="16" style="margin-top:12px">
      <el-col :span="6" v-for="c in cards" :key="c.label">
        <el-card shadow="hover" :body-style="{ padding: '16px 20px' }">
          <div class="stat-card">
            <div class="stat-icon" :style="{ background: c.bg, color: c.color }">
            <el-icon :size="24"><component :is="c.icon" /></el-icon>
          </div>
            <div class="stat-body">
              <div class="stat-value">{{ c.value.toLocaleString() }}</div>
              <div class="stat-label">{{ c.label }}</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 图表区 第一行 -->
    <el-row :gutter="16" style="margin-top:16px">
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>📈 账单状态分布</span></template>
          <div ref="pieChart" class="chart-box"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>💰 月度营收</span></template>
          <div ref="barChart" class="chart-box"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 图表区 第二行 -->
    <el-row :gutter="16" style="margin-top:16px">
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>⚡ 近6月用电趋势</span></template>
          <div ref="lineChart" class="chart-box"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>🎯 本月缴费率</span></template>
          <div ref="gaugeChart" class="chart-box"></div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import userApi from '@/api/user'
import houseApi from '@/api/house'
import billApi from '@/api/bill'
import alertApi from '@/api/alert'

// ---- 数据 ----
const stats = ref({ users: 0, houses: 0, bills: 0, alerts: 0 })
const billStatus = ref([])
const monthlyRevenue = ref([])
const allBillsCache = ref([])  // 共享缓存，避免重复请求

const cards = ref([])

// ---- 图表容器 ----
const pieChart = ref(null)
const barChart = ref(null)
const lineChart = ref(null)
const gaugeChart = ref(null)
let charts = []

function initChart(refEl, option) {
  if (!refEl.value) return
  const instance = echarts.init(refEl.value)
  instance.setOption(option)
  charts.push(instance)
  return instance
}

function resizeAll() {
  charts.forEach(c => { try { c.resize() } catch (_) { /* ignore */ } })
}

// ---- 加载 ----
onMounted(async () => {
  await fetchData()
  await nextTick()
  renderCharts()
  window.addEventListener('resize', resizeAll)
})

onUnmounted(() => {
  window.removeEventListener('resize', resizeAll)
  charts.forEach(c => c.dispose())
  charts = []
})

async function fetchData() {
  try {
    const [u, h, a] = await Promise.all([
      userApi.list({ page: 1, pageSize: 999 }),
      houseApi.list({ page: 1, pageSize: 999 }),
      alertApi.list({ page: 1, pageSize: 999, status: 'PENDING' })
    ])
    stats.value.users = u.data.data?.total || 0
    stats.value.houses = h.data.data?.total || 0
    stats.value.alerts = a.data.data?.total || 0

    const allBills = await billApi.list({ page: 1, pageSize: 999 })
    const bills = allBills.data.data?.records || []
    allBillsCache.value = bills  // 缓存，renderLineChart/renderGaugeChart 复用
    stats.value.bills = bills.length

    // 统计卡片
    cards.value = [
      { label: '用户总数', value: stats.value.users, icon: 'User', bg: '#ECFEFF', color: '#0891B2' },
      { label: '房产总数', value: stats.value.houses, icon: 'HomeFilled', bg: '#ECFDF5', color: '#059669' },
      { label: '账单总数', value: stats.value.bills, icon: 'Document', bg: '#FFFBEB', color: '#D97706' },
      { label: '待处理告警', value: stats.value.alerts, icon: 'Warning', bg: stats.value.alerts > 0 ? '#FEF2F2' : '#ECFDF5', color: stats.value.alerts > 0 ? '#DC2626' : '#059669' }
    ]

    // 账单状态分布
    const statusMap = { PENDING: '待缴费', PAID: '已缴费', OVERDUE: '已逾期' }
    const counts = {}
    bills.forEach(b => { counts[b.status] = (counts[b.status] || 0) + 1 })
    billStatus.value = Object.entries(statusMap).map(([k, v]) => ({
      name: v, value: counts[k] || 0
    }))

    // 月度营收（已缴费账单）
    const monthMap = {}
    bills.filter(b => b.status === 'PAID').forEach(b => {
      if (b.billMonth) {
        monthMap[b.billMonth] = (monthMap[b.billMonth] || 0) + (b.totalAmount || 0)
      }
    })
    monthlyRevenue.value = Object.entries(monthMap)
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([month, amount]) => ({ month, amount }))
  } catch { /* ignore */ }
}

function renderCharts() {
  // ---- 饼图: 账单状态分布 ----
  initChart(pieChart, {
    tooltip: { trigger: 'item', formatter: '{b}: {c} 条 ({d}%)' },
    legend: { bottom: 0 },
    series: [{
      type: 'pie',
      radius: ['50%', '75%'],
      center: ['50%', '48%'],
      avoidLabelOverlap: false,
      itemStyle: { borderRadius: 6, borderColor: '#fff', borderWidth: 3 },
      label: { show: true, formatter: '{b}\n{d}%' },
      data: billStatus.value,
      color: ['#059669', '#D97706', '#DC2626']
    }]
  })

  // ---- 柱状图: 月度营收 ----
  const barMonths = monthlyRevenue.value.map(m => m.month)
  const barAmounts = monthlyRevenue.value.map(m => parseFloat(m.amount.toFixed(2)))
  initChart(barChart, {
    tooltip: { trigger: 'axis', formatter: p => `${p[0].name}<br/>¥${p[0].value.toLocaleString()}` },
    grid: { left: 8, right: 16, top: 8, bottom: 0, containLabel: true },
    xAxis: { type: 'category', data: barMonths, axisLabel: { rotate: 0 } },
    yAxis: { type: 'value', axisLabel: { formatter: v => '¥' + (v / 1000).toFixed(0) + 'k' } },
    series: [{
      type: 'bar',
      data: barAmounts,
      itemStyle: {
        borderRadius: [6, 6, 0, 0],
        color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: '#0891B2' }, { offset: 1, color: '#67C8DB' }
        ])
      },
      barMaxWidth: 40
    }]
  })

  // ---- 折线图: 近6月用电趋势 ----
  const allBills = billStatus.value.reduce((s, i) => s + i.value, 0) > 0
    ? monthlyRevenue.value
    : []
  // 需要重新从原始数据计算用电量趋势 — 这里我们需要单独加载用电数据
  // 用已有的 monthlyRevenue 数据 + 从后端重新获取
  renderLineChart()

  // ---- 仪表盘: 本月缴费率 ----
  renderGaugeChart()
}

function renderLineChart() {
    const bills = allBillsCache.value
    const usageMap = {}
    bills.forEach(b => {
      if (b.billMonth) {
        usageMap[b.billMonth] = (usageMap[b.billMonth] || 0) + (b.totalUsage || 0)
      }
    })
    const sorted = Object.entries(usageMap)
      .sort((a, b) => a[0].localeCompare(b[0]))
    const last6 = sorted.slice(-6)
    const months = last6.map(e => e[0])
    const usages = last6.map(e => parseFloat(e[1].toFixed(0)))

    initChart(lineChart, {
      tooltip: { trigger: 'axis', formatter: p => `${p[0].name}<br/>${p[0].value.toLocaleString()} kWh` },
      grid: { left: 8, right: 16, top: 8, bottom: 0, containLabel: true },
      xAxis: { type: 'category', data: months },
      yAxis: { type: 'value', axisLabel: { formatter: v => (v / 1000).toFixed(0) + 'k' } },
      series: [{
        type: 'line',
        data: usages,
        smooth: true,
        symbol: 'circle',
        symbolSize: 8,
        lineStyle: { width: 3, color: '#0891B2' },
        itemStyle: { color: '#0891B2' },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(8,145,178,0.25)' }, { offset: 1, color: 'rgba(8,145,178,0.02)' }
          ])
        }
      }]
    })
}

function renderGaugeChart() {
    const bills = allBillsCache.value
    // 找当前月份
    const now = new Date()
    const thisMonth = now.getFullYear() + String(now.getMonth() + 1).padStart(2, '0')
    const monthBills = bills.filter(b => b.billMonth === thisMonth)
    const paid = monthBills.filter(b => b.status === 'PAID').length
    const total = monthBills.length
    const rate = total > 0 ? Math.round(paid / total * 100) : 0

    initChart(gaugeChart, {
      series: [{
        type: 'gauge',
        startAngle: 210,
        endAngle: -30,
        center: ['50%', '55%'],
        radius: '85%',
        min: 0, max: 100,
        splitNumber: 10,
        axisLine: {
          show: true,
          lineStyle: {
            width: 20,
            color: [
              [0.3, '#DC2626'], [0.7, '#D97706'], [1, '#059669']
            ]
          }
        },
        pointer: { length: '60%', width: 6, itemStyle: { color: '#303133' } },
        axisTick: { distance: -20, length: 6, lineStyle: { width: 1 } },
        splitLine: { distance: -24, length: 18, lineStyle: { width: 2 } },
        axisLabel: { distance: 30, fontSize: 12, formatter: '{value}%' },
        anchor: { show: true, size: 16 },
        title: { offsetCenter: [0, '75%'], fontSize: 14 },
        detail: {
          valueAnimation: true,
          fontSize: 32,
          fontWeight: 'bold',
          offsetCenter: [0, '50%'],
          formatter: '{value}%'
        },
        data: [{ value: rate, name: thisMonth + ' 缴费率' }]
      }]
    })
}
</script>

<style scoped>
.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
}
.stat-icon {
  width: 52px;
  height: 52px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26px;
  flex-shrink: 0;
}
.stat-body { flex: 1; }
.stat-value {
  font-size: 26px;
  font-weight: 700;
  color: #303133;
  line-height: 1.2;
}
.stat-label {
  font-size: 13px;
  color: #909399;
  margin-top: 2px;
}
.chart-box {
  width: 100%;
  height: 320px;
}
</style>
