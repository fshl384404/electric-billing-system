// ============================================================================
// 前后端通信测试 API
//
// 使用 axios 发送 HTTP 请求到后端 /api/ping 端点。
//
// 关于 baseURL:
//   开发环境 (npm run dev): 请求走 Vite 代理，路径以 /api 开头即可
//                          Vite 会自动转发到 http://localhost:8080
//   生产环境 (npm run build): 需要配置 Nginx 反向代理或直接指定后端地址
//                            此处通过环境变量 VITE_API_BASE_URL 控制
// ============================================================================

import axios from 'axios'

// 创建 axios 实例（集中管理请求配置）
const apiClient = axios.create({
  // 基础 URL: 开发环境通过 Vite 代理转发，留空即可
  //          生产环境通过 .env.production 文件设置 VITE_API_BASE_URL
  baseURL: import.meta.env.VITE_API_BASE_URL || '',

  // 请求超时时间（毫秒）
  timeout: 10000,

  // 请求头
  headers: {
    'Content-Type': 'application/json'
  }
})

// --------------------------------------------------------------------------
// 响应拦截器: 统一处理错误
// --------------------------------------------------------------------------
apiClient.interceptors.response.use(
  // 成功回调: 直接返回响应数据
  (response) => {
    return response
  },
  // 错误回调: 统一打印错误信息，然后抛出
  (error) => {
    console.error('[API Error]', error.message)
    return Promise.reject(error)
  }
)

// --------------------------------------------------------------------------
// 发送 GET 请求到 /api/ping
// 返回: Promise<AxiosResponse>
//
// 使用示例:
//   import { ping } from '@/api/ping'
//   const response = await ping()
//   console.log(response.data)  // { status: "ok", message: "...", ... }
// --------------------------------------------------------------------------
export function ping() {
  return apiClient.get('/api/ping')
}

export default apiClient
