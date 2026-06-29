import http from './index'

export default {
  login: (username, password) =>
    http.post('/api/auth/login', { username, password }),

  me: () => http.get('/api/auth/me')
}
