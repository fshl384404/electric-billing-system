import http from './index'

export default {
  list: (customerType) => http.get('/api/price/list', { params: { customerType } }),
  update: (data) => http.put('/api/price', data)
}
