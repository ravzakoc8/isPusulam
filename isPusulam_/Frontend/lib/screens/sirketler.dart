import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';

/// Şirketler sayfası: isverenler tablosundaki şirketler, açık rol sayılarıyla.
class SirketlerEkrani extends StatefulWidget {
  final String baslangicArama;
  const SirketlerEkrani({super.key, this.baslangicArama = ''});
  @override
  State<SirketlerEkrani> createState() => _SirketlerEkraniState();
}

class _SirketlerEkraniState extends State<SirketlerEkrani> {
  late final TextEditingController _arama;
  Map<String, dynamic>? _veri;
  String? _hata;

  // Kart başlık renkleri (tasarımdaki pastel tonlar)
  static const _tonlar = [Color(0xFFE8DCC8), Color(0xFFD9E6E0), Color(0xFFE9E3C9), Color(0xFFE3DDEE), Color(0xFFF3D9CF), Color(0xFFDCE4EE)];

  @override
  void initState() {
    super.initState();
    _arama = TextEditingController(text: widget.baslangicArama);
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final j = await Api.get('/api/sirketler');
      if (mounted) setState(() => _veri = Map<String, dynamic>.from(j));
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    }
  }

  void _detayAc(Map s) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Renk.kart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Yukle(
              getir: () => Api.get('/api/sirketler/${s['isveren_id']}'),
              yap: (context, d, yenile) {
                final ilanlar = (d['ilanlar'] ?? []) as List;
                return SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Avatar(d['sirket_adi'], boyut: 52),
                      const SizedBox(width: 14),
                      Expanded(child: Text(d['sirket_adi'], style: serif(26))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ]),
                    const SizedBox(height: 10),
                    if (d['dogrulanmis'] == true) const Etiket('Doğrulanmış işveren', ikon: Icons.verified_outlined),
                    const SizedBox(height: 18),
                    Text('Açık roller', style: serif(18)),
                    const SizedBox(height: 8),
                    if (ilanlar.isEmpty) const Text('Şu an açık rol yok.', style: TextStyle(color: Renk.soluk)),
                    for (final i in ilanlar)
                      Kart(ic: const EdgeInsets.all(14), dis: const EdgeInsets.only(bottom: 8), child: Row(children: [
                        const Icon(Icons.work_outline, size: 18, color: Renk.soluk),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i['baslik'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (i['konum'] != null) Text(i['konum'], style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                        ])),
                      ])),
                  ]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.of(context).size.width >= 1000;
    if (_hata != null) return Center(child: Text(_hata!));
    if (_veri == null) return const Center(child: CircularProgressIndicator(color: Renk.yesil));

    final aranan = _arama.text.trim().toLowerCase();
    final tumu = (_veri!['sirketler'] as List);
    final liste = tumu.where((s) => aranan.isEmpty || s['sirket_adi'].toString().toLowerCase().contains(aranan)).toList();

    final ana = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DOĞRULANMIŞ İŞVERENLER', style: ustYazi(renk: Renk.kil)),
      const SizedBox(height: 6),
      Text('Şirketler', style: serif(genis ? 48 : 36)),
      const SizedBox(height: 6),
      const Text('Çalışma biçimini ve ekibini görerek keşfet.', style: TextStyle(color: Renk.soluk)),
      const SizedBox(height: 22),
      // Sayaçlar
      LayoutBuilder(builder: (context, c) {
        final sayaclar = [
          _Sayac(Icons.verified_outlined, '${_veri!['dogrulanmis_sayisi']}', 'doğrulanmış şirket'),
          _Sayac(Icons.work_outline, '${_veri!['acik_ilan_sayisi']}', 'açık fırsat'),
          _Sayac(Icons.business_outlined, '${tumu.length}', 'listelenen şirket'),
        ];
        return Wrap(spacing: 14, runSpacing: 14, children: [
          for (final s in sayaclar) SizedBox(width: c.maxWidth >= 600 ? (c.maxWidth - 28) / 3 : c.maxWidth, child: s),
        ]);
      }),
      const SizedBox(height: 20),
      TextField(
        controller: _arama,
        decoration: const InputDecoration(hintText: 'Şirket ara...', prefixIcon: Icon(Icons.search)),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 22),
      Row(children: [
        Text('Ağında yer açabileceğin ekipler', style: serif(22, renk: Renk.yesil)),
        const Spacer(),
        Etiket('${liste.length} şirket'),
      ]),
      const SizedBox(height: 14),
      if (liste.isEmpty)
        const BosDurum('Şirket bulunamadı.')
      else
        LayoutBuilder(builder: (context, c) {
          final sutun = c.maxWidth >= 760 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
          final genislik = (c.maxWidth - (sutun - 1) * 16) / sutun;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (var i = 0; i < liste.length; i++)
              SizedBox(width: genislik, child: _SirketKarti(sirket: liste[i], ton: _tonlar[i % _tonlar.length], tikla: () => _detayAc(liste[i]))),
          ]);
        }),
    ]);

    return SayfaGovdesi(
      child: genis
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: ana),
              const SizedBox(width: 24),
              const SizedBox(width: 300, child: _NasilSeciyoruz()),
            ])
          : ana,
    );
  }
}

class _Sayac extends StatelessWidget {
  final IconData ikon;
  final String sayi, etiket;
  const _Sayac(this.ikon, this.sayi, this.etiket);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ikon, color: Renk.yesil, size: 20),
        const SizedBox(height: 10),
        Text(sayi, style: serif(28)),
        Text(etiket, style: const TextStyle(color: Renk.soluk, fontSize: 12)),
      ]),
    );
  }
}

class _SirketKarti extends StatelessWidget {
  final Map sirket;
  final Color ton;
  final VoidCallback tikla;
  const _SirketKarti({required this.sirket, required this.ton, required this.tikla});

  @override
  Widget build(BuildContext context) {
    final acik = sirket['acik_rol'] ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: tikla,
      child: Container(
        decoration: BoxDecoration(color: Renk.kart, borderRadius: BorderRadius.circular(18), border: Border.all(color: Renk.cizgi)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 100,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ton, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
            child: Stack(children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: 46, height: 46, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Text(bashar2(sirket['sirket_adi']), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              if (acik > 0) const Align(alignment: Alignment.topRight, child: Etiket('Öne çıkan', zemin: Colors.white)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(sirket['sirket_adi'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                if (sirket['dogrulanmis'] == true) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, size: 16, color: Renk.adacayiKoyu),
                ],
                const Spacer(),
                const Icon(Icons.north_east, size: 16, color: Renk.soluk),
              ]),
              const SizedBox(height: 10),
              Text(acik > 0 ? '$acik açık rol' : 'Şu an açık rol yok',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: acik > 0 ? Renk.kil : Renk.soluk)),
            ]),
          ),
        ]),
      ),
    );
  }

  static String bashar2(String ad) => ad.trim().isEmpty ? '?' : (ad.trim().length >= 2 ? ad.trim().substring(0, 2).toUpperCase() : ad.trim().toUpperCase());
}

/// Sağdaki bilgi kartı (tasarımdaki "Nasıl seçiyoruz?").
class _NasilSeciyoruz extends StatelessWidget {
  const _NasilSeciyoruz();
  @override
  Widget build(BuildContext context) {
    return Kart(
      ic: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NASIL SEÇİYORUZ?', style: ustYazi()),
        const SizedBox(height: 8),
        Text('Güven, görünür olmalı.', style: serif(24)),
        const SizedBox(height: 12),
        const Text('Şirketler doğrulandıktan sonra rozet alır. İlanlarda aranan beceriler açıkça yazılır ve ret durumunda gerekçe paylaşılır.',
            style: TextStyle(color: Renk.soluk, height: 1.5, fontSize: 13)),
        const Divider(height: 28),
        const _Satir('Doğrulanmış işveren rozeti'),
        const _Satir('Net tanımlı ilan gereksinimleri'),
        const _Satir('Gerekçeli geri dönüş'),
      ]),
    );
  }
}

class _Satir extends StatelessWidget {
  final String yazi;
  const _Satir(this.yazi);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(yazi, style: const TextStyle(fontSize: 13))),
          const Icon(Icons.verified_outlined, size: 16, color: Renk.adacayiKoyu),
        ]),
      );
}
