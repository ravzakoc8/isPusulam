import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../core/yardimci.dart';
import '../widgets/bilesenler.dart';
import '../widgets/ret_kutusu.dart';
import 'ana_sayfa.dart';
import 'mesajlar.dart';
import 'profil.dart';

/// İşverenin başvuru yönetimi: profil incele, mülakat planla, AI soruları al, kabul et veya GEREKÇELİ reddet.
class IsverenBasvurularEkrani extends StatefulWidget {
  const IsverenBasvurularEkrani({super.key});
  @override
  State<IsverenBasvurularEkrani> createState() =>
      _IsverenBasvurularEkraniState();
}

class _IsverenBasvurularEkraniState extends State<IsverenBasvurularEkrani> {
  int _anahtar = 0;
  void _yenile() => setState(() => _anahtar++);

  @override
  Widget build(BuildContext context) {
    return SayfaGovdesi(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BAŞVURU YÖNETİMİ', style: ustYazi(renk: Renk.kil)),
        const SizedBox(height: 6),
        Text('Başvurular',
            style: serif(MediaQuery.of(context).size.width >= 700 ? 46 : 34)),
        const SizedBox(height: 6),
        const Text('Her ret kararında adaya gerekçe iletilir.',
            style: TextStyle(color: Renk.soluk)),
        const SizedBox(height: 22),
        Yukle(
          key: ValueKey(_anahtar),
          getir: () => Api.get('/api/basvurular/isveren'),
          yap: (context, veri, yenile) {
            final liste = veri as List;
            if (liste.isEmpty)
              return const BosDurum('İlanlarına henüz başvuru gelmedi.');
            return Column(children: [
              for (final b in liste) _BasvuruKarti(b: b, yenile: _yenile)
            ]);
          },
        ),
      ]),
    );
  }
}

class _BasvuruKarti extends StatelessWidget {
  final Map b;
  final VoidCallback yenile;
  const _BasvuruKarti({required this.b, required this.yenile});

  /// Tarih + saat seçtirir, isteğe bağlı görüşme linki sorar ve mülakatı planlar.
  Future<void> _mulakatPlanla(BuildContext context) async {
    final bugun = DateTime.now();
    final gun = await showDatePicker(
        context: context,
        initialDate: bugun.add(const Duration(days: 3)),
        firstDate: bugun,
        lastDate: bugun.add(const Duration(days: 180)));
    if (gun == null || !context.mounted) return;
    final saat = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 14, minute: 30));
    if (saat == null || !context.mounted) return;

    final link = TextEditingController();
    final devam = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Renk.kart,
        title: Text('Görüşme bağlantısı', style: serif(20)),
        content: TextField(
            controller: link,
            decoration: const InputDecoration(
                hintText: 'Meet / Zoom linki (isteğe bağlı)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mülakatı planla')),
        ],
      ),
    );
    if (devam != true) return;

    try {
      final tarih =
          DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
      await Api.patch('/api/basvurular/${b['basvuru_id']}/mulakat',
          {'tarih': tarih.toIso8601String(), 'link': link.text.trim()});
      if (context.mounted)
        mesaj(context, 'Mülakat planlandı, adaya bildirim gitti');
      yenile();
    } on ApiHata catch (e) {
      if (context.mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  /// Adayın itirazla önerdiği tarihi kabul et -> tarih kesinleşir.
  Future<void> _oneriKabul(BuildContext context) async {
    try {
      await Api.patch('/api/basvurular/${b['basvuru_id']}/mulakat-oneri-kabul');
      if (context.mounted) mesaj(context, 'Adayın önerdiği tarih kabul edildi, mülakat kesinleşti');
      yenile();
    } on ApiHata catch (e) {
      if (context.mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  Future<void> _kabul(BuildContext context) async {
    try {
      await Api.patch('/api/basvurular/${b['basvuru_id']}/kabul');
      if (context.mounted) mesaj(context, 'Aday kabul edildi');
      yenile();
    } on ApiHata catch (e) {
      if (context.mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  /// 1) gerekçe kutucuğunu aç (yazmadan geçilemez)  2) sunucuya gönder  3) sunucu adaya bildirim düşürür
  Future<void> _ret(BuildContext context) async {
    final asama = b['asama'] == 'mulakat' ? 'mülakat' : 'başvuru değerlendirme';
    final gerekce =
        await retGerekcesiIste(context, aday: b['aday_ad'], asama: asama);
    if (gerekce == null) return; // vazgeçti
    try {
      await Api.patch(
          '/api/basvurular/${b['basvuru_id']}/ret', {'gerekce': gerekce});
      if (context.mounted) mesaj(context, 'Ret gerekçesi adaya bildirildi');
      yenile();
    } on ApiHata catch (e) {
      if (context.mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  /// Kayıtlı AI mülakat sorularını gösterir; hiç yoksa (veya yeniden = true ise) yapay zekâdan üretir.
  Future<void> _aiSorular(BuildContext context, {bool yeniden = false}) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: Renk.yesil)));
    try {
      final j = await Api.post('/api/basvurular/${b['basvuru_id']}/ai-sorular',
          {'yeniden': yeniden});
      if (!context.mounted) return;
      Navigator.pop(context); // yükleniyor penceresini kapat
      final sorular = List<String>.from(j['sorular']);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Renk.kart,
          title: Text('Önerilen mülakat soruları', style: serif(20)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sorular.length; i++)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text('${i + 1}. ${sorular[i]}',
                              style: const TextStyle(height: 1.4))),
                  ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _aiSorular(context, yeniden: true);
              },
              child: const Text('Yeniden üret'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat')),
          ],
        ),
      );
    } on ApiHata catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      mesaj(context, e.mesaj, hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durum = b['durum'] as String;
    final md = b['mulakat_durumu'];
    final sonuclandi = durum == 'ret' || durum == 'kabul';

    return Kart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(b['aday_ad'], boyut: 46),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(b['aday_ad'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                if (b['unvan'] != null)
                  Text(b['unvan'],
                      style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                Text(b['ilan_baslik'],
                    style: const TextStyle(fontSize: 12, color: Renk.soluk)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('%${b['eslesme']} eşleşme',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            DurumEtiketi(durum, mulakatDurumu: b['mulakat_durumu']),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
          Text('Başvuru: ${zamanOnce(b['basvuru_tarihi'])}',
              style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => mesajlasmaAc(context, kisiId: (b['aday_id'] as num).toInt(), basvuruId: (b['basvuru_id'] as num).toInt()),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Mesaj'),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                await adayProfiliAc(context, (b['aday_id'] as num).toInt());
              } catch (_) {}
            },
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Profili incele'),
          ),
        ]),
        if (durum == 'mulakat_planlandi' && b['mulakat_tarihi'] != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: md == 'aday_itiraz' ? Renk.kilAcik : Renk.adacayi,
                borderRadius: BorderRadius.circular(12),
                border: md == 'onaylandi' ? Border.all(color: Renk.adacayiKoyu) : null),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(md == 'onaylandi' ? Icons.event_available : (md == 'aday_itiraz' ? Icons.event_busy_outlined : Icons.event_outlined),
                    size: 18, color: md == 'aday_itiraz' ? Renk.kil : Renk.yesil),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Mülakat: ${tarihSaat(b['mulakat_tarihi'])}',
                        style: TextStyle(fontSize: 13, fontWeight: md == 'onaylandi' ? FontWeight.w700 : FontWeight.w400))),
                Etiket(
                    md == 'onaylandi'
                        ? 'Onaylandı'
                        : (md == 'aday_itiraz' ? 'Aday itiraz etti' : 'Aday onayı bekleniyor'),
                    ikon: md == 'onaylandi' ? Icons.check : null,
                    zemin: Colors.white,
                    renk: md == 'onaylandi' ? Renk.yesil : Renk.kil),
              ]),
              if (md == 'aday_itiraz') ...[
                const SizedBox(height: 8),
                if (b['mulakat_itiraz_notu'] != null)
                  Text('Adayın sebebi: ${b['mulakat_itiraz_notu']}', style: const TextStyle(fontSize: 13, height: 1.4)),
                if (b['mulakat_onerilen_tarih'] != null)
                  Text('Adayın önerdiği tarih: ${tarihSaat(b['mulakat_onerilen_tarih'])}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (b['mulakat_onerilen_tarih'] != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                      onPressed: () => _oneriKabul(context),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Önerilen tarihi kabul et'),
                    ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => _mulakatPlanla(context),
                    child: const Text('Yeni tarih öner'),
                  ),
                ]),
              ],
            ]),
          ),
        ],
        if (durum == 'ret' && b['ret_gerekcesi'] != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Renk.kilAcik, borderRadius: BorderRadius.circular(12)),
            child: Text(
                'Gerekçe (${b['asama'] == 'mulakat' ? 'mülakat' : 'başvuru'} aşaması): ${b['ret_gerekcesi']}',
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
        if (!sonuclandi) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (durum == 'basvuruldu')
              FilledButton(
                  onPressed: () => _mulakatPlanla(context),
                  child: const Text('Mülakata davet et')),
            if (durum == 'mulakat_planlandi') ...[
              if (md == 'onaylandi')
                FilledButton(onPressed: () => _kabul(context), child: const Text('Kabul et'))
              else
                const Tooltip(
                  message: 'Kabul için mülakat tarihinin iki tarafça onaylanması gerekir',
                  child: FilledButton(onPressed: null, child: Text('Kabul et')),
                ),
              OutlinedButton(
                  onPressed: () => _mulakatPlanla(context),
                  child: const Text('Tarihi değiştir')),
              OutlinedButton.icon(
                onPressed: () => _aiSorular(context),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('AI mülakat soruları'),
              ),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Renk.kil,
                  side: const BorderSide(color: Renk.kil)),
              onPressed: () => _ret(context),
              child: const Text('Reddet'),
            ),
          ]),
        ],
      ]),
    );
  }
}
