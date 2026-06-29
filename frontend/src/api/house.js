import http from './index'

export default {
  list: (params) => http.get('/api/house/list', { params }),
  get: (id) => http.get(`/api/house/${id}`),
  create: (data) => http.post('/api/house', data),
  delete: (id) => http.delete(`/api/house/${id}`)
}
