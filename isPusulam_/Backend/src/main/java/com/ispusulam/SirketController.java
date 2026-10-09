package com.ispusulam;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.*;

import static com.ispusulam.Yardimci.*;

/** Şirketler sayfası (isverenler tablosu). */
@RestController
@RequestMapping("/api/sirketler")
public class SirketController {
    private final JdbcTemplate jdbc;
    private final Oturum oturum;

    public SirketController(JdbcTemplate jdbc, Oturum oturum) { this.jdbc = jdbc; this.oturum = oturum; }

    /** GET /api/sirketler?q=arama -> şirket listesi + üstteki sayaçlar */
    @GetMapping
    public Map<String, Object> liste(@RequestHeader(value = "Authorization", required = false) String yetki,
                                     @RequestParam(required = false) String q) {
        oturum.kullanici(yetki);
        String sql = "SELECT v.isveren_id, v.sirket_adi, v.dogrulanmis, " +
                     "(SELECT COUNT(*) FROM is_ilanlari i WHERE i.isveren_id = v.isveren_id AND i.durum = 'aktif') AS acik_rol " +
                     "FROM isverenler v";
        List<Object> p = new ArrayList<>();
        if (q != null && !q.isBlank()) { sql += " WHERE v.sirket_adi ILIKE ?"; p.add("%" + q.trim() + "%"); }
        sql += " ORDER BY v.dogrulanmis DESC, v.sirket_adi";

        Map<String, Object> cevap = new HashMap<>();
        cevap.put("sirketler", jdbc.queryForList(sql, p.toArray()));
        cevap.put("dogrulanmis_sayisi", jdbc.queryForObject("SELECT COUNT(*) FROM isverenler WHERE dogrulanmis = TRUE", Integer.class));
        cevap.put("acik_ilan_sayisi", jdbc.queryForObject("SELECT COUNT(*) FROM is_ilanlari WHERE durum = 'aktif'", Integer.class));
        return cevap;
    }

    /** GET /api/sirketler/{id} -> şirket ve açık ilanları */
    @GetMapping("/{id}")
    public Map<String, Object> detay(@RequestHeader(value = "Authorization", required = false) String yetki, @PathVariable int id) {
        oturum.kullanici(yetki);
        List<Map<String, Object>> l = jdbc.queryForList("SELECT isveren_id, sirket_adi, dogrulanmis FROM isverenler WHERE isveren_id = ?", id);
        if (l.isEmpty()) throw hata(HttpStatus.NOT_FOUND, "Şirket bulunamadı");
        Map<String, Object> sirket = l.get(0);
        sirket.put("ilanlar", jdbc.queryForList(
                "SELECT ilan_id, baslik, konum FROM is_ilanlari WHERE isveren_id = ? AND durum = 'aktif' ORDER BY olusturulma_tarihi DESC", id));
        return sirket;
    }
}
