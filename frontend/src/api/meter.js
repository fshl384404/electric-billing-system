import http from './index'

export default {
  list: (params) => http.get('/api/meter/list', { params }),
  get: (id) => http.get(`/api/meter/${id}`),
  create: (data) => http.post('/api/meter', data),
  update: (data) => http.put('/api/meter', data),
  updateStatus: (id, status) => http.put(`/api/meter/${id}/status`, { status })
}
