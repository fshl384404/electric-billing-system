<template>
  <div>
    <h2>📊 系统仪表盘</h2>
    <el-row :gutter="20" style="margin-top: 20px">
      <el-col :span="6">
        <el-card shadow="hover"><el-statistic title="用户总数" :value="stats.users" /></el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover"><el-statistic title="房产总数" :value="stats.houses" /></el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover"><el-statistic title="账单总数" :value="stats.bills" /></el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover"><el-statistic title="待处理告警" :value="stats.alerts" /></el-card>
      </el-col>
    </el-row>

    <!-- 图表区域 -->
    <el-row :gutter="20" style="margin-top: 20px">
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>📈 账单状态分布</span></template>
          <div style="padding: 10px">
            <div v-for="s in billStatus" :key="s.label" style="margin-bottom: 16px">
              <div style="display:flex;justify-content:space-between;margin-bottom:4px">
                <span>{{ s.label }}</span><span>{{ s.count }} 条 ({{ s.pct }}%)</span>
              </div>
              <el-progress :percentage="s.pct" :color="s.color" :stroke-width="18" :text-inside="false" />
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header><span>💰 月度营收 (元)</span></template>
          <div style="padding: 10px">
            <div v-for="m in monthlyRevenue" :key="m.month" style="margin-bottom: 12px">
              <div style="display:flex;justify-content:space-between;margin-bottom:4px">
                <span>{{ m.month }}</span><span>¥{{ m.amount.toFixed(2) }}</span>
              </div>
              <el-progress
                :percentage="(m.amount / maxRevenue) * 100"
                :color="'#409EFF'"
                :stroke-width="14"
                :text-inside="false"
              />
            </div>
            <div v-if="!monthlyRevenue.length" style="color:#999;text-align:center">暂无数据</div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import userApi from '@/api/user'
import houseApi from '@/api/house'
import billApi from '@/api/bill'
import alertApi from '@/api/alert'

const stats = ref({ users: 0, houses: 0, bills: 0, alerts: 0 })
const billStatus = ref([])
const monthlyRevenue = ref([])

const maxRevenue = computed(() =>
  Math.max(...monthlyRevenue.value.map(m => m.amount), 1)
)

onMounted(async () => {
  try {
    const [u, h, b, a] = await Promise.all([
      userApi.list(), houseApi.list(), billApi.list(), alertApi.list({ status: 'PENDING' })
    ])
    stats.value.users = u.data.data?.length || 0
    stats.value.houses = h.data.data?.length || 0
    stats.value.alerts = a.data.data?.length || 0

    // 按状态统计账单
    const bills = b.data.data || []
    stats.value.bills = bills.length
    const statusMap = { PENDING: '待缴费', PAID: '已缴费', OVERDUE: '已逾期' }
    const colors = { PENDING: '#E6A23C', PAID: '#67C23A', OVERDUE: '#F56C6C' }
    const counts = {}
    bills.forEach(b => { counts[b.status] = (counts[b.status] || 0) + 1 })
    billStatus.value = Object.entries(statusMap).map(([k, v]) => ({
      label: v, count: counts[k] || 0,
      pct: bills.length ? Math.round((counts[k] || 0) / bills.length * 100) : 0,
      color: colors[k]
    }))

    // 按月度统计营收（只用已缴费账单的 totalAmount）
    const monthMap = {}
    bills.filter(b => b.status === 'PAID').forEach(b => {
      monthMap[b.billMonth] = (monthMap[b.billMonth] || 0) + (b.totalAmount || 0)
    })
    monthlyRevenue.value = Object.entries(monthMap)
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([month, amount]) => ({ month, amount }))
  } catch { /* ignore */ }
})
</script>
