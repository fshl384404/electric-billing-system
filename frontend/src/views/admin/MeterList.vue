<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><Cpu /></el-icon> 电表管理</h2>
    <el-button type="primary" @click="showDialog" style="margin: 8px 0">新增电表</el-button>

    <el-table :data="list" border stripe v-loading="loading" max-height="calc(100vh - 230px)">
      <el-table-column prop="meterId" label="ID" width="60" />
      <el-table-column prop="meterNo" label="电表编号" min-width="140" show-overflow-tooltip />
      <el-table-column prop="houseId" label="房产ID" width="70" />
      <el-table-column prop="model" label="型号" width="90" show-overflow-tooltip />
      <el-table-column prop="initialReading" label="初始读数" width="85" />
      <el-table-column prop="lastReading" label="最新读数" width="85" />
      <el-table-column prop="status" label="状态" width="80">
        <template #default="{ row }">
          <el-tag :type="row.status === 'NORMAL' ? 'success' : row.status === 'FAULT' ? 'warning' : 'info'" size="small">
            {{ row.status === 'NORMAL' ? '正常' : row.status === 'FAULT' ? '故障' : '拆除' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="270" fixed="right">
        <template #default="{ row }">
          <el-button size="small" type="primary" @click="showReading(row)" v-if="row.status === 'NORMAL'">抄表</el-button>
          <el-button size="small" type="warning" @click="updateStatus(row, 'FAULT')" v-if="row.status === 'NORMAL'">故障</el-button>
          <el-button size="small" type="success" @click="updateStatus(row, 'NORMAL')" v-if="row.status === 'FAULT'">恢复</el-button>
          <el-button size="small" type="danger" @click="handleDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:8px;justify-content:flex-end" />

    <el-dialog v-model="dialogVisible" title="新增电表" width="500px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="80px">
        <el-form-item label="电表编号" prop="meterNo">
          <el-input v-model="form.meterNo" />
        </el-form-item>
        <el-form-item label="房产" prop="houseId">
          <el-select v-model="form.houseId" placeholder="请选择房产" style="width:100%" filterable>
            <el-option v-for="h in houses" :key="h.houseId" :label="h.address" :value="h.houseId" />
          </el-select>
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
        <el-button type="primary" @click="handleSubmit" :loading="submitting">确定</el-button>
      </template>
    </el-dialog>

    <!-- 人工抄表弹窗 -->
    <el-dialog v-model="readingVisible" title="人工抄表" width="460px">
      <el-form :model="readingForm" :rules="readingRules" ref="readingFormRef" label-width="80px">
        <el-form-item label="电表编号">
          <el-input :model-value="readingForm.meterNo" disabled />
        </el-form-item>
        <el-form-item label="上次读数">
          <el-input :model-value="readingForm.lastReading" disabled>
            <template #suffix>kWh</template>
          </el-input>
        </el-form-item>
        <el-form-item label="抄表日期" prop="readingDate">
          <el-date-picker v-model="readingForm.readingDate" type="date" value-format="YYYY-MM-DD"
            style="width:100%" :disabled-date="d => d.getTime() > Date.now()" />
        </el-form-item>
        <el-form-item label="本次读数" prop="readingValue">
          <el-input-number v-model="readingForm.readingValue" :precision="2" :step="10"
            :min="0" style="width:100%" placeholder="请输入电表当前读数" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="readingForm.remarks" placeholder="选填" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="readingVisible = false">取消</el-button>
        <el-button type="primary" @click="handleReadingSubmit" :loading="readingSubmitting">确认录入</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import meterApi from '@/api/meter'
import houseApi from '@/api/house'
import readingApi from '@/api/reading'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const dialogVisible = ref(false)
const submitting = ref(false)
const formRef = ref(null)
const form = ref({})
const houses = ref([])

onMounted(() => { fetchList(); fetchHouses() })
async function fetchList() {
  loading.value = true
  try {
    const res = await meterApi.list({ page: currentPage.value, pageSize: pageSize.value })
    list.value = res.data.data.records
    total.value = res.data.data.total
  } finally { loading.value = false }
}

async function fetchHouses() {
  try {
    const res = await houseApi.list({ page: 1, pageSize: 999 })
    houses.value = res.data.data.records
  } catch { /* ignore */ }
}

function showDialog() {
  form.value = { meterNo: '', houseId: null, model: '', initialReading: null, installDate: '', status: 'NORMAL' }
  dialogVisible.value = true
}

const rules = {
  meterNo: [{ required: true, message: '请输入电表编号', trigger: 'blur' }],
  houseId: [{ required: true, message: '请选择房产', trigger: 'change' }],
  model: [{ required: true, message: '请输入电表型号', trigger: 'blur' }],
  initialReading: [{ required: true, message: '请输入初始读数', trigger: 'blur' }],
  installDate: [{ required: true, message: '请选择安装日期', trigger: 'change' }]
}

async function handleSubmit() {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  submitting.value = true
  try {
    await meterApi.create(form.value)
    ElMessage.success('新增成功')
    dialogVisible.value = false
    fetchList()
  } finally { submitting.value = false }
}

async function updateStatus(row, status) {
  await meterApi.updateStatus(row.meterId, status)
  ElMessage.success('状态已更新')
  fetchList()
}

async function handleDelete(row) {
  await ElMessageBox.confirm('确定删除电表「' + row.meterNo + '」吗？', '确认', { type: 'warning' })
  await meterApi.delete(row.meterId)
  ElMessage.success('已删除')
  fetchList()
}

// ---- 人工抄表 ----
const readingVisible = ref(false)
const readingSubmitting = ref(false)
const readingFormRef = ref(null)
const readingForm = reactive({
  meterId: null, meterNo: '', lastReading: 0, readingDate: '', readingValue: null, remarks: ''
})
const readingRules = {
  readingDate: [{ required: true, message: '请选择抄表日期', trigger: 'change' }],
  readingValue: [{ required: true, message: '请输入本次读数', trigger: 'blur' }]
}

function showReading(row) {
  readingForm.meterId = row.meterId
  readingForm.meterNo = row.meterNo
  readingForm.lastReading = row.lastReading || 0
  readingForm.readingDate = new Date().toISOString().slice(0, 10) // 默认今天
  readingForm.readingValue = null
  readingForm.remarks = ''
  readingVisible.value = true
}

async function handleReadingSubmit() {
  const valid = await readingFormRef.value?.validate().catch(() => false)
  if (!valid) return
  // 前端友好提示: 读数低于上次读数可能是倒转
  if (readingForm.readingValue <= readingForm.lastReading) {
    try {
      await ElMessageBox.confirm(
        `本次读数(${readingForm.readingValue})不高于上次读数(${readingForm.lastReading})，系统将标记为读数倒转异常。确认继续录入吗？`,
        '读数异常提示', { type: 'warning', confirmButtonText: '确认录入', cancelButtonText: '取消' }
      )
    } catch { return }
  }
  readingSubmitting.value = true
  try {
    await readingApi.create({
      meterId: readingForm.meterId,
      readingDate: readingForm.readingDate,
      readingValue: readingForm.readingValue,
      remarks: readingForm.remarks || undefined
    })
    ElMessage.success('抄表录入成功')
    readingVisible.value = false
    fetchList() // 刷新电表列表以更新 lastReading
  } finally { readingSubmitting.value = false }
}
</script>
