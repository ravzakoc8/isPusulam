import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renkler tasarım görsellerinden: krem zemin, koyu yeşil, adaçayı yeşili, terrakota vurgu.
class Renk {
  static const krem = Color(0xFFF8F7F1);
  static const kart = Color(0xFFFDFCF8);
  static const yesil = Color(0xFF1F4A43);
  static const adacayi = Color(0xFFE4EDE6);
  static const adacayiKoyu = Color(0xFF6E9A86);
  static const kil = Color(0xFFC4704F);        // terrakota (vurgu, ret)
  static const kilAcik = Color(0xFFF7E6DE);
  static const yazi = Color(0xFF1D2B28);
  static const soluk = Color(0xFF7A8783);
  static const cizgi = Color(0xFFE6E4DA);
}

/// Başlıklar serif (tasarımdaki gibi).
TextStyle serif(double boyut, {Color renk = Renk.yazi}) =>
    GoogleFonts.playfairDisplay(fontSize: boyut, fontWeight: FontWeight.w700, color: renk, height: 1.15);

/// Küçük, harf aralıklı üst başlık (tasarımdaki "DOĞRULANMIŞ İŞVERENLER" gibi).
TextStyle ustYazi({Color renk = Renk.soluk}) =>
    TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: renk);

ThemeData tema() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Renk.krem,
    colorScheme: ColorScheme.fromSeed(seedColor: Renk.yesil, primary: Renk.yesil, surface: Renk.krem),
    textTheme: GoogleFonts.interTextTheme().apply(bodyColor: Renk.yazi, displayColor: Renk.yazi),
    appBarTheme: const AppBarTheme(backgroundColor: Renk.krem, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Renk.kart,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Renk.cizgi)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Renk.cizgi)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Renk.yesil, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Renk.yesil,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Renk.yesil,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: Renk.cizgi),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
