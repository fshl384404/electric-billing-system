<template>
  <div>
    <h2>🎫 工单处理</h2>
    <el-form :inline="true" style="margin: 8px 0">
      <el-form-item label="状态">
        <el-select v-model="filters.status" clearable placeholder="全部" @change="fetchList" style="width:110px">
          <el-option label="待处理" value="PENDING" />
          <el-option label="已回复" value="REPLIED" />
        </el-select>
      </el-form-item>
    </el-form>

    <el-table :data="list" border stripe v-loading="loading" row-key="ticketId" max-height="calc(100vh - 230px)">
      <el-table-column type="expand">
        <template #default="{ row }">
          <div style="padding: 0 20px 20px">
            <h4>📝 工单详情</h4>
            <p>{{ row.description }}</p>
            <el-divider />
            <h4>💬 回复记录</h4>
            <el-timeline v-if="row._replies?.length">
              <el-timeline-item v-for="r in row._replies" :key="r.replyId" :timestamp="r.createdAt">
                {{ r.content }}
              </el-timeline-item>
            </el-timeline>
            <p v-else style="color:#999">暂无回复</p>
            <div v-if="row.status === 'PENDING'" style="margin-top: 12px">
              <el-input v-model="row._replyText" type="textarea" :rows="2" placeholder="输入回复内容..." />
              <el-button type="primary" size="small" style="margin-top: 8px" @click="handleReply(row)">提交回复</el-button>
            </div>
          </div>
        </template>
      </el-table-column>
      <el-table-column prop="ticketId" label="ID" width="70" />
      <el-table-column prop="userId" label="提交人ID" width="90" />
      <el-table-column prop="type" label="类型" width="100">
        <template #default="{ row }">
          {{ { BILL_INQUIRY: '账单疑问', METER_FAULT: '电表故障', COMPLAINT: '投诉', OTHER: '其他' }[row.type] }}
        </template>
      </el-table-column>
      <el-table-column prop="title" label="标题" min-width="180" />
      <el-table-column prop="status" label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="row.status === 'PENDING' ? 'warning' : 'success'" size="small">
            {{ row.status === 'PENDING' ? '待处理' : '已回复' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="createdAt" label="创建时间" width="160" />
    </el-table>

    <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:8px;justify-content:flex-end" />
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import ticketApi from '@/api/ticket'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const filters = reactive({ status: null })

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try {
    const res = await ticketApi.list({ page: currentPage.value, pageSize: pageSize.value, ...filters })
    list.value = res.data.data.records
    total.value = res.data.data.total
    for (const row of list.value) {
      row._replyText = ''
      try {
        const r = await ticketApi.replies(row.ticketId)
        row._replies = r.data.data || []
      } catch { row._replies = [] }
    }
  } finally { loading.value = false }
}

async function handleReply(row) {
  if (!row._replyText?.trim()) {
    ElMessage.warning('请输入回复内容')
    return
  }
  await ticketApi.reply(row.ticketId, row._replyText)
  ElMessage.success('回复成功')
  row._replyText = ''
  fetchList()
}
</script>
