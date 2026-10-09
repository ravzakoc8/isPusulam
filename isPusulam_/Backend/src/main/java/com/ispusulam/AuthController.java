package com.ispusulam;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import static com.ispusulam.Yardimci.*;

/** Kayıt ve giriş. */
@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;
    private final BCryptPasswordEncoder sifreleyici = new BCryptPasswordEncoder();

    public AuthController(JdbcTemplate jdbc, Oturum oturum) {
        this.jdbc = jdbc;
        this.oturum = oturum;
    }

    /**
     * POST /api/auth/kayit -> kullanicilar tablosuna, sonra adaylar veya isverenler
     * tablosuna yazar.
     */
    @PostMapping("/kayit")
    @Transactional
    public Map<String, Object> kayit(@RequestBody Map<String, Object> g) {
        String eposta = zorunlu(g, "eposta", "E-posta zorunlu").toLowerCase(Locale.ROOT); // Locale.ROOT: Türkçe ayarda
                                                                                          // "I" -> "ı" olmasın
        String sifre = zorunlu(g, "sifre", "Şifre zorunlu");
        String ad = zorunlu(g, "ad", "Ad zorunlu");
        String soyad = zorunlu(g, "soyad", "Soyad zorunlu");
        String tip = zorunlu(g, "tip", "Hesap türü zorunlu");

        if (sifre.length() < 6)
            throw hata(HttpStatus.BAD_REQUEST, "Şifre en az 6 karakter olmalı");
        if (!tip.equals("aday") && !tip.equals("isveren"))
            throw hata(HttpStatus.BAD_REQUEST, "Hesap türü geçersiz");
        Integer var = jdbc.queryForObject("SELECT COUNT(*) FROM kullanicilar WHERE eposta = ?", Integer.class, eposta);
        if (var != null && var > 0)
            throw hata(HttpStatus.CONFLICT, "Bu e-posta ile zaten bir hesap var");

        // Şifreyi düz halde saklamıyoruz, BCrypt ile hash'leyip saklıyoruz.
        Integer id = jdbc.queryForObject(
                "INSERT INTO kullanicilar (eposta, sifre_hash, ad, soyad, telefon, kullanici_tipi) " +
                        "VALUES (?, ?, ?, ?, ?, ?) RETURNING kullanici_id",
                Integer.class, eposta, sifreleyici.encode(sifre), ad, soyad, metin(g, "telefon"), tip);

        if (tip.equals("aday")) {
            jdbc.update("INSERT INTO adaylar (aday_id) VALUES (?)", id);
        } else {
            String sirket = zorunlu(g, "sirket_adi", "İşveren kaydında şirket adı zorunlu");
            // YARIŞMA SÜRÜMÜ: kayıt olan her işveren otomatik "doğrulanmış" sayılır
            // (dogrulanmis = TRUE).
            // Gerçek doğrulama (vergi no kontrolü, admin onayı) sonraya bırakıldı.
            jdbc.update("INSERT INTO isverenler (isveren_id, sirket_adi, vergi_no, dogrulanmis) VALUES (?, ?, ?, TRUE)",
                    id, sirket, metin(g, "vergi_no"));
        }
        return girisCevabi(id, ad, soyad, tip);
    }

    /** POST /api/auth/giris */
    @PostMapping("/giris")
    public Map<String, Object> giris(@RequestBody Map<String, Object> g) {
        String eposta = zorunlu(g, "eposta", "E-posta zorunlu").toLowerCase(Locale.ROOT); // Locale.ROOT: Türkçe ayarda
                                                                                          // "I" -> "ı" olmasın
        String sifre = zorunlu(g, "sifre", "Şifre zorunlu");
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT kullanici_id, sifre_hash, ad, soyad, kullanici_tipi FROM kullanicilar WHERE eposta = ?",
                eposta);
        // Hangisinin yanlış olduğunu söylemiyoruz (güvenlik): iki durumda da aynı mesaj
        if (l.isEmpty() || !sifreleyici.matches(sifre, (String) l.get(0).get("sifre_hash")))
            throw hata(HttpStatus.UNAUTHORIZED, "E-posta veya şifre hatalı");
        Map<String, Object> k = l.get(0);
        return girisCevabi(sayi(k.get("kullanici_id")), (String) k.get("ad"), (String) k.get("soyad"),
                (String) k.get("kullanici_tipi"));
    }

    private Map<String, Object> girisCevabi(int id, String ad, String soyad, String tip) {
        Map<String, Object> c = new HashMap<>();
        c.put("token", oturum.tokenUret(id));
        c.put("id", id);
        c.put("ad", ad);
        c.put("soyad", soyad);
        c.put("tip", tip);
        return c;
    }
}
