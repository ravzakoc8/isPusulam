import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/bildirim_sayaci.dart';
import '../core/oturum.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';
import 'ana_sayfa.dart';
import 'ayarlar.dart';
import 'basvurularim.dart';
import 'beceriler.dart';
import 'bildirimler.dart';
import 'isler.dart';
import 'isveren_basvurular.dart';
import 'isveren_ilanlar.dart';
import 'mesajlar.dart';
import 'profil.dart';
import 'sirketler.dart';

class _Sayfa {
  final String ad;
  final IconData ikon;
  final Widget govde;
  _Sayfa(this.ad, this.ikon, this.govde);
}

/// Giriş yapıldıktan sonraki ana iskelet: sol menü + üst çubuk (geniş ekran) veya AppBar + Drawer (dar ekran).
/// Sayfalar listesindeki sıra numarası (0,1,2...) sayfa değiştirmek için kullanılır.
class Kabuk extends StatefulWidget {
  const Kabuk({super.key});
  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  int _sayfa = 0;
  String _arama = '';

  @override
  void initState() {
    super.initState();
    // Bildirim rozetini periyodik güncellemeye başla
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BildirimSayaci>().baslat());
  }

  void _gec(int i) => setState(() => _sayfa = i);

  /// Aday sayfaları: 0 Ana sayfa, 1 Şirketler, 2 İşler, 3 Becerilerim, 4 Başvurularım
  /// İşveren sayfaları: 0 Ana sayfa, 1 Şirketler, 2 İlanlarım, 3 Başvurular
  List<_Sayfa> _sayfalar(bool isveren) {
    if (isveren) {
      return [
        _Sayfa('Ana sayfa', Icons.home_outlined, AnaSayfaIsveren(gec: _gec)),
        _Sayfa('Şirketler', Icons.business_outlined, SirketlerEkrani(key: ValueKey('s$_arama'), baslangicArama: _arama)),
        _Sayfa('İlanlarım', Icons.work_outline, const IsverenIlanlarEkrani()),
        _Sayfa('Başvurular', Icons.assignment_outlined, const IsverenBasvurularEkrani()),
      ];
    }
    return [
      _Sayfa('Ana sayfa', Icons.home_outlined, AnaSayfaAday(gec: _gec)),
      _Sayfa('Şirketler', Icons.business_outlined, const SirketlerEkrani()),
      _Sayfa('İşler', Icons.work_outline, IslerEkrani(key: ValueKey('i$_arama'), baslangicArama: _arama)),
      _Sayfa('Becerilerim', Icons.verified_outlined, const BecerilerEkrani()),
      _Sayfa('Başvurularım', Icons.assignment_outlined, const BasvurularimEkrani()),
    ];
  }

  void _bildirimAc(bool isveren) {
    panelAc(context, (ctx) => BildirimlerPaneli(
      // bildirimdeki "başvurulara git" düğmesi: paneli kapatıp başvuru sayfasına geçer
      basvuruSayfasina: () {
        Navigator.pop(ctx);
        _gec(isveren ? 3 : 4);
      },
    )).then((_) {
      if (mounted) context.read<BildirimSayaci>().yenile();
    });
  }

  void _ayarAc() => panelAc(context, (ctx) => const AyarlarPaneli());

  void _arat(String q, bool isveren) {
    setState(() {
      _arama = q.trim();
      _sayfa = isveren ? 1 : 2; // aday: İşler'de, işveren: Şirketler'de arar
    });
  }

  @override
  Widget build(BuildContext context) {
    final oturum = context.watch<Oturum>();
    final okunmamis = context.watch<BildirimSayaci>().okunmamis;
    final mesajOkunmamis = context.watch<BildirimSayaci>().mesajOkunmamis;
    final sayfalar = _sayfalar(oturum.isveren);
    if (_sayfa >= sayfalar.length) _sayfa = 0;
    final genis = MediaQuery.of(context).size.width >= 1000;

    final govde = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: sayfalar[_sayfa].govde),
    );

    // ---------------- GENİŞ EKRAN (web) ----------------
    if (genis) {
      return Scaffold(
        body: Row(children: [
          // Sol menü
          Container(
            width: 80,
            decoration: const BoxDecoration(color: Color(0xFFEFF3EE), border: Border(right: BorderSide(color: Renk.cizgi))),
            child: Column(children: [
              const SizedBox(height: 20),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Renk.yesil, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.explore_outlined, color: Colors.white),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < sayfalar.length; i++)
                _MenuIkon(ikon: sayfalar[i].ikon, ipucu: sayfalar[i].ad, secili: _sayfa == i, tikla: () => _gec(i)),
              const Spacer(),
              _MenuIkon(
                ikon: Icons.chat_bubble_outline, ipucu: 'Mesajlar', secili: false, rozet: mesajOkunmamis,
                tikla: () => mesajlasmaAc(context),
              ),
              _MenuIkon(
                ikon: Icons.notifications_none, ipucu: 'Bildirimler', secili: false, rozet: okunmamis,
                tikla: () => _bildirimAc(oturum.isveren),
              ),
              _MenuIkon(ikon: Icons.settings_outlined, ipucu: 'Ayarlar', secili: false, tikla: _ayarAc),
              const SizedBox(height: 8),
              Tooltip(message: oturum.adSoyad, child: Avatar(oturum.harfler, boyut: 38)),
              const SizedBox(height: 18),
            ]),
          ),
          Expanded(
            child: Column(children: [
              // Üst çubuk
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(children: [
                  Text('işPusulam', style: serif(24, renk: Renk.yesil)),
                  const SizedBox(width: 28),
                  TextButton(onPressed: () => _gec(1), child: const Text('Şirketler', style: TextStyle(color: Renk.yazi))),
                  TextButton(
                      onPressed: () => _gec(2),
                      child: Text(oturum.isveren ? 'İlanlarım' : 'İşler', style: const TextStyle(color: Renk.yazi))),
                  const Spacer(),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: oturum.isveren ? 'Şirket ara...' : 'İş, beceri veya şirket ara...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (q) => _arat(q, oturum.isveren),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _ProfilMenusu(oturum: oturum),
                ]),
              ),
              Expanded(child: govde),
            ]),
          ),
        ]),
      );
    }

    // ---------------- DAR EKRAN (telefon) ----------------
    return Scaffold(
      appBar: AppBar(
        title: Text('işPusulam', style: serif(22, renk: Renk.yesil)),
        actions: [
          IconButton(
            tooltip: 'Mesajlar',
            onPressed: () => mesajlasmaAc(context),
            icon: Badge(
              isLabelVisible: mesajOkunmamis > 0,
              backgroundColor: Renk.kil,
              label: Text('$mesajOkunmamis'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          IconButton(
            onPressed: () => _bildirimAc(oturum.isveren),
            icon: Badge(
              isLabelVisible: okunmamis > 0,
              backgroundColor: Renk.kil,
              label: Text('$okunmamis'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          _ProfilMenusu(oturum: oturum),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Renk.krem,
        child: SafeArea(
          child: ListView(children: [
            Padding(padding: const EdgeInsets.all(20), child: Text('işPusulam', style: serif(26, renk: Renk.yesil))),
            for (var i = 0; i < sayfalar.length; i++)
              ListTile(
                leading: Icon(sayfalar[i].ikon, color: _sayfa == i ? Renk.yesil : Renk.soluk),
                title: Text(sayfalar[i].ad),
                selected: _sayfa == i,
                selectedTileColor: Renk.adacayi,
                onTap: () {
                  Navigator.pop(context);
                  _gec(i);
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Renk.soluk),
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pop(context);
                _ayarAc();
              },
            ),
          ]),
        ),
      ),
      body: govde,
    );
  }
}

/// Sol menüdeki tek ikon (seçiliyse yeşilimsi zemin, rozet varsa kırmızı nokta).
class _MenuIkon extends StatelessWidget {
  final IconData ikon;
  final String ipucu;
  final bool secili;
  final int rozet;
  final VoidCallback tikla;
  const _MenuIkon({required this.ikon, required this.ipucu, required this.secili, required this.tikla, this.rozet = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: ipucu,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: tikla,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: secili ? Renk.adacayi : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Badge(
              isLabelVisible: rozet > 0,
              backgroundColor: Renk.kil,
              label: Text('$rozet'),
              child: Icon(ikon, color: secili ? Renk.yesil : Renk.soluk),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sağ üstteki avatar: tıklayınca Profilim / Çıkış yap menüsü açılır.
class _ProfilMenusu extends StatelessWidget {
  final Oturum oturum;
  const _ProfilMenusu({required this.oturum});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: oturum.adSoyad,
      offset: const Offset(0, 46),
      onSelected: (v) {
        if (v == 'profil') profilDuzenleAc(context);
        if (v == 'cikis') {
          context.read<BildirimSayaci>().durdur();
          context.read<Oturum>().cikis(); // main.dart otomatik giriş ekranına döner
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(oturum.adSoyad, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (!oturum.isveren) const PopupMenuItem(value: 'profil', child: Text('Profilim')),
        const PopupMenuItem(value: 'cikis', child: Text('Çıkış yap')),
      ],
      child: Avatar(oturum.harfler, boyut: 40),
    );
  }
}
