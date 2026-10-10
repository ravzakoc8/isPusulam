import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/oturum.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';
import '../widgets/gereksinimler.dart';

/// Adayın "İşler" sayfası: sol tarafta ilan listesi, sağ tarafta seçili ilanın detayı (telefonda alttan açılan pencere).
class IslerEkrani extends StatefulWidget {
  final String baslangicArama;
  const IslerEkrani({super.key, this.baslangicArama = ''});
  @override
  State<IslerEkrani> createState() => _IslerEkraniState();
}

class _IslerEkraniState extends State<IslerEkrani> {
  late final TextEditingController _arama;
  List<dynamic> _ilanlar = [];
  bool _yukleniyor = true;
  String? _hata;
  int? _seciliId;

  @override
  void initState() {
    super.initState();
    _arama = TextEditingController(text: widget.baslangicArama);
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final j = await Api.get(
          '/api/ilanlar?q=${Uri.encodeQueryComponent(_arama.text.trim())}');
      if (!mounted) return;
      setState(() {
        _ilanlar = j;
        _yukleniyor = false;
        _hata = null;
        // seçili ilan listede yoksa ilkini seç
        if (_ilanlar.isNotEmpty &&
            !_ilanlar.any((i) => i['ilan_id'] == _seciliId))
          _seciliId = _ilanlar.first['ilan_id'];
      });
    } on ApiHata catch (e) {
      if (mounted)
        setState(() {
          _hata = e.mesaj;
          _yukleniyor = false;
        });
    }
  }

  Future<void> _basvur(Map ilan) async {
    try {
      await Api.post('/api/ilanlar/${ilan['ilan_id']}/basvur');
      if (mounted)
        mesaj(context,
            'Başvurun gönderildi. Durumunu "Başvurularım" sayfasından takip edebilirsin.');
      await _yukle();
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  void _detayAc(Map ilan) {
    setState(() => _seciliId = ilan['ilan_id']);
    final genis = MediaQuery.of(context).size.width >= 1000;
    if (genis) return; // geniş ekranda sağ panel zaten görünüyor
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Renk.krem,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, kaydirma) => SingleChildScrollView(
          controller: kaydirma,
          padding: const EdgeInsets.all(20),
          child: IlanDetay(
              ilan: ilan,
              basvur: () async {
                Navigator.pop(ctx);
                await _basvur(ilan);
              }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = context.watch<Oturum>().ad;
    final genis = MediaQuery.of(context).size.width >= 1000;
    final enIyi =
        _ilanlar.isEmpty ? 0 : (_ilanlar.first['eslesme'] ?? 0) as int;
    Map? secili;
    for (final i in _ilanlar) {
      if (i['ilan_id'] == _seciliId) secili = i;
    }

    final liste =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${ad.toUpperCase()} İÇİN SEÇİLDİ', style: ustYazi(renk: Renk.kil)),
      const SizedBox(height: 6),
      Text('İşler', style: serif(genis ? 48 : 36)),
      const SizedBox(height: 6),
      const Text('Unvanı değil, birlikte nasıl çalışacağınızı gör.',
          style: TextStyle(color: Renk.soluk)),
      const SizedBox(height: 20),
      // Özet kartı
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Renk.adacayi, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('NET İHTİYAÇLARLA EŞLEŞ',
                    style: ustYazi(renk: Renk.yesil)),
                const SizedBox(height: 8),
                Text('Sana uygun fırsatlar, açıkça anlatılmış.',
                    style: serif(genis ? 28 : 22)),
                const SizedBox(height: 8),
                const Text(
                    'Her ilanda aranan becerileri ve süreci net olarak görebilirsin.',
                    style: TextStyle(color: Renk.soluk, fontSize: 13)),
              ])),
          const SizedBox(width: 12),
          YuzdeHalka(enIyi, boyut: 68),
        ]),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _arama,
        decoration: InputDecoration(
          hintText: 'Beceri, araç veya şirket ara...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward), onPressed: _yukle),
        ),
        onSubmitted: (_) => _yukle(),
      ),
      const SizedBox(height: 16),
      if (_yukleniyor)
        const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: Renk.yesil)))
      else if (_hata != null)
        Center(child: Text(_hata!))
      else if (_ilanlar.isEmpty)
        const BosDurum('Aradığın kriterlere uygun açık ilan yok.')
      else
        for (final i in _ilanlar)
          IlanKarti(
              ilan: i,
              secili: i['ilan_id'] == _seciliId,
              tikla: () => _detayAc(i)),
    ]);

    return SayfaGovdesi(
      child: genis
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: liste),
              const SizedBox(width: 24),
              SizedBox(
                width: 360,
                child: secili == null
                    ? const SizedBox()
                    : Kart(
                        ic: const EdgeInsets.all(22),
                        child: IlanDetay(
                            key: ValueKey(_seciliId),
                            ilan: secili!,
                            basvur: () => _basvur(secili!))),
              ),
            ])
          : liste,
    );
  }
}

/// Listedeki tek ilan satırı (ana sayfada da kullanılır).
class IlanKarti extends StatelessWidget {
  final Map ilan;
  final bool secili;
  final VoidCallback tikla;
  const IlanKarti(
      {super.key,
      required this.ilan,
      required this.tikla,
      this.secili = false});

  @override
  Widget build(BuildContext context) {
    final kriterler = (ilan['kriterler'] ?? []) as List;
    final eslesme = ilan['eslesme'];
    return Kart(
      tikla: tikla,
      kenar: secili ? Renk.kil : Renk.cizgi,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(ilan['sirket_adi'] ?? '', boyut: 46),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(ilan['sirket_adi'] ?? '',
                          style:
                              const TextStyle(fontSize: 12, color: Renk.soluk)),
                      if (ilan['dogrulanmis'] == true)
                        const Etiket('Doğrulanmış',
                            ikon: Icons.verified_outlined),
                    ]),
                const SizedBox(height: 4),
                Text(ilan['baslik'], style: serif(22)),
                if (ilan['konum'] != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: Renk.soluk),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(ilan['konum'],
                            style: const TextStyle(
                                fontSize: 12, color: Renk.soluk))),
                  ]),
                ],
                if (gereksinimOzeti((ilan['gereksinimler'] ?? []) as List)
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.work_history_outlined,
                        size: 14, color: Renk.soluk),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(
                            gereksinimOzeti(
                                (ilan['gereksinimler'] ?? []) as List),
                            style: const TextStyle(
                                fontSize: 12, color: Renk.soluk))),
                  ]),
                ],
              ])),
          if (eslesme != null)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('SANA UYGUNLUK', style: ustYazi()),
                const SizedBox(height: 2),
                Text('%$eslesme eşleşme',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              for (final k in kriterler)
                Etiket(k['ad'],
                    zemin: const Color(0xFFF0EFE8), renk: Renk.yazi),
            ]),
          ),
          if (ilan['basvurdum'] == true)
            const Etiket('Başvurdun', ikon: Icons.check)
          else
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: tikla,
              child: const Text('İncele →'),
            ),
        ]),
      ]),
    );
  }
}

/// Sağdaki / alttan açılan ilan detayı: net ihtiyaç tanımı ve "Başvuruyu başlat".
class IlanDetay extends StatefulWidget {
  final Map ilan;
  final Future<void> Function() basvur;
  const IlanDetay({super.key, required this.ilan, required this.basvur});
  @override
  State<IlanDetay> createState() => _IlanDetayState();
}

class _IlanDetayState extends State<IlanDetay> {
  bool _bekliyor = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.ilan;
    final kriterler = (i['kriterler'] ?? []) as List;
    final gereksinimler = (i['gereksinimler'] ?? []) as List;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Avatar(i['sirket_adi'] ?? '', boyut: 44),
        const Spacer(),
        if (i['dogrulanmis'] == true)
          const Etiket('İşveren doğrulandı', ikon: Icons.verified_outlined),
      ]),
      const SizedBox(height: 14),
      Text(i['baslik'], style: serif(28)),
      const SizedBox(height: 4),
      Text(i['sirket_adi'] ?? '', style: const TextStyle(color: Renk.soluk)),
      if (i['konum'] != null)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(i['konum'],
                style: const TextStyle(color: Renk.soluk, fontSize: 13))),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Renk.adacayi, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('İHTİYAÇLARIN NET TANIMI', style: ustYazi(renk: Renk.yesil)),
          const SizedBox(height: 8),
          Text(i['aciklama'] ?? '', style: const TextStyle(height: 1.55)),
        ]),
      ),
      if (gereksinimler.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Aranan nitelikler', style: serif(17)),
        const SizedBox(height: 10),
        GereksinimListesi(gereksinimler),
      ],
      if (kriterler.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Aranan beceriler', style: serif(17)),
        const SizedBox(height: 8),
        for (final k in kriterler)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  size: 18, color: Renk.adacayiKoyu),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      '${k['ad']} · ${_seviyeYazi(k['seviye'])}${k['zorunlu_mu'] == true ? ' · zorunlu' : ' · tercih'}',
                      style: const TextStyle(fontSize: 13))),
            ]),
          ),
      ],
      const SizedBox(height: 12),
      const _Madde('15 dakikalık mülakat aşaması vardır'),
      const _Madde('Kabul edilmezsen gerekçe paylaşılır'),
      if (i['eslesme'] != null) _Madde('Profilinle eşleşme: %${i['eslesme']}'),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: (_bekliyor || i['basvurdum'] == true)
              ? null
              : () async {
                  setState(() => _bekliyor = true);
                  await widget.basvur();
                  if (mounted) setState(() => _bekliyor = false);
                },
          child:
              Text(i['basvurdum'] == true ? 'Başvurdun' : 'Başvuruyu başlat →'),
        ),
      ),
    ]);
  }
}

String _seviyeYazi(dynamic s) =>
    switch (s) { 'baslangic' => 'başlangıç', 'ileri' => 'ileri', _ => 'orta' };

class _Madde extends StatelessWidget {
  final String yazi;
  const _Madde(this.yazi);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const Icon(Icons.verified_outlined,
              size: 18, color: Renk.adacayiKoyu),
          const SizedBox(width: 8),
          Expanded(child: Text(yazi, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
