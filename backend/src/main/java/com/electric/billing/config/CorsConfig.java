package com.electric.billing.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.List;

/**
 * 跨域资源共享 (CORS) 配置
 *
 * <p>为什么需要 CORS？
 * <ul>
 *   <li>前端 (Vue 3 + Vite) 运行在 localhost:5173</li>
 *   <li>后端 (Spring Boot) 运行在 localhost:8080</li>
 *   <li>浏览器同源策略会阻止不同端口间的 AJAX 请求</li>
 *   <li>此配置告诉浏览器："允许来自 5173 的请求访问本后端"</li>
 * </ul>
 *
 * <p>注意: 生产环境中应限制 allowedOrigins 为具体域名，生产不使用 "*"
 *
 * @author Electric Billing Team
 */
@Configuration  // 标记为 Spring 配置类
public class CorsConfig {

    /**
     * 注册 CORS 过滤器 Bean。
     *
     * <p>Spring Boot 会自动检测 CorsFilter Bean 并应用到整个过滤器链。
     * 优先级高于 WebMvcConfigurer.addCorsMappings() 方式。
     *
     * @return CorsFilter 实例
     */
    @Bean
    public CorsFilter corsFilter() {
        // 步骤1: 创建 CORS 配置对象
        CorsConfiguration config = new CorsConfiguration();

        // 步骤2: 允许的源（前端开发服务器地址）
        //        setAllowedOriginPatterns 支持通配符，比 setAllowedOrigins 更灵活
        //        生产环境应改为: "https://你的域名.com"
        config.setAllowedOriginPatterns(List.of(
                "http://localhost:5173",    // Vite 默认开发端口
                "http://127.0.0.1:5173"     // 部分浏览器用 127.0.0.1
        ));

        // 步骤3: 是否允许携带 Cookie/认证信息
        //        如果前端使用 axios withCredentials: true，此处必须设为 true
        config.setAllowCredentials(true);

        // 步骤4: 允许的 HTTP 方法
        config.setAllowedMethods(List.of(
                "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"
        ));

        // 步骤5: 允许的请求头
        //        allowCredentials(true) 与 "*" 不兼容（CORS 规范禁止）
        config.setAllowedHeaders(List.of(
                "Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"
        ));

        // 步骤6: 预检请求 (OPTIONS) 缓存时间（秒）
        //        浏览器在有效期内不会重复发送 OPTIONS 预检
        config.setMaxAge(3600L);

        // 步骤7: 将 CORS 配置绑定到所有路径 (/**)
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);

        // 步骤8: 返回 CorsFilter Bean
        return new CorsFilter(source);
    }
}
