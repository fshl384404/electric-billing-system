<template>
  <div class="login-page">
    <div class="login-card">
      <h1>⚡ 民用电缴费系统</h1>
      <p class="subtitle">Electric Billing System</p>
      <el-form :model="form" :rules="rules" ref="formRef" label-position="top" @submit.prevent="handleLogin">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" placeholder="请输入用户名" size="large" />
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="form.password" type="password" placeholder="请输入密码" size="large" show-password />
        </el-form-item>
        <el-button type="primary" size="large" :loading="loading" native-type="submit" class="login-btn">
          登 录
        </el-button>
        <p class="forgot-link" @click="showForgotDialog">忘记密码？</p>
      </el-form>
    </div>

    <!-- 忘记密码弹窗 -->
    <el-dialog v-model="forgotVisible" title="找回密码" width="420px" :close-on-click-modal="false">
      <!-- Step 1: 验证身份 -->
      <div v-if="forgotStep === 1">
        <el-form :model="forgotForm" :rules="forgotRules1" ref="forgotFormRef1" label-width="80px">
          <el-form-item label="用户名" prop="username">
            <el-input v-model="forgotForm.username" placeholder="请输入用户名" />
          </el-form-item>
          <el-form-item label="手机/邮箱" prop="phoneOrEmail">
            <el-input v-model="forgotForm.phoneOrEmail" placeholder="请输入绑定的手机号或邮箱" />
          </el-form-item>
        </el-form>
      </div>

      <!-- Step 2: 设置新密码 -->
      <div v-if="forgotStep === 2">
        <p class="forgot-hint">已验证：{{ forgotMatchedUser }}</p>
        <el-form :model="forgotForm" :rules="forgotRules2" ref="forgotFormRef2" label-width="80px">
          <el-form-item label="新密码" prop="newPassword">
            <el-input v-model="forgotForm.newPassword" type="password" show-password placeholder="至少4位" />
          </el-form-item>
          <el-form-item label="确认密码" prop="confirmPassword">
            <el-input v-model="forgotForm.confirmPassword" type="password" show-password placeholder="再次输入新密码" />
          </el-form-item>
        </el-form>
      </div>

      <template #footer>
        <el-button @click="forgotVisible = false">取消</el-button>
        <el-button v-if="forgotStep === 1" type="primary" :loading="forgotLoading" @click="handleForgotStep1">验证身份</el-button>
        <el-button v-if="forgotStep === 2" type="primary" :loading="forgotLoading" @click="handleForgotStep2">重置密码</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { reactive, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessage } from 'element-plus'
import authApi from '@/api/auth'

const router = useRouter()
const authStore = useAuthStore()
const loading = ref(false)
const formRef = ref(null)

const form = reactive({ username: 'admin', password: 'admin123' })
const rules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

// ---- 忘记密码 ----
const forgotVisible = ref(false)
const forgotStep = ref(1)
const forgotLoading = ref(false)
const forgotMatchedUser = ref('')
const forgotFormRef1 = ref(null)
const forgotFormRef2 = ref(null)
const forgotForm = reactive({ username: '', phoneOrEmail: '', newPassword: '', confirmPassword: '' })
const forgotRules1 = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  phoneOrEmail: [{ required: true, message: '请输入手机号或邮箱', trigger: 'blur' }]
}
const forgotRules2 = {
  newPassword: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 4, message: '密码至少4位', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请再次输入密码', trigger: 'blur' },
    { validator: (rule, value, cb) => value !== forgotForm.newPassword ? cb('两次密码不一致') : cb(), trigger: 'blur' }
  ]
}

function showForgotDialog() {
  forgotStep.value = 1
  forgotForm.username = ''
  forgotForm.phoneOrEmail = ''
  forgotForm.newPassword = ''
  forgotForm.confirmPassword = ''
  forgotMatchedUser.value = ''
  forgotVisible.value = true
}

async function handleForgotStep1() {
  const valid = await forgotFormRef1.value?.validate().catch(() => false)
  if (!valid) return
  forgotLoading.value = true
  try {
    const res = await authApi.forgotPassword(forgotForm.username.trim(), forgotForm.phoneOrEmail.trim())
    forgotMatchedUser.value = res.data.data.realName || res.data.data.username
    forgotStep.value = 2
  } catch (e) {
    ElMessage.error(e.message || '验证失败')
  } finally { forgotLoading.value = false }
}

async function handleForgotStep2() {
  const valid = await forgotFormRef2.value?.validate().catch(() => false)
  if (!valid) return
  forgotLoading.value = true
  try {
    await authApi.resetPasswordPublic(
      forgotForm.username.trim(), forgotForm.phoneOrEmail.trim(), forgotForm.newPassword
    )
    ElMessage.success('密码重置成功，请登录')
    forgotVisible.value = false
    form.username = forgotForm.username
    form.password = ''
  } catch (e) {
    ElMessage.error(e.message || '重置失败')
  } finally { forgotLoading.value = false }
}

// 进入登录页时清理残留状态，确保干净环境
onMounted(() => {
  authStore.logout()
})

async function handleLogin() {
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  loading.value = true
  try {
    const data = await authStore.login(form.username, form.password)
    ElMessage.success(`欢迎回来，${data.realName}`)
    if (data.role === 'RESIDENT') {
      router.push('/resident/bills')
    } else {
      router.push('/admin/dashboard')
    }
  } catch (e) {
    // 区分不同类型的错误
    const msg = e.message || ''
    if (msg.includes('Network Error') || msg.includes('网络')) {
      ElMessage.error('无法连接到后端服务，请确认后端已启动 (localhost:8080)')
    } else if (msg.includes('401') || msg.includes('过期')) {
      ElMessage.error('登录状态已过期，请重新登录')
    } else {
      ElMessage.error(msg || '登录失败，请检查用户名和密码')
    }
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1e3a5f, #3b82f6);
}
.login-card {
  width: 400px;
  padding: 40px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}
.login-card h1 {
  text-align: center;
  font-size: 24px;
  margin-bottom: 4px;
  color: #1e3a5f;
}
.subtitle {
  text-align: center;
  font-size: 13px;
  color: #94a3b8;
  margin-bottom: 32px;
}
.login-btn {
  width: 100%;
  margin-top: 8px;
}
.forgot-link {
  text-align: right;
  margin-top: 12px;
  font-size: 13px;
  color: #409EFF;
  cursor: pointer;
}
.forgot-link:hover { color: #1e6bb8; }
.forgot-hint {
  color: #67c23a;
  font-size: 14px;
  margin-bottom: 16px;
  padding: 8px 12px;
  background: #f0f9eb;
  border-radius: 6px;
}
</style>
