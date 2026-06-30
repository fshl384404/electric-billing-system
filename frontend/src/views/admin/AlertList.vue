<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><Warning /></el-icon> 异常告警</h2>
    <el-form :inline="true" style="margin: 8px 0">
      <el-form-item label="状态">
        <el-select v-model="filters.status" clearable placeholder="全部" @change="fetchList" style="width:110px">
          <el-option label="待处理" value="PENDING" />
          <el-option label="已处理" value="HANDLED" />
        </el-select>
      </el-form-item>
    </el-form>

    <el-table :data="list" border stripe v-loading="loading" max-height="calc(100vh - 230px)">
      <el-table-column prop="alertId" label="ID" width="70" />
      <el-table-column prop="meterId" label="电表ID" width="80" />
      <el-table-column prop="type" label="类型" width="90">
        <template #default="{ row }">
          <el-tag :type="row.type === 'SURGE' ? 'danger' : row.type === 'PLUNGE' ? 'warning' : 'info'" size="small">
            {{ { SURGE: '飙升', PLUNGE: '骤降', REVERSAL: '倒转' }[row.type] }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="alertLevel" label="级别" width="80">
        <template #default="{ row }">
          <el-tag :type="row.alertLevel === 'CRITICAL' ? 'danger' : row.alertLevel === 'WARN' ? 'warning' : 'info'" size="small">
            {{ row.alertLevel }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="description" label="描述" min-width="300" />
      <el-table-column prop="status" label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="row.status === 'PENDING' ? 'danger' : 'success'" size="small">
            {{ row.status === 'PENDING' ? '待处理' : '已处理' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="120">
        <template #default="{ row }">
          <el-button v-if="row.status === 'PENDING'" size="small" type="primary" @click="handleAlert(row)">处理</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:8px;justify-content:flex-end" />
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import alertApi from '@/api/alert'

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
    const res = await alertApi.list({ page: currentPage.value, pageSize: pageSize.value, ...filters })
    list.value = res.data.data.records
    total.value = res.data.data.total
  } finally { loading.value = false }
}

async function handleAlert(row) {
  await alertApi.handle(row.alertId)
  ElMessage.success('告警已处理')
  fetchList()
}
</script>
