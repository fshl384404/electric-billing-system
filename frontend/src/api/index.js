import axios from 'axios'
import { ElMessage } from 'element-plus'

const http = axios.create({
  baseURL: '',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' }
})

// 请求拦截器 — 自动附加 JWT Token + 调试日志
http.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  console.log(`[REQ] ${config.method.toUpperCase()} ${config.baseURL || ''}${config.url}`)
  return config
}, error => Promise.reject(error))

// 响应拦截器 — 统一错误处理
http.interceptors.response.use(
  response => {
    const data = response.data
    // 后端返回 R 格式 { code, message, data }
    if (data.code && data.code !== 200) {
      if (data.code === 401) {
        localStorage.clear()
        window.location.href = '/login'
        return Promise.reject(new Error('登录已过期'))
      }
      ElMessage.error(data.message || '请求失败')
      return Promise.reject(new Error(data.message))
    }
    return response
  },
  error => {
    // HTTP 状态码错误 (网络不通 / 服务器 500 等)
    if (error.response) {
      const status = error.response.status
      if (status === 401) {
        localStorage.clear()
        window.location.href = '/login'
        return Promise.reject(error)
      }
      if (status === 403) {
        ElMessage.error('无权访问，请检查账号权限')
      } else if (status >= 500) {
        ElMessage.error('服务器内部错误，请稍后重试')
      } else {
        ElMessage.error('请求失败: ' + (error.response.data?.message || error.message))
      }
    } else if (error.code === 'ERR_NETWORK') {
      ElMessage.error('网络连接失败，请确认后端服务已启动 (localhost:8080)')
    } else {
      ElMessage.error(error.message || '网络错误')
    }
    return Promise.reject(error)
  }
)

export default http
