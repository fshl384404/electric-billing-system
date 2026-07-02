<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><HomeFilled /></el-icon> 房产管理</h2>
    <el-button type="primary" @click="showDialog" style="margin: 8px 0">新增房产</el-button>

    <el-table :data="list" border stripe v-loading="loading" max-height="calc(100vh - 230px)">
      <el-table-column prop="houseId" label="ID" width="80" />
      <el-table-column label="业主" width="120">
        <template #default="{ row }">
          {{ row._ownerName || ('#' + row.userId) }}
        </template>
      </el-table-column>
      <el-table-column prop="address" label="地址" min-width="280" />
      <el-table-column prop="area" label="面积(㎡)" width="100" />
      <el-table-column prop="houseType" label="类型" width="100" />
      <el-table-column label="操作" width="80" fixed="right">
        <template #default="{ row }">
          <el-button size="small" type="danger" @click="handleDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:8px;justify-content:flex-end" />

    <el-dialog v-model="dialogVisible" title="新增房产" width="500px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="80px">
        <el-form-item label="业主" prop="userId">
          <el-select v-model="form.userId" placeholder="请选择业主" style="width:100%" filterable>
            <el-option v-for="u in users" :key="u.userId" :label="u.realName + ' (#' + u.userId + ')'" :value="u.userId" />
          </el-select>
        </el-form-item>
        <el-form-item label="地址" prop="address">
          <el-input v-model="form.address" />
        </el-form-item>
        <el-form-item label="面积" prop="area">
          <el-input-number v-model="form.area" :min="1" :precision="2" />
        </el-form-item>
        <el-form-item label="类型" prop="houseType">
          <el-select v-model="form.houseType">
            <el-option label="住宅" value="RESIDENTIAL" />
            <el-option label="商业" value="COMMERCIAL" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit" :loading="submitting">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import houseApi from '@/api/house'
import userApi from '@/api/user'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const dialogVisible = ref(false)
const submitting = ref(false)
const formRef = ref(null)
const form = ref({})
const users = ref([])

onMounted(async () => { await fetchUsers(); fetchList() })
async function fetchList() {
  loading.value = true
  try {
    const res = await houseApi.list({ page: currentPage.value, pageSize: pageSize.value })
    const records = res.data.data.records || []
    // 填充业主姓名
    for (const r of records) {
      const u = users.value.find(u => u.userId === r.userId)
      r._ownerName = u ? u.realName : null
    }
    list.value = records
    total.value = res.data.data.total
  } finally { loading.value = false }
}

async function fetchUsers() {
  try {
    const res = await userApi.list({ page: 1, pageSize: 999 })
    // 仅居民可作为业主
    users.value = (res.data.data?.records || []).filter(u => u.role === 'RESIDENT')
  } catch { /* ignore */ }
}

function showDialog() {
  form.value = { userId: null, address: '', area: null, houseType: 'RESIDENTIAL' }
  dialogVisible.value = true
}

const rules = {
  userId: [{ required: true, message: '请选择业主', trigger: 'change' }],
  address: [{ required: true, message: '请输入地址', trigger: 'blur' }],
  area: [{ required: true, message: '请输入面积', trigger: 'blur' }],
  houseType: [{ required: true, message: '请选择类型', trigger: 'change' }]
}

async function handleSubmit() {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  submitting.value = true
  try {
    await houseApi.create(form.value)
    ElMessage.success('新增成功')
    dialogVisible.value = false
    fetchList()
  } finally { submitting.value = false }
}

async function handleDelete(row) {
  await ElMessageBox.confirm('确定删除「' + row.address + '」吗？', '确认', { type: 'warning' })
  await houseApi.delete(row.houseId)
  ElMessage.success('已删除')
  fetchList()
}
</script>
