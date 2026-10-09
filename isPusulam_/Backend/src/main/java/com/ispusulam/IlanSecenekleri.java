package com.ispusulam;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * İlan oluştururken sunulan hazır seçenekler. Flutter bunları GET /api/ilanlar/secenekler ile alır,
 * yapay zekâ da öneri yaparken aynı listeleri kullanır. Listeye yeni seçenek eklemek için burayı düzenlemen yeterli.
 * Bölüm, dil ve sertifikada listede olmayan bir değer de yazılabilir.
 */
public final class IlanSecenekleri {
    private IlanSecenekleri() {}

    public static final List<String> EGITIM = List.of(
            "Lise", "Önlisans öğrencisi", "Önlisans mezunu", "Lisans öğrencisi", "Lisans mezunu",
            "Yüksek lisans", "Doktora");

    public static final List<String> DENEYIM = List.of(
            "Deneyim gerekmez (stajyer)", "0-1 yıl", "1-3 yıl", "3-5 yıl", "5+ yıl");

    public static final List<String> CALISMA_SEKLI = List.of("Ofisten", "Hibrit", "Uzaktan");

    public static final List<String> CALISMA_TURU = List.of(
            "Staj", "Uzun dönem staj", "Yarı zamanlı", "Tam zamanlı", "Proje bazlı / serbest");

    public static final List<String> BOLUM = List.of(
            "Bilgisayar Mühendisliği", "Yazılım Mühendisliği", "Elektrik-Elektronik Mühendisliği",
            "Endüstri Mühendisliği", "Yönetim Bilişim Sistemleri", "Bilgisayar Programcılığı",
            "Matematik", "İstatistik", "Fizik", "İşletme", "İktisat", "Grafik Tasarım",
            "Görsel İletişim Tasarımı", "Halkla İlişkiler", "Herhangi bir bölüm");

    public static final List<String> DIL = List.of(
            "İngilizce", "Almanca", "Fransızca", "İspanyolca", "İtalyanca", "Rusça", "Arapça",
            "Çince", "Japonca", "Korece", "Türkçe");

    public static final List<String> DIL_SEVIYE = List.of("A1", "A2", "B1", "B2", "C1", "C2", "Anadil");

    public static final List<String> SERTIFIKA = List.of(
            "AWS Certified Cloud Practitioner", "AWS Solutions Architect – Associate", "Microsoft Azure Fundamentals (AZ-900)",
            "Google Cloud Associate Cloud Engineer", "Oracle Certified Professional: Java SE", "Cisco CCNA",
            "CompTIA Security+", "ISTQB Foundation", "Professional Scrum Master (PSM I)", "PMP",
            "Google Data Analytics", "Google UX Design", "Google Analytics (GA4)", "Microsoft Office Specialist (MOS)",
            "TOEFL iBT", "IELTS", "YDS / YÖKDİL");

    /** Geçerli gereksinim türleri ve ekranda görünen adları */
    public static final Map<String, String> TURLER = new LinkedHashMap<>();
    static {
        TURLER.put("calisma_turu", "Çalışma türü");
        TURLER.put("calisma_sekli", "Çalışma şekli");
        TURLER.put("deneyim", "Deneyim");
        TURLER.put("egitim", "Eğitim durumu");
        TURLER.put("bolum", "Bölüm");
        TURLER.put("dil", "Yabancı dil");
        TURLER.put("sertifika", "Sertifika");
        TURLER.put("diger", "Diğer beklenti");
    }

    public static Map<String, Object> hepsi() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("egitim", EGITIM);
        m.put("deneyim", DENEYIM);
        m.put("calisma_sekli", CALISMA_SEKLI);
        m.put("calisma_turu", CALISMA_TURU);
        m.put("bolum", BOLUM);
        m.put("dil", DIL);
        m.put("dil_seviye", DIL_SEVIYE);
        m.put("sertifika", SERTIFIKA);
        m.put("turler", TURLER);
        m.put("min_aciklama", IlanController.MIN_ACIKLAMA);
        return m;
    } 
}