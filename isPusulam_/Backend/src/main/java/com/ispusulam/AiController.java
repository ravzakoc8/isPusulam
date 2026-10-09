package com.ispusulam;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;

import static com.ispusulam.Yardimci.*;

/** İşverenin ilan yazarken kullandığı yapay zekâ desteği (DeepSeek). */
@RestController
@RequestMapping("/api/ai")
public class AiController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;
    private final DeepSeekServisi yapayZeka;
    private final BeceriServisi beceriServisi;

    public AiController(JdbcTemplate jdbc, Oturum oturum, DeepSeekServisi yapayZeka, BeceriServisi beceriServisi) {
        this.jdbc = jdbc; this.oturum = oturum; this.yapayZeka = yapayZeka; this.beceriServisi = beceriServisi;
    }

    /**
     * GET /api/ai/durum -> yapay zekâ çalışıyor mu? (giriş gerektirmez; tarayıcıdan açıp test edebilirsin)
     * Cevap: { calisiyor: true/false, model, mesaj }
     */
    @GetMapping("/durum")
    public Map<String, Object> durum() {
        Map<String, Object> c = new HashMap<>();
        c.put("model", yapayZeka.modelAdi());
        if (!yapayZeka.anahtarVar()) {
            c.put("calisiyor", false);
            c.put("mesaj", "API anahtarı tanımlı değil");
            return c;
        }
        try {
            JsonNode ai = yapayZeka.sor("Yanıtı SADECE json olarak ver: {\"cevap\": \"tamam\"}", "Test", 50);
            c.put("calisiyor", true);
            c.put("mesaj", "Yapay zekâ çalışıyor: " + ai.path("cevap").asText("?"));
        } catch (ResponseStatusException e) {
            c.put("calisiyor", false);
            c.put("mesaj", e.getReason());
        }
        return c;
    }

    /**
     * POST /api/ai/gereksinimler  {pozisyon, aciklama?}
     * İlan formunu yapay zekâ ile doldurur. Cevap:
     * { aciklama, maddeler: [...],
     *   beceriler: [{beceri_id, ad, seviye, zorunlu}],          <- listede olmayan beceriler otomatik eklenir
     *   gereksinimler: [{tur, deger, seviye, zorunlu_mu}] }     <- eğitim, bölüm, dil, sertifika, deneyim, çalışma şekli/türü
     */
    @PostMapping("/gereksinimler")
    public Map<String, Object> gereksinimler(@RequestHeader(value = "Authorization", required = false) String yetki,
                                             @RequestBody Map<String, Object> g) {
        oturum.isverenId(yetki);
        String pozisyon = zorunlu(g, "pozisyon", "Önce pozisyon başlığını yaz");
        String mevcutAciklama = metin(g, "aciklama");
        List<String> mevcut = jdbc.queryForList("SELECT ad FROM beceriler ORDER BY ad", String.class);

        String sistem = "Sen deneyimli bir işe alım uzmanısın ve Türkiye'deki staj/yeni mezun ilanlarını çok iyi biliyorsun. Türkçe yanıt ver. " +
                "Belirsiz pozisyon adlarını (ör. 'Backend', 'Yazılımcı') somut ve net bir ihtiyaç tanımına dönüştür. " +
                "Yanıtı SADECE şu json biçiminde döndür:\n" +
                "{\n" +
                " \"aciklama\": \"4-6 cümlelik net iş tanımı: ekipte ne yapılacak, hangi teknolojilerle, kimlere destek olunacak\",\n" +
                " \"maddeler\": [\"5-7 kısa, somut sorumluluk/beklenti maddesi\"],\n" +
                " \"beceriler\": [{\"ad\": \"Java\", \"kategori\": \"Yazılım\", \"seviye\": \"baslangic|orta|ileri\", \"zorunlu\": true}],\n" +
                " \"egitim\": [\"" + String.join("\", \"", IlanSecenekleri.EGITIM) + "\" listesinden 1-3 tane],\n" +
                " \"egitim_zorunlu\": true,\n" +
                " \"bolumler\": [\"uygun 1-4 bölüm, ör. Bilgisayar Mühendisliği\"],\n" +
                " \"diller\": [{\"ad\": \"İngilizce\", \"seviye\": \"A1|A2|B1|B2|C1|C2|Anadil\", \"zorunlu\": true}],\n" +
                " \"sertifikalar\": [{\"ad\": \"varsa pozisyona uygun gerçek sertifika adı\", \"zorunlu\": false}],\n" +
                " \"deneyim\": \"" + String.join(" | ", IlanSecenekleri.DENEYIM) + " değerlerinden TEK biri\",\n" +
                " \"calisma_sekli\": [\"" + String.join("\", \"", IlanSecenekleri.CALISMA_SEKLI) + "\" içinden 1-2 tane],\n" +
                " \"calisma_turu\": [\"" + String.join("\", \"", IlanSecenekleri.CALISMA_TURU) + "\" içinden 1-2 tane]\n" +
                "}\n" +
                "Kurallar: beceriler 4-8 tane olsun; mümkünse şu mevcut listeden birebir aynı yazımla seç, gerekirse listede olmayan " +
                "gerçek beceri de ekleyebilirsin (en fazla 40 karakter): " + String.join(", ", mevcut) + ". " +
                "Sertifikalar genelde zorunlu olmasın (tercih sebebi). Yeni mezun/staj pozisyonlarında abartılı deneyim isteme.";
        String kullanici = "Pozisyon: " + pozisyon + (mevcutAciklama == null ? "" : "\nİşverenin yazdığı not: " + mevcutAciklama);

        JsonNode ai = yapayZeka.sor(sistem, kullanici, 2500);

        List<String> maddeler = new ArrayList<>();
        ai.path("maddeler").forEach(n -> { if (!n.asText().isBlank()) maddeler.add(n.asText()); });

        // Beceriler: listede varsa onu kullan, yoksa ekle
        List<Map<String, Object>> beceriler = new ArrayList<>();
        Set<Integer> eklenen = new HashSet<>();
        for (JsonNode n : ai.path("beceriler")) {
            String ad = n.isTextual() ? n.asText() : n.path("ad").asText("");
            Map<String, Object> b = beceriServisi.bulVeyaOlustur(ad, n.path("kategori").asText(null));
            if (b == null || !eklenen.add(sayi(b.get("beceri_id")))) continue;
            String seviye = n.path("seviye").asText("orta");
            if (!List.of("baslangic", "orta", "ileri").contains(seviye)) seviye = "orta";
            Map<String, Object> m = new HashMap<>(b);
            m.put("seviye", seviye);
            m.put("zorunlu", n.path("zorunlu").asBoolean(true));
            beceriler.add(m);
        }

        // Diğer gereksinimler -> ilan formundaki biçim
        List<Map<String, Object>> gereksinimler = new ArrayList<>();
        boolean egitimZorunlu = ai.path("egitim_zorunlu").asBoolean(true);
        for (JsonNode n : ai.path("egitim"))
            if (IlanSecenekleri.EGITIM.contains(n.asText())) gereksinimler.add(gereksinim("egitim", n.asText(), null, egitimZorunlu));
        for (JsonNode n : ai.path("bolumler"))
            if (!n.asText().isBlank() && n.asText().length() <= 150) gereksinimler.add(gereksinim("bolum", n.asText(), null, false));
        for (JsonNode n : ai.path("diller")) {
            String ad = n.path("ad").asText("");
            String sv = n.path("seviye").asText("B1");
            if (!IlanSecenekleri.DIL_SEVIYE.contains(sv)) sv = "B1";
            if (!ad.isBlank()) gereksinimler.add(gereksinim("dil", ad, sv, n.path("zorunlu").asBoolean(true)));
        }
        for (JsonNode n : ai.path("sertifikalar")) {
            String ad = n.isTextual() ? n.asText() : n.path("ad").asText("");
            if (!ad.isBlank() && ad.length() <= 150) gereksinimler.add(gereksinim("sertifika", ad, null, n.path("zorunlu").asBoolean(false)));
        }
        String deneyim = ai.path("deneyim").asText("");
        if (IlanSecenekleri.DENEYIM.contains(deneyim)) gereksinimler.add(gereksinim("deneyim", deneyim, null, true));
        for (JsonNode n : ai.path("calisma_sekli"))
            if (IlanSecenekleri.CALISMA_SEKLI.contains(n.asText())) gereksinimler.add(gereksinim("calisma_sekli", n.asText(), null, true));
        for (JsonNode n : ai.path("calisma_turu"))
            if (IlanSecenekleri.CALISMA_TURU.contains(n.asText())) gereksinimler.add(gereksinim("calisma_turu", n.asText(), null, true));

        Map<String, Object> c = new HashMap<>();
        c.put("aciklama", ai.path("aciklama").asText(""));
        c.put("maddeler", maddeler);
        c.put("beceriler", beceriler);
        c.put("gereksinimler", gereksinimler);
        return c;
    }

    private static Map<String, Object> gereksinim(String tur, String deger, String seviye, boolean zorunlu) {
        Map<String, Object> m = new HashMap<>();
        m.put("tur", tur);
        m.put("deger", deger.trim());
        m.put("seviye", seviye);
        m.put("zorunlu_mu", zorunlu);
        return m;
    }
}
