package com.ispusulam;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/** Bildirimler (ret, mülakat, kabul, yeni başvuru, beceri doğrulama). */
@RestController
@RequestMapping("/api/bildirimler")
public class BildirimController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;

    public BildirimController(JdbcTemplate jdbc, Oturum oturum) { this.jdbc = jdbc; this.oturum = oturum; }

    /** GET /api/bildirimler -> benim bildirimlerim (en yeni üstte) */
    @GetMapping
    public List<Map<String, Object>> liste(@RequestHeader(value = "Authorization", required = false) String yetki) {
        int id = oturum.id(yetki);
        return jdbc.queryForList(
                "SELECT n.bildirim_id, n.tur, n.baslik, n.mesaj, n.okundu, n.tarih, n.basvuru_id, " +
                "v.sirket_adi, ka.ad || ' ' || ka.soyad AS aday_ad " +
                "FROM bildirimler n " +
                "LEFT JOIN basvurular b ON b.basvuru_id = n.basvuru_id " +
                "LEFT JOIN is_ilanlari i ON i.ilan_id = b.ilan_id " +
                "LEFT JOIN isverenler v ON v.isveren_id = i.isveren_id " +
                "LEFT JOIN kullanicilar ka ON ka.kullanici_id = b.aday_id " +
                "WHERE n.kullanici_id = ? ORDER BY n.tarih DESC LIMIT 100", id);
    }

    /** GET /api/bildirimler/sayi -> zil üzerindeki kırmızı rozet için okunmamış sayısı */
    @GetMapping("/sayi")
    public Map<String, Object> sayi(@RequestHeader(value = "Authorization", required = false) String yetki) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM bildirimler WHERE kullanici_id = ? AND okundu = FALSE",
                Integer.class, oturum.id(yetki));
        return Map.of("sayi", n == null ? 0 : n);
    }

    @PatchMapping("/{id}/okundu")
    public void okundu(@RequestHeader(value = "Authorization", required = false) String yetki, @PathVariable int id) {
        // kullanici_id şartı: başkasının bildirimini değiştirmeyi engeller
        jdbc.update("UPDATE bildirimler SET okundu = TRUE WHERE bildirim_id = ? AND kullanici_id = ?", id, oturum.id(yetki));
    }

    @PatchMapping("/hepsi-okundu")
    public void hepsiOkundu(@RequestHeader(value = "Authorization", required = false) String yetki) {
        jdbc.update("UPDATE bildirimler SET okundu = TRUE WHERE kullanici_id = ?", oturum.id(yetki));
    }
}
