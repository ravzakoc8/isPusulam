import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../core/yardimci.dart';
import '../widgets/bilesenler.dart';
import 'ana_sayfa.dart';
import 'mesajlar.dart';

/// Adayın başvuruları: durum, ret gerekçesi (şeffaf iş takibi) ve mülakat tarihi.
class BasvurularimEkrani extends StatelessWidget {
  const BasvurularimEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return SayfaGovdesi(
      child: Yukle(
        getir: () => Api.get('/api/basvurular/benim'),
        yap: (context, veri, yenile) {
          final liste = veri as List;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ŞEFFAF İŞ TAKİBİ', style: ustYazi(renk: Renk.kil)),
            const SizedBox(height: 6),
            Text('Başvurularım', style: serif(MediaQuery.of(context).size.width >= 700 ? 44 : 34)),
            const SizedBox(height: 6),
            const Text('Başvurularının hangi aşamada olduğunu ve varsa sebebini burada gör.', style: TextStyle(color: Renk.soluk)),
            const SizedBox(height: 22),
            if (liste.isEmpty) const BosDurum('Henüz başvurun yok. "İşler" sayfasından başlayabilirsin.'),
            for (final b in liste) _BasvuruKarti(b: b, yenile: yenile),
          ]);
        },
      ),
    );
  }
}

class _BasvuruKarti extends StatelessWidget {
  final Map b;
  final VoidCallback yenile;
  const _BasvuruKarti({required this.b, required this.yenile});

  Future<void> _onayla(BuildContext context) async {
    try {
      await Api.patch('/api/basvurular/${b['basvuru_id']}/mulakat-onay');
      if (context.mounted) mesaj(context, 'Mülakat tarihini onayladın. İşverene bildirim gitti.');
      yenile();
    } on ApiHata catch (e) {
      if (context.mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  /// Tarihe itiraz: sebep zorunlu, yeni tarih önerisi isteğe bağlı.
  Future<void> _itiraz(BuildContext context) async {
    final sonuc = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _ItirazKutusu());
    if (sonuc == null || !context.mounted) return;
    try {
      await Api.patch('/api/basvurular/${b['basvuru_id']}/mulakat-itiraz', sonuc);
      if (context.mounted) mesaj(context, 'İtirazın işverene iletildi');
      yenile();
    } on ApiHata catch (e) {
      if (context.mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ret = b['durum'] == 'ret';
    final mulakatVar = b['mulakat_tarihi'] != null;
    final md = b['mulakat_durumu'];
    final onayli = md == 'onaylandi';
    final itirazda = md == 'aday_itiraz';

    return Kart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(b['sirket_adi'], boyut: 44),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b['ilan_baslik'], style: serif(20)),
            Text(b['sirket_adi'], style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          DurumEtiketi(b['durum'], mulakatDurumu: md),
          const Spacer(),
          Text(zamanOnce(b['basvuru_tarihi']), style: const TextStyle(fontSize: 12, color: Renk.soluk)),
        ]),
        // Mülakat bilgisi (kabul veya ret verilmediyse)
        if (mulakatVar && b['durum'] == 'mulakat_planlandi') ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: itirazda ? Renk.kilAcik : Renk.adacayi,
              borderRadius: BorderRadius.circular(14),
              border: onayli ? Border.all(color: Renk.adacayiKoyu) : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(onayli ? Icons.event_available : (itirazda ? Icons.event_busy_outlined : Icons.event_outlined),
                    color: itirazda ? Renk.kil : Renk.yesil, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    onayli ? 'Mülakat tarihi onaylandı' : (itirazda ? 'Tarihe itiraz ettin' : '15 dakikalık mülakat daveti'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (onayli) const Etiket('Onaylandı', ikon: Icons.check, zemin: Colors.white),
              ]),
              const SizedBox(height: 6),
              Text('${onayli ? 'Kesin tarih' : 'İşverenin önerdiği tarih'}: ${tarihSaat(b['mulakat_tarihi'])}',
                  style: TextStyle(fontWeight: onayli ? FontWeight.w700 : FontWeight.w400)),
              if (b['gorusme_linki'] != null && '${b['gorusme_linki']}'.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText('Görüşme bağlantısı: ${b['gorusme_linki']}', style: const TextStyle(fontSize: 13))),
              if (itirazda) ...[
                const SizedBox(height: 6),
                if (b['mulakat_itiraz_notu'] != null) Text('Sebebin: ${b['mulakat_itiraz_notu']}', style: const TextStyle(fontSize: 13, height: 1.4)),
                if (b['mulakat_onerilen_tarih'] != null)
                  Text('Önerdiğin tarih: ${tarihSaat(b['mulakat_onerilen_tarih'])}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('İşverenin cevabı bekleniyor. Yeni tarih önerilirse bildirim alacaksın.',
                    style: TextStyle(fontSize: 12, color: Renk.soluk)),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (!onayli && !itirazda)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => _onayla(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Tarihi onayla'),
                  ),
                if (!itirazda)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: Renk.kil),
                    onPressed: () => _itiraz(context),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: Text(onayli ? 'Katılamıyorum, tarih değişsin' : 'İtiraz et / başka tarih öner'),
                  ),
              ]),
            ]),
          ),
        ],
        // Ret gerekçesi
        if (ret && b['ret_gerekcesi'] != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Renk.kilAcik, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b['asama'] == 'mulakat' ? 'Ret gerekçesi (mülakat aşaması)' : 'Ret gerekçesi (başvuru aşaması)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.kil)),
              const SizedBox(height: 4),
              Text(b['ret_gerekcesi'], style: const TextStyle(height: 1.45)),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => mesajlasmaAc(context, kisiId: (b['isveren_id'] as num).toInt(), basvuruId: (b['basvuru_id'] as num).toInt()),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('İşverene mesaj yaz'),
          ),
        ),
      ]),
    );
  }
}

/// Adayın mülakat tarihine itiraz penceresi: sebep (zorunlu) + isteğe bağlı yeni tarih önerisi.
class _ItirazKutusu extends StatefulWidget {
  const _ItirazKutusu();
  @override
  State<_ItirazKutusu> createState() => _ItirazKutusuState();
}

class _ItirazKutusuState extends State<_ItirazKutusu> {
  final _neden = TextEditingController();
  DateTime? _oneri;
  String? _hata;

  static const _hazir = [
    'O saatte dersim/sınavım var.',
    'O gün şehir dışında olacağım.',
    'Başka bir mülakatım var.',
  ];

  @override
  void dispose() {
    _neden.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final bugun = DateTime.now();
    final gun = await showDatePicker(
        context: context,
        initialDate: _oneri ?? bugun.add(const Duration(days: 2)),
        firstDate: bugun,
        lastDate: bugun.add(const Duration(days: 180)));
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 14, minute: 0));
    if (saat == null) return;
    setState(() => _oneri = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Renk.kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Mülakat tarihine itiraz', style: serif(22)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('İşveren itirazını ve önerdiğin tarihi görecek; önerini kabul edebilir ya da yeni bir tarih belirleyebilir.',
                style: TextStyle(color: Renk.soluk, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: _neden,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(hintText: 'Neden uygun değil?', errorText: _hata),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in _hazir)
                ActionChip(label: Text(h, style: const TextStyle(fontSize: 11)), onPressed: () => setState(() => _neden.text = h)),
            ]),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _tarihSec,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_oneri == null ? 'Uygun olduğum tarihi öner (isteğe bağlı)' : 'Önerim: ${tarihSaat(_oneri!.toIso8601String())}'),
            ),
            if (_oneri != null)
              TextButton(onPressed: () => setState(() => _oneri = null), child: const Text('Tarih önerisini kaldır')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Renk.kil),
          onPressed: () {
            if (_neden.text.trim().length < 5) {
              setState(() => _hata = 'İtiraz sebebini yaz (en az 5 karakter)');
              return;
            }
            Navigator.pop(context, {
              'neden': _neden.text.trim(),
              if (_oneri != null) 'onerilen_tarih': _oneri!.toIso8601String(),
            });
          },
          child: const Text('İtirazı gönder'),
        ),
      ],
    );
  }
}
