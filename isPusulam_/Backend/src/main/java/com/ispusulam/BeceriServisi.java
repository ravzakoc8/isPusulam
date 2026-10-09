package com.ispusulam;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

/**
 * Beceri listesi artık sadece bizim tanımladıklarımızla sınırlı değil:
 * aday veya işveren listede olmayan bir beceri yazarsa yapay zekâ bunun gerçek bir beceri olup olmadığını
 * kontrol eder, adını düzgün yazıma çevirir (örn. "reactjs" -> "React") ve beceriler tablosuna ekler.
 */
@Component
public class BeceriServisi {
    private final JdbcTemplate jdbc;
    private final DeepSeekServisi yapayZeka;

    public BeceriServisi(JdbcTemplate jdbc, DeepSeekServisi yapayZeka) {
        this.jdbc = jdbc;
        this.yapayZeka = yapayZeka;
    }

    /** Aynı ada sahip (büyük/küçük harf fark etmeksizin) beceri varsa onu döndürür. */
    public Map<String, Object> bul(String ad) {
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT beceri_id, ad, kategori FROM beceriler WHERE lower(ad) = lower(?) LIMIT 1", ad.trim());
        return l.isEmpty() ? null : l.get(0);
    }

    /**
     * Kullanıcının yazdığı beceriyi bulur; yoksa yapay zekâ ile kontrol edip ekler.
     * Yapay zekâ "bu bir beceri değil" derse 400 hatası verir.
     * Yapay zekâya ulaşılamazsa beceriyi yine de "Diğer" kategorisiyle ekler (kullanıcı takılmasın).
     */
    public Map<String, Object> kontrolluBulVeyaOlustur(String yazilan) {
        String ad = temizle(yazilan);
        Map<String, Object> mevcut = bul(ad);
        if (mevcut != null) return mevcut;

        String kategori = "Diğer";
        if (yapayZeka.anahtarVar()) {
            try {
                JsonNode ai = yapayZeka.sor(
                        "Sen bir kariyer platformunda beceri kataloğunu yöneten uzmansın. Kullanıcı bir beceri adı yazdı. " +
                        "Bunun iş hayatında kullanılan gerçek bir beceri, araç, yazılım, programlama dili, framework, yabancı dil, " +
                        "sertifika alanı veya mesleki yetkinlik olup olmadığını değerlendir. Küfür, anlamsız harf dizisi, kişi adı " +
                        "veya alakasız şeyler geçersizdir. Yanıtı SADECE şu json biçiminde ver: " +
                        "{\"gecerli\": true/false, \"ad\": \"en yaygın doğru yazımı, en fazla 40 karakter\", " +
                        "\"kategori\": \"Yazılım | Veri | Yapay Zekâ | DevOps | Tasarım | Mobil | Güvenlik | Ofis | Dil | İş & Yönetim | Pazarlama | Diğer\", " +
                        "\"neden\": \"geçersizse kısa Türkçe açıklama\"}",
                        "Beceri: " + ad, 300);
                if (!ai.path("gecerli").asBoolean(true)) {
                    String neden = ai.path("neden").asText("");
                    throw Yardimci.hata(HttpStatus.BAD_REQUEST,
                            "\"" + ad + "\" geçerli bir beceri gibi görünmüyor." + (neden.isBlank() ? "" : " " + neden));
                }
                String duzgun = temizle(ai.path("ad").asText(ad));
                if (!duzgun.isBlank()) ad = duzgun;
                kategori = kisalt(ai.path("kategori").asText("Diğer"), 50);
                Map<String, Object> tekrar = bul(ad);
                if (tekrar != null) return tekrar;
            } catch (ResponseStatusException e) {
                // "geçersiz beceri" hatasını kullanıcıya ilet; servis hatalarında beceriyi yine de ekle
                if (e.getStatusCode().value() == 400) throw e;
                System.err.println("[Beceri] Yapay zekâ kontrolü yapılamadı, beceri doğrudan ekleniyor: " + e.getReason());
            }
        }
        return olustur(ad, kategori);
    }

    /** Yapay zekânın ilan için önerdiği becerileri (zaten AI'dan geldiği için tekrar sormadan) bulur veya ekler. */
    public Map<String, Object> bulVeyaOlustur(String yazilan, String kategori) {
        if (yazilan == null || yazilan.isBlank() || yazilan.trim().length() > 50) return null;
        String ad = temizle(yazilan);
        Map<String, Object> mevcut = bul(ad);
        if (mevcut != null) return mevcut;
        return olustur(ad, kategori == null || kategori.isBlank() ? "Diğer" : kisalt(kategori, 50));
    }

    private Map<String, Object> olustur(String ad, String kategori) {
        jdbc.update("INSERT INTO beceriler (ad, kategori, ai_ile_eklendi) VALUES (?, ?, TRUE) ON CONFLICT (ad) DO NOTHING",
                ad, kategori);
        Map<String, Object> yeni = bul(ad);
        if (yeni == null) throw Yardimci.hata(HttpStatus.INTERNAL_SERVER_ERROR, "Beceri eklenemedi");
        return yeni;
    }

    /** Boşlukları toparlar, 50 karakter sınırına uyar (beceriler.ad VARCHAR(50)). */
    private static String temizle(String s) {
        if (s == null) return "";
        String t = s.trim().replaceAll("\\s+", " ");
        if (t.isEmpty()) throw Yardimci.hata(HttpStatus.BAD_REQUEST, "Beceri adı boş olamaz");
        if (t.length() > 50) throw Yardimci.hata(HttpStatus.BAD_REQUEST, "Beceri adı en fazla 50 karakter olabilir");
        return t;
    }

    private static String kisalt(String s, int n) {
        return s.length() > n ? s.substring(0, n) : s;
    }
}