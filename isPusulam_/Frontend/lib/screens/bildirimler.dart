import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/oturum.dart';
import '../core/tema.dart';
import '../core/yardimci.dart';
import '../widgets/bilesenler.dart';

/// Sağdan açılan Bildirimler paneli. Ret bildirimleri terrakota vurguyla ve gerekçesiyle gösterilir.
class BildirimlerPaneli extends StatefulWidget {
  /// "Başvurularımı gör" düğmesine basılınca çağrılır (paneli kapatıp başvuru sayfasına geçer)
  final VoidCallback basvuruSayfasina;
  const BildirimlerPaneli({super.key, required this.basvuruSayfasina});
  @override
  State<BildirimlerPaneli> createState() => _BildirimlerPaneliState();
}

class _BildirimlerPaneliState extends State<BildirimlerPaneli> {
  List<dynamic> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  int _sekme = 0; // 0 = Tümü, 1 = Okunmamış

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final j = await Api.get('/api/bildirimler');
      if (mounted) setState(() { _liste = j; _yukleniyor = false; _hata = null; });
    } on ApiHata catch (e) {
      if (mounted) setState(() { _hata = e.mesaj; _yukleniyor = false; });
    }
  }

  Future<void> _hepsiniOkundu() async {
    try {
      await Api.patch('/api/bildirimler/hepsi-okundu');
      setState(() { for (final b in _liste) { b['okundu'] = true; } });
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  Future<void> _okundu(Map b) async {
    if (b['okundu'] == true) return;
    try {
      await Api.patch('/api/bildirimler/${b['bildirim_id']}/okundu');
      setState(() => b['okundu'] = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isveren = context.watch<Oturum>().isveren;
    final okunmamisSayisi = _liste.where((b) => b['okundu'] != true).length;
    final gorunen = _sekme == 0 ? _liste : _liste.where((b) => b['okundu'] != true).toList();

    // Gün gruplarına ayır (BUGÜN, DÜN, ...) sıralamayı bozmadan
    final gruplar = <String, List<dynamic>>{};
    for (final b in gorunen) {
      gruplar.putIfAbsent(gunGrubu(b['tarih']), () => []).add(b);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Renk.soluk)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.notifications_none, color: Renk.yesil),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('İŞPUSULAM', style: ustYazi()),
            Text('Bildirimler', style: serif(30)),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 20, 8),
        child: Row(children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text('Tümü ${_liste.length}')),
              ButtonSegment(value: 1, label: Text('Okunmamış $okunmamisSayisi')),
            ],
            selected: {_sekme},
            onSelectionChanged: (s) => setState(() => _sekme = s.first),
          ),
          const Spacer(),
          TextButton(onPressed: _hepsiniOkundu, child: const Text('Tümünü okundu işaretle', style: TextStyle(color: Renk.kil, fontSize: 12))),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator(color: Renk.yesil))
            : _hata != null
                ? Center(child: Text(_hata!))
                : gorunen.isEmpty
                    ? const BosDurum('Bildirimin yok.')
                    : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                        for (final g in gruplar.entries) ...[
                          Padding(padding: const EdgeInsets.fromLTRB(8, 14, 0, 10), child: Text(g.key, style: ustYazi())),
                          for (final b in g.value) _Bildirim(b: b, isveren: isveren, okundu: () => _okundu(b), git: widget.basvuruSayfasina),
                        ],
                      ]),
      ),
    ]);
  }
}

class _Bildirim extends StatelessWidget {
  final Map b;
  final bool isveren;
  final VoidCallback okundu, git;
  const _Bildirim({required this.b, required this.isveren, required this.okundu, required this.git});

  @override
  Widget build(BuildContext context) {
    final tur = b['tur'] as String;
    final ret = tur == 'ret';
    final okunmus = b['okundu'] == true;
    // Kimin adı gösterilsin: aday ise şirket, işveren ise aday
    final kim = isveren ? b['aday_ad'] : b['sirket_adi'];

    // Ret mesajı "... Gerekçe: sebep" biçiminde; sebebi ayrı kutuda gösteriyoruz
    String ana = b['mesaj'];
    String? sebep;
    final i = ana.indexOf('Gerekçe: ');
    if (ret && i >= 0) {
      sebep = ana.substring(i + 9);
      ana = ana.substring(0, i).trim();
    }

    return Kart(
      tikla: okundu,
      renk: okunmus ? Renk.kart : const Color(0xFFF3F7F3),
      kenar: ret ? Renk.kil.withOpacity(0.5) : Renk.cizgi,
      ic: const EdgeInsets.all(14),
      dis: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (kim != null)
          Avatar(kim.toString(), boyut: 40)
        else
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.verified_outlined, color: Renk.yesil, size: 20),
          ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(kim?.toString() ?? b['baslik'], style: const TextStyle(fontWeight: FontWeight.w700))),
            if (!okunmus) const Icon(Icons.circle, size: 9, color: Renk.kil),
            const SizedBox(width: 6),
            Text(zamanOnce(b['tarih']), style: const TextStyle(fontSize: 11, color: Renk.soluk)),
          ]),
          const SizedBox(height: 4),
          if (kim != null) Text(b['baslik'], style: TextStyle(fontSize: 12, color: ret ? Renk.kil : Renk.yesil, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(ana, style: const TextStyle(height: 1.45, fontSize: 13)),
          if (sebep != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Renk.kilAcik, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ret gerekçesi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Renk.kil)),
                const SizedBox(height: 3),
                Text(sebep, style: const TextStyle(fontSize: 13, height: 1.4)),
              ]),
            ),
          ],
          if (tur == 'dogrulandi') ...[
            const SizedBox(height: 8),
            const Etiket('Profilinde doğrulanmış olarak görünüyor', ikon: Icons.verified_outlined),
          ],
          if (b['basvuru_id'] != null) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              onPressed: git,
              child: Text(isveren ? 'Başvuruları gör →' : 'Başvurularımı gör →', style: const TextStyle(color: Renk.yesil, fontSize: 12)),
            ),
          ],
        ])),
      ]),
    );
  }
}
