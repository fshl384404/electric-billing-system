package com.electric.billing.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

/**
 * Ollama / ChromaDB 连接配置
 */
@Configuration
@ConfigurationProperties(prefix = "app.rag")
public class OllamaConfig {

    private String ollamaUrl = "http://localhost:11434";
    private String chromaUrl = "http://localhost:8000";
    private String model = "qwen2.5:3b";
    private String embedModel = "nomic-embed-text";

    // ---- getters / setters (Spring 属性绑定需要) ----

    public String getOllamaUrl() { return ollamaUrl; }
    public void setOllamaUrl(String ollamaUrl) { this.ollamaUrl = ollamaUrl; }

    public String getChromaUrl() { return chromaUrl; }
    public void setChromaUrl(String chromaUrl) { this.chromaUrl = chromaUrl; }

    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }

    public String getEmbedModel() { return embedModel; }
    public void setEmbedModel(String embedModel) { this.embedModel = embedModel; }

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
