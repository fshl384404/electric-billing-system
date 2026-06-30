package com.electric.billing.module.chat;

import com.electric.billing.common.R;
import com.electric.billing.security.AuthContext;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.Map;

/**
 * 智能客服 SSE 端点
 */
@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    /** SSE 流式对话 */
    @PostMapping(produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter chat(@RequestBody Map<String, String> body) {
        String message = body.get("message");
        if (message == null || message.isBlank()) {
            throw new com.electric.billing.common.BusinessException("消息不能为空");
        }

        Long userId = AuthContext.getCurrentUserId();
        String username = AuthContext.getCurrentUsername();
        String role = AuthContext.getCurrentRole();
        if (userId == null) {
            throw new com.electric.billing.common.BusinessException(401, "请先登录");
        }

        return chatService.chat(userId, username, role, message);
    }

    /** 清空对话历史 */
    @DeleteMapping("/history")
    public R<?> clearHistory() {
        Long userId = AuthContext.getCurrentUserId();
        if (userId == null) {
            return R.fail(401, "请先登录");
        }
        chatService.clearHistory(userId);
        return R.ok();
    }
}
