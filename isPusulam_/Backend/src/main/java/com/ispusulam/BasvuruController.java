package com.ispusulam;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

import static com.ispusulam.Yardimci.*;

/**
 * Başvuru süreci:
 * basvuruldu --(mülakat tarihi belirle)--> mulakat_planlandi --(kabul)--> kabul
 * Mülakat tarihi (mulakatlar.durum):
 *   planlandi   : işveren tarih önerdi, adayın cevabı bekleniyor
 *   aday_itiraz : aday tarihe itiraz etti (isterse yeni tarih önerdi), işverenin cevabı bekleniyor
 *   onaylandi   : iki taraf da onayladı
 * İşveren itirazı görünce adayın önerdiği tarihi kabul edebilir ya da yeni bir tarih önerebilir.
 * basvuruldu / mulakat_planlandi --(RET: gerekçe zorunlu)--> ret
 * Reddin hangi aşamada verildiği mulakatlar tablosundan anlaşılır: mülakat
 * kaydı varsa "mülakat", yoksa "başvuru" aşaması.
 */
@RestController
@RequestMapping("/api/basvurular")
public class BasvuruController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;
    private final Bildirimci bildirimci;
    private final Eslestirici eslestirici;
    private final YapayZekaServisi yapayZeka;

    public BasvuruController(JdbcTemplate jdbc, Oturum oturum, Bildirimci bildirimci, Eslestirici eslestirici,
            YapayZekaServisi yapayZeka) {
        this.jdbc = jdbc;
        this.oturum = oturum;
        this.bildirimci = bildirimci;
        this.eslestirici = eslestirici;
        this.yapayZeka = yapayZeka;
    }

    // Hem aday hem işveren listesinde kullanılan ortak SQL parçası
    private static final String ORTAK_SECIM = "SELECT b.basvuru_id, b.durum, b.ret_gerekcesi, b.basvuru_tarihi, i.ilan_id, i.baslik AS ilan_baslik, "
            +
            "v.sirket_adi, v.isveren_id, m.tarih AS mulakat_tarihi, m.gorusme_linki, m.durum AS mulakat_durumu, " +
            "m.onerilen_tarih AS mulakat_onerilen_tarih, m.itiraz_notu AS mulakat_itiraz_notu, " +
            "CASE WHEN m.mulakat_id IS NULL THEN 'basvuru' ELSE 'mulakat' END AS asama ";
    private static final String ORTAK_BAGLA = "FROM basvurular b JOIN is_ilanlari i ON i.ilan_id = b.ilan_id JOIN isverenler v ON v.isveren_id = i.isveren_id "
            +
            "LEFT JOIN mulakatlar m ON m.basvuru_id = b.basvuru_id ";

    /**
     * GET /api/basvurular/benim -> adayın başvuruları (ret gerekçesi ve mülakat
     * bilgisiyle)
     */
    @GetMapping("/benim")
    public List<Map<String, Object>> benim(@RequestHeader(value = "Authorization", required = false) String yetki) {
        int adayId = oturum.adayId(yetki);
        return jdbc.queryForList(ORTAK_SECIM + ORTAK_BAGLA + "WHERE b.aday_id = ? ORDER BY b.basvuru_tarihi DESC",
                adayId);
    }

    /**
     * GET /api/basvurular/isveren -> işverenin ilanlarına gelen başvurular (eşleşme
     * yüzdesiyle)
     */
    @GetMapping("/isveren")
    public List<Map<String, Object>> isveren(@RequestHeader(value = "Authorization", required = false) String yetki) {
        int isverenId = oturum.isverenId(yetki);
        List<Map<String, Object>> liste = jdbc.queryForList(
                ORTAK_SECIM + ", b.aday_id, k.ad || ' ' || k.soyad AS aday_ad, a.unvan " +
                        ORTAK_BAGLA
                        + "JOIN kullanicilar k ON k.kullanici_id = b.aday_id LEFT JOIN adaylar a ON a.aday_id = b.aday_id "
                        +
                        "WHERE i.isveren_id = ? ORDER BY b.basvuru_tarihi DESC",
                isverenId);
        for (Map<String, Object> b : liste) {
            b.put("eslesme",
                    eslestirici.yuzde(sayi(b.get("ilan_id")), eslestirici.adayBecerileri(sayi(b.get("aday_id")))));
        }
        return liste;
    }

    /**
     * PATCH /api/basvurular/{id}/mulakat {tarih: "2026-10-07T14:30:00", link} ->
     * mülakat tarihi belirler, adaya bildirim gider
     */
    @PatchMapping("/{id}/mulakat")
    @Transactional
    public void mulakatPlanla(@RequestHeader(value = "Authorization", required = false) String yetki,
            @PathVariable int id, @RequestBody Map<String, Object> g) {
        int isverenId = oturum.isverenId(yetki);
        Map<String, Object> b = isverenBasvurusu(isverenId, id);
        if (!"basvuruldu".equals(b.get("durum")) && !"mulakat_planlandi".equals(b.get("durum")))
            throw hata(HttpStatus.CONFLICT, "Bu başvuru için mülakat planlanamaz");

        LocalDateTime tarih = tarihOku(zorunlu(g, "tarih", "Mülakat tarihi zorunlu"));
        if (tarih.isBefore(LocalDateTime.now()))
            throw hata(HttpStatus.BAD_REQUEST, "Mülakat tarihi geçmişte olamaz");
        String link = metin(g, "link");

        // mulakatlar tablosu bir mülakatçı istiyor: işverenin kayıtlı mülakatçısı yoksa
        // işveren hesabından otomatik oluşturuyoruz
        List<Integer> mulakatcilar = jdbc.queryForList(
                "SELECT mulakatci_id FROM mulakatcilar WHERE isveren_id = ? ORDER BY mulakatci_id LIMIT 1",
                Integer.class, isverenId);
        Integer mulakatciId;
        if (mulakatcilar.isEmpty()) {
            mulakatciId = jdbc.queryForObject(
                    "INSERT INTO mulakatcilar (isveren_id, ad_soyad, eposta) " +
                            "SELECT CAST(? AS INTEGER), v.sirket_adi, k.eposta FROM isverenler v JOIN kullanicilar k ON k.kullanici_id = v.isveren_id WHERE v.isveren_id = ? "
                            +
                            "RETURNING mulakatci_id",
                    Integer.class, isverenId, isverenId);
        } else {
            mulakatciId = mulakatcilar.get(0);
        }

        // Daha önce planlandıysa tarihi güncelle (aday onayı sıfırlanır), yoksa yeni
        // mülakat ekle
        int guncellenen = jdbc.update(
                "UPDATE mulakatlar SET tarih = ?, gorusme_linki = ?, durum = 'planlandi', onerilen_tarih = NULL, itiraz_notu = NULL WHERE basvuru_id = ?",
                Timestamp.valueOf(tarih), link, id);
        if (guncellenen == 0) {
            jdbc.update(
                    "INSERT INTO mulakatlar (basvuru_id, mulakatci_id, tarih, gorusme_linki, durum) VALUES (?, ?, ?, ?, 'planlandi')",
                    id, mulakatciId, Timestamp.valueOf(tarih), link);
        }
        jdbc.update("UPDATE basvurular SET durum = 'mulakat_planlandi' WHERE basvuru_id = ?", id);

        bildirimci.gonder(sayi(b.get("aday_id")), "mulakat", "Mülakata davet edildin",
                "\"" + b.get("baslik")
                        + "\" başvurun olumlu değerlendirildi. 15 dakikalık mülakat için önerilen tarih: " +
                        tarih.format(DateTimeFormatter.ofPattern("d.MM.yyyy HH:mm"))
                        + ". Başvurularım ekranından tarihi onaylayabilir ya da uygun değilse itiraz edip yeni tarih önerebilirsin.",
                id);
    }

    /**
     * PATCH /api/basvurular/{id}/mulakat-onay -> aday işverenin önerdiği tarihi onaylar (iki tarafın onayı)
     */
    @PatchMapping("/{id}/mulakat-onay")
    @Transactional
    public Map<String, Object> mulakatOnay(@RequestHeader(value = "Authorization", required = false) String yetki,
            @PathVariable int id) {
        Map<String, Object> b = adayBasvurusu(oturum.adayId(yetki), id);
        Map<String, Object> m = mulakat(id);
        String md = (String) m.get("durum");
        if ("onaylandi".equals(md)) throw hata(HttpStatus.CONFLICT, "Bu mülakat tarihi zaten onaylandı");
        if ("aday_itiraz".equals(md))
            throw hata(HttpStatus.CONFLICT, "Bu tarihe itiraz ettin; işverenin yeni tarih önermesini bekle");
        jdbc.update("UPDATE mulakatlar SET durum = 'onaylandi', onerilen_tarih = NULL WHERE basvuru_id = ?", id);
        bildirimci.gonder(sayi(b.get("isveren_id")), "mulakat", "Mülakat tarihi onaylandı",
                b.get("aday_ad") + ", \"" + b.get("baslik") + "\" mülakatı için " + tarihYazisi(m.get("tarih"))
                        + " tarihini onayladı.", id);
        return Map.of("mulakat_durumu", "onaylandi");
    }

    /**
     * PATCH /api/basvurular/{id}/mulakat-itiraz  {neden, onerilen_tarih?: "2026-10-09T15:00:00"}
     * Aday tarihe itiraz eder (onaylamış olsa bile sonradan itiraz edebilir) ve isterse yeni tarih önerir.
     */
    @PatchMapping("/{id}/mulakat-itiraz")
    @Transactional
    public Map<String, Object> mulakatItiraz(@RequestHeader(value = "Authorization", required = false) String yetki,
            @PathVariable int id, @RequestBody Map<String, Object> g) {
        Map<String, Object> b = adayBasvurusu(oturum.adayId(yetki), id);
        mulakat(id);
        String neden = zorunlu(g, "neden", "İtiraz sebebini yazmalısın");
        if (neden.length() < 5) throw hata(HttpStatus.BAD_REQUEST, "İtiraz sebebi çok kısa");
        if (neden.length() > 500) throw hata(HttpStatus.BAD_REQUEST, "İtiraz sebebi en fazla 500 karakter olabilir");
        String oneriYazi = metin(g, "onerilen_tarih");
        LocalDateTime oneri = oneriYazi == null ? null : tarihOku(oneriYazi);
        if (oneri != null && oneri.isBefore(LocalDateTime.now()))
            throw hata(HttpStatus.BAD_REQUEST, "Önerdiğin tarih geçmişte olamaz");

        jdbc.update("UPDATE mulakatlar SET durum = 'aday_itiraz', itiraz_notu = ?, onerilen_tarih = ? WHERE basvuru_id = ?",
                neden, oneri == null ? null : Timestamp.valueOf(oneri), id);
        bildirimci.gonder(sayi(b.get("isveren_id")), "mulakat", "Mülakat tarihine itiraz",
                b.get("aday_ad") + ", \"" + b.get("baslik") + "\" mülakat tarihine itiraz etti. Sebep: " + neden
                        + (oneri == null ? " Yeni bir tarih önermeni bekliyor."
                                         : " Önerdiği tarih: " + oneri.format(DateTimeFormatter.ofPattern("d.MM.yyyy HH:mm")) + "."),
                id);
        return Map.of("mulakat_durumu", "aday_itiraz");
    }

    /**
     * PATCH /api/basvurular/{id}/mulakat-oneri-kabul -> işveren adayın önerdiği tarihi kabul eder (tarih kesinleşir)
     */
    @PatchMapping("/{id}/mulakat-oneri-kabul")
    @Transactional
    public Map<String, Object> mulakatOneriKabul(@RequestHeader(value = "Authorization", required = false) String yetki,
            @PathVariable int id) {
        Map<String, Object> b = isverenBasvurusu(oturum.isverenId(yetki), id);
        Map<String, Object> m = mulakat(id);
        if (!"aday_itiraz".equals(m.get("durum")) || m.get("onerilen_tarih") == null)
            throw hata(HttpStatus.CONFLICT, "Adayın önerdiği bir tarih yok; yeni tarih belirleyebilirsin");
        jdbc.update("UPDATE mulakatlar SET tarih = onerilen_tarih, onerilen_tarih = NULL, durum = 'onaylandi' WHERE basvuru_id = ?", id);
        bildirimci.gonder(sayi(b.get("aday_id")), "mulakat", "Önerdiğin tarih kabul edildi",
                "\"" + b.get("baslik") + "\" mülakatı için önerdiğin " + tarihYazisi(m.get("onerilen_tarih"))
                        + " tarihi işveren tarafından kabul edildi. Mülakat tarihi kesinleşti.", id);
        return Map.of("mulakat_durumu", "onaylandi");
    }

    /** PATCH /api/basvurular/{id}/kabul -> mülakat sonrası kabul */
    @PatchMapping("/{id}/kabul")
    @Transactional
    public void kabul(@RequestHeader(value = "Authorization", required = false) String yetki, @PathVariable int id) {
        Map<String, Object> b = isverenBasvurusu(oturum.isverenId(yetki), id);
        if (!"mulakat_planlandi".equals(b.get("durum")))
            throw hata(HttpStatus.CONFLICT, "Kabul için önce mülakat aşaması gerekir");
        if (!"onaylandi".equals(mulakat(id).get("durum")))
            throw hata(HttpStatus.CONFLICT, "Kabul için önce mülakat tarihinin iki tarafça onaylanması gerekir");
        jdbc.update("UPDATE basvurular SET durum = 'kabul' WHERE basvuru_id = ?", id);
        bildirimci.gonder(sayi(b.get("aday_id")), "kabul", "Başvurun kabul edildi",
                "Tebrikler! \"" + b.get("baslik") + "\" başvurun kabul edildi.", id);
    }

    /**
     * PATCH /api/basvurular/{id}/ret {gerekce}
     * Gerekçe ZORUNLU. Flutter'daki kutucuk boş göndermez ama kuralı sunucuda da
     * uyguluyoruz.
     * Reddedilen adaya gerekçeyle birlikte bildirim düşer.
     */
    @PatchMapping("/{id}/ret")
    @Transactional
    public void ret(@RequestHeader(value = "Authorization", required = false) String yetki,
            @PathVariable int id, @RequestBody Map<String, Object> g) {
        Map<String, Object> b = isverenBasvurusu(oturum.isverenId(yetki), id);
        String gerekce = zorunlu(g, "gerekce", "Ret gerekçesi zorunludur");
        if (gerekce.length() < 10)
            throw hata(HttpStatus.BAD_REQUEST, "Gerekçe en az 10 karakter olmalı");
        if (!"basvuruldu".equals(b.get("durum")) && !"mulakat_planlandi".equals(b.get("durum")))
            throw hata(HttpStatus.CONFLICT, "Bu başvuru zaten sonuçlanmış");

        // Aşama: mülakat kaydı varsa mülakat aşaması, yoksa başvuru aşaması
        Integer mulakatSayisi = jdbc.queryForObject("SELECT COUNT(*) FROM mulakatlar WHERE basvuru_id = ?",
                Integer.class, id);
        String asama = (mulakatSayisi != null && mulakatSayisi > 0) ? "mülakat" : "başvuru değerlendirme";

        jdbc.update("UPDATE basvurular SET durum = 'ret', ret_gerekcesi = ? WHERE basvuru_id = ?", gerekce, id);
        bildirimci.gonder(sayi(b.get("aday_id")), "ret", "Başvurun sonuçlandı",
                "\"" + b.get("baslik") + "\" (" + asama + " aşaması) için ilerleyemedik. Gerekçe: " + gerekce, id);
    }

    /**
     * POST /api/basvurular/{id}/ai-sorular {yeniden: false|true}
     * Daha önce üretilmiş sorular varsa onları döndürür (yapay zekâya tekrar gitmez,
     * aynı sorular birikmez).
     * yeniden = true gönderilirse eski AI sorularını silip yapay zekâdan yenilerini
     * ister.
     */
    @PostMapping("/{id}/ai-sorular")
    @Transactional
    public Map<String, Object> aiSorular(@RequestHeader(value = "Authorization", required = false) String yetki,
            @PathVariable int id,
            @RequestBody(required = false) Map<String, Object> g) {
        Map<String, Object> b = isverenBasvurusu(oturum.isverenId(yetki), id);
        List<Integer> mulakat = jdbc.queryForList("SELECT mulakat_id FROM mulakatlar WHERE basvuru_id = ?",
                Integer.class, id);
        if (mulakat.isEmpty())
            throw hata(HttpStatus.BAD_REQUEST, "Önce mülakat tarihi belirlemelisin");

        boolean yeniden = g != null && Boolean.TRUE.equals(g.get("yeniden"));
        List<String> kayitli = jdbc.queryForList(
                "SELECT soru_metni FROM mulakat_sorulari WHERE mulakat_id = ? AND ai_tarafindan_mi = TRUE ORDER BY soru_id",
                String.class, mulakat.get(0));
        if (!yeniden && !kayitli.isEmpty())
            return Map.of("sorular", kayitli);

        String gereksinimler = String.join(", ", jdbc.queryForList(
                "SELECT b2.ad FROM ilan_kriterleri k JOIN beceriler b2 ON b2.beceri_id = k.beceri_id WHERE k.ilan_id = ?",
                String.class, b.get("ilan_id")));
        List<String> diger = new ArrayList<>();
        for (Map<String, Object> r : jdbc.queryForList(
                "SELECT tur, deger, seviye FROM ilan_gereksinimleri WHERE ilan_id = ? AND tur IN ('dil','sertifika','deneyim','egitim')",
                b.get("ilan_id"))) {
            diger.add(r.get("deger") + (r.get("seviye") == null ? "" : " (" + r.get("seviye") + ")"));
        }
        String talep = "Pozisyon: " + b.get("baslik") + " | Beceriler: " + gereksinimler
                + (diger.isEmpty() ? "" : " | Diğer beklentiler: " + String.join(", ", diger));

        JsonNode ai = yapayZeka.sor(
                "Sen deneyimli bir teknik mülakatçısın. Türkçe yanıt ver. Yanıtı SADECE şu json biçiminde döndür: " +
                        "{\"maddeler\": [\"soru 1\", \"soru 2\"]}. 15 dakikalık bir mülakata sığacak 5 soru yaz; adayın gerçek bilgisini ölçsün, ezberi değil.",
                talep);
        List<String> sorular = new ArrayList<>();
        ai.path("maddeler").forEach(n -> sorular.add(n.asText()));
        if (sorular.isEmpty())
            throw hata(HttpStatus.BAD_GATEWAY, "Yapay zekâ beklenen formatta cevap vermedi");

        int mulakatId = mulakat.get(0);
        jdbc.update("DELETE FROM mulakat_sorulari WHERE mulakat_id = ? AND ai_tarafindan_mi = TRUE", mulakatId);
        jdbc.update("INSERT INTO ai_soru_talepleri (mulakat_id, talep_parametreleri) VALUES (?, ?)", mulakatId, talep);
        for (String s : sorular) {
            jdbc.update("INSERT INTO mulakat_sorulari (mulakat_id, soru_metni, ai_tarafindan_mi) VALUES (?, ?, TRUE)",
                    mulakatId, s);
        }
        return Map.of("sorular", sorular);
    }

    /** Başvuru bu adayın mı? Değilse 404. Mülakat aşamasında değilse 409. */
    private Map<String, Object> adayBasvurusu(int adayId, int basvuruId) {
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT b.durum, i.isveren_id, i.baslik, k.ad || ' ' || k.soyad AS aday_ad FROM basvurular b " +
                        "JOIN is_ilanlari i ON i.ilan_id = b.ilan_id JOIN kullanicilar k ON k.kullanici_id = b.aday_id " +
                        "WHERE b.basvuru_id = ? AND b.aday_id = ?",
                basvuruId, adayId);
        if (l.isEmpty())
            throw hata(HttpStatus.NOT_FOUND, "Başvuru bulunamadı");
        if (!"mulakat_planlandi".equals(l.get(0).get("durum")))
            throw hata(HttpStatus.CONFLICT, "Bu başvuru mülakat aşamasında değil");
        return l.get(0);
    }

    private Map<String, Object> mulakat(int basvuruId) {
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT mulakat_id, tarih, durum, onerilen_tarih FROM mulakatlar WHERE basvuru_id = ? ORDER BY mulakat_id DESC LIMIT 1",
                basvuruId);
        if (l.isEmpty())
            throw hata(HttpStatus.BAD_REQUEST, "Bu başvuru için planlanmış mülakat yok");
        return l.get(0);
    }

    private static LocalDateTime tarihOku(String yazi) {
        try {
            // Flutter "2026-10-07T14:30:00.000" gönderir; saniye kesirlerini de kabul et
            return LocalDateTime.parse(yazi.length() > 19 ? yazi.substring(0, 19) : yazi);
        } catch (Exception e) {
            throw hata(HttpStatus.BAD_REQUEST, "Tarih formatı geçersiz");
        }
    }

    private static String tarihYazisi(Object o) {
        if (o instanceof Timestamp t)
            return t.toLocalDateTime().format(DateTimeFormatter.ofPattern("d.MM.yyyy HH:mm"));
        return String.valueOf(o);
    }

    /** Başvuru bu işverenin ilanına mı ait? Değilse 404. */
    private Map<String, Object> isverenBasvurusu(int isverenId, int basvuruId) {
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT b.basvuru_id, b.durum, b.aday_id, i.ilan_id, i.baslik FROM basvurular b " +
                        "JOIN is_ilanlari i ON i.ilan_id = b.ilan_id WHERE b.basvuru_id = ? AND i.isveren_id = ?",
                basvuruId, isverenId);
        if (l.isEmpty())
            throw hata(HttpStatus.NOT_FOUND, "Başvuru bulunamadı");
        return l.get(0);
    }
}
