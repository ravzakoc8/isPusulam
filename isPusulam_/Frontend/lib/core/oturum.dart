import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Giriş yapan kullanıcı bilgisi. Ekranlar context.watch<Oturum>() ile bunu dinler.
class Oturum extends ChangeNotifier {
  Map<String, dynamic>? kullanici; // {token, id, ad, soyad, tip}
  bool yukleniyor = true;          // uygulama açılırken kayıtlı oturum aranıyor

  Oturum() {
    Api.oturumDustu = cikis; // token geçersizse otomatik çıkış yap
  }

  bool get girisli => kullanici != null;
  bool get isveren => kullanici?['tip'] == 'isveren';
  String get ad => kullanici?['ad'] ?? '';
  String get adSoyad => '${kullanici?['ad'] ?? ''} ${kullanici?['soyad'] ?? ''}'.trim();
  String get harfler {
    final a = (kullanici?['ad'] ?? '') as String;
    final s = (kullanici?['soyad'] ?? '') as String;
    return '${a.isNotEmpty ? a[0] : ''}${s.isNotEmpty ? s[0] : ''}'.toUpperCase();
  }

  /// Açılışta telefonda/tarayıcıda kayıtlı oturum var mı bak.
  Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    final kayit = p.getString('kullanici');
    if (kayit != null) {
      kullanici = jsonDecode(kayit);
      Api.token = kullanici!['token'];
    }
    yukleniyor = false;
    notifyListeners();
  }

  Future<void> giris(String eposta, String sifre) async {
    final j = await Api.post('/api/auth/giris', {'eposta': eposta, 'sifre': sifre});
    await _kaydet(j);
  }

  Future<void> kayit(Map<String, dynamic> govde) async {
    final j = await Api.post('/api/auth/kayit', govde);
    await _kaydet(j);
  }

  Future<void> _kaydet(Map<String, dynamic> j) async {
    kullanici = j;
    Api.token = j['token'];
    final p = await SharedPreferences.getInstance();
    await p.setString('kullanici', jsonEncode(j));
    notifyListeners();
  }

  Future<void> cikis() async {
    kullanici = null;
    Api.token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('kullanici');
    notifyListeners();
  }
}
