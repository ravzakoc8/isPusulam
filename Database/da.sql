

-- 1. KULLANICILAR (Ana Tablo)
CREATE TABLE kullanicilar (
    kullanici_id SERIAL PRIMARY KEY,
    eposta VARCHAR(100) UNIQUE NOT NULL,
    sifre_hash VARCHAR(255) NOT NULL,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    telefon VARCHAR(20),
    kullanici_tipi VARCHAR(20) NOT NULL CHECK (kullanici_tipi IN ('aday', 'isveren')),
    profil_gizliligi VARCHAR(30) DEFAULT 'herkese_acik' CHECK (profil_gizliligi IN ('herkese_acik', 'sadece_isverenler', 'gizli')),
    olusturulma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. ADAYLAR (Kullanıcı Kalıtımı)
CREATE TABLE adaylar (
    aday_id INT PRIMARY KEY REFERENCES kullanicilar(kullanici_id) ON DELETE CASCADE,
    unvan VARCHAR(100),
    biyografi TEXT,
    mevcut_durum VARCHAR(50) DEFAULT 'is_ariyor'
);

-- 3. İŞVERENLER (Kullanıcı Kalıtımı)
CREATE TABLE isverenler (
    isveren_id INT PRIMARY KEY REFERENCES kullanicilar(kullanici_id) ON DELETE CASCADE,
    sirket_adi VARCHAR(100) NOT NULL,
    vergi_no VARCHAR(50),
    dogrulanmis BOOLEAN DEFAULT FALSE
);

-- 4. BECERİLER (Master Tablo)
CREATE TABLE beceriler (
    beceri_id SERIAL PRIMARY KEY,
    ad VARCHAR(50) UNIQUE NOT NULL,
    kategori VARCHAR(50)
);

-- 5. ADAY BECERİLERİ (İlişki Tablosu)
CREATE TABLE aday_becerileri (
    aday_id INT REFERENCES adaylar(aday_id) ON DELETE CASCADE,
    beceri_id INT REFERENCES beceriler(beceri_id) ON DELETE CASCADE,
    kendi_seviyesi VARCHAR(20),
    dogrulanmis BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (aday_id, beceri_id)
);

-- 6. BECERİ TESTLERİ
CREATE TABLE beceri_testleri (
    test_id SERIAL PRIMARY KEY,
    beceri_id INT REFERENCES beceriler(beceri_id) ON DELETE CASCADE,
    baraj_puani INT DEFAULT 70
);

-- 7. TEST SORULARI
CREATE TABLE test_sorulari (
    soru_id SERIAL PRIMARY KEY,
    test_id INT REFERENCES beceri_testleri(test_id) ON DELETE CASCADE,
    soru_metni TEXT NOT NULL,
    dogru_cevap TEXT NOT NULL
);

-- 8. CV TABLOSU
CREATE TABLE cv (
    cv_id SERIAL PRIMARY KEY,
    aday_id INT REFERENCES adaylar(aday_id) ON DELETE CASCADE,
    dosya_url VARCHAR(255) NOT NULL,
    onayli BOOLEAN DEFAULT FALSE,
    yuklenme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. CV TEST LOGLARI (Onay Süreci)
CREATE TABLE cv_test_loglari (
    log_id SERIAL PRIMARY KEY,
    cv_id INT REFERENCES cv(cv_id) ON DELETE CASCADE,
    test_id INT REFERENCES beceri_testleri(test_id) ON DELETE CASCADE,
    puan INT NOT NULL,
    gecti_mi BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. İŞ İLANLARI
CREATE TABLE is_ilanlari (
    ilan_id SERIAL PRIMARY KEY,
    isveren_id INT REFERENCES isverenler(isveren_id) ON DELETE CASCADE,
    baslik VARCHAR(100) NOT NULL,
    aciklama TEXT NOT NULL,
    konum VARCHAR(100),
    durum VARCHAR(20) DEFAULT 'aktif' CHECK (durum IN ('aktif', 'kapali')),
    olusturulma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 11. İLAN KRİTERLERİ
CREATE TABLE ilan_kriterleri (
    kriter_id SERIAL PRIMARY KEY,
    ilan_id INT REFERENCES is_ilanlari(ilan_id) ON DELETE CASCADE,
    beceri_id INT REFERENCES beceriler(beceri_id) ON DELETE CASCADE,
    zorunlu_mu BOOLEAN DEFAULT TRUE,
    seviye VARCHAR(20)
);

-- 12. BAŞVURULAR
CREATE TABLE basvurular (
    basvuru_id SERIAL PRIMARY KEY,
    ilan_id INT REFERENCES is_ilanlari(ilan_id) ON DELETE CASCADE,
    aday_id INT REFERENCES adaylar(aday_id) ON DELETE CASCADE,
    durum VARCHAR(30) DEFAULT 'basvuruldu' CHECK (durum IN ('basvuruldu', 'mulakat_planlandi', 'kabul', 'ret')),
    ret_gerekcesi TEXT,
    basvuru_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 13. MÜLAKATÇILAR
CREATE TABLE mulakatcilar (
    mulakatci_id SERIAL PRIMARY KEY,
    isveren_id INT REFERENCES isverenler(isveren_id) ON DELETE CASCADE,
    ad_soyad VARCHAR(100) NOT NULL,
    unvan VARCHAR(50),
    eposta VARCHAR(100)
);

-- 14. MÜLAKATLAR
CREATE TABLE mulakatlar (
    mulakat_id SERIAL PRIMARY KEY,
    basvuru_id INT REFERENCES basvurular(basvuru_id) ON DELETE CASCADE,
    mulakatci_id INT REFERENCES mulakatcilar(mulakatci_id) ON DELETE CASCADE,
    tarih TIMESTAMP NOT NULL,
    gorusme_linki VARCHAR(255),
    durum VARCHAR(20) DEFAULT 'planlandi',
    genel_puan INT,
    degerlendirme_notu TEXT
);

-- 15. AI SORU TALEPLERİ
CREATE TABLE ai_soru_talepleri (
    talep_id SERIAL PRIMARY KEY,
    mulakat_id INT REFERENCES mulakatlar(mulakat_id) ON DELETE CASCADE,
    talep_parametreleri TEXT,
    talep_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 16. MÜLAKAT SORULARI
CREATE TABLE mulakat_sorulari (
    soru_id SERIAL PRIMARY KEY,
    mulakat_id INT REFERENCES mulakatlar(mulakat_id) ON DELETE CASCADE,
    soru_metni TEXT NOT NULL,
    ai_tarafindan_mi BOOLEAN DEFAULT FALSE,
    aday_cevap_notlari TEXT,
    mulakatci_puani INT
);

