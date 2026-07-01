import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue')
  },
  {
    path: '/admin',
    component: () => import('@/layouts/AdminLayout.vue'),
    meta: { role: ['ADMIN', 'COLLECTOR'] },
    children: [
      { path: '', redirect: '/admin/dashboard' },
      { path: 'dashboard', name: 'Dashboard', component: () => import('@/views/admin/Dashboard.vue') },
      { path: 'users', name: 'UserList', component: () => import('@/views/admin/UserList.vue') },
      { path: 'houses', name: 'HouseList', component: () => import('@/views/admin/HouseList.vue') },
      { path: 'meters', name: 'MeterList', component: () => import('@/views/admin/MeterList.vue') },
      { path: 'bills', name: 'BillList', component: () => import('@/views/admin/BillList.vue') },
      { path: 'payments', name: 'PaymentList', component: () => import('@/views/admin/PaymentList.vue') },
      { path: 'alerts', name: 'AlertList', component: () => import('@/views/admin/AlertList.vue') },
      { path: 'tickets', name: 'TicketList', component: () => import('@/views/admin/TicketList.vue') },
      { path: 'price', name: 'PriceConfig', component: () => import('@/views/admin/PriceConfig.vue') }
    ]
  },
  {
    path: '/resident',
    component: () => import('@/layouts/AdminLayout.vue'),
    meta: { role: ['RESIDENT'] },
    children: [
      { path: '', redirect: '/resident/bills' },
      { path: 'bills', name: 'MyBills', component: () => import('@/views/resident/MyBills.vue') },
      { path: 'payments', name: 'MyPayments', component: () => import('@/views/resident/MyPayments.vue') },
      { path: 'tickets', name: 'MyTickets', component: () => import('@/views/resident/MyTickets.vue') },
      { path: 'notifications', name: 'MyNotifications', component: () => import('@/views/resident/MyNotifications.vue') }
    ]
  },
  { path: '/', redirect: '/login' },
  { path: '/:pathMatch(.*)*', redirect: '/login' }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 路由守卫
router.beforeEach(async (to) => {
  const auth = useAuthStore()

  // 登录页：已登录用户按角色跳转
  if (to.path === '/login') {
    if (auth.isLoggedIn()) {
      return auth.role() === 'RESIDENT' ? '/resident/bills' : '/admin/dashboard'
    }
    return
  }

  // 未登录 → 跳登录
  if (!auth.isLoggedIn()) {
    return '/login'
  }

  // 有 token 但无用户信息 → 获取
  if (!auth.user) {
    await auth.fetchMe()
    if (!auth.user) return '/login'
  }

  // 角色权限检查
  const allowedRoles = to.matched[0]?.meta?.role
  if (allowedRoles && !allowedRoles.includes(auth.role())) {
    if (auth.role() === 'RESIDENT') return '/resident/bills'
    return '/admin/dashboard'
  }
})

export default router
