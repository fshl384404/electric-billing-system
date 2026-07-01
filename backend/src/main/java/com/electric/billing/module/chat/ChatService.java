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

        // 1. 意图检测 + 预取用户数据 (包含预计算答案)
        String precomputedAnswer = null;
        String userDataContext = null;
        try {
            String[] result = detectAndFetchUserData(userId, message);
            if (result != null) {
                precomputedAnswer = result[0];  // 预计算好的答案
                userDataContext = result[1];     // 原始数据（备用）
            }
        } catch (Exception e) {
            log.warn("[CHAT] Pre-fetch failed: {}", e.getMessage());
        }

        // 2. 嵌入 → ChromaDB 检索知识
        //    注意: 当有预计算答案时，跳过向量检索——知识库内容只会干扰模型
        List<String> retrievedDocs;
        if (precomputedAnswer != null) {
            retrievedDocs = List.of();  // 不需要知识库
        } else {
            float[] embedding = embed(message);
            retrievedDocs = searchChroma(embedding, TOP_K);
        }

        // 3-4. 构建消息
        List<Map<String, Object>> history = histories.computeIfAbsent(userId, k -> new ArrayList<>());
        List<Map<String, Object>> messages = buildMessages(username, message,
            retrievedDocs, precomputedAnswer, userDataContext, history);

        // 5. Ollama 流式
        String assistantContent = callOllamaStreamSimple(emitter, messages);

        // 6. 保存历史
        history.add(Map.of("role", "user", "content", message));
        history.add(Map.of("role", "assistant", "content", assistantContent != null ? assistantContent : ""));
        while (history.size() > MAX_HISTORY * 2) { history.removeFirst(); history.removeFirst(); }

        emitter.complete();
    }

    /**
     * 检测意图并预取用户数据。
     * @return [预计算的答案, 原始数据] — 预计算答案可直接交给模型复述；为 null 表示非个人数据问题
     */
    private String[] detectAndFetchUserData(Long userId, String message) {
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

        // 检测目标月份
        String targetMonth = detectTargetMonth(message);

        // 查询账单并预计算答案
        StringBuilder answer = new StringBuilder();
        StringBuilder rawData = new StringBuilder();

        try {
            Map<String, Object> billArgs = new java.util.HashMap<>();
            if (targetMonth != null) billArgs.put("billMonth", targetMonth);
            String bills = toolExecutor.execute("get_my_bills", billArgs, userId);
            if (bills != null && !bills.startsWith("未找到") && !bills.startsWith("暂无")) {
                String summary = buildBillSummary(bills, targetMonth);
                rawData.append(bills);

                if (summary != null) {
                    // 构建针对用户问题的自然语言答案
                    boolean askingTotal = msg.contains("多少钱") || msg.contains("多少电费")
                        || msg.contains("费用") || msg.contains("合计") || msg.contains("总共");
                    boolean askingStatus = msg.contains("欠费") || msg.contains("逾期")
                        || msg.contains("待缴") || msg.contains("已缴") || msg.contains("缴费");

                    answer.append(summary).append("。");

                    // 补充提醒
                    if (summary.contains("逾期")) {
                        answer.append("请尽快缴纳逾期账单，避免产生更多滞纳金或断电风险。");
                    } else if (askingStatus && summary.contains("待缴")) {
                        answer.append("请在截止日前完成缴费，逾期将产生滞纳金。");
                    }
                }
            } else {
                String monthLabel = targetMonth != null ? formatMonthLabel(targetMonth) : "";
                answer.append(monthLabel.isEmpty()
                    ? "抱歉，未找到您的账单记录。"
                    : "您" + monthLabel + "没有电费账单记录。");
            }
        } catch (Exception e) {
            log.warn("Pre-fetch bills failed: {}", e.getMessage());
            return null;
        }

        // 如果用户还问了缴费记录
        if (msg.contains("缴费") || msg.contains("支付") || msg.contains("交费") || msg.contains("交了")) {
            try {
                String payments = toolExecutor.execute("get_my_payments", Map.of(), userId);
                if (payments != null && !payments.startsWith("暂无")) {
                    rawData.append("\n").append(payments);
                    answer.append("\n").append(payments.replace("您的最近缴费记录:\n", "您的缴费记录："));
                }
            } catch (Exception e) { log.warn("Pre-fetch payments failed: {}", e.getMessage()); }
        }

        return new String[]{answer.toString(), rawData.toString()};
    }

    /** YYYYMM → "YYYY年M月" */
    private String formatMonthLabel(String yyyymm) {
        String y = yyyymm.substring(0, 4);
        String m = yyyymm.substring(4);
        return y + "年" + Integer.parseInt(m) + "月";
    }

    /** 从用户消息中提取目标月份 (YYYYMM 格式)。未识别到则返回 null */
    private String detectTargetMonth(String message) {
        java.time.YearMonth now = java.time.YearMonth.now();
        String msg = message.toLowerCase();

        // "上个月" / "上月" → 当前月 - 1
        if (msg.contains("上个月") || msg.contains("上月")) {
            return now.minusMonths(1).format(java.time.format.DateTimeFormatter.ofPattern("yyyyMM"));
        }
        // "上上月" / "前个月" → 当前月 - 2
        if (msg.contains("上上月") || msg.contains("前个月")) {
            return now.minusMonths(2).format(java.time.format.DateTimeFormatter.ofPattern("yyyyMM"));
        }
        // "这个月" / "本月" → 当前月
        if (msg.contains("这个月") || msg.contains("本月")) {
            return now.format(java.time.format.DateTimeFormatter.ofPattern("yyyyMM"));
        }
        // "YYYY年M月" / "YYYY-MM" 等格式
        java.util.regex.Pattern p = java.util.regex.Pattern.compile("(\\d{4})\\s*年\\s*(\\d{1,2})\\s*月");
        java.util.regex.Matcher m = p.matcher(message);
        if (m.find()) {
            return m.group(1) + String.format("%02d", Integer.parseInt(m.group(2)));
        }
        // "M月份" / "M月" (无年份 → 当前年份)
        p = java.util.regex.Pattern.compile("(?<![0-9])(\\d{1,2})\\s*月(?:份)?");
        m = p.matcher(message);
        if (m.find()) {
            int month = Integer.parseInt(m.group(1));
            if (month >= 1 && month <= 12) {
                return now.getYear() + String.format("%02d", month);
            }
        }
        return null;
    }

    /** 从账单明细文本中提取汇总信息。targetMonth 为 null 时汇总全部，否则只汇总指定月份 */
    private String buildBillSummary(String bills, String targetMonth) {
        // 账单格式: - [202606] 用量: 371kWh, 金额: 193.99元, 滞纳金: 0.00元, 状态: PENDING, 地址: xxx
        int totalCount = 0;
        double totalAmount = 0;
        int overdueCount = 0;
        int pendingCount = 0;
        int paidCount = 0;
        double overdueAmount = 0;
        double pendingAmount = 0;

        for (String line : bills.split("\n")) {
            if (!line.trim().startsWith("- [")) continue;
            // 如果指定了目标月份，跳过不匹配的行
            if (targetMonth != null) {
                int bracketEnd = line.indexOf("]");
                if (bracketEnd < 0) continue;
                String month = line.substring(line.indexOf("[") + 1, bracketEnd);
                if (!targetMonth.equals(month)) continue;
            }
            totalCount++;
            // 提取金额
            int amountIdx = line.indexOf("金额:");
            if (amountIdx >= 0) {
                int end = line.indexOf("元", amountIdx);
                if (end > amountIdx) {
                    try {
                        double amt = Double.parseDouble(line.substring(amountIdx + 3, end).trim());
                        totalAmount += amt;
                    } catch (NumberFormatException ignored) {}
                }
            }
            if (line.contains("OVERDUE")) {
                overdueCount++;
                int amtIdx = line.indexOf("金额:");
                if (amtIdx >= 0) {
                    int end = line.indexOf("元", amtIdx);
                    if (end > amtIdx) {
                        try { overdueAmount += Double.parseDouble(line.substring(amtIdx + 3, end).trim()); } catch (NumberFormatException ignored) {}
                    }
                }
            } else if (line.contains("PENDING")) {
                pendingCount++;
                int amtIdx = line.indexOf("金额:");
                if (amtIdx >= 0) {
                    int end = line.indexOf("元", amtIdx);
                    if (end > amtIdx) {
                        try { pendingAmount += Double.parseDouble(line.substring(amtIdx + 3, end).trim()); } catch (NumberFormatException ignored) {}
                    }
                }
            } else if (line.contains("PAID")) {
                paidCount++;
            }
        }

        if (totalCount == 0) {
            if (targetMonth != null) {
                return "该用户在 " + targetMonth + " 月份没有电费账单。";
            }
            return null;
        }

        // 格式化月份显示
        String monthLabel = "";
        if (targetMonth != null) {
            String y = targetMonth.substring(0, 4);
            String mo = targetMonth.substring(4);
            monthLabel = y + "年" + Integer.parseInt(mo) + "月";
        }

        StringBuilder sb = new StringBuilder();
        if (!monthLabel.isEmpty()) {
            sb.append("用户 ").append(monthLabel).append(" 共有 ").append(totalCount).append(" 笔账单");
        } else {
            sb.append("该用户共有 ").append(totalCount).append(" 笔账单");
        }
        sb.append(", 合计金额 ").append(String.format("%.2f", totalAmount)).append(" 元");
        if (paidCount > 0) sb.append(", 其中已缴 ").append(paidCount).append(" 笔");
        if (pendingCount > 0) sb.append(", 待缴 ").append(pendingCount).append(" 笔 ").append(String.format("%.2f", pendingAmount)).append(" 元");
        if (overdueCount > 0) sb.append(", 逾期 ").append(overdueCount).append(" 笔 ").append(String.format("%.2f", overdueAmount)).append(" 元（请提醒用户尽快缴纳）");
        sb.append("。");

        return sb.toString();
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
                                                     String precomputedAnswer,
                                                     String userDataContext,
                                                     List<Map<String, Object>> history) {
        List<Map<String, Object>> messages = new ArrayList<>();

        String sysPrompt = buildSystemPrompt(docs, precomputedAnswer, userDataContext);
        messages.add(Map.of("role", "system", "content", sysPrompt));

        int start = Math.max(0, history.size() - 8);
        messages.addAll(history.subList(start, history.size()));
        messages.add(Map.of("role", "user", "content", userMsg));

        return messages;
    }

    private String buildSystemPrompt(List<String> docs, String precomputedAnswer, String userDataContext) {
        StringBuilder sb = new StringBuilder();
        sb.append("你是民用电缴费系统的智能客服，用中文简洁回答（不超过 200 字）。\n\n");

        if (precomputedAnswer != null && !precomputedAnswer.isBlank()) {
            // 核心模式: 预计算答案 — 模型只需用自然语言复述
            sb.append("系统已查数据库并计算完毕。正确的回答如下，请用自然的口吻对用户说一遍"
                + "（可以调整措辞但不要改变数字和事实）：\n\n");
            sb.append("【正确答案】\n");
            sb.append(precomputedAnswer).append("\n\n");
            sb.append("你只需要把上面的【正确答案】用口语化的方式告诉用户即可。"
                + "不要说你不知道，不要说需要更多信息，不要叫用户自己去查。");
        } else if (userDataContext != null && !userDataContext.isBlank()) {
            // 降级模式: 有原始数据但无预计算答案
            sb.append("以下是从数据库查到的用户数据，请据此回答用户问题：\n");
            sb.append(userDataContext).append("\n\n");
            sb.append("请直接引用这些数据回答，不要推诿。");
        } else if (!docs.isEmpty()) {
            // 知识库模式
            sb.append("以下是相关知识，请据此回答：\n");
            for (int i = 0; i < Math.min(docs.size(), 2); i++) {
                sb.append(docs.get(i)).append("\n");
            }
            sb.append("\n");
        } else {
            sb.append("如果无法回答，建议用户提交工单或联系管理员。\n");
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
