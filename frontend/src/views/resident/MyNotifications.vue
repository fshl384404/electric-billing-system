<template>
  <div>
    <div style="display: flex; justify-content: space-between; align-items: center">
      <h2>🔔 我的通知</h2>
      <el-button @click="markAll">全部标记已读</el-button>
    </div>

    <el-table :data="list" border stripe v-loading="loading" style="margin-top: 16px" max-height="calc(100vh - 280px)"
      row-key="notifId" @row-click="showDetail" highlight-current-row>
      <el-table-column prop="type" label="类型" width="120">
        <template #default="{ row }">
          <el-tag size="small">{{ { ARREARS: '欠费提醒', CUTOFF_WARNING: '断电预警', ANOMALY: '异常告警', TICKET_REPLY: '工单回复', PAYMENT_CONFIRM: '缴费确认' }[row.type] }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="title" label="标题" width="150" />
      <el-table-column prop="content" label="内容" min-width="150" show-overflow-tooltip />
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
          <el-button v-if="row.isRead === 'N'" size="small" @click.stop="markOne(row)">已读</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:16px;justify-content:flex-end" />

    <!-- 详情弹窗 -->
    <el-dialog v-model="dialogVisible" title="通知详情" width="500px">
      <p><strong>类型：</strong>{{ { ARREARS: '欠费提醒', CUTOFF_WARNING: '断电预警', ANOMALY: '异常告警', TICKET_REPLY: '工单回复', PAYMENT_CONFIRM: '缴费确认' }[current?.type] }}</p>
      <p><strong>标题：</strong>{{ current?.title }}</p>
      <p><strong>时间：</strong>{{ current?.createdAt }}</p>
      <el-divider />
      <p style="white-space:pre-wrap">{{ current?.content }}</p>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import notifApi from '@/api/notification'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const dialogVisible = ref(false)
const current = ref(null)

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try {
    const res = await notifApi.list({ page: currentPage.value, pageSize: pageSize.value })
    list.value = res.data.data.records
    total.value = res.data.data.total
  } finally { loading.value = false }
}

function showDetail(row) {
  current.value = row
  dialogVisible.value = true
  if (row.isRead === 'N') markOne(row)
}

async function markOne(row) {
  await notifApi.markRead(row.notifId)
  row.isRead = 'Y'
}

async function markAll() {
  await notifApi.markAllRead()
  ElMessage.success('全部已读')
  fetchList()
}
</script>
