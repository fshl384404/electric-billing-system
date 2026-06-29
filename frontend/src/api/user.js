import http from './index'

export default {
  list: () => http.get('/api/user/list'),
  get: (id) => http.get(`/api/user/${id}`),
  create: (data) => http.post('/api/user', data),
  update: (data) => http.put('/api/user', data),
  disable: (id) => http.put(`/api/user/${id}/disable`),
  resetPassword: (id, password) => http.put(`/api/user/${id}/reset-password`, { password })
}
