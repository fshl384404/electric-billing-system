<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><HomeFilled /></el-icon> 房产管理</h2>
    <el-button type="primary" @click="showDialog" style="margin: 8px 0">新增房产</el-button>

    <el-table :data="list" border stripe v-loading="loading" max-height="calc(100vh - 230px)">
      <el-table-column prop="houseId" label="ID" width="80" />
      <el-table-column prop="userId" label="业主ID" width="80" />
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
        <el-form-item label="业主ID" prop="userId">
          <el-input-number v-model="form.userId" :min="1" />
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
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import houseApi from '@/api/house'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const dialogVisible = ref(false)
const formRef = ref(null)
const form = ref({})

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try {
    const res = await houseApi.list({ page: currentPage.value, pageSize: pageSize.value })
    list.value = res.data.data.records
    total.value = res.data.data.total
  } finally { loading.value = false }
}

function showDialog() {
  form.value = { userId: null, address: '', area: null, houseType: 'RESIDENTIAL' }
  dialogVisible.value = true
}

const rules = {
  userId: [{ required: true, message: '请输入业主ID', trigger: 'blur' }],
  address: [{ required: true, message: '请输入地址', trigger: 'blur' }],
  area: [{ required: true, message: '请输入面积', trigger: 'blur' }]
}

async function handleSubmit() {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  await houseApi.create(form.value)
  ElMessage.success('新增成功')
  dialogVisible.value = false
  fetchList()
}

async function handleDelete(row) {
  await ElMessageBox.confirm('确定删除「' + row.address + '」吗？', '确认', { type: 'warning' })
  await houseApi.delete(row.houseId)
  ElMessage.success('已删除')
  fetchList()
}
</script>
