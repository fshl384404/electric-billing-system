import { defineStore } from 'pinia'
import { ref } from 'vue'
import authApi from '@/api/auth'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('token') || '')
  const user = ref(JSON.parse(localStorage.getItem('user') || 'null'))

  /** 是否已登录 */
  const isLoggedIn = () => !!token.value

  /** 当前角色 */
  const role = () => user.value?.role || ''

  /** 登录 */
  async function login(username, password) {
    const res = await authApi.login(username, password)
    const data = res.data.data
    token.value = data.token
    user.value = {
      userId: data.userId,
      username: data.username,
      realName: data.realName,
      role: data.role
    }
    localStorage.setItem('token', data.token)
    localStorage.setItem('user', JSON.stringify(user.value))
    return data
  }

  /** 获取当前用户信息 */
  async function fetchMe() {
    try {
      const res = await authApi.me()
      if (res.data.data) {
        user.value = { ...user.value, ...res.data.data }
        localStorage.setItem('user', JSON.stringify(user.value))
      }
    } catch (e) {
      // 仅 401（Token 无效/过期）时登出，网络瞬断等不强制登出
      if (e.response?.status === 401) {
        logout()
      }
    }
  }

  /** 退出 — 仅清除认证数据 */
  function logout() {
    token.value = ''
    user.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('user')
  }

  return { token, user, isLoggedIn, role, login, fetchMe, logout }
})
