-- =====================================================================
-- 02_bildirimler.sql  ->  01_da.sql'den SONRA çalıştır.
-- Senin tablolarında bildirim saklayacak yer olmadığı için TEK yeni tablo. Başka hiçbir şeye dokunmaz.
-- =====================================================================
CREATE TABLE IF NOT EXISTS bildirimler (
    bildirim_id SERIAL PRIMARY KEY,
    kullanici_id INT NOT NULL REFERENCES kullanicilar(kullanici_id) ON DELETE CASCADE,  -- bildirimi alan kişi
    basvuru_id INT REFERENCES basvurular(basvuru_id) ON DELETE CASCADE,                -- ilgili başvuru (yoksa boş)
    tur VARCHAR(30) NOT NULL,        -- ret | kabul | mulakat | yeni_basvuru | dogrulandi
    baslik VARCHAR(150) NOT NULL,
    mesaj TEXT NOT NULL,             -- ret gerekçesi de burada yazar
    okundu BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);