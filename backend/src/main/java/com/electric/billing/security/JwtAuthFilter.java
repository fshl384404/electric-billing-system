package com.electric.billing.security;

import com.electric.billing.common.GlobalExceptionHandler.AuthException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

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
            throw new AuthException("未登录或 Token 格式错误");
        }

        String token = authHeader.substring(7);
        if (!jwtUtils.validateToken(token)) {
            throw new AuthException("Token 无效或已过期");
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

    private boolean isPublicPath(String path) {
        return PUBLIC_PATHS.stream().anyMatch(p ->
                p.endsWith("/**") ? path.startsWith(p.replace("/**", "")) : path.equals(p)
        );
    }
}
