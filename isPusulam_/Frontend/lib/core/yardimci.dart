/// Tarih ve zaman yazıları.
const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

/// "3 EKİM 2026 · CUMARTESİ" (ana sayfadaki küçük başlık)
String bugunYazisi() {
  final t = DateTime.now();
  return '${t.day} ${_aylar[t.month - 1]} ${t.year} · ${_gunler[t.weekday - 1]}'.toUpperCase();
}

/// Sunucudan gelen tarih yazısını DateTime'a çevirir (yerel saate).
DateTime tarihCoz(dynamic yazi) => DateTime.parse(yazi.toString()).toLocal();

/// "5 dk önce", "2 sa önce", "3 gün önce" ...
String zamanOnce(dynamic yazi) {
  final fark = DateTime.now().difference(tarihCoz(yazi));
  if (fark.inMinutes < 1) return 'şimdi';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
  if (fark.inHours < 24) return '${fark.inHours} sa önce';
  if (fark.inDays < 7) return '${fark.inDays} gün önce';
  final t = tarihCoz(yazi);
  return '${t.day} ${_aylar[t.month - 1]} ${t.year}';
}

/// "7 Ekim 2026, 14:30"
String tarihSaat(dynamic yazi) {
  final t = tarihCoz(yazi);
  final saat = t.hour.toString().padLeft(2, '0');
  final dk = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_aylar[t.month - 1]} ${t.year}, $saat:$dk';
}

/// Bildirim gruplama: Bugün / Dün / Bu hafta / Daha önce
String gunGrubu(dynamic yazi) {
  final t = tarihCoz(yazi);
  final bugun = DateTime.now();
  final gunFarki = DateTime(bugun.year, bugun.month, bugun.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (gunFarki <= 0) return 'BUGÜN';
  if (gunFarki == 1) return 'DÜN';
  if (gunFarki < 7) return 'BU HAFTA';
  return 'DAHA ÖNCE';
}

/// "Ravza Aydın" -> "RA"
String bashar(String ad) {
  final p = ad.trim().split(RegExp(r'\s+'));
  if (p.isEmpty || p[0].isEmpty) return '?';
  if (p.length == 1) return p[0].substring(0, p[0].length >= 2 ? 2 : 1).toUpperCase();
  return (p[0][0] + p[1][0]).toUpperCase();
}
