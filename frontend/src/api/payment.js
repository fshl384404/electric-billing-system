import http from './index'

export default {
  pay: (data) => http.post('/api/payment', data),
  list: (billId) => http.get('/api/payment/list', { params: { billId } }),
  get: (id) => http.get(`/api/payment/${id}`)
}
