-- =====================================================================
-- 05_guncelleme.sql
-- Backend her açıldığında OTOMATİK çalışır (BaslangicAyari.java). Elle çalıştırmana gerek yok.
-- Sadece eksik tablo/sütunları ekler; mevcut verine dokunmaz. Kaç kez çalışırsa çalışsın sorun çıkarmaz.
-- =====================================================================

-- 1) MESAJLAŞMA: aday <-> işveren yazışmaları
CREATE TABLE IF NOT EXISTS mesajlar (
    mesaj_id SERIAL PRIMARY KEY,
    gonderen_id INT NOT NULL REFERENCES kullanicilar(kullanici_id) ON DELETE CASCADE,
    alici_id INT NOT NULL REFERENCES kullanicilar(kullanici_id) ON DELETE CASCADE,
    basvuru_id INT REFERENCES basvurular(basvuru_id) ON DELETE SET NULL,
    icerik TEXT NOT NULL,
    okundu BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_mesajlar_alici ON mesajlar (alici_id, okundu);
CREATE INDEX IF NOT EXISTS ix_mesajlar_gonderen ON mesajlar (gonderen_id, tarih);

-- 2) NET İŞ TANIMI: ilanın beceri dışındaki gereksinimleri (birden fazla seçenek)
--    tur: egitim | bolum | dil | sertifika | deneyim | calisma_sekli | calisma_turu | diger
--    seviye: dil için A1..C2/Anadil (diğerlerinde boş)
CREATE TABLE IF NOT EXISTS ilan_gereksinimleri (
    gereksinim_id SERIAL PRIMARY KEY,
    ilan_id INT NOT NULL REFERENCES is_ilanlari(ilan_id) ON DELETE CASCADE,
    tur VARCHAR(30) NOT NULL,
    deger VARCHAR(150) NOT NULL,
    seviye VARCHAR(30),
    zorunlu_mu BOOLEAN DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS ix_ilan_gereksinimleri_ilan ON ilan_gereksinimleri (ilan_id);

-- 3) MÜLAKAT İTİRAZI: aday tarihe itiraz edip yeni tarih önerebilir
--    mulakatlar.durum: planlandi (işveren önerdi, aday onayı bekleniyor)
--                      aday_itiraz (aday itiraz etti / yeni tarih önerdi, işveren cevabı bekleniyor)
--                      onaylandi (iki taraf da onayladı)
ALTER TABLE mulakatlar ADD COLUMN IF NOT EXISTS onerilen_tarih TIMESTAMP;
ALTER TABLE mulakatlar ADD COLUMN IF NOT EXISTS itiraz_notu TEXT;

-- 4) YAPAY ZEKÂ İLE ÜRETİLEN BECERİ SINAVLARI
--    Her sınav denemesi için sorular yeniden üretilir (ezberlenmesin). Doğru cevaplar sadece sunucuda durur.
CREATE TABLE IF NOT EXISTS sinav_oturumlari (
    oturum_id SERIAL PRIMARY KEY,
    aday_id INT NOT NULL REFERENCES adaylar(aday_id) ON DELETE CASCADE,
    beceri_id INT NOT NULL REFERENCES beceriler(beceri_id) ON DELETE CASCADE,
    seviye VARCHAR(20),
    sorular TEXT NOT NULL,
    baraj_puani INT DEFAULT 70,
    sure_saniye INT,
    kaynak VARCHAR(10) DEFAULT 'ai',
    tamamlandi BOOLEAN DEFAULT FALSE,
    puan INT,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5) Kullanıcının/işverenin yazdığı, yapay zekânın kontrol edip eklediği beceriler
ALTER TABLE beceriler ADD COLUMN IF NOT EXISTS ai_ile_eklendi BOOLEAN DEFAULT FALSE;