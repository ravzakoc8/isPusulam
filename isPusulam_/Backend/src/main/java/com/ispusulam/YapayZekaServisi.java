package com.ispusulam;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Yapay zekâ servisini çağırır. Hangi sağlayıcı kullanılacağı application.properties'ten seçilir
 * (ai.base-url ve ai.model). OpenAI uyumlu her servisle çalışır: Groq, DeepSeek, Gemini...
 *   POST <ai.base-url>/chat/completions
 *   Başlık : Authorization: Bearer <API_ANAHTARI>
 *   Gövde  : { "model": "...", "messages": [ ... ] }
 *   Cevap  : choices[0].message.content
 *
 * Notlar:
 *  - DeepSeek'te "düşünme modu" (thinking) varsayılan açık ve cevaplar 60 sn'yi aşıyordu; DeepSeek kullanılırsa kapatılır.
 *  - Groq'taki gpt-oss modellerinde düşünme kısa tutulur (reasoning_effort = low): hızlı cevap, az token.
 *  - Model bazen JSON'u ```json ... ``` içine sarıyor; temizlenip çözülür.
 *  - Hata kodları (401 anahtar yanlış, 402 bakiye yok, 429 çok istek) Türkçe ve net mesajlara çevrilir.
 *
 * API anahtarı sadece burada (sunucuda) durur, Flutter uygulamasına ASLA koyma.
 * Anahtar önce AI_API_KEY ortam değişkeninden, yoksa application.properties'teki ai.api-key'den okunur.
 */
@Service
public class YapayZekaServisi {
    private final RestClient istemci;
    private final String model;
    private final String anahtar;
    private final boolean deepseekMi; // "thinking" ayarı sadece DeepSeek'te var; diğer servislere gönderilmez
    private final ObjectMapper json = new ObjectMapper();

    public YapayZekaServisi(@Value("${AI_API_KEY:${ai.api-key:}}") String anahtar,
                            @Value("${ai.base-url:https://api.groq.com/openai/v1}") String adres,
                            @Value("${ai.model:openai/gpt-oss-120b}") String model) {
        this.anahtar = anahtar == null ? "" : anahtar.trim();
        this.model = model;
        this.deepseekMi = adres.contains("deepseek");
        SimpleClientHttpRequestFactory ayar = new SimpleClientHttpRequestFactory();
        ayar.setConnectTimeout(15_000);
        ayar.setReadTimeout(90_000);   // uzun sınav soruları üretirken 90 sn'ye kadar bekle
        this.istemci = RestClient.builder()
                .baseUrl(adres)
                .requestFactory(ayar)
                .defaultHeader("Authorization", "Bearer " + this.anahtar)
                .build();
    }

    public boolean anahtarVar() {
        return !anahtar.isBlank() && !anahtar.startsWith("BURAYA");
    }

    public String modelAdi() { return model; }

    /** Varsayılan uzunlukla sorar. */
    public JsonNode sor(String sistemMesaji, String kullaniciMesaji) {
        return sor(sistemMesaji, kullaniciMesaji, 2000);
    }

    /**
     * Yapay zekâya soru sorar ve cevabı JSON olarak döndürür.
     * Prompt içinde "json" kelimesi geçmeli; sistem mesajında açıkça istiyoruz.
     * @param maksimumToken cevabın en fazla uzunluğu (10 soruluk sınav gibi uzun cevaplarda artır)
     */
    public JsonNode sor(String sistemMesaji, String kullaniciMesaji, int maksimumToken) {
        if (!anahtarVar())
            throw Yardimci.hata(HttpStatus.SERVICE_UNAVAILABLE,
                    "Yapay zekâ API anahtarı yok. application.properties dosyasındaki ai.api-key satırına anahtarını yaz.");

        Map<String, Object> govde = new HashMap<>();
        govde.put("model", model);
        govde.put("messages", List.of(
                Map.of("role", "system", "content", sistemMesaji),
                Map.of("role", "user", "content", kullaniciMesaji)));
        govde.put("response_format", Map.of("type", "json_object"));   // cevap düzgün JSON gelsin
        if (deepseekMi) govde.put("thinking", Map.of("type", "disabled")); // ÖNEMLİ: düşünme modu kapalı = hızlı cevap
        if (model.contains("gpt-oss")) govde.put("reasoning_effort", "low"); // Groq gpt-oss: kısa düşünsün, hızlı ve az token
        govde.put("max_tokens", maksimumToken);
        govde.put("temperature", 0.7);
        govde.put("stream", false);

        String ham;
        try {
            ham = istemci.post().uri("/chat/completions")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(govde)
                    .retrieve()
                    .body(String.class);
        } catch (HttpStatusCodeException e) {
            int kod = e.getStatusCode().value();
            String neden = switch (kod) {
                case 400 -> "Yapay zekâ servisi isteği reddetti (400). ai.model = " + model + " doğru mu? Ayrıntı: " + kisalt(e.getResponseBodyAsString());
                case 401 -> "Yapay zekâ API anahtarı geçersiz (401). Yeni anahtar alıp ai.api-key satırına yaz.";
                case 402 -> "Yapay zekâ hesabında bakiye yok (402).";
                case 422 -> "Yapay zekâ servisi isteği anlayamadı (422): " + kisalt(e.getResponseBodyAsString());
                case 429 -> "Çok fazla istek gönderildi (429). Ücretsiz kotada dakikalık sınır var; bir dakika bekleyip tekrar dene.";
                case 500, 502, 503 -> "Yapay zekâ servisi şu an yoğun/arızalı (" + kod + "). Biraz sonra tekrar dene.";
                default -> "Yapay zekâ hatası (" + kod + "): " + kisalt(e.getResponseBodyAsString());
            };
            System.err.println("[YapayZeka] " + kod + " " + e.getResponseBodyAsString());
            throw Yardimci.hata(HttpStatus.BAD_GATEWAY, neden);
        } catch (ResourceAccessException e) {
            System.err.println("[YapayZeka] bağlantı hatası: " + e.getMessage());
            throw Yardimci.hata(HttpStatus.GATEWAY_TIMEOUT,
                    "Yapay zekâ servisine ulaşılamadı veya cevap çok uzun sürdü. İnternet bağlantını kontrol edip tekrar dene.");
        } catch (Exception e) {
            System.err.println("[YapayZeka] beklenmeyen hata: " + e);
            throw Yardimci.hata(HttpStatus.BAD_GATEWAY, "Yapay zekâ servisine ulaşılamadı: " + e.getMessage());
        }

        try {
            JsonNode mesaj = json.readTree(ham).path("choices").path(0).path("message");
            String icerik = mesaj.path("content").asText("");
            // Bazı servislerde cevap düşünme alanında kalabilir
            if (icerik.isBlank()) icerik = mesaj.path("reasoning_content").asText("");
            if (icerik.isBlank()) icerik = mesaj.path("reasoning").asText("");
            return jsonCikar(icerik);
        } catch (Exception e) {
            System.err.println("[YapayZeka] JSON çözülemedi. Ham cevap: " + kisalt(ham));
            throw Yardimci.hata(HttpStatus.BAD_GATEWAY, "Yapay zekâ beklenen formatta cevap vermedi, tekrar dene.");
        }
    }

    /** ```json ... ``` sarmalını ve baştaki/sondaki fazlalıkları temizleyip JSON'u çözer. */
    private JsonNode jsonCikar(String metin) throws Exception {
        String s = metin.trim();
        if (s.startsWith("```")) {
            int ilkSatir = s.indexOf('\n');
            s = ilkSatir >= 0 ? s.substring(ilkSatir + 1) : s.substring(3);
            if (s.endsWith("```")) s = s.substring(0, s.length() - 3);
        }
        int bas = s.indexOf('{'), son = s.lastIndexOf('}');
        if (bas >= 0 && son > bas) s = s.substring(bas, son + 1);
        return json.readTree(s);
    }

    private static String kisalt(String s) {
        if (s == null) return "";
        return s.length() > 300 ? s.substring(0, 300) + "..." : s;
    }

    /** {"maddeler": ["...", "..."]} biçimindeki cevabı listeye çevirir. */
    public List<String> maddeler(String sistemMesaji, String kullaniciMesaji) {
        JsonNode cevap = sor(sistemMesaji, kullaniciMesaji);
        List<String> liste = new java.util.ArrayList<>();
        cevap.path("maddeler").forEach(n -> liste.add(n.asText()));
        if (liste.isEmpty()) throw Yardimci.hata(HttpStatus.BAD_GATEWAY, "Yapay zekâ beklenen formatta cevap vermedi");
        return liste;
    }
}
