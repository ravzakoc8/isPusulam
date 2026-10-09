package com.ispusulam;

import org.springframework.boot.CommandLineRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;

/**
 * Uygulama açılırken bir kez çalışır.
 * 1) guncelleme.sql: yeni özellikler için eksik tablo/sütunları ekler (mesajlar, ilan gereksinimleri,
 *    mülakat itirazı, AI sınavları). Mevcut veriye dokunmaz, tekrar tekrar çalışabilir.
 * 2) Örnek hesapların şifresi 'DEMO' yazıyorsa gerçek hash'e (123456) çevirir.
 */
@Component
public class BaslangicAyari implements CommandLineRunner {
    private final JdbcTemplate jdbc;
    private final DataSource veriKaynagi;
    private final DeepSeekServisi yapayZeka;

    public BaslangicAyari(JdbcTemplate jdbc, DataSource veriKaynagi, DeepSeekServisi yapayZeka) {
        this.jdbc = jdbc;
        this.veriKaynagi = veriKaynagi;
        this.yapayZeka = yapayZeka;
    }

    @Override
    public void run(String... args) {
        ResourceDatabasePopulator guncelleme = new ResourceDatabasePopulator(new ClassPathResource("guncelleme.sql"));
        guncelleme.setSqlScriptEncoding("UTF-8");
        guncelleme.execute(veriKaynagi);
        System.out.println("Veritabanı güncellemesi tamam (mesajlar, ilan gereksinimleri, mülakat itirazı, AI sınavları).");

        int sayi = jdbc.update("UPDATE kullanicilar SET sifre_hash = ? WHERE sifre_hash = 'DEMO'",
                new BCryptPasswordEncoder().encode("123456"));
        if (sayi > 0) System.out.println(sayi + " örnek hesabın şifresi 123456 olarak ayarlandı.");

        if (!yapayZeka.anahtarVar())
            System.out.println("UYARI: DeepSeek API anahtarı yok, yapay zekâ özellikleri çalışmayacak.");
        else
            System.out.println("Yapay zekâ hazır (model: " + yapayZeka.modelAdi() + "). Test: GET http://localhost:8080/api/ai/durum");
    }
}
