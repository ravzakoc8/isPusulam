import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';

/// Zil ve mesaj ikonlarındaki kırmızı rozetler: okunmamış bildirim ve mesaj sayısı. 20 saniyede bir sunucuya sorar.
class BildirimSayaci extends ChangeNotifier {
  int okunmamis = 0;
  int mesajOkunmamis = 0;
  Timer? _zamanlayici;

  void baslat() {
    yenile();
    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(const Duration(seconds: 20), (_) => yenile());
  }

  void durdur() {
    _zamanlayici?.cancel();
    okunmamis = 0;
    mesajOkunmamis = 0;
  }

  Future<void> yenile() async {
    try {
      final j = await Api.get('/api/bildirimler/sayi');
      okunmamis = (j['sayi'] as num).toInt();
    } catch (_) {
      // Rozet güncellenemezse sessiz geç, uygulama bozulmasın
    }
    try {
      final m = await Api.get('/api/mesajlar/sayi');
      mesajOkunmamis = (m['sayi'] as num).toInt();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }
}
