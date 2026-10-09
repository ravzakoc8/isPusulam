-- =====================================================================
-- 04_sinav_duzeltme.sql
-- "Sınav yok" sorununu düzeltir. pgAdmin > ispusulam veritabanı > Query Tool'da
-- dosyanın TAMAMINI çalıştırın (F5).
--
-- - Tablo yapısına dokunmaz, sadece eksik sınav/soru ekler.
-- - Becerileri ID ile değil ADI ile eşleştirir; ID'ler farklı olsa da çalışır.
-- - Bir becerinin sınavı zaten varsa ona dokunmaz. İki kez çalıştırmak sorun çıkarmaz.
-- =====================================================================

-- 1) Sayaçları (sequence) mevcut en büyük ID'nin üstüne al (ID çakışmasını önler)
SELECT setval(pg_get_serial_sequence('beceri_testleri','test_id'), COALESCE((SELECT MAX(test_id) FROM beceri_testleri), 0) + 1, false);
SELECT setval(pg_get_serial_sequence('test_sorulari','soru_id'),  COALESCE((SELECT MAX(soru_id)  FROM test_sorulari),  0) + 1, false);

-- 2) Soru havuzu (geçici tablo, oturum kapanınca silinir)
DROP TABLE IF EXISTS tmp_sinav;
CREATE TEMP TABLE tmp_sinav (beceri_ad TEXT, soru_metni TEXT, dogru_cevap TEXT);

-- Çoktan seçmeli: "soru\nA) ...\nB) ...\nC) ..."  dogru_cevap = harf
INSERT INTO tmp_sinav VALUES
 ('Java', E'Java''da aynı isimli bir metodun farklı parametrelerle birden fazla kez tanımlanmasına ne denir?\nA) Overriding\nB) Overloading\nC) Encapsulation', 'B'),
 ('Java', E'Hangisi Java''da değiştirilemez (immutable) bir sınıftır?\nA) StringBuilder\nB) ArrayList\nC) String', 'C'),
 ('Java', E'Bir arayüzü (interface) uygulayan sınıf hangi anahtar kelimeyi kullanır?\nA) extends\nB) implements\nC) inherits', 'B'),

 ('Spring Boot', E'Bir sınıfı REST uç noktası olarak işaretlemek için hangi anotasyon kullanılır?\nA) @RestController\nB) @Entity\nC) @Table', 'A'),
 ('Spring Boot', E'Spring Boot''ta veritabanı bağlantı bilgileri genelde nereye yazılır?\nA) pom.xml\nB) application.properties\nC) main metodu', 'B'),
 ('Spring Boot', E'Bağımlılıkların Spring tarafından otomatik verilmesine ne denir?\nA) Dependency Injection\nB) Garbage Collection\nC) Serialization', 'A'),

 ('SQL', E'Bir tablodan yinelenen satırları çıkarmak için hangisi kullanılır?\nA) DISTINCT\nB) GROUP\nC) LIMIT', 'A'),
 ('SQL', E'İki tabloyu ortak bir sütuna göre birleştirmek için hangisi kullanılır?\nA) MERGE ROWS\nB) JOIN\nC) TRUNCATE', 'B'),
 ('SQL', E'Bir tablodaki kayıtları silmek için hangisi kullanılır?\nA) DELETE FROM\nB) DROP ROW\nC) REMOVE', 'A'),

 ('Flutter', E'Flutter''da durum değişince arayüzü yeniden çizdirmek için ne kullanılır?\nA) StatelessWidget\nB) StatefulWidget ve setState\nC) Container', 'B'),
 ('Flutter', E'Uzun bir listeyi kaydırılabilir göstermek için hangisi uygundur?\nA) ListView\nB) Stack\nC) Padding', 'A'),
 ('Flutter', E'Flutter uygulamaları hangi dille yazılır?\nA) Kotlin\nB) Dart\nC) Swift', 'B'),

 ('Python', E'Python''da bir liste nasıl tanımlanır?\nA) liste = (1, 2, 3)\nB) liste = [1, 2, 3]\nC) liste = {1: 2}', 'B'),
 ('Python', E'Python''da kod blokları neyle belirlenir?\nA) Süslü parantez\nB) Girinti (indentation)\nC) Noktalı virgül', 'B'),
 ('Python', E'Bir fonksiyon tanımlamak için hangi anahtar kelime kullanılır?\nA) def\nB) function\nC) func', 'A'),

 ('React', E'React''ta bileşenin kendi durumunu tutmak için hangi hook kullanılır?\nA) useState\nB) useRoute\nC) useStyle', 'A'),
 ('React', E'Üst bileşenden alt bileşene veri aktarmak için ne kullanılır?\nA) props\nB) state\nC) refs', 'A'),
 ('React', E'Listelerde her öğeye verilmesi gereken benzersiz özellik hangisidir?\nA) id\nB) key\nC) index', 'B'),

 ('Figma', E'Figma''da yeniden kullanılabilir tasarım parçalarına ne denir?\nA) Frame\nB) Component\nC) Layer', 'B'),
 ('Figma', E'Auto Layout ne işe yarar?\nA) Öğeleri içeriğe göre otomatik hizalar ve boyutlandırır\nB) Dosyayı yazdırır\nC) Renkleri rastgele seçer', 'A'),
 ('Figma', E'Prototip modunda ekranlar arası geçiş neyle tanımlanır?\nA) Interaction (bağlantı)\nB) Export\nC) Mask', 'A'),

 ('Kullanıcı araştırması', E'Bir mobil bankacılık akışında kullanıcılar para transferini tamamlamadan önce bekliyor. İlk araştırma adımın ne olurdu?\nA) Önce davranış analitiğini inceler, sonra bekleme anlarını anlamak için 5 kullanıcıyla görüşürdüm.\nB) Akışı baştan tasarlar, yeni tasarımı doğrudan A/B testine alırdım.\nC) Rakip uygulamaların transfer akışlarını karşılaştırıp en yaygın deseni uygulardım.', 'A'),
 ('Kullanıcı araştırması', E'Kullanıcı görüşmesinde en iyi soru tipi hangisidir?\nA) Evet/hayır soruları\nB) Yönlendirici sorular\nC) Açık uçlu ve davranışa dair sorular', 'C'),
 ('Kullanıcı araştırması', E'Nitel araştırmada ilk örüntüleri görmek için kaç kullanıcıyla görüşmek genelde yeterlidir?\nA) 5 civarı\nB) 500\nC) 1', 'A'),

 ('Prototipleme', E'Düşük doğruluklu (low-fidelity) prototipin temel amacı nedir?\nA) Fikri hızlı ve ucuz şekilde test etmek\nB) Son ürünü yayınlamak\nC) Renk paletini kesinleştirmek', 'A'),
 ('Prototipleme', E'Prototip kullanıcı testinde ne gözlemlenir?\nA) Kullanıcının görevi nasıl tamamladığı\nB) Sunucu hızı\nC) Kod kalitesi', 'A'),
 ('Prototipleme', E'Kağıt prototip hangi aşamada en faydalıdır?\nA) Erken fikir aşamasında\nB) Yayından hemen önce\nC) Bakım aşamasında', 'A'),

 ('Erişilebilirlik', E'Görsellere eklenen alternatif metin (alt text) kimin işine yarar?\nA) Ekran okuyucu kullananlar\nB) Sadece arama motorları\nC) Hiç kimse', 'A'),
 ('Erişilebilirlik', E'WCAG''ye göre normal metin için önerilen minimum kontrast oranı nedir?\nA) 2:1\nB) 4.5:1\nC) 10:1', 'B'),
 ('Erişilebilirlik', E'Bilgiyi sadece renkle vermek neden sorunludur?\nA) Renk körü kullanıcılar ayırt edemeyebilir\nB) Sayfa yavaşlar\nC) Yazdırılamaz', 'A'),

 ('Storybook', E'Storybook ne için kullanılır?\nA) Arayüz bileşenlerini ayrı ayrı geliştirmek ve belgelemek\nB) Veritabanı yönetmek\nC) Sunucu kurmak', 'A'),
 ('Storybook', E'Storybook''ta bir bileşenin tek bir durumunu gösteren örneğe ne denir?\nA) Story\nB) Page\nC) Module', 'A'),
 ('Storybook', E'Bileşen özelliklerini arayüzden canlı değiştirmeyi sağlayan özellik hangisidir?\nA) Controls (args)\nB) Webpack\nC) Router', 'A'),

 ('Deney tasarımı', E'A/B testinde kontrol grubu nedir?\nA) Değişikliği görmeyen grup\nB) Değişikliği gören grup\nC) Testi yöneten ekip', 'A'),
 ('Deney tasarımı', E'Bir deneyde aynı anda birçok değişkeni değiştirmenin sakıncası nedir?\nA) Sonucun hangi değişiklikten geldiği anlaşılmaz\nB) Test daha ucuz olur\nC) Hiçbir sakıncası yoktur', 'A'),
 ('Deney tasarımı', E'Deneye başlamadan önce ne belirlenmelidir?\nA) Hipotez ve başarı ölçütü\nB) Sadece tasarım rengi\nC) Sonucun ne çıkacağı', 'A'),

 ('İngilizce', E'"She ___ to school every day." boşluğa hangisi gelir?\nA) go\nB) goes\nC) going', 'B'),
 ('İngilizce', E'"Deadline" kelimesinin anlamı nedir?\nA) Son teslim tarihi\nB) Toplantı\nC) Maaş', 'A'),
 ('İngilizce', E'"I have lived here ___ 2020." boşluğa hangisi gelir?\nA) for\nB) since\nC) at', 'B');

-- 3) Eksik sınavları ekle (beceri adına göre; o becerinin çoktan seçmeli sınavı zaten varsa atlar)
DO $$
DECLARE
  r   RECORD;
  bid INT;
  tid INT;
BEGIN
  FOR r IN SELECT DISTINCT beceri_ad FROM tmp_sinav LOOP
    SELECT beceri_id INTO bid FROM beceriler WHERE ad = r.beceri_ad;
    IF bid IS NULL THEN
      RAISE NOTICE 'Beceri bulunamadı, atlandı: %', r.beceri_ad;
      CONTINUE;
    END IF;

    IF EXISTS (SELECT 1 FROM beceri_testleri t JOIN test_sorulari q ON q.test_id = t.test_id
               WHERE t.beceri_id = bid AND q.soru_metni LIKE '%' || chr(10) || 'A)%') THEN
      RAISE NOTICE 'Zaten sınavı var: %', r.beceri_ad;
      CONTINUE;
    END IF;

    INSERT INTO beceri_testleri (beceri_id, baraj_puani) VALUES (bid, 60) RETURNING test_id INTO tid;
    INSERT INTO test_sorulari (test_id, soru_metni, dogru_cevap)
      SELECT tid, soru_metni, dogru_cevap FROM tmp_sinav WHERE beceri_ad = r.beceri_ad;
    RAISE NOTICE 'Sınav eklendi: % (test_id=%)', r.beceri_ad, tid;
  END LOOP;
END $$;

-- 4) Yetenek Görevleri (açık uçlu, DeepSeek puanlar) yoksa ekle
DO $$
DECLARE bid INT; tid INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM test_sorulari WHERE soru_metni NOT LIKE '%' || chr(10) || 'A)%') THEN
    SELECT beceri_id INTO bid FROM beceriler WHERE ad = 'Kullanıcı araştırması';
    IF bid IS NOT NULL THEN
      INSERT INTO beceri_testleri (beceri_id, baraj_puani) VALUES (bid, 60) RETURNING test_id INTO tid;
      INSERT INTO test_sorulari (test_id, soru_metni, dogru_cevap) VALUES (tid,
        'Bir mobil bankacılık uygulamasında yeni kullanıcıların %40''ı hesap açma adımında ayrılıyor. İlk 3 adımda neyi değiştirirdin ve neden? Kısaca (5-8 cümle) anlat.',
        'İyi bir cevap: önce veriye/kullanıcıya bakmayı (analitik, görüşme) önerir; sürtünme noktalarını (gereksiz alan, belge yükleme, belirsiz adımlar) tanımlar; değişiklikleri önceliklendirir ve nasıl ölçeceğini söyler.');
    END IF;
    SELECT beceri_id INTO bid FROM beceriler WHERE ad = 'Spring Boot';
    IF bid IS NOT NULL THEN
      INSERT INTO beceri_testleri (beceri_id, baraj_puani) VALUES (bid, 60) RETURNING test_id INTO tid;
      INSERT INTO test_sorulari (test_id, soru_metni, dogru_cevap) VALUES (tid,
        'Bir kütüphane uygulaması için kitap ödünç alma sürecinin REST API uç noktalarını (URL + HTTP metodu) listele ve her birinin ne yaptığını bir cümleyle açıkla.',
        'İyi bir cevap: kitapları listeleme (GET /kitaplar), ödünç alma (POST /oduncler), iade (PATCH veya PUT), üyenin ödünçlerini listeleme gibi uç noktaları doğru HTTP metotları ve anlamlı URL isimleriyle verir.');
    END IF;
    RAISE NOTICE 'Yetenek görevleri eklendi';
  END IF;
END $$;

-- 5) Kontrol: her becerinin kaç sorusu var? "coktan_secmeli" sütunu 0 olan beceride "Sınav yok" görünür.
SELECT b.beceri_id, b.ad,
       COUNT(q.soru_id) FILTER (WHERE q.soru_metni LIKE '%' || chr(10) || 'A)%')     AS coktan_secmeli,
       COUNT(q.soru_id) FILTER (WHERE q.soru_metni NOT LIKE '%' || chr(10) || 'A)%') AS gorev
FROM beceriler b
LEFT JOIN beceri_testleri t ON t.beceri_id = b.beceri_id
LEFT JOIN test_sorulari q   ON q.test_id   = t.test_id
GROUP BY b.beceri_id, b.ad
ORDER BY b.beceri_id;
