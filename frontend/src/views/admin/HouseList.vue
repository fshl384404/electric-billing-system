<template>
  <div>
    <h2>🏠 房产管理</h2>
    <el-button type="primary" @click="showDialog(null)" style="margin: 16px 0">新增房产</el-button>

    <el-table :data="list" border stripe v-loading="loading">
      <el-table-column prop="houseId" label="ID" width="80" />
      <el-table-column prop="userId" label="业主ID" width="80" />
      <el-table-column prop="address" label="地址" min-width="250" />
      <el-table-column prop="area" label="面积(㎡)" width="100" />
      <el-table-column prop="houseType" label="类型" width="100" />
      <el-table-column label="操作" width="150">
        <template #default="{ row }">
          <el-button size="small" @click="showDialog(row)">编辑</el-button>
          <el-button size="small" type="danger" @click="handleDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑房产' : '新增房产'" width="500px">
      <el-form :model="form" ref="formRef" label-width="80px">
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
const dialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)
const form = ref({})

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try { list.value = (await houseApi.list()).data.data } finally { loading.value = false }
}

function showDialog(row) {
  isEdit.value = !!row
  form.value = row ? { ...row } : { houseType: 'RESIDENTIAL' }
  dialogVisible.value = true
}

async function handleSubmit() {
  if (isEdit.value) {
    await houseApi.update(form.value)
  } else {
    await houseApi.create(form.value)
  }
  ElMessage.success(isEdit.value ? '更新成功' : '新增成功')
  dialogVisible.value = false
  fetchList()
}

async function handleDelete(row) {
  await ElMessageBox.confirm(`确定删除「${row.address}」吗？`, '确认', { type: 'warning' })
  await houseApi.delete(row.houseId)
  ElMessage.success('已删除')
  fetchList()
}
</script>
