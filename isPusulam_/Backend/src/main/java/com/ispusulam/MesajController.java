package com.ispusulam;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.*;

import static com.ispusulam.Yardimci.*;

/**
 * Mesajlaşma: aday <-> işveren.
 * Kim kime yazabilir?
 *  - Aday, başvurduğu ilanın işverenine yazabilir.
 *  - İşveren, ilanına başvuran adaya yazabilir; ayrıca profili görünür olan (gizli olmayan) adaylara ilk mesajı atabilir
 *    ("sadece işverenler" profilleri için işveren doğrulanmış olmalı).
 *  - Aralarında daha önce yazışma olan iki kişi yazışmaya devam edebilir.
 *  - Aday adaya, işveren işverene yazamaz.
 */
@RestController
@RequestMapping("/api/mesajlar")
public class MesajController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;

    public MesajController(JdbcTemplate jdbc, Oturum oturum) {
        this.jdbc = jdbc;
        this.oturum = oturum;
    }

    /** GET /api/mesajlar -> konuşmalarım (her kişiyle son mesaj + okunmamış sayısı), en yeni üstte */
    @GetMapping
    public List<Map<String, Object>> konusmalar(@RequestHeader(value = "Authorization", required = false) String yetki) {
        int ben = oturum.id(yetki);
        return jdbc.queryForList(
                "WITH m AS (" +
                "  SELECT CASE WHEN gonderen_id = ? THEN alici_id ELSE gonderen_id END AS karsi_id, icerik, tarih, gonderen_id, mesaj_id " +
                "  FROM mesajlar WHERE gonderen_id = ? OR alici_id = ?" +
                "), son AS (" +
                "  SELECT DISTINCT ON (karsi_id) karsi_id, icerik, tarih, gonderen_id FROM m ORDER BY karsi_id, tarih DESC, mesaj_id DESC" +
                ") " +
                "SELECT s.karsi_id, s.icerik AS son_mesaj, s.tarih AS son_tarih, (s.gonderen_id = ?) AS benden, " +
                "COALESCE(v.sirket_adi, k.ad || ' ' || k.soyad) AS gorunen_ad, k.kullanici_tipi, " +
                "CASE WHEN v.isveren_id IS NULL THEN a.unvan ELSE k.ad || ' ' || k.soyad END AS alt_yazi, " +
                "(SELECT COUNT(*) FROM mesajlar x WHERE x.gonderen_id = s.karsi_id AND x.alici_id = ? AND x.okundu = FALSE) AS okunmamis " +
                "FROM son s JOIN kullanicilar k ON k.kullanici_id = s.karsi_id " +
                "LEFT JOIN isverenler v ON v.isveren_id = s.karsi_id LEFT JOIN adaylar a ON a.aday_id = s.karsi_id " +
                "ORDER BY s.tarih DESC",
                ben, ben, ben, ben, ben);
    }

    /** GET /api/mesajlar/sayi -> okunmamış mesaj sayısı (menüdeki rozet) */
    @GetMapping("/sayi")
    public Map<String, Object> okunmamisSayisi(@RequestHeader(value = "Authorization", required = false) String yetki) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM mesajlar WHERE alici_id = ? AND okundu = FALSE",
                Integer.class, oturum.id(yetki));
        return Map.of("sayi", n == null ? 0 : n);
    }

    /**
     * GET /api/mesajlar/kisiler -> yeni konuşma başlatılabilecek kişiler.
     * Aday: başvurduğu ilanların şirketleri. İşveren: ilanlarına başvuran adaylar.
     */
    @GetMapping("/kisiler")
    public List<Map<String, Object>> kisiler(@RequestHeader(value = "Authorization", required = false) String yetki) {
        Map<String, Object> k = oturum.kullanici(yetki);
        int ben = sayi(k.get("kullanici_id"));
        if ("aday".equals(k.get("kullanici_tipi"))) {
            return jdbc.queryForList(
                    "SELECT DISTINCT ON (v.isveren_id) v.isveren_id AS karsi_id, v.sirket_adi AS gorunen_ad, i.baslik AS alt_yazi " +
                    "FROM basvurular b JOIN is_ilanlari i ON i.ilan_id = b.ilan_id JOIN isverenler v ON v.isveren_id = i.isveren_id " +
                    "WHERE b.aday_id = ? ORDER BY v.isveren_id, b.basvuru_tarihi DESC", ben);
        }
        return jdbc.queryForList(
                "SELECT DISTINCT ON (b.aday_id) b.aday_id AS karsi_id, ku.ad || ' ' || ku.soyad AS gorunen_ad, i.baslik AS alt_yazi " +
                "FROM basvurular b JOIN is_ilanlari i ON i.ilan_id = b.ilan_id JOIN kullanicilar ku ON ku.kullanici_id = b.aday_id " +
                "WHERE i.isveren_id = ? ORDER BY b.aday_id, b.basvuru_tarihi DESC", ben);
    }

    /** GET /api/mesajlar/{karsiId} -> o kişiyle yazışma (gelen mesajlar okundu işaretlenir) */
    @GetMapping("/{karsiId}")
    public Map<String, Object> yazisma(@RequestHeader(value = "Authorization", required = false) String yetki,
                                       @PathVariable int karsiId) {
        int ben = oturum.id(yetki);
        Map<String, Object> karsi = kisiBilgisi(karsiId);
        List<Map<String, Object>> mesajlar = jdbc.queryForList(
                "SELECT mesaj_id, gonderen_id, icerik, tarih, okundu, (gonderen_id = ?) AS benden FROM mesajlar " +
                "WHERE (gonderen_id = ? AND alici_id = ?) OR (gonderen_id = ? AND alici_id = ?) " +
                "ORDER BY tarih, mesaj_id LIMIT 500",
                ben, ben, karsiId, karsiId, ben);
        jdbc.update("UPDATE mesajlar SET okundu = TRUE WHERE gonderen_id = ? AND alici_id = ? AND okundu = FALSE", karsiId, ben);

        Map<String, Object> c = new HashMap<>();
        c.put("karsi", karsi);
        c.put("mesajlar", mesajlar);
        String engel = engelSebebi(ben, karsiId);
        c.put("yazabilir", engel == null);
        c.put("engel", engel);
        return c;
    }

    /** POST /api/mesajlar/{karsiId}  {icerik, basvuru_id?} -> mesaj gönderir */
    @PostMapping("/{karsiId}")
    public Map<String, Object> gonder(@RequestHeader(value = "Authorization", required = false) String yetki,
                                      @PathVariable int karsiId, @RequestBody Map<String, Object> g) {
        int ben = oturum.id(yetki);
        String icerik = zorunlu(g, "icerik", "Boş mesaj gönderilemez");
        if (icerik.length() > 2000) throw hata(HttpStatus.BAD_REQUEST, "Mesaj en fazla 2000 karakter olabilir");
        String engel = engelSebebi(ben, karsiId);
        if (engel != null) throw hata(HttpStatus.FORBIDDEN, engel);

        Integer basvuruId = null;
        Object b = g.get("basvuru_id");
        if (b instanceof Number n) basvuruId = n.intValue();

        return jdbc.queryForList(
                "INSERT INTO mesajlar (gonderen_id, alici_id, basvuru_id, icerik) VALUES (?, ?, ?, ?) " +
                "RETURNING mesaj_id, gonderen_id, icerik, tarih, okundu, TRUE AS benden",
                ben, karsiId, basvuruId, icerik).get(0);
    }

    // ------------------------------------------------------------------

    private Map<String, Object> kisiBilgisi(int id) {
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT k.kullanici_id AS id, k.kullanici_tipi, COALESCE(v.sirket_adi, k.ad || ' ' || k.soyad) AS gorunen_ad, " +
                "CASE WHEN v.isveren_id IS NULL THEN a.unvan ELSE k.ad || ' ' || k.soyad END AS alt_yazi " +
                "FROM kullanicilar k LEFT JOIN isverenler v ON v.isveren_id = k.kullanici_id LEFT JOIN adaylar a ON a.aday_id = k.kullanici_id " +
                "WHERE k.kullanici_id = ?", id);
        if (l.isEmpty()) throw hata(HttpStatus.NOT_FOUND, "Kişi bulunamadı");
        return l.get(0);
    }

    /** Yazabiliyorsa null, yazamıyorsa sebebini döndürür. */
    private String engelSebebi(int ben, int karsi) {
        if (ben == karsi) return "Kendine mesaj gönderemezsin";
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT kullanici_id, kullanici_tipi, profil_gizliligi FROM kullanicilar WHERE kullanici_id IN (?, ?)", ben, karsi);
        Map<String, Object> benK = null, karsiK = null;
        for (Map<String, Object> r : l) {
            if (sayi(r.get("kullanici_id")) == ben) benK = r; else karsiK = r;
        }
        if (benK == null || karsiK == null) return "Kişi bulunamadı";
        if (Objects.equals(benK.get("kullanici_tipi"), karsiK.get("kullanici_tipi")))
            return "Mesajlaşma sadece aday ile işveren arasında yapılabilir";

        boolean benAday = "aday".equals(benK.get("kullanici_tipi"));
        int adayId = benAday ? ben : karsi;
        int isverenId = benAday ? karsi : ben;

        Integer basvuru = jdbc.queryForObject(
                "SELECT COUNT(*) FROM basvurular b JOIN is_ilanlari i ON i.ilan_id = b.ilan_id WHERE b.aday_id = ? AND i.isveren_id = ?",
                Integer.class, adayId, isverenId);
        if (basvuru != null && basvuru > 0) return null;

        Integer onceki = jdbc.queryForObject(
                "SELECT COUNT(*) FROM mesajlar WHERE (gonderen_id = ? AND alici_id = ?) OR (gonderen_id = ? AND alici_id = ?)",
                Integer.class, ben, karsi, karsi, ben);
        if (onceki != null && onceki > 0) return null;

        if (benAday) return "Bu şirkete yazabilmek için önce ilanlarından birine başvurmalısın";

        // İşveren, başvurmamış bir adaya ilk mesajı atıyor: gizlilik ayarına uy
        String giz = (String) karsiK.get("profil_gizliligi");
        if ("gizli".equals(giz)) return "Bu aday profilini gizli tutuyor; ilk mesajı gönderemezsin";
        if ("sadece_isverenler".equals(giz)) {
            Boolean dogrulanmis = jdbc.queryForObject("SELECT dogrulanmis FROM isverenler WHERE isveren_id = ?", Boolean.class, isverenId);
            if (!Boolean.TRUE.equals(dogrulanmis)) return "Bu adaya sadece doğrulanmış işverenler yazabilir";
        }
        return null;
    }
}