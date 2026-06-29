import http from './index'

export default {
  pay: (data) => http.post('/api/payment', data),
  list: (params) => http.get('/api/payment/list', { params }),
  get: (id) => http.get(`/api/payment/${id}`)
}
