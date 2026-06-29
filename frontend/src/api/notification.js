import http from './index'

export default {
  list: (params) => http.get('/api/notification/list', { params }),
  unreadCount: () => http.get('/api/notification/unread-count'),
  markRead: (id) => http.put(`/api/notification/${id}/read`),
  markAllRead: () => http.put('/api/notification/read-all')
}
