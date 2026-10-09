import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/bildirim_sayaci.dart';
import 'core/oturum.dart';
import 'core/tema.dart';
import 'screens/giris.dart';
import 'screens/kabuk.dart';

void main() {
  runApp(
    // Oturum ve bildirim sayacı uygulamanın en üstünde durur; her ekran bunlara ulaşabilir.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Oturum()..yukle()),
        ChangeNotifierProvider(create: (_) => BildirimSayaci()),
      ],
      child: const IsPusulamApp(),
    ),
  );
}

class IsPusulamApp extends StatelessWidget {
  const IsPusulamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'işPusulam',
      debugShowCheckedModeBanner: false,
      theme: tema(),
      // Oturuma göre ekran seçilir: açılıyor -> bekleme, girişli -> ana yapı, değilse -> giriş ekranı
      home: Consumer<Oturum>(builder: (context, oturum, _) {
        if (oturum.yukleniyor) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Renk.yesil)));
        }
        return oturum.girisli ? const Kabuk() : const GirisEkrani();
      }),
    );
  }
}
