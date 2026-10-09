package com.ispusulam;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.*;

import static com.ispusulam.Yardimci.*;

/** İş ilanları: listeleme, oluşturma, başvuru ve işveren için uygun aday önerisi. */
@RestController
@RequestMapping("/api/ilanlar")
public class IlanController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;
    private final Eslestirici eslestirici;
    private final Bildirimci bildirimci;
    private final BeceriServisi beceriServisi;

    /** "Backend" yazıp geçmesin diye iş tanımı en az bu kadar karakter olmalı. */
    public static final int MIN_ACIKLAMA = 80;

    public IlanController(JdbcTemplate jdbc, Oturum oturum, Eslestirici eslestirici, Bildirimci bildirimci,
                          BeceriServisi beceriServisi) {
        this.jdbc = jdbc; this.oturum = oturum; this.eslestirici = eslestirici; this.bildirimci = bildirimci;
        this.beceriServisi = beceriServisi;
    }

    /** GET /api/ilanlar/secenekler -> ilan formundaki hazır seçenekler (eğitim, dil, sertifika, deneyim...) */
    @GetMapping("/secenekler")
    public Map<String, Object> secenekler(@RequestHeader(value = "Authorization", required = false) String yetki) {
        oturum.kullanici(yetki);
        return IlanSecenekleri.hepsi();
    }

    /** GET /api/ilanlar?q=arama  -> aktif ilanlar. Aday ise her ilan için eşleşme yüzdesi de gelir ve ona göre sıralanır. */
    @GetMapping
    public List<Map<String, Object>> liste(@RequestHeader(value = "Authorization", required = false) String yetki,
                                           @RequestParam(required = false) String q) {
        Map<String, Object> ben = oturum.kullanici(yetki);
        int benId = sayi(ben.get("kullanici_id"));
        boolean aday = "aday".equals(ben.get("kullanici_tipi"));

        String sql = "SELECT i.ilan_id, i.baslik, i.aciklama, i.konum, i.olusturulma_tarihi, i.isveren_id, v.sirket_adi, v.dogrulanmis " +
                     "FROM is_ilanlari i JOIN isverenler v ON v.isveren_id = i.isveren_id WHERE i.durum = 'aktif'";
        List<Object> parametreler = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            // başlıkta, şirket adında, açıklamada veya istenen becerilerde ara (büyük/küçük harf fark etmez: ILIKE)
            sql += " AND (i.baslik ILIKE ? OR v.sirket_adi ILIKE ? OR i.aciklama ILIKE ? OR i.konum ILIKE ? OR EXISTS (" +
                   "SELECT 1 FROM ilan_kriterleri k JOIN beceriler b ON b.beceri_id = k.beceri_id WHERE k.ilan_id = i.ilan_id AND b.ad ILIKE ?) " +
                   "OR EXISTS (SELECT 1 FROM ilan_gereksinimleri g WHERE g.ilan_id = i.ilan_id AND g.deger ILIKE ?))";
            String aranan = "%" + q.trim() + "%";
            for (int n = 0; n < 6; n++) parametreler.add(aranan);
        }
        sql += " ORDER BY i.olusturulma_tarihi DESC";
        List<Map<String, Object>> ilanlar = jdbc.queryForList(sql, parametreler.toArray());

        Map<Integer, Boolean> benimBecerilerim = aday ? eslestirici.adayBecerileri(benId) : new HashMap<>();
        Set<Integer> basvurduklarim = new HashSet<>();
        if (aday) basvurduklarim.addAll(jdbc.queryForList("SELECT ilan_id FROM basvurular WHERE aday_id = ?", Integer.class, benId));

        for (Map<String, Object> ilan : ilanlar) {
            int ilanId = sayi(ilan.get("ilan_id"));
            ilan.put("kriterler", kriterler(ilanId));
            ilan.put("gereksinimler", gereksinimler(ilanId));
            if (aday) {
                ilan.put("eslesme", eslestirici.yuzde(ilanId, benimBecerilerim));
                ilan.put("basvurdum", basvurduklarim.contains(ilanId));
            }
        }
        if (aday) ilanlar.sort((a, b) -> sayi(b.get("eslesme")) - sayi(a.get("eslesme"))); // en uygun üstte
        return ilanlar;
    }

    /** GET /api/ilanlar/benim -> işverenin kendi ilanları */
    @GetMapping("/benim")
    public List<Map<String, Object>> benim(@RequestHeader(value = "Authorization", required = false) String yetki) {
        int isverenId = oturum.isverenId(yetki);
        List<Map<String, Object>> ilanlar = jdbc.queryForList(
                "SELECT i.ilan_id, i.baslik, i.aciklama, i.konum, i.durum, i.olusturulma_tarihi, " +
                "(SELECT COUNT(*) FROM basvurular b WHERE b.ilan_id = i.ilan_id) AS basvuru_sayisi " +
                "FROM is_ilanlari i WHERE i.isveren_id = ? ORDER BY i.olusturulma_tarihi DESC", isverenId);
        for (Map<String, Object> i : ilanlar) {
            i.put("kriterler", kriterler(sayi(i.get("ilan_id"))));
            i.put("gereksinimler", gereksinimler(sayi(i.get("ilan_id"))));
        }
        return ilanlar;
    }

    /**
     * POST /api/ilanlar
     * { baslik, aciklama, konum,
     *   kriterler:     [ {beceri_id | ad, zorunlu_mu, seviye}, ... ]            -> aranan beceriler (ad: listede olmayan yeni beceri)
     *   gereksinimler: [ {tur, deger, seviye, zorunlu_mu}, ... ] }               -> eğitim, bölüm, dil, sertifika, deneyim...
     * NET İHTİYAÇ TANIMI KURALLARI: iş tanımı en az 80 karakter; en az 1 beceri; çalışma türü, çalışma şekli,
     * deneyim ve eğitim durumu seçilmiş olmalı. Böylece "Backend" yazıp ilan yayınlanamaz.
     */
    @PostMapping
    @Transactional
    @SuppressWarnings("unchecked")
    public Map<String, Object> olustur(@RequestHeader(value = "Authorization", required = false) String yetki,
                                       @RequestBody Map<String, Object> g) {
        int isverenId = oturum.isverenId(yetki);
        String baslik = zorunlu(g, "baslik", "Pozisyon başlığı zorunlu");
        if (baslik.length() < 3) throw hata(HttpStatus.BAD_REQUEST, "Pozisyon başlığı çok kısa");
        if (baslik.length() > 100) throw hata(HttpStatus.BAD_REQUEST, "Pozisyon başlığı en fazla 100 karakter olabilir");
        String aciklama = zorunlu(g, "aciklama", "İş tanımı zorunlu");
        if (aciklama.length() < MIN_ACIKLAMA)
            throw hata(HttpStatus.BAD_REQUEST, "İş tanımı en az " + MIN_ACIKLAMA + " karakter olmalı (şu an " + aciklama.length() +
                    "). Pozisyonda neler yapılacağını, kullanılacak araçları ve beklentileri yaz ya da yapay zekâ önerisini kullan.");

        // ---- Beceriler ----
        List<Map<String, Object>> kriterler = (List<Map<String, Object>>) g.getOrDefault("kriterler", new ArrayList<>());
        Map<Integer, Map<String, Object>> beceriler = new LinkedHashMap<>();
        for (Map<String, Object> k : kriterler) {
            Integer beceriId = null;
            if (k.get("beceri_id") instanceof Number n) beceriId = n.intValue();
            else if (metin(k, "ad") != null) {
                Map<String, Object> b = beceriServisi.bulVeyaOlustur(metin(k, "ad"), null);
                if (b != null) beceriId = sayi(b.get("beceri_id"));
            }
            if (beceriId == null) continue;
            String seviye = metin(k, "seviye");
            if (seviye == null || !List.of("baslangic", "orta", "ileri").contains(seviye)) seviye = "orta";
            Map<String, Object> m = new HashMap<>();
            m.put("zorunlu", !Boolean.FALSE.equals(k.get("zorunlu_mu")));
            m.put("seviye", seviye);
            beceriler.put(beceriId, m);
        }
        if (beceriler.isEmpty()) throw hata(HttpStatus.BAD_REQUEST, "En az bir aranan beceri seçmelisin (net ihtiyaç tanımı)");

        // ---- Diğer gereksinimler ----
        List<Map<String, Object>> ham = (List<Map<String, Object>>) g.getOrDefault("gereksinimler", new ArrayList<>());
        List<Object[]> gereksinimler = new ArrayList<>();
        Set<String> gorulen = new HashSet<>();
        Map<String, Integer> turSayisi = new HashMap<>();
        for (Map<String, Object> r : ham) {
            String tur = metin(r, "tur");
            String deger = metin(r, "deger");
            if (tur == null || deger == null || !IlanSecenekleri.TURLER.containsKey(tur)) continue;
            if (deger.length() > 150) throw hata(HttpStatus.BAD_REQUEST, "Gereksinim çok uzun: " + deger.substring(0, 40) + "...");
            if (!gorulen.add(tur + "|" + deger.toLowerCase(Locale.ROOT))) continue; // aynısını iki kez ekleme
            String seviye = metin(r, "seviye");
            if ("dil".equals(tur)) {
                if (seviye == null || !IlanSecenekleri.DIL_SEVIYE.contains(seviye))
                    throw hata(HttpStatus.BAD_REQUEST, deger + " için dil seviyesi seçmelisin (A1-C2)");
            } else seviye = null;
            gereksinimler.add(new Object[]{tur, deger, seviye, !Boolean.FALSE.equals(r.get("zorunlu_mu"))});
            turSayisi.merge(tur, 1, Integer::sum);
        }
        if (!turSayisi.containsKey("calisma_turu")) throw hata(HttpStatus.BAD_REQUEST, "Çalışma türünü seç (staj, tam zamanlı...)");
        if (!turSayisi.containsKey("calisma_sekli")) throw hata(HttpStatus.BAD_REQUEST, "Çalışma şeklini seç (ofisten, hibrit, uzaktan)");
        if (!turSayisi.containsKey("deneyim")) throw hata(HttpStatus.BAD_REQUEST, "Beklenen deneyim seviyesini seç");
        if (turSayisi.get("deneyim") > 1) throw hata(HttpStatus.BAD_REQUEST, "Deneyim için tek bir seviye seç");
        if (!turSayisi.containsKey("egitim")) throw hata(HttpStatus.BAD_REQUEST, "En az bir eğitim durumu seç (lisans öğrencisi, mezun...)");

        Integer ilanId = jdbc.queryForObject(
                "INSERT INTO is_ilanlari (isveren_id, baslik, aciklama, konum) VALUES (?, ?, ?, ?) RETURNING ilan_id",
                Integer.class, isverenId, baslik, aciklama, metin(g, "konum"));
        for (Map.Entry<Integer, Map<String, Object>> e : beceriler.entrySet()) {
            jdbc.update("INSERT INTO ilan_kriterleri (ilan_id, beceri_id, zorunlu_mu, seviye) VALUES (?, ?, ?, ?)",
                    ilanId, e.getKey(), e.getValue().get("zorunlu"), e.getValue().get("seviye"));
        }
        for (Object[] r : gereksinimler) {
            jdbc.update("INSERT INTO ilan_gereksinimleri (ilan_id, tur, deger, seviye, zorunlu_mu) VALUES (?, ?, ?, ?, ?)",
                    ilanId, r[0], r[1], r[2], r[3]);
        }
        return Map.of("ilan_id", ilanId);
    }

    /** PATCH /api/ilanlar/{id}/durum  {durum: aktif|kapali} */
    @PatchMapping("/{id}/durum")
    public void durum(@RequestHeader(value = "Authorization", required = false) String yetki,
                      @PathVariable int id, @RequestBody Map<String, Object> g) {
        int isverenId = oturum.isverenId(yetki);
        String durum = zorunlu(g, "durum", "Durum zorunlu");
        if (!durum.equals("aktif") && !durum.equals("kapali")) throw hata(HttpStatus.BAD_REQUEST, "Geçersiz durum");
        int n = jdbc.update("UPDATE is_ilanlari SET durum = ? WHERE ilan_id = ? AND isveren_id = ?", durum, id, isverenId);
        if (n == 0) throw hata(HttpStatus.NOT_FOUND, "İlan bulunamadı");
    }

    /** POST /api/ilanlar/{id}/basvur -> aday başvurur, işverene bildirim gider */
    @PostMapping("/{id}/basvur")
    @Transactional
    public Map<String, Object> basvur(@RequestHeader(value = "Authorization", required = false) String yetki, @PathVariable int id) {
        int adayId = oturum.adayId(yetki);
        List<Map<String, Object>> ilan = jdbc.queryForList("SELECT isveren_id, baslik, durum FROM is_ilanlari WHERE ilan_id = ?", id);
        if (ilan.isEmpty()) throw hata(HttpStatus.NOT_FOUND, "İlan bulunamadı");
        if (!"aktif".equals(ilan.get(0).get("durum"))) throw hata(HttpStatus.BAD_REQUEST, "Bu ilan artık başvuruya kapalı");
        Integer var = jdbc.queryForObject("SELECT COUNT(*) FROM basvurular WHERE ilan_id = ? AND aday_id = ?", Integer.class, id, adayId);
        if (var != null && var > 0) throw hata(HttpStatus.CONFLICT, "Bu ilana zaten başvurdun");

        Integer basvuruId = jdbc.queryForObject(
                "INSERT INTO basvurular (ilan_id, aday_id) VALUES (?, ?) RETURNING basvuru_id", Integer.class, id, adayId);
        Map<String, Object> aday = jdbc.queryForList("SELECT ad, soyad FROM kullanicilar WHERE kullanici_id = ?", adayId).get(0);
        bildirimci.gonder(sayi(ilan.get(0).get("isveren_id")), "yeni_basvuru", "Yeni başvuru",
                aday.get("ad") + " " + aday.get("soyad") + ", \"" + ilan.get(0).get("baslik") + "\" ilanına başvurdu.", basvuruId);
        return Map.of("basvuru_id", basvuruId);
    }

    /**
     * GET /api/ilanlar/{id}/onerilen-adaylar -> henüz başvurmamış ama ilana uyan adaylar (yapay zekâ yerine beceri eşleşmesi).
     * Gizli profiller görünmez; "sadece işverenler" profilleri sadece doğrulanmış işverenlere görünür.
     */
    @GetMapping("/{id}/onerilen-adaylar")
    public List<Map<String, Object>> onerilenAdaylar(@RequestHeader(value = "Authorization", required = false) String yetki,
                                                     @PathVariable int id) {
        int isverenId = oturum.isverenId(yetki);
        Integer benimIlanim = jdbc.queryForObject("SELECT COUNT(*) FROM is_ilanlari WHERE ilan_id = ? AND isveren_id = ?", Integer.class, id, isverenId);
        if (benimIlanim == null || benimIlanim == 0) throw hata(HttpStatus.NOT_FOUND, "İlan bulunamadı");
        boolean dogrulanmis = Boolean.TRUE.equals(
                jdbc.queryForObject("SELECT dogrulanmis FROM isverenler WHERE isveren_id = ?", Boolean.class, isverenId));

        List<Map<String, Object>> adaylar = jdbc.queryForList(
                "SELECT k.kullanici_id AS aday_id, k.ad, k.soyad, a.unvan, k.profil_gizliligi FROM kullanicilar k " +
                "JOIN adaylar a ON a.aday_id = k.kullanici_id WHERE k.profil_gizliligi <> 'gizli' " +
                "AND NOT EXISTS (SELECT 1 FROM basvurular b WHERE b.ilan_id = ? AND b.aday_id = k.kullanici_id)", id);

        List<Map<String, Object>> sonuc = new ArrayList<>();
        for (Map<String, Object> a : adaylar) {
            if ("sadece_isverenler".equals(a.get("profil_gizliligi")) && !dogrulanmis) continue;
            int adayId = sayi(a.get("aday_id"));
            int yuzde = eslestirici.yuzde(id, eslestirici.adayBecerileri(adayId));
            if (yuzde == 0) continue;
            a.remove("profil_gizliligi");
            a.put("eslesme", yuzde);
            sonuc.add(a);
        }
        sonuc.sort((x, y) -> sayi(y.get("eslesme")) - sayi(x.get("eslesme")));
        return sonuc.size() > 10 ? sonuc.subList(0, 10) : sonuc;
    }

    private List<Map<String, Object>> gereksinimler(int ilanId) {
        return jdbc.queryForList(
                "SELECT tur, deger, seviye, zorunlu_mu FROM ilan_gereksinimleri WHERE ilan_id = ? ORDER BY gereksinim_id", ilanId);
    }

    private List<Map<String, Object>> kriterler(int ilanId) {
        return jdbc.queryForList(
                "SELECT b.beceri_id, b.ad, k.zorunlu_mu, k.seviye FROM ilan_kriterleri k JOIN beceriler b ON b.beceri_id = k.beceri_id " +
                "WHERE k.ilan_id = ? ORDER BY k.kriter_id", ilanId);
    }
}