package com.hango.hango_backend.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;

@Configuration
@EnableConfigurationProperties({JwtProperties.class, GeminiProperties.class, AIAssistantProperties.class})
public class AppConfig {

    /**
     * WebClient dùng riêng để gọi Gemini API.
     * Timeout được set theo NAC-03 trong SRS (15 giây) để tránh treo request quá lâu.
     */
    @Bean
    public WebClient geminiWebClient(GeminiProperties geminiProperties) {
        HttpClient httpClient = HttpClient.create()
                .responseTimeout(Duration.ofSeconds(geminiProperties.getTimeoutSeconds()));

        return WebClient.builder()
                .baseUrl(geminiProperties.getBaseUrl())
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}