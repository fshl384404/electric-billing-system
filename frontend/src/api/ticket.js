import http from './index'

export default {
  list: (params) => http.get('/api/ticket/list', { params }),
  get: (id) => http.get(`/api/ticket/${id}`),
  create: (data) => http.post('/api/ticket', data),
  reply: (id, content) => http.post(`/api/ticket/${id}/reply`, { content }),
  replies: (id) => http.get(`/api/ticket/${id}/replies`)
}
