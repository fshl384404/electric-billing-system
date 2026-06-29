<template>
  <div>
    <h2>🎫 我的工单</h2>
    <el-button type="primary" @click="showCreate" style="margin: 16px 0">提交工单</el-button>

    <el-table :data="list" border stripe v-loading="loading">
      <el-table-column prop="ticketId" label="ID" width="70" />
      <el-table-column prop="type" label="类型" width="100">
        <template #default="{ row }">
          {{ { BILL_INQUIRY: '账单疑问', METER_FAULT: '电表故障', COMPLAINT: '投诉', OTHER: '其他' }[row.type] }}
        </template>
      </el-table-column>
      <el-table-column prop="title" label="标题" min-width="180" />
      <el-table-column prop="status" label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 'PENDING' ? 'warning' : 'success'" size="small">
            {{ row.status === 'PENDING' ? '待处理' : '已回复' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="createdAt" label="创建时间" width="160" />
      <el-table-column label="回复" width="80">
        <template #default="{ row }">
          <el-button size="small" @click="viewReplies(row)">查看</el-button>
        </template>
      </el-table-column>
    </el-table>

    <!-- 提交工单弹窗 -->
    <el-dialog v-model="createVisible" title="提交工单" width="500px">
      <el-form :model="form" ref="formRef" label-width="80px">
        <el-form-item label="类型" prop="type">
          <el-select v-model="form.type" style="width:100%">
            <el-option label="账单疑问" value="BILL_INQUIRY" />
            <el-option label="电表故障" value="METER_FAULT" />
            <el-option label="投诉" value="COMPLAINT" />
            <el-option label="其他" value="OTHER" />
          </el-select>
        </el-form-item>
        <el-form-item label="标题" prop="title">
          <el-input v-model="form.title" />
        </el-form-item>
        <el-form-item label="描述" prop="description">
          <el-input v-model="form.description" type="textarea" :rows="3" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" @click="handleCreate">提交</el-button>
      </template>
    </el-dialog>

    <!-- 回复查看弹窗 -->
    <el-dialog v-model="replyVisible" title="回复记录" width="500px">
      <el-timeline v-if="currentReplies.length">
        <el-timeline-item v-for="r in currentReplies" :key="r.replyId" :timestamp="r.createdAt">
          {{ r.content }}
        </el-timeline-item>
      </el-timeline>
      <p v-else style="color:#999">暂无回复</p>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import ticketApi from '@/api/ticket'

const list = ref([])
const loading = ref(false)
const createVisible = ref(false)
const replyVisible = ref(false)
const currentReplies = ref([])
const formRef = ref(null)
const form = reactive({ type: 'BILL_INQUIRY', title: '', description: '' })

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try { list.value = (await ticketApi.list()).data.data } finally { loading.value = false }
}

function showCreate() {
  form.type = 'BILL_INQUIRY'
  form.title = ''
  form.description = ''
  createVisible.value = true
}

async function handleCreate() {
  await ticketApi.create(form)
  ElMessage.success('工单已提交')
  createVisible.value = false
  fetchList()
}

async function viewReplies(row) {
  try {
    const res = await ticketApi.replies(row.ticketId)
    currentReplies.value = res.data.data || []
  } catch { currentReplies.value = [] }
  replyVisible.value = true
}
</script>
