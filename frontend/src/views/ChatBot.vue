<template>
  <div class="chatbot-container" :style="containerStyle">
    <!-- 悬浮按钮 (可拖动) -->
    <div
      v-if="!open"
      class="chatbot-float-btn"
      :style="btnStyle"
      @mousedown="onDragStart"
      @touchstart.prevent="onDragStart"
      title="智能客服（可拖动）"
    >
      <span class="chatbot-btn-icon">💬</span>
    </div>

    <!-- 聊天面板 -->
    <transition name="chatbot-slide">
      <div v-if="open" class="chatbot-panel" :style="panelStyle">
        <!-- 顶栏 -->
        <div class="chatbot-header">
          <span>🤖 智能客服</span>
          <div class="chatbot-header-actions">
            <el-button text size="small" @click="handleNewChat" :disabled="sending">新对话</el-button>
            <el-button text size="small" @click="open = false">✕</el-button>
          </div>
        </div>

        <!-- 消息区 -->
        <div class="chatbot-messages" ref="msgBox">
          <div v-if="messages.length === 0" class="chatbot-welcome">
            <p>👋 您好！我是电力服务助手。</p>
            <p>您可以问我：</p>
            <ul>
              <li @click="sendQuick('我上个月电费多少钱？')">"我上个月电费多少钱？"</li>
              <li @click="sendQuick('阶梯电价怎么算的？')">"阶梯电价怎么算的？"</li>
              <li @click="sendQuick('忘记密码怎么办？')">"忘记密码怎么办？"</li>
              <li @click="sendQuick('如何在线缴费？')">"如何在线缴费？"</li>
            </ul>
          </div>

          <div v-for="(msg, i) in messages" :key="i" :class="['chatbot-msg', msg.role]">
            <span class="chatbot-msg-avatar">{{ msg.role === 'user' ? '👤' : '🤖' }}</span>
            <div
              :class="['chatbot-msg-bubble', { typing: msg.role === 'assistant' && i === messages.length - 1 && sending && !msg.content }]"
              v-html="renderContent(msg, i)"
            ></div>
          </div>
        </div>

        <!-- 输入区 -->
        <div class="chatbot-input">
          <el-input
            v-model="input"
            placeholder="输入问题..."
            @keyup.enter="handleSend"
            :disabled="sending"
            maxlength="500"
            show-word-limit
          />
          <el-button type="primary" :disabled="!input.trim() || sending" @click="handleSend" :loading="sending">
            发送
          </el-button>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, watch, onMounted, onUnmounted } from 'vue'
import { ElMessage } from 'element-plus'
import chatApi from '@/api/chat'

const open = ref(false)
const input = ref('')
const sending = ref(false)
const streamingText = ref('')
const messages = ref([])   // { role: 'user'|'assistant', content: '...' }
const msgBox = ref(null)
let cancelFn = null

// ---- 拖动 ----
const btnX = ref(window.innerWidth - 80)   // 默认右下角
const btnY = ref(window.innerHeight - 80)
const dragging = ref(false)
const dragStartX = ref(0)
const dragStartY = ref(0)
const dragOrigX = ref(0)
const dragOrigY = ref(0)
const hasMoved = ref(false)   // 区分点击和拖动

const containerStyle = computed(() => {
  if (open.value) return {}   // 打开时固定在右下角
  return {
    right: 'auto',
    bottom: 'auto',
    left: btnX.value + 'px',
    top: btnY.value + 'px'
  }
})

const btnStyle = computed(() => {
  if (dragging.value) return { transition: 'none' }
  return {}
})

const panelStyle = computed(() => {
  const pw = 400   // 面板宽度
  const ph = 560   // 面板高度
  const gap = 12   // 与按钮的间距
  const btnSize = 56

  const btnCenterX = btnX.value + btnSize / 2
  const btnCenterY = btnY.value + btnSize / 2

  // 智能方向：按钮在哪半边，面板就向反方向打开
  const toRight = btnCenterX < window.innerWidth / 2
  const toBottom = btnCenterY < window.innerHeight / 2

  const style = {}

  if (toRight) {
    style.left = (btnX.value + btnSize + gap) + 'px'
  } else {
    style.left = (btnX.value - pw - gap) + 'px'
  }
  style.left = clamp(parseFloat(style.left), 8, window.innerWidth - pw - 8) + 'px'

  if (toBottom) {
    style.top = btnY.value + 'px'
  } else {
    style.top = (btnY.value + btnSize - ph) + 'px'
  }
  style.top = clamp(parseFloat(style.top), 8, window.innerHeight - ph - 8) + 'px'

  style.right = 'auto'
  style.bottom = 'auto'
  return style
})

function clamp(v, min, max) { return Math.min(max, Math.max(min, v)) }

function onDragStart(e) {
  if (dragging.value) return  // 防止 mousedown+touchstart 重复触发
  if (e.type === 'touchstart') {
    dragStartX.value = e.touches[0].clientX
    dragStartY.value = e.touches[0].clientY
  } else {
    dragStartX.value = e.clientX
    dragStartY.value = e.clientY
  }
  dragOrigX.value = btnX.value
  dragOrigY.value = btnY.value
  hasMoved.value = false
  dragging.value = true

  const onMove = (ev) => {
    const cx = ev.type.startsWith('touch') ? ev.touches[0].clientX : ev.clientX
    const cy = ev.type.startsWith('touch') ? ev.touches[0].clientY : ev.clientY
    const dx = cx - dragStartX.value
    const dy = cy - dragStartY.value
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) hasMoved.value = true
    btnX.value = clamp(dragOrigX.value + dx, 0, window.innerWidth - 56)
    btnY.value = clamp(dragOrigY.value + dy, 0, window.innerHeight - 56)
  }

  const onUp = () => {
    dragging.value = false
    document.removeEventListener('mousemove', onMove)
    document.removeEventListener('mouseup', onUp)
    document.removeEventListener('touchmove', onMove)
    document.removeEventListener('touchend', onUp)
    // 只有纯点击（未拖动）才打开面板
    if (!hasMoved.value) open.value = true
  }

  document.addEventListener('mousemove', onMove)
  document.addEventListener('mouseup', onUp)
  document.addEventListener('touchmove', onMove, { passive: false })
  document.addEventListener('touchend', onUp)
}

onMounted(() => {
  btnX.value = window.innerWidth - 80
  btnY.value = window.innerHeight - 80
})

// ---- 发送 ----

async function handleSend() {
  const msg = input.value.trim()
  if (!msg || sending.value) return
  input.value = ''
  await sendMessage(msg)
}

function sendQuick(text) {
  sendMessage(text)
}

async function sendMessage(text) {
  messages.value.push({ role: 'user', content: text })
  sending.value = true
  streamingText.value = ''
  scrollBottom()

  // 先添加一个空的 assistant 消息占位
  const aiIdx = messages.value.length
  messages.value.push({ role: 'assistant', content: '' })

  cancelFn = chatApi.send(text, {
    onToken(data) {
      streamingText.value += data
      messages.value[aiIdx].content += data
      scrollBottom()
    },
    onStatus(data) {
      // 状态信息：追加到当前 AI 消息
      if (messages.value[aiIdx].content) {
        messages.value[aiIdx].content += '\n\n> ' + data
      }
      scrollBottom()
    },
    onError(msg) {
      if (messages.value[aiIdx].content) {
        messages.value[aiIdx].content += '\n\n⚠️ ' + msg
      } else {
        messages.value[aiIdx].content = '⚠️ ' + msg
      }
      ElMessage.error(msg)
    },
    onDone() {
      sending.value = false
      streamingText.value = ''
      // 如果 AI 回复为空
      if (!messages.value[aiIdx].content) {
        messages.value[aiIdx].content = '抱歉，我暂时无法回答这个问题，请稍后重试或提交工单。'
      }
      scrollBottom()
    }
  })
}

// ---- 新对话 ----

async function handleNewChat() {
  cancelFn?.()
  messages.value = []
  streamingText.value = ''
  sending.value = false
  try { await chatApi.clearHistory() } catch (_) { /* ok */ }
}

// ---- 辅助 ----

function scrollBottom() {
  nextTick(() => {
    if (msgBox.value) {
      msgBox.value.scrollTop = msgBox.value.scrollHeight
    }
  })
}

function renderContent(msg, index) {
  if (msg.role !== 'assistant') return escapeHtml(msg.content)
  // 正在流式输出且内容为空时显示打字动画
  if (!msg.content && index === messages.value.length - 1 && sending.value) {
    return '<span class="typing-dots"><span>.</span><span>.</span><span>.</span></span>'
  }
  return simpleMarkdown(msg.content)
}

function escapeHtml(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function simpleMarkdown(text) {
  let html = escapeHtml(text)
  // 粗体 **text**
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
  // 行内代码 `code`
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>')
  // 换行
  html = html.replace(/\n/g, '<br>')
  return html
}

// 关闭时清理
watch(open, (val) => {
  if (!val) {
    cancelFn?.()
    sending.value = false
    streamingText.value = ''
  }
})
</script>

<style scoped>
/* ---- 悬浮按钮 ---- */
.chatbot-container {
  position: fixed;
  z-index: 9999;
  right: 24px;
  bottom: 24px;
}

.chatbot-float-btn {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: #0891B2;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: grab;
  box-shadow: 0 4px 12px rgba(0,0,0,0.2);
  transition: transform 0.2s, box-shadow 0.2s;
  user-select: none;
}
.chatbot-float-btn:active { cursor: grabbing; }
.chatbot-float-btn:hover {
  transform: scale(1.08);
  box-shadow: 0 6px 20px rgba(0,0,0,0.3);
}
.chatbot-btn-icon {
  font-size: 24px;
  pointer-events: none;
}

/* ---- 聊天面板 ---- */
.chatbot-panel {
  position: fixed;
  right: 24px;
  bottom: 24px;
  width: 400px;
  height: 560px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.18);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* 动画 */
.chatbot-slide-enter-active,
.chatbot-slide-leave-active {
  transition: all 0.25s ease;
}
.chatbot-slide-enter-from,
.chatbot-slide-leave-to {
  opacity: 0;
  transform: translateY(20px) scale(0.95);
}

/* ---- 顶栏 ---- */
.chatbot-header {
  background: #0891B2;
  color: white;
  padding: 10px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 15px;
  font-weight: 500;
  flex-shrink: 0;
}
.chatbot-header-actions {
  display: flex;
  gap: 4px;
}
.chatbot-header-actions .el-button {
  color: rgba(255,255,255,0.85);
  font-size: 13px;
}
.chatbot-header-actions .el-button:hover {
  color: white;
}

/* ---- 消息区 ---- */
.chatbot-messages {
  flex: 1;
  overflow-y: auto;
  padding: 12px;
  background: #f5f7fa;
}

.chatbot-welcome {
  text-align: center;
  color: #666;
  padding: 20px 0;
  font-size: 14px;
}
.chatbot-welcome ul {
  list-style: none;
  padding: 0;
  margin-top: 8px;
}
.chatbot-welcome li {
  color: #0891B2;
  cursor: pointer;
  padding: 6px 0;
  font-size: 13px;
  transition: color 0.15s;
}
.chatbot-welcome li:hover {
  color: #337ecc;
  text-decoration: underline;
}

/* ---- 消息气泡 ---- */
.chatbot-msg {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
}
.chatbot-msg.user {
  flex-direction: row-reverse;
}
.chatbot-msg-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: #e8ecf1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
  align-self: flex-start;
}
.chatbot-msg-bubble {
  max-width: 75%;
  padding: 10px 14px;
  border-radius: 12px;
  font-size: 14px;
  line-height: 1.6;
  word-break: break-word;
}
.chatbot-msg.user .chatbot-msg-bubble {
  background: #0891B2;
  color: white;
  border-bottom-right-radius: 4px;
}
.chatbot-msg.assistant .chatbot-msg-bubble {
  background: white;
  color: #333;
  border-bottom-left-radius: 4px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

/* 打字动画 */
.chatbot-msg-bubble.typing {
  min-width: 60px;
}
.typing-dots span {
  animation: typing-blink 1.4s infinite both;
  font-size: 20px;
  font-weight: bold;
}
.typing-dots span:nth-child(2) { animation-delay: 0.2s; }
.typing-dots span:nth-child(3) { animation-delay: 0.4s; }
@keyframes typing-blink {
  0% { opacity: 0.2; }
  20% { opacity: 1; }
  100% { opacity: 0.2; }
}

/* ---- 输入区 ---- */
.chatbot-input {
  padding: 10px 12px;
  border-top: 1px solid #ebeef5;
  display: flex;
  gap: 8px;
  background: white;
  flex-shrink: 0;
}
.chatbot-input .el-input {
  flex: 1;
}

/* ---- Markdown 渲染 ---- */
.chatbot-msg-bubble :deep(strong) {
  color: #e6a23c;
}
.chatbot-msg-bubble :deep(code) {
  background: rgba(0,0,0,0.06);
  padding: 1px 5px;
  border-radius: 3px;
  font-size: 13px;
}

/* 响应式 */
@media (max-width: 480px) {
  .chatbot-container, .chatbot-panel {
    right: 8px;
    bottom: 8px;
  }
  .chatbot-panel {
    width: calc(100vw - 16px);
    height: calc(100vh - 80px);
  }
}
</style>
