package com.ispusulam;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * İlan - aday eşleşme yüzdesi (yapay zekâ değil, basit bir hesap).
 * İlanın istediği her beceri için: adayda DOĞRULANMIŞ varsa 1 puan, sadece beyan edilmişse 0.6 puan, yoksa 0.
 * Yüzde = toplam puan / istenen beceri sayısı * 100
 */
@Component
public class Eslestirici {
    private final JdbcTemplate jdbc;
    public Eslestirici(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    /** Adayın becerileri: beceri_id -> doğrulanmış mı */
    public Map<Integer, Boolean> adayBecerileri(int adayId) {
        Map<Integer, Boolean> sonuc = new HashMap<>();
        List<Map<String, Object>> satirlar = jdbc.queryForList(
                "SELECT beceri_id, dogrulanmis FROM aday_becerileri WHERE aday_id = ?", adayId);
        for (Map<String, Object> s : satirlar) {
            sonuc.put(Yardimci.sayi(s.get("beceri_id")), Boolean.TRUE.equals(s.get("dogrulanmis")));
        }
        return sonuc;
    }

    public int yuzde(int ilanId, Map<Integer, Boolean> adayBecerileri) {
        List<Map<String, Object>> kriterler = jdbc.queryForList(
                "SELECT beceri_id FROM ilan_kriterleri WHERE ilan_id = ?", ilanId);
        if (kriterler.isEmpty()) return 0;
        double puan = 0;
        for (Map<String, Object> k : kriterler) {
            Boolean dogrulanmis = adayBecerileri.get(Yardimci.sayi(k.get("beceri_id")));
            if (dogrulanmis != null) puan += dogrulanmis ? 1.0 : 0.6;
        }
        return (int) Math.round(puan * 100 / kriterler.size());
    }
}
