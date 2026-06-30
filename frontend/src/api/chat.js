/**
 * 智能客服 SSE 流式 API
 *
 * SSE 协议:  event: <type>\n  data: <payload>\n\n
 * 我们用 event 区分消息类型: token(文本增量), status(状态提示), error(错误), done(结束)
 */

const BASE = ''

export default {
  /**
   * 发送消息，返回 Reader 流
   *
   * @param {string} message
   * @param {object} handlers - { onToken, onStatus, onError, onDone }
   * @returns {function} cancel — 取消请求
   */
  send(message, handlers = {}) {
    const token = localStorage.getItem('token')
    const controller = new AbortController()
    const { onToken, onStatus, onError, onDone } = handlers

    fetch(`${BASE}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ? `Bearer ${token}` : ''
      },
      body: JSON.stringify({ message }),
      signal: controller.signal
    }).then(async (response) => {
      if (!response.ok) {
        let msg = '请求失败'
        try {
          const t = await response.text()
          const j = JSON.parse(t)
          msg = j.message || msg
        } catch (_) { /* keep default */ }
        onError?.(msg)
        return
      }

      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ''
      let currentEvent = 'token'

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        buffer += decoder.decode(value, { stream: true })

        // 按空行分割 SSE 事件块
        const blocks = buffer.split('\n\n')
        buffer = blocks.pop() || ''  // 保留最后一个不完整块

        for (const block of blocks) {
          if (!block.trim()) continue
          const lines = block.split('\n')
          let eventType = 'token'
          let data = ''

          for (const line of lines) {
            if (line.startsWith('event:')) {
              eventType = line.substring(6).trim()
            } else if (line.startsWith('data:')) {
              data = line.substring(5).trim()
            }
          }

          if (!data) continue

          // 分发
          switch (eventType) {
            case 'token':
              onToken?.(data)
              break
            case 'status':
              onStatus?.(data)
              break
            case 'error':
              onError?.(data)
              break
            default:
              // 未知类型也当 token 处理
              onToken?.(data)
          }
        }
      }

      onDone?.()
    }).catch(err => {
      if (err.name !== 'AbortError') {
        onError?.(err.message || '网络连接失败，请检查后端服务')
      }
    })

    return () => controller.abort()
  },

  /** 清空对话历史 */
  clearHistory() {
    const token = localStorage.getItem('token')
    return fetch(`${BASE}/api/chat/history`, {
      method: 'DELETE',
      headers: { 'Authorization': token ? `Bearer ${token}` : '' }
    })
  }
}
