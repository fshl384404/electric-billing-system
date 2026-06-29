<template>
  <div>
    <h2>📊 系统仪表盘</h2>
    <el-row :gutter="20" style="margin-top: 20px">
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="用户总数" :value="stats.users" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="房产总数" :value="stats.houses" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="账单总数" :value="stats.bills" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="待处理告警" :value="stats.alerts" />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import userApi from '@/api/user'
import houseApi from '@/api/house'
import billApi from '@/api/bill'
import alertApi from '@/api/alert'

const stats = ref({ users: 0, houses: 0, bills: 0, alerts: 0 })

onMounted(async () => {
  try {
    const [u, h, b, a] = await Promise.all([
      userApi.list(), houseApi.list(), billApi.list(), alertApi.list({ status: 'PENDING' })
    ])
    stats.value.users = u.data.data?.length || 0
    stats.value.houses = h.data.data?.length || 0
    stats.value.bills = b.data.data?.length || 0
    stats.value.alerts = a.data.data?.length || 0
  } catch { /* ignore */ }
})
</script>
