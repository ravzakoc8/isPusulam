package com.ispusulam;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

import static com.ispusulam.Yardimci.*;

/** Kendi profilim, profil gizliliği ve (işveren için) bir adayın profili. */
@RestController
@RequestMapping("/api/profil")
public class ProfilController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;

    public ProfilController(JdbcTemplate jdbc, Oturum oturum) {
        this.jdbc = jdbc;
        this.oturum = oturum;
    }

    /**
     * GET /api/profil -> giriş yapan kişinin kendi profili (aday ise beceriler ve
     * tamamlanma yüzdesi de gelir).
     */
    @GetMapping
    public Map<String, Object> ben(@RequestHeader(value = "Authorization", required = false) String yetki) {
        Map<String, Object> k = oturum.kullanici(yetki);
        int id = sayi(k.get("kullanici_id"));

        if ("isveren".equals(k.get("kullanici_tipi"))) {
            return jdbc.queryForList(
                    "SELECT k.kullanici_id, k.ad, k.soyad, k.eposta, k.kullanici_tipi, v.sirket_adi, v.dogrulanmis " +
                            "FROM kullanicilar k JOIN isverenler v ON v.isveren_id = k.kullanici_id WHERE k.kullanici_id = ?",
                    id).get(0);
        }

        Map<String, Object> p = jdbc.queryForList(
                "SELECT k.kullanici_id, k.ad, k.soyad, k.eposta, k.telefon, k.kullanici_tipi, k.profil_gizliligi, " +
                        "a.unvan, a.biyografi, a.mevcut_durum, " +
                        "(SELECT dosya_url FROM cv WHERE aday_id = k.kullanici_id ORDER BY cv_id DESC LIMIT 1) AS cv_url "
                        +
                        "FROM kullanicilar k LEFT JOIN adaylar a ON a.aday_id = k.kullanici_id WHERE k.kullanici_id = ?",
                id).get(0);

        List<Map<String, Object>> beceriler = becerileri(id);
        long dogrulanan = beceriler.stream().filter(b -> Boolean.TRUE.equals(b.get("dogrulanmis"))).count();
        p.put("becerileri", beceriler);
        p.put("dogrulanan_sayisi", dogrulanan);

        // Profil tamamlanma yüzdesi: 5 maddenin her biri %20
        int puan = 0;
        if (p.get("unvan") != null)
            puan += 20;
        if (p.get("biyografi") != null)
            puan += 20;
        if (p.get("cv_url") != null)
            puan += 20;
        if (beceriler.size() >= 3)
            puan += 20;
        if (dogrulanan >= 1)
            puan += 20;
        p.put("tamamlanma", puan);
        return p;
    }

    /**
     * PUT /api/profil -> unvan, biyografi, telefon ve CV bağlantısını günceller.
     */
    @PutMapping
    public Map<String, Object> guncelle(@RequestHeader(value = "Authorization", required = false) String yetki,
            @RequestBody Map<String, Object> g) {
        int id = oturum.adayId(yetki);
        jdbc.update("UPDATE adaylar SET unvan = ?, biyografi = ? WHERE aday_id = ?", metin(g, "unvan"),
                metin(g, "biyografi"), id);
        jdbc.update("UPDATE kullanicilar SET telefon = ? WHERE kullanici_id = ?", metin(g, "telefon"), id);

        // CV: cv tablosunda kayıt varsa güncelle, yoksa ekle
        String cvUrl = metin(g, "cv_url");
        if (cvUrl != null) {
            List<Integer> cvler = jdbc.queryForList(
                    "SELECT cv_id FROM cv WHERE aday_id = ? ORDER BY cv_id DESC LIMIT 1", Integer.class, id);
            if (cvler.isEmpty())
                jdbc.update("INSERT INTO cv (aday_id, dosya_url) VALUES (?, ?)", id, cvUrl);
            else
                jdbc.update("UPDATE cv SET dosya_url = ? WHERE cv_id = ?", cvUrl, cvler.get(0));
        }
        return ben(yetki);
    }

    /** PUT /api/profil/gizlilik -> herkese_acik | sadece_isverenler | gizli */
    @PutMapping("/gizlilik")
    public Map<String, Object> gizlilik(@RequestHeader(value = "Authorization", required = false) String yetki,
            @RequestBody Map<String, Object> g) {
        int id = oturum.id(yetki);
        String deger = zorunlu(g, "profil_gizliligi", "Gizlilik seçimi zorunlu");
        if (!List.of("herkese_acik", "sadece_isverenler", "gizli").contains(deger))
            throw hata(HttpStatus.BAD_REQUEST, "Geçersiz gizlilik seçimi");
        jdbc.update("UPDATE kullanicilar SET profil_gizliligi = ? WHERE kullanici_id = ?", deger, id);
        return Map.of("profil_gizliligi", deger);
    }

    /**
     * GET /api/profil/{id} -> İşverenin bir adayın profiline bakması (gizlilik
     * kurallarına uyar).
     */
    @GetMapping("/{adayId}")
    public Map<String, Object> adayProfili(@RequestHeader(value = "Authorization", required = false) String yetki,
            @PathVariable int adayId) {
        int isverenId = oturum.isverenId(yetki);
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT k.kullanici_id, k.ad, k.soyad, k.profil_gizliligi, a.unvan, a.biyografi, " +
                        "(SELECT dosya_url FROM cv WHERE aday_id = k.kullanici_id ORDER BY cv_id DESC LIMIT 1) AS cv_url "
                        +
                        "FROM kullanicilar k JOIN adaylar a ON a.aday_id = k.kullanici_id WHERE k.kullanici_id = ?",
                adayId);
        if (l.isEmpty())
            throw hata(HttpStatus.NOT_FOUND, "Aday bulunamadı");
        Map<String, Object> p = l.get(0);

        String giz = (String) p.get("profil_gizliligi");
        // Kendi ilanına başvuran adayı her zaman görebilir; diğer durumlarda gizlilik
        // ayarına bakılır.
        Integer basvurdu = jdbc.queryForObject(
                "SELECT COUNT(*) FROM basvurular b JOIN is_ilanlari i ON i.ilan_id = b.ilan_id WHERE b.aday_id = ? AND i.isveren_id = ?",
                Integer.class, adayId, isverenId);
        boolean gorebilir = (basvurdu != null && basvurdu > 0)
                || "herkese_acik".equals(giz)
                || ("sadece_isverenler".equals(giz) && dogrulanmisIsverenMi(isverenId));
        if (!gorebilir)
            throw hata(HttpStatus.FORBIDDEN, "Bu aday profilini gizli tutuyor");

        p.remove("profil_gizliligi");
        p.put("becerileri", becerileri(adayId));
        return p;
    }

    private boolean dogrulanmisIsverenMi(int isverenId) {
        Boolean b = jdbc.queryForObject("SELECT dogrulanmis FROM isverenler WHERE isveren_id = ?", Boolean.class,
                isverenId);
        return Boolean.TRUE.equals(b);
    }

    private List<Map<String, Object>> becerileri(int adayId) {
        return jdbc.queryForList(
                "SELECT b.beceri_id, b.ad, ab.kendi_seviyesi, ab.dogrulanmis FROM aday_becerileri ab " +
                        "JOIN beceriler b ON b.beceri_id = ab.beceri_id WHERE ab.aday_id = ? ORDER BY ab.dogrulanmis DESC, b.ad",
                adayId);
    }
}
