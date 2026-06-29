import http from './index'

export default {
  list: () => http.get('/api/house/list'),
  get: (id) => http.get(`/api/house/${id}`),
  create: (data) => http.post('/api/house', data),
  update: (data) => http.put('/api/house', data),
  delete: (id) => http.delete(`/api/house/${id}`)
}
