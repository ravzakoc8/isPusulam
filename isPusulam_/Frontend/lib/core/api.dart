import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ayarlar.dart';

/// Ekranda gösterilebilecek hata. mesaj doğrudan kullanıcıya yazılır.
class ApiHata implements Exception {
  final String mesaj;
  final int? kod;
  ApiHata(this.mesaj, [this.kod]);
  @override
  String toString() => mesaj;
}

/// Backend ile konuşan TEK yer. Giriş token'ını her isteğe kendisi ekler.
class Api {
  static String? token;
  /// Sunucu "oturum bitti" (401) derse Oturum sınıfı buraya bağlanıp çıkış yaptırır.
  static void Function()? oturumDustu;

  static Map<String, String> get _baslik => {
        'Content-Type': 'application/json; charset=utf-8',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Uri _uri(String yol) => Uri.parse('${Ayarlar.adres}$yol');

  static Future<dynamic> get(String yol) => _gonder(() => http.get(_uri(yol), headers: _baslik));
  static Future<dynamic> post(String yol, [Map<String, dynamic>? govde]) =>
      _gonder(() => http.post(_uri(yol), headers: _baslik, body: jsonEncode(govde ?? {})));
  static Future<dynamic> put(String yol, Map<String, dynamic> govde) =>
      _gonder(() => http.put(_uri(yol), headers: _baslik, body: jsonEncode(govde)));
  static Future<dynamic> patch(String yol, [Map<String, dynamic>? govde]) =>
      _gonder(() => http.patch(_uri(yol), headers: _baslik, body: jsonEncode(govde ?? {})));
  static Future<dynamic> delete(String yol) => _gonder(() => http.delete(_uri(yol), headers: _baslik));

  static Future<dynamic> _gonder(Future<http.Response> Function() istek) async {
    http.Response r;
    try {
      // Yapay zekâ cevapları (özellikle 15 soruluk sınav üretimi) yavaş olabilir: 120 saniye bekliyoruz
      r = await istek().timeout(const Duration(seconds: 120));
    } catch (_) {
      throw ApiHata('Sunucuya bağlanılamadı. Backend açık mı?');
    }
    // utf8 ile çözüyoruz ki Türkçe karakterler bozulmasın
    final govde = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return govde;

    if (r.statusCode == 401 && token != null) oturumDustu?.call();
    final mesaj = (govde is Map && govde['message'] != null && govde['message'].toString().isNotEmpty)
        ? govde['message'].toString()
        : 'Bir hata oluştu (${r.statusCode})';
    throw ApiHata(mesaj, r.statusCode);
  }
}
