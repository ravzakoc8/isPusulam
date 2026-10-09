package com.ispusulam;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Bildirim oluşturmak için ortak yer. Ret, mülakat, kabul gibi her bildirim buradan geçer. */
@Component
public class Bildirimci {
    private final JdbcTemplate jdbc;
    public Bildirimci(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    /**
     * @param aliciId   bildirimi alacak kişi
     * @param tur       ret | kabul | mulakat | yeni_basvuru | dogrulandi
     * @param basvuruId ilgili başvuru (yoksa null)
     */
    public void gonder(int aliciId, String tur, String baslik, String mesaj, Integer basvuruId) {
        jdbc.update("INSERT INTO bildirimler (kullanici_id, tur, baslik, mesaj, basvuru_id) VALUES (?, ?, ?, ?, ?)",
                aliciId, tur, baslik, mesaj, basvuruId);
    }
}
