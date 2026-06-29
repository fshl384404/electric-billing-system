import http from './index'

export default {
  list: (params) => http.get('/api/user/list', { params }),
  get: (id) => http.get(`/api/user/${id}`),
  create: (data) => http.post('/api/user', data),
  update: (data) => http.put('/api/user', data),
  disable: (id) => http.put(`/api/user/${id}/disable`),
  enable: (id) => http.put(`/api/user/${id}/enable`),
  resetPassword: (id) => http.put(`/api/user/${id}/reset-password`)
}
