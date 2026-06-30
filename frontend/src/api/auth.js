import http from './index'

export default {
  login: (username, password) =>
    http.post('/api/auth/login', { username, password }),

  me: () => http.get('/api/auth/me'),

  /** 忘记密码 — 第一步：验证身份 */
  forgotPassword: (username, phoneOrEmail) =>
    http.post('/api/auth/forgot-password', { username, phoneOrEmail }),

  /** 忘记密码 — 第二步：重置密码（公开接口） */
  resetPasswordPublic: (username, phoneOrEmail, newPassword) =>
    http.post('/api/auth/reset-password-public', { username, phoneOrEmail, newPassword })
}
