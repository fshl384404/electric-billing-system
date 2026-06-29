import http from './index'

export default {
  list: (params) => http.get('/api/bill/list', { params }),
  get: (id) => http.get(`/api/bill/${id}`)
}
