import http from './index'

export default {
  pay: (data) => http.post('/api/payment', data),
  list: (billId) => {
    const params = {}
    if (billId) params.billId = billId
    return http.get('/api/payment/list', { params })
  },
  get: (id) => http.get(`/api/payment/${id}`)
}
