<template>
  <div>
    <h2>🔌 电表管理</h2>
    <el-button type="primary" @click="showDialog(null)" style="margin: 16px 0">新增电表</el-button>

    <el-table :data="list" border stripe v-loading="loading">
      <el-table-column prop="meterId" label="ID" width="80" />
      <el-table-column prop="meterNo" label="电表编号" width="180" />
      <el-table-column prop="houseId" label="房产ID" width="80" />
      <el-table-column prop="model" label="型号" width="120" />
      <el-table-column prop="initialReading" label="初始读数" width="100" />
      <el-table-column prop="lastReading" label="最新读数" width="100" />
      <el-table-column prop="status" label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="row.status === 'NORMAL' ? 'success' : row.status === 'FAULT' ? 'warning' : 'info'" size="small">
            {{ { NORMAL: '正常', FAULT: '故障', REMOVED: '已拆除' }[row.status] }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="250">
        <template #default="{ row }">
          <el-button size="small" @click="showDialog(row)">编辑</el-button>
          <el-button size="small" type="warning" @click="updateStatus(row, 'FAULT')" v-if="row.status === 'NORMAL'">报故障</el-button>
          <el-button size="small" type="success" @click="updateStatus(row, 'NORMAL')" v-if="row.status !== 'NORMAL'">恢复</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑电表' : '新增电表'" width="500px">
      <el-form :model="form" ref="formRef" label-width="80px">
        <el-form-item label="电表编号" prop="meterNo">
          <el-input v-model="form.meterNo" :disabled="isEdit" />
        </el-form-item>
        <el-form-item label="房产ID" prop="houseId">
          <el-input-number v-model="form.houseId" :min="1" />
        </el-form-item>
        <el-form-item label="型号" prop="model">
          <el-input v-model="form.model" />
        </el-form-item>
        <el-form-item label="初始读数" prop="initialReading">
          <el-input-number v-model="form.initialReading" :precision="2" :step="100" />
        </el-form-item>
        <el-form-item label="安装日期" prop="installDate">
          <el-date-picker v-model="form.installDate" type="date" value-format="YYYY-MM-DD" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import meterApi from '@/api/meter'

const list = ref([])
const loading = ref(false)
const dialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)
const form = ref({})

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try { list.value = (await meterApi.list()).data.data } finally { loading.value = false }
}

function showDialog(row) {
  isEdit.value = !!row
  form.value = row ? { ...row } : { status: 'NORMAL' }
  dialogVisible.value = true
}

async function handleSubmit() {
  if (isEdit.value) {
    await meterApi.update(form.value)
  } else {
    await meterApi.create(form.value)
  }
  ElMessage.success(isEdit.value ? '更新成功' : '新增成功')
  dialogVisible.value = false
  fetchList()
}

async function updateStatus(row, status) {
  await meterApi.updateStatus(row.meterId, status)
  ElMessage.success('状态已更新')
  fetchList()
}
</script>
