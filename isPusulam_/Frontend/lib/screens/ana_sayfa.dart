import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/oturum.dart';
import '../core/tema.dart';
import '../core/yardimci.dart';
import '../widgets/bilesenler.dart';
import 'isler.dart';
import 'profil.dart';

/// Başvuru durumunun Türkçe yazısı ve rengi.
/// Mülakat aşamasında mülakat tarihinin durumu da yazıya yansır (onay bekleniyor / onaylandı / itiraz edildi).
String durumYazisi(String d, [String? mulakatDurumu]) => switch (d) {
      'basvuruldu' => 'Değerlendiriliyor',
      'mulakat_planlandi' => switch (mulakatDurumu) {
          'onaylandi' => 'Mülakat onaylandı',
          'aday_itiraz' => 'Mülakat: yeni tarih istendi',
          'planlandi' => 'Mülakat: onay bekleniyor',
          _ => 'Mülakat aşamasında',
        },
      'kabul' => 'Kabul edildi',
      'ret' => 'Kabul edilmedi',
      _ => d,
    };

class DurumEtiketi extends StatelessWidget {
  final String durum;
  final String? mulakatDurumu;
  const DurumEtiketi(this.durum, {super.key, this.mulakatDurumu});
  @override
  Widget build(BuildContext context) {
    final ret = durum == 'ret';
    final itiraz =
        durum == 'mulakat_planlandi' && mulakatDurumu == 'aday_itiraz';
    final onayli = durum == 'kabul' ||
        (durum == 'mulakat_planlandi' && mulakatDurumu == 'onaylandi');
    return Etiket(durumYazisi(durum, mulakatDurumu),
        zemin: ret || itiraz ? Renk.kilAcik : Renk.adacayi,
        renk: ret || itiraz ? Renk.kil : Renk.yesil,
        ikon: ret
            ? Icons.close
            : (onayli
                ? Icons.check
                : (itiraz
                    ? Icons.report_gmailerrorred_outlined
                    : Icons.schedule)));
  }
}

// =====================================================================
//  ADAY ANA SAYFASI
// =====================================================================
class AnaSayfaAday extends StatelessWidget {
  final void Function(int)
      gec; // 1 Şirketler, 2 İşler, 3 Becerilerim, 4 Başvurularım
  const AnaSayfaAday({super.key, required this.gec});

  @override
  Widget build(BuildContext context) {
    final ad = context.watch<Oturum>().ad;
    return SayfaGovdesi(
      child: Yukle(
        getir: () => Future.wait([
          Api.get('/api/profil'),
          Api.get('/api/ilanlar'),
          Api.get('/api/basvurular/benim')
        ]),
        yap: (context, veri, yenile) {
          final profil = Map<String, dynamic>.from(veri[0]);
          final ilanlar = (veri[1] as List).take(3).toList();
          final basvurular = (veri[2] as List).take(3).toList();
          final genis = MediaQuery.of(context).size.width >= 1000;

          final giz = {
                'herkese_acik': 'Profilin herkese açık',
                'sadece_isverenler':
                    'Profilin yalnızca doğrulanmış işverenlere açık',
                'gizli': 'Profilin gizli'
              }[profil['profil_gizliligi']] ??
              '';

          final sol =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.circle, size: 8, color: Renk.kil),
              const SizedBox(width: 8),
              Text(bugunYazisi(), style: ustYazi(renk: Renk.kil)),
            ]),
            const SizedBox(height: 10),
            Text('Hoş geldin $ad', style: serif(genis ? 48 : 34)),
            const SizedBox(height: 8),
            const Text('Bugün senin için neler var, birlikte bakalım.',
                style: TextStyle(color: Renk.soluk)),
            const SizedBox(height: 10),
            Etiket(giz, ikon: Icons.lock_outline),
            const SizedBox(height: 28),
            Row(children: [
              Text('Sana uygun fırsatlar', style: serif(26)),
              const Spacer(),
              TextButton(
                  onPressed: () => gec(2), child: const Text('Tümünü gör')),
            ]),
            const SizedBox(height: 10),
            if (ilanlar.isEmpty) const BosDurum('Şu an açık ilan yok.'),
            for (final i in ilanlar) IlanKarti(ilan: i, tikla: () => gec(2)),
            const SizedBox(height: 16),
            Row(children: [
              Text('Başvurularım', style: serif(26)),
              const Spacer(),
              TextButton(
                  onPressed: () => gec(4), child: const Text('Tümünü gör')),
            ]),
            const SizedBox(height: 10),
            if (basvurular.isEmpty)
              const BosDurum(
                  'Henüz başvurun yok. "İşler" sayfasından başlayabilirsin.'),
            for (final b in basvurular)
              Kart(
                tikla: () => gec(4),
                child: Row(children: [
                  Avatar(b['sirket_adi'], boyut: 40),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(b['ilan_baslik'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(b['sirket_adi'],
                            style: const TextStyle(
                                fontSize: 12, color: Renk.soluk)),
                      ])),
                  DurumEtiketi(b['durum'], mulakatDurumu: b['mulakat_durumu']),
                ]),
              ),
          ]);

          final sag = _ProfilKarti(
              profil: profil, becerilerSayfasi: () => gec(3), yenile: yenile);
          return genis
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: sol),
                  const SizedBox(width: 28),
                  SizedBox(width: 340, child: sag)
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [sol, const SizedBox(height: 16), sag]);
        },
      ),
    );
  }
}

/// Sağdaki profil kartı: ad, unvan, doğrulama durumu, tamamlanma yüzdesi ve beceriler.
class _ProfilKarti extends StatelessWidget {
  final Map<String, dynamic> profil;
  final VoidCallback becerilerSayfasi, yenile;
  const _ProfilKarti(
      {required this.profil,
      required this.becerilerSayfasi,
      required this.yenile});

  @override
  Widget build(BuildContext context) {
    final adSoyad = '${profil['ad']} ${profil['soyad']}';
    final dogrulanan = (profil['dogrulanan_sayisi'] ?? 0) as num;
    final tamam = (profil['tamamlanma'] ?? 0) as num;
    final beceriler = (profil['becerileri'] ?? []) as List;

    return Container(
      decoration: BoxDecoration(
          color: Renk.kart,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Renk.cizgi)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Üst yeşil şerit
        Container(height: 84, color: Renk.adacayi),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Transform.translate(
              offset: const Offset(0, -26),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Renk.kart,
                      borderRadius: BorderRadius.circular(22)),
                  child: Avatar(adSoyad, boyut: 60),
                ),
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: () async {
                    await profilDuzenleAc(context);
                    yenile();
                  },
                  child:
                      const Text('Profil gör', style: TextStyle(fontSize: 12)),
                ),
              ]),
            ),
            Transform.translate(
              offset: const Offset(0, -14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(adSoyad, style: serif(24)),
                    const SizedBox(height: 4),
                    Text(profil['unvan'] ?? 'Unvanını profilinden ekle',
                        style:
                            const TextStyle(color: Renk.soluk, fontSize: 13)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Renk.adacayi, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.shield_outlined, color: Renk.yesil, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          dogrulanan > 0
                              ? 'Doğrulanmış profil'
                              : 'Profilini doğrula',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                          dogrulanan > 0
                              ? '$dogrulanan beceri kanıtı onaylandı'
                              : 'Henüz doğrulanmış becerin yok',
                          style:
                              const TextStyle(color: Renk.soluk, fontSize: 12)),
                    ])),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Profil tamamlanma',
                  style: TextStyle(fontSize: 12, color: Renk.soluk)),
              const Spacer(),
              Text('%$tamam',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: tamam / 100,
                  minHeight: 7,
                  color: Renk.adacayiKoyu,
                  backgroundColor: Renk.adacayi),
            ),
            const SizedBox(height: 14),
            BeceriRozetleri(beceriler),
            const SizedBox(height: 14),
            Center(
                child: TextButton(
                    onPressed: becerilerSayfasi,
                    child: const Text('Kanıtlarını ve becerilerini yönet ↗',
                        style: TextStyle(color: Renk.yesil)))),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
//  İŞVEREN ANA SAYFASI
// =====================================================================
class AnaSayfaIsveren extends StatelessWidget {
  final void Function(int) gec; // 1 Şirketler, 2 İlanlarım, 3 Başvurular
  const AnaSayfaIsveren({super.key, required this.gec});

  @override
  Widget build(BuildContext context) {
    return SayfaGovdesi(
      child: Yukle(
        getir: () => Future.wait([
          Api.get('/api/profil'),
          Api.get('/api/ilanlar/benim'),
          Api.get('/api/basvurular/isveren')
        ]),
        yap: (context, veri, yenile) {
          final profil = Map<String, dynamic>.from(veri[0]);
          final ilanlar = veri[1] as List;
          final basvurular = veri[2] as List;
          final genis = MediaQuery.of(context).size.width >= 1000;

          final aktif = ilanlar.where((i) => i['durum'] == 'aktif').length;
          final bekleyen =
              basvurular.where((b) => b['durum'] == 'basvuruldu').length;
          final mulakat =
              basvurular.where((b) => b['durum'] == 'mulakat_planlandi').length;
          final itirazlar = basvurular
              .where((b) =>
                  b['durum'] == 'mulakat_planlandi' &&
                  b['mulakat_durumu'] == 'aday_itiraz')
              .length;

          final sol =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.circle, size: 8, color: Renk.kil),
              const SizedBox(width: 8),
              Text(bugunYazisi(), style: ustYazi(renk: Renk.kil)),
            ]),
            const SizedBox(height: 10),
            Text('Hoş geldin ${profil['ad']}', style: serif(genis ? 48 : 34)),
            const SizedBox(height: 8),
            const Text('İlanlarının ve başvuruların durumu burada.',
                style: TextStyle(color: Renk.soluk)),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth >= 600 ? (c.maxWidth - 28) / 3 : c.maxWidth;
              Widget sayac(IconData ikon, int n, String yazi, int sayfa) =>
                  SizedBox(
                    width: w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => gec(sayfa),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Renk.adacayi,
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(ikon, color: Renk.yesil, size: 20),
                              const SizedBox(height: 10),
                              Text('$n', style: serif(30)),
                              Text(yazi,
                                  style: const TextStyle(
                                      color: Renk.soluk, fontSize: 12)),
                            ]),
                      ),
                    ),
                  );
              return Wrap(spacing: 14, runSpacing: 14, children: [
                sayac(Icons.work_outline, aktif, 'aktif ilan', 2),
                sayac(Icons.hourglass_empty, bekleyen,
                    'değerlendirme bekleyen başvuru', 3),
                sayac(
                    Icons.event_available_outlined,
                    mulakat,
                    itirazlar > 0
                        ? 'mülakat aşamasında · $itirazlar itiraz'
                        : 'mülakat aşamasında',
                    3),
              ]);
            }),
            const SizedBox(height: 28),
            Row(children: [
              Text('Son başvurular', style: serif(26)),
              const Spacer(),
              TextButton(
                  onPressed: () => gec(3), child: const Text('Tümünü gör')),
            ]),
            const SizedBox(height: 10),
            if (basvurular.isEmpty)
              const BosDurum('İlanlarına henüz başvuru gelmedi.'),
            for (final b in basvurular.take(4))
              Kart(
                tikla: () => gec(3),
                child: Row(children: [
                  Avatar(b['aday_ad'], boyut: 40),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(b['aday_ad'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(b['ilan_baslik'],
                            style: const TextStyle(
                                fontSize: 12, color: Renk.soluk)),
                      ])),
                  Text('%${b['eslesme']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  DurumEtiketi(b['durum'], mulakatDurumu: b['mulakat_durumu']),
                ]),
              ),
          ]);

          final sag = Kart(
            ic: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Avatar(profil['sirket_adi'] ?? '', boyut: 56),
              const SizedBox(height: 14),
              Text(profil['sirket_adi'] ?? '', style: serif(24)),
              const SizedBox(height: 10),
              if (profil['dogrulanmis'] == true)
                const Etiket('Doğrulanmış işveren',
                    ikon: Icons.verified_outlined)
              else
                const Etiket('Doğrulama bekliyor',
                    zemin: Renk.kilAcik, renk: Renk.kil),
              const SizedBox(height: 18),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => gec(2),
                      child: const Text('İlan yayınla'))),
            ]),
          );
          return genis
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: sol),
                  const SizedBox(width: 28),
                  SizedBox(width: 340, child: sag)
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [sol, const SizedBox(height: 16), sag]);
        },
      ),
    );
  }
}
