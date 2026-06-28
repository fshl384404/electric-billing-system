package com.electric.billing;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 民用电缴费系统 — Spring Boot 主启动类
 *
 * <p>@SpringBootApplication 是一个组合注解，等价于:
 * <ul>
 *   <li>@Configuration      — 标记该类为 Java 配置类</li>
 *   <li>@EnableAutoConfiguration — 启用 Spring Boot 自动配置机制
 *       （根据 classpath 中的依赖自动配置 DataSource、Web MVC 等）</li>
 *   <li>@ComponentScan      — 扫描当前包及其子包中的 @Component/@Service/@Controller 等</li>
 * </ul>
 *
 * <p>启动方式:
 * <pre>
 *   # 开发环境
 *   mvn spring-boot:run
 *
 *   # 生产环境（指定 profile）
 *   java -jar target/electric-billing-system.jar --spring.profiles.active=prod
 * </pre>
 *
 * @author Electric Billing Team
 * @version 1.0.0
 */
@SpringBootApplication
public class ElectricBillingApplication {

    /**
     * 应用入口。
     * <p>SpringApplication.run() 执行以下步骤:
     * <ol>
     *   <li>创建 Spring 应用上下文 (ApplicationContext)</li>
     *   <li>扫描并注册所有 Bean</li>
     *   <li>启动内嵌 Tomcat 服务器（默认端口 8080）</li>
     *   <li>初始化 MyBatis-Plus、数据源连接池等</li>
     * </ol>
     *
     * @param args 命令行参数（可覆盖 application.yml 中的配置）
     */
    public static void main(String[] args) {
        SpringApplication.run(ElectricBillingApplication.class, args);
    }
}
