package com.electric.billing.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * JWT 认证过滤器 — 每个请求进入控制器前校验 Token
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    /** 无需认证即可访问的路径 */
    private static final List<String> PUBLIC_PATHS = List.of(
            "/api/auth/login",
            "/api/auth/register",
            "/api/ping",
            "/api"
    );

    private final JwtUtils jwtUtils;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public JwtAuthFilter(JwtUtils jwtUtils) {
        this.jwtUtils = jwtUtils;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain)
            throws ServletException, IOException {

        String path = request.getRequestURI();

        // 公开路径跳过认证
        if (isPublicPath(path)) {
            chain.doFilter(request, response);
            return;
        }

        // 提取 Authorization header
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            writeAuthError(response, 401, "未登录或 Token 格式错误");
            return;
        }

        String token = authHeader.substring(7);
        if (!jwtUtils.validateToken(token)) {
            writeAuthError(response, 401, "Token 无效或已过期");
            return;
        }

        // 将用户信息写入上下文
        AuthContext.set(
                jwtUtils.getUserIdFromToken(token),
                jwtUtils.getUsernameFromToken(token),
                jwtUtils.getRoleFromToken(token)
        );

        try {
            chain.doFilter(request, response);
        } finally {
            AuthContext.clear();
        }
    }

    /** 直接写入 JSON 错误响应（Filter 层异常无法被 @RestControllerAdvice 捕获） */
    private void writeAuthError(HttpServletResponse response, int code, String message) throws IOException {
        response.setStatus(200); // HTTP 200，业务错误码在 body 中
        response.setContentType("application/json;charset=UTF-8");
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("code", code);
        body.put("message", message);
        body.put("data", null);
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }

    private boolean isPublicPath(String path) {
        return PUBLIC_PATHS.stream().anyMatch(p ->
                p.endsWith("/**") ? path.startsWith(p.replace("/**", "")) : path.equals(p)
        );
    }
}
