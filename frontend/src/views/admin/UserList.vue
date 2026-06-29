<template>
  <div>
    <h2>👤 用户管理</h2>
    <el-button type="primary" @click="showDialog(null)" style="margin: 16px 0">新增用户</el-button>

    <el-table :data="list" border stripe v-loading="loading">
      <el-table-column prop="userId" label="ID" width="80" />
      <el-table-column prop="username" label="用户名" width="120" />
      <el-table-column prop="realName" label="姓名" width="100" />
      <el-table-column prop="role" label="角色" width="100">
        <template #default="{ row }">
          <el-tag :type="row.role === 'ADMIN' ? 'danger' : row.role === 'COLLECTOR' ? 'warning' : 'info'" size="small">
            {{ { ADMIN: '管理员', COLLECTOR: '收费员', RESIDENT: '居民' }[row.role] }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="phone" label="手机号" width="130" />
      <el-table-column prop="email" label="邮箱" min-width="180" />
      <el-table-column prop="status" label="状态" width="80">
        <template #default="{ row }">
          <el-tag :type="row.status === 'ACTIVE' ? 'success' : 'danger'" size="small">{{ row.status === 'ACTIVE' ? '正常' : '禁用' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="280">
        <template #default="{ row }">
          <el-button size="small" @click="showDialog(row)">编辑</el-button>
          <el-button size="small" type="warning" @click="handleResetPwd(row)">重置密码</el-button>
          <el-button v-if="row.status === 'ACTIVE' && row.role !== 'ADMIN'" size="small" type="danger" @click="handleDisable(row)">禁用</el-button>
        </template>
      </el-table-column>
    </el-table>

    <!-- 新增/编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑用户' : '新增用户'" width="500px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="80px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" :disabled="isEdit" />
        </el-form-item>
        <el-form-item label="姓名" prop="realName">
          <el-input v-model="form.realName" />
        </el-form-item>
        <el-form-item label="角色" prop="role" v-if="!isEdit">
          <el-select v-model="form.role" style="width:100%">
            <el-option label="管理员" value="ADMIN" />
            <el-option label="收费员" value="COLLECTOR" />
            <el-option label="居民" value="RESIDENT" />
          </el-select>
        </el-form-item>
        <el-form-item label="密码" prop="password" v-if="!isEdit">
          <el-input v-model="form.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="form.phone" />
        </el-form-item>
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="form.email" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit" :loading="submitting">确定</el-button>
      </template>
    </el-dialog>

    <!-- 重置密码弹窗 -->
    <el-dialog v-model="pwdVisible" title="重置密码" width="400px">
      <el-input v-model="newPassword" type="password" show-password placeholder="请输入新密码" />
      <template #footer>
        <el-button @click="pwdVisible = false">取消</el-button>
        <el-button type="primary" @click="doResetPwd">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import userApi from '@/api/user'

const list = ref([])
const loading = ref(false)
const dialogVisible = ref(false)
const isEdit = ref(false)
const submitting = ref(false)
const formRef = ref(null)
const form = ref({})
const pwdVisible = ref(false)
const resetUserId = ref(null)
const newPassword = ref('')

const rules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  realName: [{ required: true, message: '请输入姓名', trigger: 'blur' }],
  role: [{ required: true, message: '请选择角色', trigger: 'change' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

onMounted(() => fetchList())

async function fetchList() {
  loading.value = true
  try { list.value = (await userApi.list()).data.data } finally { loading.value = false }
}

function showDialog(row) {
  isEdit.value = !!row
  form.value = row ? { ...row } : { role: 'RESIDENT', password: '123456' }
  dialogVisible.value = true
}

async function handleSubmit() {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  submitting.value = true
  try {
    if (isEdit.value) {
      await userApi.update(form.value)
      ElMessage.success('更新成功')
    } else {
      await userApi.create({ ...form.value, passwordHash: form.value.password })
      ElMessage.success('新增成功')
    }
    dialogVisible.value = false
    fetchList()
  } finally { submitting.value = false }
}

function handleResetPwd(row) {
  resetUserId.value = row.userId
  newPassword.value = ''
  pwdVisible.value = true
}

async function doResetPwd() {
  await userApi.resetPassword(resetUserId.value, newPassword.value)
  ElMessage.success('密码已重置')
  pwdVisible.value = false
}

async function handleDisable(row) {
  await ElMessageBox.confirm(`确定禁用用户「${row.realName}」吗？`, '确认', { type: 'warning' })
  await userApi.disable(row.userId)
  ElMessage.success('已禁用')
  fetchList()
}
</script>
