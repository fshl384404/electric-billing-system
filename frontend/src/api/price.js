import http from './index'

export default {
  list: () => http.get('/api/price/list'),
  update: (data) => http.put('/api/price', data)
}
