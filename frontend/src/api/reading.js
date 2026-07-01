import http from './index'

export default {
  list: (params) => http.get('/api/reading/list', { params }),
  create: (data) => http.post('/api/reading', data)
}
