import 'package:flutter/material.dart';
import '../core/tema.dart';
import 'bilesenler.dart';

/// İlan gereksinim türlerinin ekrandaki adları ve ikonları (sıra = gösterim sırası).
const gereksinimTurleri = <String, (String, IconData)>{
  'calisma_turu': ('Çalışma türü', Icons.badge_outlined),
  'calisma_sekli': ('Çalışma şekli', Icons.apartment_outlined),
  'deneyim': ('Deneyim', Icons.timeline_outlined),
  'egitim': ('Eğitim durumu', Icons.school_outlined),
  'bolum': ('Bölüm', Icons.menu_book_outlined),
  'dil': ('Yabancı dil', Icons.translate),
  'sertifika': ('Sertifika', Icons.workspace_premium_outlined),
  'diger': ('Diğer beklenti', Icons.more_horiz),
};

String _yazi(Map g) =>
    g['seviye'] != null ? '${g['deger']} · ${g['seviye']}' : '${g['deger']}';

/// İlan detayında gereksinimleri türlerine göre gruplayıp gösterir.
/// Zorunlu olanlar koyu yeşil, "tercih sebebi" olanlar soluk etiketle görünür.
class GereksinimListesi extends StatelessWidget {
  final List gereksinimler;
  const GereksinimListesi(this.gereksinimler, {super.key});

  @override
  Widget build(BuildContext context) {
    if (gereksinimler.isEmpty) return const SizedBox();
    final gruplar = <String, List>{};
    for (final g in gereksinimler) {
      gruplar.putIfAbsent('${g['tur']}', () => []).add(g);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final tur in gereksinimTurleri.keys)
        if (gruplar[tur] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(gereksinimTurleri[tur]!.$2,
                    size: 17, color: Renk.adacayiKoyu),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gereksinimTurleri[tur]!.$1,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Renk.soluk,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final g in gruplar[tur]!)
                          Etiket(
                            g['zorunlu_mu'] == false
                                ? '${_yazi(g)} · tercih'
                                : _yazi(g),
                            zemin: g['zorunlu_mu'] == false
                                ? const Color(0xFFF0EFE8)
                                : Renk.adacayi,
                            renk: g['zorunlu_mu'] == false
                                ? Renk.soluk
                                : Renk.yesil,
                          ),
                      ]),
                    ]),
              ),
            ]),
          ),
      const Text('“tercih” yazanlar zorunlu değil, tercih sebebidir.',
          style: TextStyle(fontSize: 11, color: Renk.soluk)),
    ]);
  }
}

/// Kartlarda kısa özet: çalışma türü · şekil · deneyim (örn. "Staj · Hibrit · Deneyim gerekmez")
String gereksinimOzeti(List gereksinimler) {
  final parca = <String>[];
  for (final tur in const ['calisma_turu', 'calisma_sekli', 'deneyim']) {
    final degerler = [
      for (final g in gereksinimler)
        if (g['tur'] == tur) '${g['deger']}'
    ];
    if (degerler.isNotEmpty) parca.add(degerler.join(' / '));
  }
  return parca.join(' · ');
}
