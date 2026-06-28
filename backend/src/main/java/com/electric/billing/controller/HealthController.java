package com.electric.billing.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 健康检查 & 前后端通信测试控制器
 *
 * <p>提供 /api/ping 端点，用于验证:
 * <ul>
 *   <li>后端服务是否正常启动</li>
 *   <li>前端能否成功跨域调用后端接口</li>
 *   <li>CORS 配置是否生效</li>
 * </ul>
 *
 * <p>所有接口统一以 /api 为前缀，方便:
 * <ul>
 *   <li>前端代理配置 (Vite proxy 将 /api/* 转发到后端)</li>
 *   <li>Nginx 反向代理规则编写</li>
 *   <li>未来 API 网关路径匹配</li>
 * </ul>
 *
 * @author Electric Billing Team
 */
@RestController                    // = @Controller + @ResponseBody（每个方法返回 JSON）
@RequestMapping("/api")           // 统一路径前缀: /api/*
public class HealthController {

    /**
     * 前后端通信测试端点。
     *
     * <p>请求示例:
     * <pre>
     *   GET http://localhost:8080/api/ping
     * </pre>
     *
     * <p>响应示例:
     * <pre>
     * {
     *   "status": "ok",
     *   "message": "民用电缴费系统后端服务运行中",
     *   "timestamp": "2026-06-28 15:30:00",
     *   "javaVersion": "24.0.2",
     *   "appName": "electric-billing-system"
     * }
     * </pre>
     *
     * @return 包含服务状态和系统信息的一个 Map（自动序列化为 JSON）
     */
    @GetMapping("/ping")
    public Map<String, Object> ping() {
        // 使用 LinkedHashMap 保持字段插入顺序
        Map<String, Object> result = new LinkedHashMap<>();

        result.put("status", "ok");
        result.put("message", "民用电缴费系统后端服务运行中");
        result.put("appName", "electric-billing-system");
        result.put("version", "1.0.0-SNAPSHOT");

        // 当前服务器时间（ISO 格式）
        result.put("timestamp", LocalDateTime.now()
                .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));

        // 运行时 Java 版本
        result.put("javaVersion", System.getProperty("java.version"));

        // Spring Boot 版本
        result.put("springBootVersion",
                org.springframework.boot.SpringBootVersion.getVersion());

        return result;
    }

    /**
     * 根路径欢迎页。
     *
     * <p>浏览器直接访问 http://localhost:8080/api 时显示
     *
     * @return 欢迎信息
     */
    @GetMapping("")
    public Map<String, Object> index() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("app", "民用电缴费系统");
        result.put("docs", "/api/ping — 通信测试");
        result.put("swagger", "待集成 (SpringDoc OpenAPI)");
        result.put("time", LocalDateTime.now().toString());
        return result;
    }
}
