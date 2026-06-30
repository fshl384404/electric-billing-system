package com.electric.billing.module.chat;

import com.electric.billing.config.OllamaConfig;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/**
 * RAG 智能客服核心服务
 *
 * 流程: embed → ChromaDB检索 → buildPrompt → Ollama streaming chat (with tools) → tool_call? → execute → continue
 */
@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);
    private static final int MAX_HISTORY = 10;           // 保留最近 10 轮对话
    private static final int TOP_K = 4;                   // 检索返回文档数
    private static final String COLLECTION_NAME = "elec_knowledge";

    private final OllamaConfig config;
    private final RestTemplate restTemplate;
    private final ToolExecutor toolExecutor;
    private final ObjectMapper mapper = new ObjectMapper();

    // 对话历史 (userId → messages)
    private final Map<Long, List<Map<String, Object>>> histories = new ConcurrentHashMap<>();

    public ChatService(OllamaConfig config, RestTemplate restTemplate, ToolExecutor toolExecutor) {
        this.config = config;
        this.restTemplate = restTemplate;
        this.toolExecutor = toolExecutor;
    }

    // ========================================================================
    // 公开接口
    // ========================================================================

    /** 开始 SSE 流式对话 */
    public SseEmitter chat(Long userId, String username, String role, String message) {
        SseEmitter emitter = new SseEmitter(180_000L); // 3 分钟超时

        Thread.ofVirtual().start(() -> {
            try {
                doChat(emitter, userId, username, message);
            } catch (Exception e) {
                log.error("Chat error for user {}", userId, e);
                safeSend(emitter, SseEmitter.event().name("error").data("服务异常，请稍后重试"));
                emitter.completeWithError(e);
            }
        });

        return emitter;
    }

    /** 清空对话历史 */
    public void clearHistory(Long userId) {
        histories.remove(userId);
    }

    // ========================================================================
    // 核心流程
    // ========================================================================

    private void doChat(SseEmitter emitter, Long userId, String username, String message) throws Exception {
        log.info("[CHAT] userId={}, query='{}'", userId, message);

        // 1. 意图检测 + 预取用户数据
        String userDataContext = null;
        try {
            userDataContext = detectAndFetchUserData(userId, message);
        } catch (Exception e) {
            log.warn("[CHAT] Pre-fetch failed: {}", e.getMessage());
        }

        // 2. 嵌入 → ChromaDB 检索知识
        float[] embedding = embed(message);
        List<String> retrievedDocs = searchChroma(embedding, TOP_K);

        // 3-4. 构建消息
        List<Map<String, Object>> history = histories.computeIfAbsent(userId, k -> new ArrayList<>());
        List<Map<String, Object>> messages = buildMessages(username, message,
            retrievedDocs, userDataContext, history);

        // 5. Ollama 流式
        String assistantContent = callOllamaStreamSimple(emitter, messages);

        // 6. 保存历史
        history.add(Map.of("role", "user", "content", message));
        history.add(Map.of("role", "assistant", "content", assistantContent != null ? assistantContent : ""));
        while (history.size() > MAX_HISTORY * 2) { history.removeFirst(); history.removeFirst(); }

        emitter.complete();
    }

    /** 检测意图并预取用户数据 */
    private String detectAndFetchUserData(Long userId, String message) {
        if (userId == null) return null;
        String msg = message.toLowerCase();
        boolean asksPersonal = msg.contains("我的") || msg.contains("我上") || msg.contains("我上个月")
            || msg.contains("电费") || msg.contains("账单") || msg.contains("缴费")
            || msg.contains("欠费") || msg.contains("抄表") || msg.contains("用电")
            || msg.contains("多少钱") || msg.contains("交费") || msg.contains("扣款")
            || msg.contains("余额") || msg.contains("房产") || msg.contains("地址")
            || msg.contains("度数") || msg.contains("读数");

        if (!asksPersonal) return null;

        log.info("Personal data intent detected for user {}, pre-fetching...", userId);
        StringBuilder ctx = new StringBuilder();

        // 取用户账单
        try {
            String bills = toolExecutor.execute("get_my_bills", Map.of(), userId);
            if (bills != null && !bills.startsWith("未找到") && !bills.startsWith("暂无")) {
                ctx.append("【用户账单数据】\n").append(bills).append("\n");
            }
        } catch (Exception e) { log.warn("Pre-fetch bills failed: {}", e.getMessage()); }

        // 取电价
        try {
            String prices = toolExecutor.execute("get_price_tiers", Map.of(), userId);
            if (prices != null && !prices.startsWith("暂无")) {
                ctx.append("【当前电价】\n").append(prices).append("\n");
            }
        } catch (Exception e) { log.warn("Pre-fetch prices failed: {}", e.getMessage()); }

        // 取缴费记录（如果用户问缴费相关）
        if (msg.contains("缴费") || msg.contains("支付") || msg.contains("交费") || msg.contains("交了")) {
            try {
                String payments = toolExecutor.execute("get_my_payments", Map.of(), userId);
                if (payments != null && !payments.startsWith("暂无")) {
                    ctx.append("【用户缴费记录】\n").append(payments).append("\n");
                }
            } catch (Exception e) { log.warn("Pre-fetch payments failed: {}", e.getMessage()); }
        }

        // 取抄表记录（如果用户问用电/度数）
        if (msg.contains("用电") || msg.contains("度数") || msg.contains("抄表") || msg.contains("读数")) {
            try {
                String readings = toolExecutor.execute("get_my_meter_readings", Map.of(), userId);
                if (readings != null && !readings.startsWith("暂无")) {
                    ctx.append("【用户抄表记录】\n").append(readings).append("\n");
                }
            } catch (Exception e) { log.warn("Pre-fetch readings failed: {}", e.getMessage()); }
        }

        return ctx.length() > 0 ? ctx.toString() : null;
    }

    // ========================================================================
    // 嵌入 & 检索
    // ========================================================================

    /** 调用 Ollama 嵌入 API */
    private float[] embed(String text) {
        try {
            Map<String, Object> req = Map.of("model", config.getEmbedModel(), "prompt", text);
            Map<String, Object> resp = restTemplate.postForObject(
                config.getOllamaUrl() + "/api/embeddings", req, Map.class);
            if (resp == null) throw new RuntimeException("Empty embedding response");

            @SuppressWarnings("unchecked")
            List<Double> raw = (List<Double>) resp.get("embedding");
            float[] vec = new float[raw.size()];
            for (int i = 0; i < raw.size(); i++) vec[i] = raw.get(i).floatValue();
            return vec;
        } catch (Exception e) {
            log.error("Embedding failed", e);
            return new float[768]; // fallback: 零向量 (会导致检索结果不准但不会崩溃)
        }
    }

    private String cachedCollectionId = null;

    /** 从 ChromaDB 检索 */
    private List<String> searchChroma(float[] embedding, int topK) {
        try {
            // 解析 collection ID (带缓存)
            String collId = getCollectionId();

            Map<String, Object> req = new LinkedHashMap<>();
            req.put("query_embeddings", List.of(embedding));
            req.put("n_results", topK);
            req.put("include", List.of("documents"));

            String url = config.getChromaUrl()
                + "/api/v2/tenants/default_tenant/databases/default_database/collections/"
                + collId + "/query";

            @SuppressWarnings("unchecked")
            Map<String, Object> resp = restTemplate.postForObject(url, req, Map.class);

            if (resp == null || !resp.containsKey("documents")) {
                return List.of();
            }

            @SuppressWarnings("unchecked")
            List<List<String>> outer = (List<List<String>>) resp.get("documents");
            return outer.isEmpty() ? List.of() : outer.getFirst();
        } catch (Exception e) {
            log.warn("ChromaDB search failed (is ChromaDB running?): {}", e.getMessage());
            return List.of(); // 优雅降级
        }
    }

    /** 获取 collection ID (按名称解析，缓存结果) */
    private String getCollectionId() {
        if (cachedCollectionId != null) return cachedCollectionId;
        try {
            String url = config.getChromaUrl()
                + "/api/v2/tenants/default_tenant/databases/default_database/collections";
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> cols = restTemplate.getForObject(url, List.class);
            if (cols != null) {
                for (Map<String, Object> col : cols) {
                    if (COLLECTION_NAME.equals(col.get("name"))) {
                        cachedCollectionId = (String) col.get("id");
                        log.info("Resolved ChromaDB collection '{}' → {}", COLLECTION_NAME, cachedCollectionId);
                        return cachedCollectionId;
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Failed to resolve collection ID: {}", e.getMessage());
        }
        throw new RuntimeException("Cannot find ChromaDB collection: " + COLLECTION_NAME);
    }

    // ========================================================================
    // Prompt 构建
    // ========================================================================

    private List<Map<String, Object>> buildMessages(String username, String userMsg,
                                                     List<String> docs,
                                                     String userDataContext,
                                                     List<Map<String, Object>> history) {
        List<Map<String, Object>> messages = new ArrayList<>();

        String sysPrompt = buildSystemPrompt(username, docs, userDataContext);
        messages.add(Map.of("role", "system", "content", sysPrompt));

        int start = Math.max(0, history.size() - 8);
        messages.addAll(history.subList(start, history.size()));
        messages.add(Map.of("role", "user", "content", userMsg));

        return messages;
    }

    private String buildSystemPrompt(String username, List<String> docs, String userDataContext) {
        StringBuilder sb = new StringBuilder();
        sb.append("你是民用电缴费系统的智能客服，用中文简洁回答（不超过 200 字）。\n\n");

        // 规则：如果已查到用户数据，直接告诉模型"这是你查到的"，让它直接引用
        if (userDataContext != null && !userDataContext.isBlank()) {
            sb.append("重要：你刚刚查询了数据库，得到了以下数据，请直接引用这些数据回答用户：\n");
            sb.append(userDataContext).append("\n\n");
            sb.append("请根据以上数据直接回答，不要说你不知道、需要更多信息或请用户自己去查。\n");
            sb.append("如果数据不足以回答用户问题，告诉他你查到了什么并给出相关建议。\n\n");
        } else if (!docs.isEmpty()) {
            // 没有用户数据但有知识库
            sb.append("以下是相关知识，请据此回答用户的问题：\n");
            for (int i = 0; i < Math.min(docs.size(), 2); i++) {
                sb.append(docs.get(i)).append("\n");
            }
            sb.append("\n");
        } else {
            sb.append("如果无法回答用户的问题，建议他提交工单或联系管理员。\n");
        }
        sb.append("不要说调用函数、执行命令等后台术语。");

        return sb.toString();
    }

    // ========================================================================
    // Ollama 流式调用 (简化版 — 不传 tools，3B 模型直接回答更可靠)
    // ========================================================================

    private String callOllamaStreamSimple(SseEmitter emitter, List<Map<String, Object>> messages) throws Exception {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", config.getModel());
        body.put("messages", messages);
        body.put("stream", true);
        body.put("options", Map.of("temperature", 0.3));

        String jsonBody = mapper.writeValueAsString(body);

        URI uri = URI.create(config.getOllamaUrl() + "/api/chat");
        HttpURLConnection conn = (HttpURLConnection) uri.toURL().openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setDoOutput(true);
        conn.setConnectTimeout(10_000);
        conn.setReadTimeout(120_000);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(jsonBody.getBytes(StandardCharsets.UTF_8));
        }

        int status = conn.getResponseCode();
        if (status != 200) {
            String err = new String(conn.getErrorStream().readAllBytes(), StandardCharsets.UTF_8);
            log.error("Ollama returned {}: {}", status, err);
            safeSend(emitter, SseEmitter.event().name("error").data("AI 服务响应异常"));
            return null;
        }

        StringBuilder fullContent = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.isBlank()) continue;
                try {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> chunk = mapper.readValue(line, Map.class);

                    @SuppressWarnings("unchecked")
                    Map<String, Object> msg = (Map<String, Object>) chunk.get("message");
                    if (msg != null) {
                        String token = (String) msg.get("content");
                        if (token != null && !token.isEmpty()) {
                            fullContent.append(token);
                            safeSend(emitter, SseEmitter.event().name("token").data(token));
                        }
                    }
                } catch (Exception ignored) { }
            }
        }

        return fullContent.toString();
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    private void safeSend(SseEmitter emitter, SseEmitter.SseEventBuilder event) {
        try {
            emitter.send(event);
        } catch (Exception e) {
            log.debug("SSE send failed (client disconnected?): {}", e.getMessage());
        }
    }
}
