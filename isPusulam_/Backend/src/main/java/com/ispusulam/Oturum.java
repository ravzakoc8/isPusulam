package com.ispusulam;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;

/**
 * Giriş sistemi (basit): giriş yapınca "kullaniciId.bitisZamani.imza" şeklinde bir token üretip Flutter'a veririz.
 * Flutter her istekte bunu "Authorization: Bearer <token>" başlığında gönderir.
 * İmzayı sadece biz (gizli anahtarla) üretebildiğimiz için kimse token'ı taklit edemez.
 * Token veritabanında saklanmaz, bu yüzden ekstra tablo gerekmez.
 */
@Component
public class Oturum {
    private final JdbcTemplate jdbc;
    private final byte[] gizliAnahtar;

    public Oturum(JdbcTemplate jdbc, @Value("${uygulama.gizli-anahtar}") String gizliAnahtar) {
        this.jdbc = jdbc;
        this.gizliAnahtar = gizliAnahtar.getBytes(StandardCharsets.UTF_8);
    }

    /** Token üretir: 30 gün geçerli. */
    public String tokenUret(int kullaniciId) {
        long bitis = System.currentTimeMillis() / 1000 + 30L * 24 * 3600;
        String icerik = kullaniciId + "." + bitis;
        return icerik + "." + imzala(icerik);
    }

    /** Başlıktaki token'ı doğrular ve kullanıcıyı bulur. Geçersizse 401 (giriş gerekli) fırlatır. */
    public Map<String, Object> kullanici(String baslik) {
        if (baslik == null || !baslik.startsWith("Bearer "))
            throw Yardimci.hata(HttpStatus.UNAUTHORIZED, "Giriş yapmalısın");
        String[] p = baslik.substring(7).split("\\.");
        if (p.length != 3) throw Yardimci.hata(HttpStatus.UNAUTHORIZED, "Geçersiz oturum");

        boolean imzaDogru = MessageDigest.isEqual(
                imzala(p[0] + "." + p[1]).getBytes(StandardCharsets.UTF_8), p[2].getBytes(StandardCharsets.UTF_8));
        boolean suresiVar;
        try { suresiVar = Long.parseLong(p[1]) > System.currentTimeMillis() / 1000; }
        catch (NumberFormatException e) { suresiVar = false; }
        if (!imzaDogru || !suresiVar)
            throw Yardimci.hata(HttpStatus.UNAUTHORIZED, "Oturum süresi doldu, tekrar giriş yap");

        List<Map<String, Object>> liste = jdbc.queryForList(
                "SELECT kullanici_id, kullanici_tipi, ad, soyad FROM kullanicilar WHERE kullanici_id = ?",
                Integer.parseInt(p[0]));
        if (liste.isEmpty()) throw Yardimci.hata(HttpStatus.UNAUTHORIZED, "Kullanıcı bulunamadı");
        return liste.get(0);
    }

    public int id(String baslik) { return Yardimci.sayi(kullanici(baslik).get("kullanici_id")); }

    /** Sadece işverenlerin yapabileceği işlemler: aday ise 403 verir. */
    public int isverenId(String baslik) {
        Map<String, Object> k = kullanici(baslik);
        if (!"isveren".equals(k.get("kullanici_tipi")))
            throw Yardimci.hata(HttpStatus.FORBIDDEN, "Bu işlem sadece işverenler içindir");
        return Yardimci.sayi(k.get("kullanici_id"));
    }

    /** Sadece adayların yapabileceği işlemler. */
    public int adayId(String baslik) {
        Map<String, Object> k = kullanici(baslik);
        if (!"aday".equals(k.get("kullanici_tipi")))
            throw Yardimci.hata(HttpStatus.FORBIDDEN, "Bu işlem sadece adaylar içindir");
        return Yardimci.sayi(k.get("kullanici_id"));
    }

    private String imzala(String metin) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(gizliAnahtar, "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(metin.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
