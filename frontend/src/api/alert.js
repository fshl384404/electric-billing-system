import http from './index'

export default {
  list: (params) => http.get('/api/alert/list', { params }),
  handle: (id) => http.put(`/api/alert/${id}/handle`)
}
