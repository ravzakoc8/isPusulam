import 'dart:math';
import 'package:flutter/material.dart';
import '../core/tema.dart';

/// Tasarımdaki krem renkli, ince kenarlıklı yuvarlak kart.
class Kart extends StatelessWidget {
  final Widget child;
  final EdgeInsets ic;
  final Color? renk;
  final Color? kenar;
  final VoidCallback? tikla;
  final EdgeInsets dis;
  const Kart(
      {super.key,
      required this.child,
      this.ic = const EdgeInsets.all(18),
      this.renk,
      this.kenar,
      this.tikla,
      this.dis = const EdgeInsets.only(bottom: 14)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: dis,
      child: Material(
        color: renk ?? Renk.kart,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: tikla,
          child: Container(
            padding: ic,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kenar ?? Renk.cizgi)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Yuvarlak köşeli baş harf kutusu ("NS", "RA").
class Avatar extends StatelessWidget {
  final String yazi;
  final double boyut;
  final Color? renk;
  const Avatar(this.yazi, {super.key, this.boyut = 44, this.renk});

  static const _renkler = [
    Color(0xFFE8D9C5),
    Color(0xFFDCE8E2),
    Color(0xFFE9DDE9),
    Color(0xFFF2D9CF),
    Color(0xFFD9E3EE)
  ];

  @override
  Widget build(BuildContext context) {
    // "Mert Tanyel" -> "MT" (iki kelimeyse baş harfler), "RK" gibi kısa yazılar olduğu gibi
    final kelimeler =
        yazi.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    final harf = kelimeler.length >= 2
        ? kelimeler[0][0] + kelimeler[1][0]
        : (yazi.length > 2 ? yazi.substring(0, 2) : yazi);
    // aynı isim hep aynı rengi alsın diye metnin kodundan renk seçiyoruz
    final secilen = renk ??
        _renkler[
            yazi.codeUnits.fold<int>(0, (a, b) => a + b) % _renkler.length];
    return Container(
      width: boyut,
      height: boyut,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: secilen, borderRadius: BorderRadius.circular(boyut / 2.6)),
      child: Text(harf.toUpperCase(),
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: boyut * 0.33,
              color: Renk.yazi)),
    );
  }
}

/// Küçük durum etiketi ("Doğrulanmış", "Mülakat aşamasında" ...).
class Etiket extends StatelessWidget {
  final String yazi;
  final Color zemin, renk;
  final IconData? ikon;
  const Etiket(this.yazi,
      {super.key,
      this.zemin = Renk.adacayi,
      this.renk = Renk.yesil,
      this.ikon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (ikon != null) ...[
          Icon(ikon, size: 13, color: renk),
          const SizedBox(width: 4)
        ],
        Flexible(
            child: Text(yazi,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: renk))),
      ]),
    );
  }
}

/// Eşleşme yüzdesi için yuvarlak gösterge ("88%").
class YuzdeHalka extends StatelessWidget {
  final int yuzde;
  final double boyut;
  const YuzdeHalka(this.yuzde, {super.key, this.boyut = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boyut,
      height: boyut,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: boyut,
          height: boyut,
          child: CircularProgressIndicator(
              value: min(yuzde, 100) / 100,
              strokeWidth: 6,
              color: Renk.adacayiKoyu,
              backgroundColor: Renk.adacayi),
        ),
        Text('%$yuzde',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: boyut * 0.26)),
      ]),
    );
  }
}

/// Alt kısımdan çıkan kısa bilgi/hata mesajı.
void mesaj(BuildContext context, String yazi, {bool hata = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(yazi),
      backgroundColor: hata ? Renk.kil : Renk.yesil,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Veriyi sunucudan getirir; yükleniyor / hata / hazır durumlarını kendisi yönetir.
/// yap(...) fonksiyonu veri hazır olunca ekranı çizer; yenile() çağrılırsa veri tekrar çekilir.
class Yukle extends StatefulWidget {
  final Future<dynamic> Function() getir;
  final Widget Function(BuildContext context, dynamic veri, VoidCallback yenile)
      yap;
  const Yukle({super.key, required this.getir, required this.yap});

  @override
  State<Yukle> createState() => _YukleState();
}

class _YukleState extends State<Yukle> {
  late Future<dynamic> _gelecek;

  @override
  void initState() {
    super.initState();
    _gelecek = widget.getir();
  }

  void _yenile() => setState(() => _gelecek = widget.getir());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _gelecek,
      builder: (context, anlik) {
        if (anlik.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(60),
              child:
                  Center(child: CircularProgressIndicator(color: Renk.yesil)));
        }
        if (anlik.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${anlik.error}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: _yenile, child: const Text('Tekrar dene')),
              ]),
            ),
          );
        }
        return widget.yap(context, anlik.data, _yenile);
      },
    );
  }
}

/// Boş liste yazısı.
class BosDurum extends StatelessWidget {
  final String yazi;
  const BosDurum(this.yazi, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
          child: Text(yazi,
              style: const TextStyle(color: Renk.soluk),
              textAlign: TextAlign.center)));
}

/// Sağdan kayarak açılan panel (Bildirimler, Ayarlar, Mesajlar tasarımındaki gibi). Arka plan bulanıklaşır.
Future<void> panelAc(BuildContext context, Widget Function(BuildContext) icerik,
    {double genislik = 480}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'kapat',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, __) {
      final ekran = MediaQuery.of(ctx).size.width;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Renk.krem,
          child: SizedBox(
              width: min(genislik, ekran),
              height: double.infinity,
              child: SafeArea(child: icerik(ctx))),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// Kenar boşluklu, ortalanmış sayfa gövdesi (geniş ekranda çok uzamasın).
class SayfaGovdesi extends StatelessWidget {
  final Widget child;
  const SayfaGovdesi({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final dar = MediaQuery.of(context).size.width < 700;
    return SingleChildScrollView(
      padding:
          EdgeInsets.fromLTRB(dar ? 16 : 32, dar ? 12 : 24, dar ? 16 : 32, 40),
      child: child,
    );
  }
}
