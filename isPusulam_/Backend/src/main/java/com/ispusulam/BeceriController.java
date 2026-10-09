package com.ispusulam;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.*;

import static com.ispusulam.Yardimci.*;

/**
 * Beceriler, beceri sınavları ve Yetenek Görevleri.
 *
 * KURAL (tablolarını değiştirmemek için):
 *  - Test sorusu çoktan seçmeli ise soru_metni şöyle yazılır:  "Soru metni\nA) şık\nB) şık\nC) şık"  ve dogru_cevap = 'A'
 *  - Soru metninde "\nA)" YOKSA bu bir "Yetenek Görevi"dir (açık uçlu). dogru_cevap alanına değerlendirme ölçütü yazılır,
 *    adayın cevabını yapay zekâ bu ölçüte göre puanlar.
 *
 * YENİ: Yapay zekâ ile sınav (/api/sinav/...): aday hangi beceriyi seçerse seçsin (listede olmasa bile),
 * yapay zekâ o beceri ve seviye için istenen sayıda (5/10/15) çoktan seçmeli soru üretir. Her denemede sorular
 * yeniden üretilir; doğru cevaplar sadece sunucuda tutulur. Sınav öncesi geçme notu ve gereken doğru sayısı,
 * sınav sonrası her sorunun doğru cevabı ve açıklaması gösterilir.
 */
@RestController
@RequestMapping("/api")
public class BeceriController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;
    private final Bildirimci bildirimci;
    private final YapayZekaServisi yapayZeka;
    private final BeceriServisi beceriServisi;
    private final ObjectMapper json = new ObjectMapper();

    /** Varsayılan geçme notu (yüzde). Becerinin beceri_testleri kaydında farklı bir baraj varsa o kullanılır. */
    public static final int VARSAYILAN_BARAJ = 70;
    private static final List<Integer> SORU_SAYILARI = List.of(5, 10, 15);

    public BeceriController(JdbcTemplate jdbc, Oturum oturum, Bildirimci bildirimci, YapayZekaServisi yapayZeka,
                            BeceriServisi beceriServisi) {
        this.jdbc = jdbc; this.oturum = oturum; this.bildirimci = bildirimci; this.yapayZeka = yapayZeka;
        this.beceriServisi = beceriServisi;
    }

    /**
     * POST /api/beceriler {ad} -> listede olmayan bir beceriyi ekler (aday da işveren de kullanabilir).
     * Yapay zekâ gerçek bir beceri olup olmadığını kontrol eder ve yazımını düzeltir. Varsa mevcut olanı döndürür.
     */
    @PostMapping("/beceriler")
    public Map<String, Object> beceriTanimla(@RequestHeader(value = "Authorization", required = false) String yetki,
                                             @RequestBody Map<String, Object> g) {
        oturum.kullanici(yetki);
        return beceriServisi.kontrolluBulVeyaOlustur(zorunlu(g, "ad", "Beceri adını yaz"));
    }

    /** GET /api/beceriler -> tüm beceri listesi (ilan oluştururken ve beceri eklerken seçilir) */
    @GetMapping("/beceriler")
    public List<Map<String, Object>> tumBeceriler(@RequestHeader(value = "Authorization", required = false) String yetki) {
        oturum.kullanici(yetki);
        return jdbc.queryForList("SELECT beceri_id, ad, kategori FROM beceriler ORDER BY kategori, ad");
    }

    /** GET /api/becerilerim -> adayın becerileri; sınavı varsa test_id de gelir */
    @GetMapping("/becerilerim")
    public List<Map<String, Object>> becerilerim(@RequestHeader(value = "Authorization", required = false) String yetki) {
        int adayId = oturum.adayId(yetki);
        return jdbc.queryForList(
                "SELECT b.beceri_id, b.ad, b.kategori, ab.kendi_seviyesi, ab.dogrulanmis, " +
                "(SELECT t.test_id FROM beceri_testleri t JOIN test_sorulari q ON q.test_id = t.test_id " +
                "  WHERE t.beceri_id = b.beceri_id AND q.soru_metni LIKE '%' || chr(10) || 'A)%' LIMIT 1) AS test_id, " +
                "COALESCE((SELECT MAX(t.baraj_puani) FROM beceri_testleri t WHERE t.beceri_id = b.beceri_id), " + VARSAYILAN_BARAJ + ") AS baraj, " +
                "(SELECT s.puan FROM sinav_oturumlari s WHERE s.aday_id = ab.aday_id AND s.beceri_id = b.beceri_id AND s.tamamlandi " +
                "  ORDER BY s.oturum_id DESC LIMIT 1) AS son_puan, " +
                "(SELECT COUNT(*) FROM sinav_oturumlari s WHERE s.aday_id = ab.aday_id AND s.beceri_id = b.beceri_id AND s.tamamlandi) AS deneme_sayisi " +
                "FROM aday_becerileri ab JOIN beceriler b ON b.beceri_id = ab.beceri_id " +
                "WHERE ab.aday_id = ? ORDER BY ab.dogrulanmis DESC, b.ad", adayId);
    }

    /**
     * POST /api/becerilerim  {beceri_id | ad, kendi_seviyesi} -> profiline beceri ekler (varsa seviyeyi günceller).
     * ad gönderilirse ve listede yoksa yapay zekâ kontrol edip yeni beceri olarak ekler.
     */
    @PostMapping("/becerilerim")
    public Map<String, Object> beceriEkle(@RequestHeader(value = "Authorization", required = false) String yetki,
                           @RequestBody Map<String, Object> g) {
        int adayId = oturum.adayId(yetki);
        Map<String, Object> beceri;
        if (metin(g, "beceri_id") != null) {
            int id;
            try { id = Integer.parseInt(metin(g, "beceri_id")); }
            catch (NumberFormatException e) { throw hata(HttpStatus.BAD_REQUEST, "Geçersiz beceri"); }
            List<Map<String, Object>> l = jdbc.queryForList("SELECT beceri_id, ad, kategori FROM beceriler WHERE beceri_id = ?", id);
            if (l.isEmpty()) throw hata(HttpStatus.NOT_FOUND, "Beceri bulunamadı");
            beceri = l.get(0);
        } else {
            beceri = beceriServisi.kontrolluBulVeyaOlustur(zorunlu(g, "ad", "Beceri seçmeli ya da yazmalısın"));
        }
        String seviye = metin(g, "kendi_seviyesi");
        if (seviye == null || !List.of("baslangic", "orta", "ileri").contains(seviye)) seviye = "orta";
        jdbc.update("INSERT INTO aday_becerileri (aday_id, beceri_id, kendi_seviyesi) VALUES (?, ?, ?) " +
                    "ON CONFLICT (aday_id, beceri_id) DO UPDATE SET kendi_seviyesi = EXCLUDED.kendi_seviyesi",
                adayId, beceri.get("beceri_id"), seviye);
        return beceri;
    }

    /** DELETE /api/becerilerim/{beceriId} */
    @DeleteMapping("/becerilerim/{beceriId}")
    public void beceriSil(@RequestHeader(value = "Authorization", required = false) String yetki, @PathVariable int beceriId) {
        jdbc.update("DELETE FROM aday_becerileri WHERE aday_id = ? AND beceri_id = ?", oturum.adayId(yetki), beceriId);
    }

    // ===================== ÇOKTAN SEÇMELİ SINAV =====================

    /** GET /api/testler/{testId} -> soruları getirir (doğru cevaplar GÖNDERİLMEZ). */
    @GetMapping("/testler/{testId}")
    public Map<String, Object> test(@RequestHeader(value = "Authorization", required = false) String yetki, @PathVariable int testId) {
        int adayId = oturum.adayId(yetki);
        cvIdBul(adayId); // CV yoksa sınava başlamadan uyar

        List<Map<String, Object>> t = jdbc.queryForList(
                "SELECT t.test_id, t.baraj_puani, b.ad AS beceri_ad FROM beceri_testleri t JOIN beceriler b ON b.beceri_id = t.beceri_id WHERE t.test_id = ?", testId);
        if (t.isEmpty()) throw hata(HttpStatus.NOT_FOUND, "Sınav bulunamadı");

        List<Map<String, Object>> sorular = new ArrayList<>();
        for (Map<String, Object> s : jdbc.queryForList("SELECT soru_id, soru_metni FROM test_sorulari WHERE test_id = ? ORDER BY soru_id", testId)) {
            String[] satirlar = ((String) s.get("soru_metni")).split("\n");
            Map<String, Object> soru = new HashMap<>();
            soru.put("soru_id", s.get("soru_id"));
            soru.put("soru", satirlar[0]);                                   // ilk satır = soru
            soru.put("secenekler", Arrays.asList(satirlar).subList(1, satirlar.length)); // kalanlar = şıklar
            sorular.add(soru);
        }
        Map<String, Object> cevap = t.get(0);
        cevap.put("sorular", sorular);
        return cevap;
    }

    /** POST /api/testler/{testId}/gonder  {cevaplar: {"soruId": "A", ...}} -> puanlar, geçtiyse beceriyi doğrular */
    @PostMapping("/testler/{testId}/gonder")
    @SuppressWarnings("unchecked")
    public Map<String, Object> testGonder(@RequestHeader(value = "Authorization", required = false) String yetki,
                                          @PathVariable int testId, @RequestBody Map<String, Object> g) {
        int adayId = oturum.adayId(yetki);
        int cvId = cvIdBul(adayId);
        Map<String, Object> cevaplar = (Map<String, Object>) g.getOrDefault("cevaplar", new HashMap<>());

        Map<String, Object> t = jdbc.queryForList("SELECT beceri_id, baraj_puani FROM beceri_testleri WHERE test_id = ?", testId).stream()
                .findFirst().orElseThrow(() -> hata(HttpStatus.NOT_FOUND, "Sınav bulunamadı"));

        List<Map<String, Object>> sorular = jdbc.queryForList("SELECT soru_id, dogru_cevap FROM test_sorulari WHERE test_id = ?", testId);
        int dogru = 0;
        for (Map<String, Object> s : sorular) {
            Object verilen = cevaplar.get(String.valueOf(s.get("soru_id")));
            if (verilen != null && verilen.toString().trim().equalsIgnoreCase(((String) s.get("dogru_cevap")).trim())) dogru++;
        }
        int puan = sorular.isEmpty() ? 0 : dogru * 100 / sorular.size();
        return sonucuKaydet(adayId, cvId, testId, sayi(t.get("beceri_id")), sayi(t.get("baraj_puani")), puan, dogru, sorular.size(), null);
    }

    // ===================== YAPAY ZEKÂ İLE SINAV =====================

    /**
     * POST /api/sinav/baslat  {beceri_id, soru_sayisi: 5|10|15, seviye?: baslangic|orta|ileri}
     * Yapay zekâ seçilen beceri için soruları üretir. Cevapta doğru cevaplar YOKTUR.
     * Cevap: {oturum_id, beceri_ad, seviye, baraj, soru_sayisi, gereken_dogru, sure_saniye, kaynak, sorular: [{no, soru, secenekler}]}
     */
    @PostMapping("/sinav/baslat")
    @Transactional
    public Map<String, Object> sinavBaslat(@RequestHeader(value = "Authorization", required = false) String yetki,
                                           @RequestBody Map<String, Object> g) {
        int adayId = oturum.adayId(yetki);
        cvIdBul(adayId); // CV yoksa sınava başlamadan uyar
        int beceriId;
        try { beceriId = Integer.parseInt(zorunlu(g, "beceri_id", "Beceri seçmelisin")); }
        catch (NumberFormatException e) { throw hata(HttpStatus.BAD_REQUEST, "Geçersiz beceri"); }
        List<Map<String, Object>> bl = jdbc.queryForList("SELECT ad, kategori FROM beceriler WHERE beceri_id = ?", beceriId);
        if (bl.isEmpty()) throw hata(HttpStatus.NOT_FOUND, "Beceri bulunamadı");
        String beceriAd = (String) bl.get(0).get("ad");

        int n = 10;
        if (g.get("soru_sayisi") instanceof Number s && SORU_SAYILARI.contains(s.intValue())) n = s.intValue();
        String seviye = metin(g, "seviye");
        if (seviye == null || !List.of("baslangic", "orta", "ileri").contains(seviye)) {
            List<String> kendi = jdbc.queryForList("SELECT kendi_seviyesi FROM aday_becerileri WHERE aday_id = ? AND beceri_id = ?",
                    String.class, adayId, beceriId);
            seviye = kendi.isEmpty() || kendi.get(0) == null ? "orta" : kendi.get(0);
        }
        int baraj = baraj(beceriId);

        // 1) Yapay zekâdan soru iste; 2) olmazsa hazır soru bankasına düş
        List<Map<String, Object>> sorular;
        String kaynak = "ai";
        try {
            sorular = aiSorulari(beceriAd, seviye, n);
        } catch (RuntimeException e) {
            sorular = hazirSorular(beceriId);
            kaynak = "hazir";
            if (sorular.isEmpty()) throw e; // yapay zekâ da hazır soru da yok: hatayı göster
            n = sorular.size();
        }

        int sure = n * 60; // soru başına 1 dakika
        Integer oturumId;
        try {
            oturumId = jdbc.queryForObject(
                    "INSERT INTO sinav_oturumlari (aday_id, beceri_id, seviye, sorular, baraj_puani, sure_saniye, kaynak) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING oturum_id",
                    Integer.class, adayId, beceriId, seviye, json.writeValueAsString(sorular), baraj, sure, kaynak);
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw hata(HttpStatus.INTERNAL_SERVER_ERROR, "Sınav kaydedilemedi");
        }
        // Profilde yoksa beceriyi profile ekle
        jdbc.update("INSERT INTO aday_becerileri (aday_id, beceri_id, kendi_seviyesi) VALUES (?, ?, ?) ON CONFLICT (aday_id, beceri_id) DO NOTHING",
                adayId, beceriId, seviye);

        List<Map<String, Object>> gorunen = new ArrayList<>();
        for (int i = 0; i < sorular.size(); i++) {
            Map<String, Object> s = new HashMap<>();
            s.put("no", i);
            s.put("soru", sorular.get(i).get("soru"));
            s.put("secenekler", sorular.get(i).get("secenekler"));
            gorunen.add(s);
        }
        Map<String, Object> c = new HashMap<>();
        c.put("oturum_id", oturumId);
        c.put("beceri_ad", beceriAd);
        c.put("seviye", seviye);
        c.put("baraj", baraj);
        c.put("soru_sayisi", sorular.size());
        c.put("gereken_dogru", gerekenDogru(baraj, sorular.size()));
        c.put("sure_saniye", sure);
        c.put("kaynak", kaynak);
        c.put("sorular", gorunen);
        return c;
    }

    /**
     * POST /api/sinav/{oturumId}/gonder  {cevaplar: {"0": "A", "1": "C", ...}}
     * Puanlar; her soru için verilen cevap, doğru cevap ve açıklamayı döndürür. Geçtiyse beceri doğrulanır.
     */
    @PostMapping("/sinav/{oturumId}/gonder")
    @Transactional
    @SuppressWarnings("unchecked")
    public Map<String, Object> sinavGonder(@RequestHeader(value = "Authorization", required = false) String yetki,
                                           @PathVariable int oturumId, @RequestBody Map<String, Object> g) {
        int adayId = oturum.adayId(yetki);
        int cvId = cvIdBul(adayId);
        List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT beceri_id, sorular, baraj_puani, tamamlandi FROM sinav_oturumlari WHERE oturum_id = ? AND aday_id = ?",
                oturumId, adayId);
        if (l.isEmpty()) throw hata(HttpStatus.NOT_FOUND, "Sınav bulunamadı");
        Map<String, Object> o = l.get(0);
        if (Boolean.TRUE.equals(o.get("tamamlandi"))) throw hata(HttpStatus.CONFLICT, "Bu sınav zaten gönderildi");

        List<Map<String, Object>> sorular;
        try { sorular = json.readValue((String) o.get("sorular"), List.class); }
        catch (Exception e) { throw hata(HttpStatus.INTERNAL_SERVER_ERROR, "Sınav okunamadı"); }
        Map<String, Object> cevaplar = (Map<String, Object>) g.getOrDefault("cevaplar", new HashMap<>());

        int dogru = 0;
        List<Map<String, Object>> detay = new ArrayList<>();
        for (int i = 0; i < sorular.size(); i++) {
            Map<String, Object> s = sorular.get(i);
            Object v = cevaplar.get(String.valueOf(i));
            String verilen = v == null ? null : v.toString().trim().toUpperCase(Locale.ROOT);
            String dogruHarf = String.valueOf(s.get("dogru"));
            boolean dogruMu = dogruHarf.equals(verilen);
            if (dogruMu) dogru++;
            Map<String, Object> d = new HashMap<>();
            d.put("no", i);
            d.put("soru", s.get("soru"));
            d.put("secenekler", s.get("secenekler"));
            d.put("verilen", verilen);
            d.put("dogru", dogruHarf);
            d.put("dogru_mu", dogruMu);
            d.put("aciklama", s.getOrDefault("aciklama", ""));
            detay.add(d);
        }
        int toplam = sorular.size();
        int puan = toplam == 0 ? 0 : (int) Math.round(dogru * 100.0 / toplam);
        int baraj = sayi(o.get("baraj_puani"));
        int beceriId = sayi(o.get("beceri_id"));
        jdbc.update("UPDATE sinav_oturumlari SET tamamlandi = TRUE, puan = ? WHERE oturum_id = ?", puan, oturumId);

        Map<String, Object> c = sonucuKaydet(adayId, cvId, testIdBulVeyaOlustur(beceriId), beceriId, baraj, puan, dogru, toplam, null);
        int gereken = gerekenDogru(baraj, toplam);
        c.put("gereken_dogru", gereken);
        c.put("eksik_dogru", Math.max(0, gereken - dogru));
        c.put("detay", detay);
        return c;
    }

    /** Yapay zekâdan n adet 4 şıklı soru ister ve sıkı biçimde doğrular. */
    private List<Map<String, Object>> aiSorulari(String beceri, String seviye, int n) {
        String seviyeYazi = switch (seviye) { case "baslangic" -> "başlangıç"; case "ileri" -> "ileri"; default -> "orta"; };
        // Fazladan 2 soru iste: biri bozuk gelirse yine n soruya ulaşalım
        int istenen = n + 2;
        JsonNode ai = yapayZeka.sor(
                "Sen deneyimli bir sınav hazırlayıcısın. Adayın beyan ettiği beceriyi gerçekten bilip bilmediğini ölçen, " +
                "Türkçe, çoktan seçmeli sorular yazıyorsun. Kurallar:\n" +
                "- Tam olarak " + istenen + " soru yaz; her soru farklı bir alt konuyu ölçsün (tekrar yok).\n" +
                "- Her sorunun 4 şıkkı olsun (A, B, C, D), sadece BİR şık kesin doğru olsun, çeldiriciler makul olsun.\n" +
                "- 'Hepsi', 'Hiçbiri' gibi şıklar kullanma. Doğru şıkların harfleri dengeli dağılsın.\n" +
                "- Ezber değil anlama/uygulama ölçen sorular olsun (kısa kod parçası, senaryo vb. kullanabilirsin).\n" +
                "- Her soru için doğru cevabın neden doğru olduğunu 1-2 cümleyle açıkla.\n" +
                "- Teknik terimleri orijinal haliyle yazabilirsin.\n" +
                "Yanıtı SADECE şu json biçiminde ver: {\"sorular\": [{\"soru\": \"...\", \"secenekler\": [\"...\", \"...\", \"...\", \"...\"], " +
                "\"dogru\": \"A|B|C|D\", \"aciklama\": \"...\"}]}",
                "Beceri: " + beceri + "\nSeviye: " + seviyeYazi + "\nSoru sayısı: " + istenen,
                Math.min(8000, 600 + istenen * 320));

        List<Map<String, Object>> liste = new ArrayList<>();
        Set<String> gorulen = new HashSet<>();
        String[] harfler = {"A", "B", "C", "D"};
        for (JsonNode q : ai.path("sorular")) {
            String soru = q.path("soru").asText("").trim();
            JsonNode sec = q.path("secenekler");
            String dogru = q.path("dogru").asText("").trim().toUpperCase(Locale.ROOT);
            if (dogru.length() > 1) dogru = dogru.substring(0, 1);
            if (soru.isEmpty() || !sec.isArray() || sec.size() != 4 || !List.of(harfler).contains(dogru)) continue;
            if (!gorulen.add(soru.toLowerCase(Locale.ROOT))) continue;
            List<String> secenekler = new ArrayList<>();
            boolean bos = false;
            for (int i = 0; i < 4; i++) {
                // Yapay zekâ "A) ..." diye başlatmış olabilir: temizleyip kendimiz ekliyoruz
                String t = sec.get(i).asText("").trim();
                if (t.length() > 2 && Character.toUpperCase(t.charAt(0)) == harfler[i].charAt(0)
                        && (t.charAt(1) == ')' || t.charAt(1) == ':' || (t.charAt(1) == '.' && t.charAt(2) == ' ')))
                    t = t.substring(2).trim();
                if (t.isEmpty()) bos = true;
                secenekler.add(harfler[i] + ") " + t);
            }
            if (bos) continue;
            Map<String, Object> m = new HashMap<>();
            m.put("soru", soru);
            m.put("secenekler", secenekler);
            m.put("dogru", dogru);
            m.put("aciklama", q.path("aciklama").asText(""));
            liste.add(m);
            if (liste.size() == n) break;
        }
        if (liste.size() < Math.min(n, 5))
            throw hata(HttpStatus.BAD_GATEWAY, "Yapay zekâ yeterli sayıda geçerli soru üretemedi, tekrar dene");
        return liste;
    }

    /** Yapay zekâ çalışmazsa: veritabanındaki hazır çoktan seçmeli sorular. */
    private List<Map<String, Object>> hazirSorular(int beceriId) {
        List<Map<String, Object>> liste = new ArrayList<>();
        for (Map<String, Object> r : jdbc.queryForList(
                "SELECT q.soru_metni, q.dogru_cevap FROM test_sorulari q JOIN beceri_testleri t ON t.test_id = q.test_id " +
                "WHERE t.beceri_id = ? AND q.soru_metni LIKE '%' || chr(10) || 'A)%' ORDER BY random() LIMIT 15", beceriId)) {
            String[] satirlar = ((String) r.get("soru_metni")).split("\n");
            Map<String, Object> m = new HashMap<>();
            m.put("soru", satirlar[0]);
            m.put("secenekler", new ArrayList<>(Arrays.asList(satirlar).subList(1, satirlar.length)));
            m.put("dogru", ((String) r.get("dogru_cevap")).trim().toUpperCase(Locale.ROOT));
            m.put("aciklama", "");
            liste.add(m);
        }
        return liste;
    }

    private int baraj(int beceriId) {
        Integer b = jdbc.queryForObject("SELECT MAX(baraj_puani) FROM beceri_testleri WHERE beceri_id = ?", Integer.class, beceriId);
        return b == null ? VARSAYILAN_BARAJ : b;
    }

    /** Barajı geçmek için gereken en az doğru sayısı. Örn. %70 baraj, 10 soru -> 7 doğru. */
    private static int gerekenDogru(int baraj, int toplam) {
        for (int d = 0; d <= toplam; d++) if (Math.round(d * 100.0 / toplam) >= baraj) return d;
        return toplam;
    }

    /** cv_test_loglari bir test_id istiyor: becerinin test kaydı yoksa oluştur. */
    private int testIdBulVeyaOlustur(int beceriId) {
        List<Integer> l = jdbc.queryForList("SELECT test_id FROM beceri_testleri WHERE beceri_id = ? ORDER BY test_id LIMIT 1",
                Integer.class, beceriId);
        if (!l.isEmpty()) return l.get(0);
        return jdbc.queryForObject("INSERT INTO beceri_testleri (beceri_id, baraj_puani) VALUES (?, ?) RETURNING test_id",
                Integer.class, beceriId, VARSAYILAN_BARAJ);
    }

    // ===================== YETENEK GÖREVLERİ (açık uçlu, AI puanlar) =====================

    /** GET /api/gorevler -> açık uçlu görevler ve adayın son sonucu */
    @GetMapping("/gorevler")
    public List<Map<String, Object>> gorevler(@RequestHeader(value = "Authorization", required = false) String yetki) {
        int adayId = oturum.adayId(yetki);
        List<Map<String, Object>> sonuc = new ArrayList<>();
        for (Map<String, Object> s : jdbc.queryForList(
                "SELECT t.test_id, t.baraj_puani, b.ad AS beceri_ad, q.soru_metni AS problem FROM beceri_testleri t " +
                "JOIN beceriler b ON b.beceri_id = t.beceri_id JOIN test_sorulari q ON q.test_id = t.test_id ORDER BY t.test_id")) {
            if (((String) s.get("problem")).contains("\nA)")) continue; // çoktan seçmeli sınav, görev değil
            List<Map<String, Object>> son = jdbc.queryForList(
                    "SELECT l.puan, l.gecti_mi FROM cv_test_loglari l JOIN cv c ON c.cv_id = l.cv_id " +
                    "WHERE c.aday_id = ? AND l.test_id = ? ORDER BY l.tarih DESC LIMIT 1", adayId, s.get("test_id"));
            s.put("son_puan", son.isEmpty() ? null : son.get(0).get("puan"));
            s.put("gecti_mi", son.isEmpty() ? null : son.get(0).get("gecti_mi"));
            sonuc.add(s);
        }
        return sonuc;
    }

    /** POST /api/gorevler/{testId}/cevap  {cevap} -> yapay zekâ cevabı değerlendirir */
    @PostMapping("/gorevler/{testId}/cevap")
    public Map<String, Object> gorevCevapla(@RequestHeader(value = "Authorization", required = false) String yetki,
                                            @PathVariable int testId, @RequestBody Map<String, Object> g) {
        int adayId = oturum.adayId(yetki);
        int cvId = cvIdBul(adayId);
        String cevap = zorunlu(g, "cevap", "Cevap yazmalısın");

        Map<String, Object> t = jdbc.queryForList(
                "SELECT t.beceri_id, t.baraj_puani, q.soru_metni, q.dogru_cevap FROM beceri_testleri t " +
                "JOIN test_sorulari q ON q.test_id = t.test_id WHERE t.test_id = ? LIMIT 1", testId).stream()
                .findFirst().orElseThrow(() -> hata(HttpStatus.NOT_FOUND, "Görev bulunamadı"));

        // Yapay zekâdan 0-100 puan ve kısa geri bildirim istiyoruz
        JsonNode ai = yapayZeka.sor(
                "Sen adil ve yapıcı bir değerlendiricisin. Türkçe yanıt ver. Yanıtı SADECE şu json biçiminde döndür: " +
                "{\"puan\": 0-100 arası tam sayı, \"geri_bildirim\": \"en fazla 3 cümlelik yapıcı yorum\"}",
                "Görev: " + t.get("soru_metni") + "\nDeğerlendirme ölçütü: " + t.get("dogru_cevap") + "\nAdayın cevabı: " + cevap);
        int puan = Math.max(0, Math.min(100, ai.path("puan").asInt(0)));
        String geriBildirim = ai.path("geri_bildirim").asText("");
        return sonucuKaydet(adayId, cvId, testId, sayi(t.get("beceri_id")), sayi(t.get("baraj_puani")), puan, 0, 0, geriBildirim);
    }

    // ===================== ORTAK =====================

    /** Sonucu cv_test_loglari'na yazar; geçtiyse beceriyi doğrular ve bildirim gönderir. */
    private Map<String, Object> sonucuKaydet(int adayId, int cvId, int testId, int beceriId, int baraj, int puan,
                                             int dogru, int toplam, String geriBildirim) {
        boolean gecti = puan >= baraj;
        jdbc.update("INSERT INTO cv_test_loglari (cv_id, test_id, puan, gecti_mi) VALUES (?, ?, ?, ?)", cvId, testId, puan, gecti);
        if (gecti) {
            jdbc.update("INSERT INTO aday_becerileri (aday_id, beceri_id, kendi_seviyesi, dogrulanmis) VALUES (?, ?, 'orta', TRUE) " +
                        "ON CONFLICT (aday_id, beceri_id) DO UPDATE SET dogrulanmis = TRUE", adayId, beceriId);
            jdbc.update("UPDATE cv SET onayli = TRUE WHERE cv_id = ?", cvId);
            String ad = jdbc.queryForObject("SELECT ad FROM beceriler WHERE beceri_id = ?", String.class, beceriId);
            bildirimci.gonder(adayId, "dogrulandi", "Beceri doğrulandı",
                    ad + " becerin onaylandı. Profilinde doğrulanmış olarak görünüyor.", null);
        }
        Map<String, Object> c = new HashMap<>();
        c.put("puan", puan);
        c.put("gecti", gecti);
        c.put("baraj", baraj);
        c.put("dogru", dogru);
        c.put("toplam", toplam);
        c.put("geri_bildirim", geriBildirim);
        return c;
    }

    /** Adayın CV kaydını bulur. Sınav sonuçları cv_test_loglari'na CV üzerinden yazıldığı için CV şart. */
    private int cvIdBul(int adayId) {
        List<Integer> l = jdbc.queryForList("SELECT cv_id FROM cv WHERE aday_id = ? ORDER BY cv_id DESC LIMIT 1", Integer.class, adayId);
        if (l.isEmpty()) throw hata(HttpStatus.BAD_REQUEST, "Önce profilinden CV bağlantını eklemelisin");
        return l.get(0);
    }
}
