<template>
  <div>
    <div style="display: flex; justify-content: space-between; align-items: center">
      <h2>🔔 我的通知</h2>
      <el-button @click="markAll">全部标记已读</el-button>
    </div>

    <el-table :data="list" border stripe v-loading="loading" style="margin-top: 16px" row-key="notifId">
      <el-table-column prop="type" label="类型" width="120">
        <template #default="{ row }">
          <el-tag size="small">{{ { ARREARS: '欠费提醒', CUTOFF_WARNING: '断电预警', ANOMALY: '异常告警', TICKET_REPLY: '工单回复', PAYMENT_CONFIRM: '缴费确认' }[row.type] }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="title" label="标题" width="150" />
      <el-table-column prop="content" label="内容" min-width="300" />
      <el-table-column prop="isRead" label="状态" width="80">
        <template #default="{ row }">
          <el-tag :type="row.isRead === 'Y' ? 'info' : 'danger'" size="small">
            {{ row.isRead === 'Y' ? '已读' : '未读' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="createdAt" label="时间" width="160" />
      <el-table-column label="操作" width="80">
        <template #default="{ row }">
          <el-button v-if="row.isRead === 'N'" size="small" @click="markOne(row)">标记已读</el-button>
        </template>
      </el-table-column>
    </el-table>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import notifApi from '@/api/notification'

const list = ref([])
const loading = ref(false)

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try { list.value = (await notifApi.list()).data.data } finally { loading.value = false }
}

async function markOne(row) {
  await notifApi.markRead(row.notifId)
  ElMessage.success('已标记')
  fetchList()
}

async function markAll() {
  await notifApi.markAllRead()
  ElMessage.success('全部已读')
  fetchList()
}
</script>
