import http from './index'

export default {
  list: () => http.get('/api/notification/list'),
  unreadCount: () => http.get('/api/notification/unread-count'),
  markRead: (id) => http.put(`/api/notification/${id}/read`),
  markAllRead: () => http.put('/api/notification/read-all')
}
