package com.ispusulam;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Flutter web (Chrome) başka bir porttan çalıştığı için tarayıcı isteği engeller.
 * Bu ayar "her yerden istek gelebilir" der. (Geliştirme için yeterli.)
 */
@Configuration
public class CorsAyari implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }
}
