import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Backend adresi. Çalıştığın yere göre otomatik seçilir.
class Ayarlar {
  static String get adres {
    if (kIsWeb) return 'http://localhost:8080';                                         // Chrome'da (web)
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080'; // Android emülatörde bilgisayarım = 10.0.2.2
    return 'http://localhost:8080';
    // GERÇEK TELEFONDA: bilgisayarının yerel IP'sini yaz, örn. 'http://192.168.1.25:8080'
  }
}
