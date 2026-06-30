<template>
  <el-container class="layout">
    <!-- 侧边栏 -->
    <el-aside :width="isCollapse ? '64px' : '220px'" class="aside">
      <div class="logo" @click="toggleCollapse">
        <span v-if="!isCollapse"><el-icon :size="18" style="vertical-align:middle;margin-right:6px"><Lightning /></el-icon>电费管理系统</span>
        <span v-else><el-icon :size="18"><Lightning /></el-icon></span>
      </div>
      <el-menu
        :default-active="route.path"
        :collapse="isCollapse"
        :router="true"
        background-color="#0F172A"
        text-color="#94A3B8"
        active-text-color="#22D3EE"
      >
        <template v-for="item in menuItems" :key="item.path">
          <el-sub-menu v-if="item.children" :index="item.path">
            <template #title>
              <el-icon><component :is="item.icon" /></el-icon>
              <span>{{ item.label }}</span>
            </template>
            <el-menu-item v-for="child in item.children" :key="child.path" :index="child.path">
              {{ child.label }}
            </el-menu-item>
          </el-sub-menu>
          <el-menu-item v-else :index="item.path">
            <el-icon><component :is="item.icon" /></el-icon>
            <span>{{ item.label }}</span>
          </el-menu-item>
        </template>
      </el-menu>
    </el-aside>

    <!-- 右侧区域 -->
    <el-container class="right-container">
      <!-- 顶栏 -->
      <el-header class="header">
        <div class="header-left">
          <el-icon class="collapse-btn" @click="toggleCollapse" :size="20">
            <Fold v-if="!isCollapse" /><Expand v-else />
          </el-icon>
        </div>
        <div class="header-right">
          <el-badge v-if="isResident" :value="unreadCount" :hidden="unreadCount === 0" class="notif-badge">
            <el-button :icon="Bell" circle @click="goNotifications" />
          </el-badge>
          <span class="user-name">{{ auth.user?.realName || '未知用户' }}</span>
          <el-tag :type="roleTagType" size="small">{{ roleLabel }}</el-tag>
          <el-button text @click="handleLogout">退出</el-button>
        </div>
      </el-header>

      <!-- 内容区 -->
      <el-main class="main">
        <router-view v-slot="{ Component }">
          <transition name="page-fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>

    <!-- 智能客服悬浮窗 (仅居民端) -->
    <ChatBot v-if="isResident" />
  </el-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { Bell } from '@element-plus/icons-vue'
import ChatBot from '@/views/ChatBot.vue'
import notifApi from '@/api/notification'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const isCollapse = ref(false)
const unreadCount = ref(0)

const roleLabel = computed(() => {
  return { ADMIN: '管理员', COLLECTOR: '收费员', RESIDENT: '居民' }[auth.role()] || ''
})
const roleTagType = computed(() => {
  return { ADMIN: 'danger', COLLECTOR: 'warning', RESIDENT: 'info' }[auth.role()] || 'info'
})

// 侧边栏菜单
const isResident = computed(() => auth.role() === 'RESIDENT')
const menuItems = computed(() => {
  if (isResident.value) {
    return [
      { path: '/resident/bills', label: '我的账单', icon: 'Tickets' },
      { path: '/resident/payments', label: '我的缴费', icon: 'Wallet' },
      { path: '/resident/tickets', label: '我的工单', icon: 'Service' },
      { path: '/resident/notifications', label: '我的通知', icon: 'Bell' }
    ]
  }
  // ADMIN: 全部菜单，COLLECTOR: 无管理类菜单
  const isAdmin = auth.role() === 'ADMIN'
  const items = [
    { path: '/admin/dashboard', label: '仪表盘', icon: 'Odometer' }
  ]
  if (isAdmin) {
    items.push(
      { path: '/admin/users', label: '用户管理', icon: 'User' },
      { path: '/admin/houses', label: '房产管理', icon: 'HomeFilled' },
      { path: '/admin/meters', label: '电表管理', icon: 'Cpu' }
    )
  }
  items.push(
    { path: '/admin/bills', label: '账单查询', icon: 'Document' },
    { path: '/admin/payments', label: '缴费记录', icon: 'Money' },
    { path: '/admin/alerts', label: '异常告警', icon: 'Warning' },
    { path: '/admin/tickets', label: '工单处理', icon: 'Service' }
  )
  if (isAdmin) {
    items.push({ path: '/admin/price', label: '电价配置', icon: 'Setting' })
  }
  return items
})

function toggleCollapse() { isCollapse.value = !isCollapse.value }

async function fetchUnreadCount() {
  try {
    const res = await notifApi.unreadCount()
    unreadCount.value = res.data.data?.count || 0
  } catch { /* ignore */ }
}

function goNotifications() {
  if (isResident.value) router.push('/resident/notifications')
}

async function handleLogout() {
  auth.logout()
  router.push('/login')
}

onMounted(() => { fetchUnreadCount() })
</script>

<style>
html, body, #app { margin: 0; padding: 0; height: 100%; overflow: hidden; }

/* 页面过渡动画 */
.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.page-fade-enter-from {
  opacity: 0;
  transform: translateY(6px);
}
.page-fade-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>

<style scoped>
.layout { height: 100vh; }

.aside {
  background: #0F172A;
  overflow-y: auto;
  transition: width 0.3s;
}
.logo {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 18px;
  font-weight: bold;
  cursor: pointer;
  border-bottom: 1px solid rgba(255,255,255,0.1);
}
.el-menu { border-right: none; }

.right-container {
  overflow: hidden !important;
  height: 100vh;
}

.header {
  background: white;
  border-bottom: 1px solid #e4e7ed;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  height: 60px;
  flex-shrink: 0;
}
.header-left { display: flex; align-items: center; }
.collapse-btn { cursor: pointer; }
.header-right { display: flex; align-items: center; gap: 12px; }
.user-name { font-weight: 500; }
.notif-badge { margin-right: 4px; }

.main {
  background: #F1F5F9;
  padding: 12px 20px 20px;
  height: calc(100vh - 60px);
  overflow-y: auto;
  box-sizing: border-box;
}
.main :deep(h2) {
  margin: 0 0 8px;
  font-size: 20px;
}
</style>
