import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';
import '../widgets/gereksinimler.dart';
import 'mesajlar.dart';
import 'profil.dart';

/// İşverenin "İlanlarım" sayfası: ilan listesi, yeni ilan yayınlama, uygun aday önerileri.
class IsverenIlanlarEkrani extends StatefulWidget {
  const IsverenIlanlarEkrani({super.key});
  @override
  State<IsverenIlanlarEkrani> createState() => _IsverenIlanlarEkraniState();
}

class _IsverenIlanlarEkraniState extends State<IsverenIlanlarEkrani> {
  int _anahtar = 0;
  void _yenile() => setState(() => _anahtar++);

  Future<void> _yeniIlan() async {
    final yayinlandi = await showDialog<bool>(context: context, builder: (_) => const _IlanOlustur());
    if (yayinlandi == true) _yenile();
  }

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.of(context).size.width >= 700;
    return SayfaGovdesi(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('İLAN YÖNETİMİ', style: ustYazi(renk: Renk.kil)),
            const SizedBox(height: 6),
            Text('İlanlarım', style: serif(genis ? 46 : 34)),
            const SizedBox(height: 6),
            const Text('Aradığın becerileri net yaz, doğru adaylar seni bulsun.', style: TextStyle(color: Renk.soluk)),
          ])),
          FilledButton.icon(onPressed: _yeniIlan, icon: const Icon(Icons.add, size: 18), label: const Text('İlan yayınla')),
        ]),
        const SizedBox(height: 22),
        Yukle(
          key: ValueKey(_anahtar),
          getir: () => Api.get('/api/ilanlar/benim'),
          yap: (context, veri, yenile) {
            final liste = veri as List;
            if (liste.isEmpty) return const BosDurum('Henüz ilan yayınlamadın.');
            return Column(children: [for (final i in liste) _IlanKarti(ilan: i, yenile: _yenile)]);
          },
        ),
      ]),
    );
  }
}

class _IlanKarti extends StatelessWidget {
  final Map ilan;
  final VoidCallback yenile;
  const _IlanKarti({required this.ilan, required this.yenile});

  Future<void> _durumDegistir(BuildContext context) async {
    final yeni = ilan['durum'] == 'aktif' ? 'kapali' : 'aktif';
    try {
      await Api.patch('/api/ilanlar/${ilan['ilan_id']}/durum', {'durum': yeni});
      yenile();
    } on ApiHata catch (e) {
      if (context.mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  void _adaylariGor(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Renk.kart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Uygun adaylar', style: serif(24))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              Text('"${ilan['baslik']}" ilanına henüz başvurmamış ama becerileri uyan adaylar. Gizli profiller görünmez.',
                  style: const TextStyle(color: Renk.soluk, fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Yukle(
                    getir: () => Api.get('/api/ilanlar/${ilan['ilan_id']}/onerilen-adaylar'),
                    yap: (context, veri, yenile) {
                      final liste = veri as List;
                      if (liste.isEmpty) return const BosDurum('Şu an uygun aday önerisi yok.');
                      return Column(children: [
                        for (final a in liste)
                          Kart(
                            ic: const EdgeInsets.all(12),
                            dis: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Avatar('${a['ad']} ${a['soyad']}', boyut: 40),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${a['ad']} ${a['soyad']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                if (a['unvan'] != null) Text(a['unvan'], style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                              ])),
                              Text('%${a['eslesme']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Mesaj gönder',
                                onPressed: () => mesajlasmaAc(context, kisiId: (a['aday_id'] as num).toInt()),
                                icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Renk.yesil),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                                onPressed: () => adayProfiliAc(context, (a['aday_id'] as num).toInt()),
                                child: const Text('Profil'),
                              ),
                            ]),
                          ),
                      ]);
                    },
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aktif = ilan['durum'] == 'aktif';
    final kriterler = (ilan['kriterler'] ?? []) as List;
    return Kart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(ilan['baslik'], style: serif(22))),
          Etiket(aktif ? 'Yayında' : 'Kapalı', zemin: aktif ? Renk.adacayi : const Color(0xFFF0EFE8), renk: aktif ? Renk.yesil : Renk.soluk),
        ]),
        if (ilan['konum'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(ilan['konum'], style: const TextStyle(fontSize: 12, color: Renk.soluk))),
        if (gereksinimOzeti((ilan['gereksinimler'] ?? []) as List).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(gereksinimOzeti((ilan['gereksinimler'] ?? []) as List), style: const TextStyle(fontSize: 12, color: Renk.soluk))),
        const SizedBox(height: 10),
        Text(ilan['aciklama'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final k in kriterler) Etiket('${k['ad']} · ${k['seviye'] ?? 'orta'}', zemin: const Color(0xFFF0EFE8), renk: Renk.yazi),
        ]),
        if (((ilan['gereksinimler'] ?? []) as List).isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 6),
              title: const Text('Aranan nitelikleri göster', style: TextStyle(fontSize: 13, color: Renk.yesil)),
              children: [GereksinimListesi((ilan['gereksinimler'] ?? []) as List)],
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Text('${ilan['basvuru_sayisi']} başvuru', style: const TextStyle(fontWeight: FontWeight.w700, color: Renk.kil, fontSize: 13)),
          const Spacer(),
          TextButton(onPressed: () => _durumDegistir(context), child: Text(aktif ? 'İlanı kapat' : 'Yeniden aç')),
          OutlinedButton.icon(
            onPressed: () => _adaylariGor(context),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Uygun adaylar'),
          ),
        ]),
      ]),
    );
  }
}


// =====================================================================
//  İLAN OLUŞTURMA PENCERESİ (net ihtiyaç tanımı + yapay zekâ desteği)
//  Sadece "Backend" yazıp geçilemez: iş tanımı en az 80 karakter, çalışma türü/şekli, deneyim,
//  eğitim ve en az bir beceri zorunlu. Eğitim, bölüm, dil, sertifika gibi alanlarda birden fazla seçenek seçilebilir.
// =====================================================================
class _IlanOlustur extends StatefulWidget {
  const _IlanOlustur();
  @override
  State<_IlanOlustur> createState() => _IlanOlusturState();
}

class _IlanOlusturState extends State<_IlanOlustur> {
  final _baslik = TextEditingController();
  final _konum = TextEditingController();
  final _aciklama = TextEditingController();

  Map<String, dynamic> _sec = {}; // sunucudan gelen hazır seçenekler
  List<dynamic> _tumBeceriler = [];
  bool _yuklendi = false;
  String? _yuklemeHatasi;

  final Map<int, Map<String, dynamic>> _secilen = {}; // beceri_id -> {seviye, zorunlu}
  final Set<String> _calismaTuru = {};
  final Set<String> _calismaSekli = {};
  String? _deneyim;
  final Set<String> _egitim = {};
  bool _egitimZorunlu = true;
  final Set<String> _bolum = {};
  bool _bolumZorunlu = false;
  final List<Map<String, dynamic>> _diller = []; // {ad, seviye, zorunlu}
  final List<Map<String, dynamic>> _sertifikalar = []; // {ad, zorunlu}

  List<String> _oneriler = [];
  bool _aiBekliyor = false;
  bool _yayinliyor = false;
  bool _beceriEkleniyor = false;

  int get _minAciklama => ((_sec['min_aciklama'] ?? 80) as num).toInt();
  List<String> _liste(String anahtar) => List<String>.from(_sec[anahtar] ?? const []);

  @override
  void initState() {
    super.initState();
    _aciklama.addListener(() => setState(() {})); // karakter sayacı güncellensin
    Future.wait([Api.get('/api/beceriler'), Api.get('/api/ilanlar/secenekler')]).then((j) {
      if (!mounted) return;
      setState(() {
        _tumBeceriler = List<dynamic>.from(j[0]);
        _sec = Map<String, dynamic>.from(j[1]);
        _yuklendi = true;
      });
    }).catchError((e) {
      if (mounted) setState(() => _yuklemeHatasi = '$e');
    });
  }

  @override
  void dispose() {
    _baslik.dispose();
    _konum.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  // ---------------- Yapay zekâ ----------------
  /// Yapay zekâdan iş tanımı, beceriler ve tüm gereksinimleri ister; formu doldurur (işveren sonra düzenleyebilir).
  Future<void> _aiOner() async {
    if (_baslik.text.trim().isEmpty) {
      mesaj(context, 'Önce pozisyon başlığını yaz (örn. Backend Developer Stajyeri)', hata: true);
      return;
    }
    setState(() => _aiBekliyor = true);
    try {
      final j = await Api.post('/api/ai/gereksinimler', {
        'pozisyon': _baslik.text.trim(),
        if (_aciklama.text.trim().isNotEmpty) 'aciklama': _aciklama.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _oneriler = List<String>.from(j['maddeler'] ?? const []);
        final aiAciklama = (j['aciklama'] ?? '').toString().trim();
        if (aiAciklama.isNotEmpty && _aciklama.text.trim().length < _minAciklama) {
          _aciklama.text = _aciklama.text.trim().isEmpty ? aiAciklama : '${_aciklama.text.trim()}\n\n$aiAciklama';
        }
        // Beceriler: listede olmayanlar sunucuda eklendi, burada da listeye ekle ve işaretle
        for (final b in (j['beceriler'] ?? const []) as List) {
          final id = (b['beceri_id'] as num).toInt();
          if (!_tumBeceriler.any((x) => (x['beceri_id'] as num).toInt() == id)) {
            _tumBeceriler.add({'beceri_id': id, 'ad': b['ad'], 'kategori': b['kategori']});
          }
          _secilen[id] = {'seviye': b['seviye'] ?? 'orta', 'zorunlu': b['zorunlu'] != false};
        }
        for (final g in (j['gereksinimler'] ?? const []) as List) {
          final deger = '${g['deger']}';
          final zorunlu = g['zorunlu_mu'] != false;
          switch (g['tur']) {
            case 'calisma_turu':
              _calismaTuru.add(deger);
            case 'calisma_sekli':
              _calismaSekli.add(deger);
            case 'deneyim':
              _deneyim = deger;
            case 'egitim':
              _egitim.add(deger);
              _egitimZorunlu = zorunlu;
            case 'bolum':
              _bolum.add(deger);
            case 'dil':
              if (!_diller.any((d) => d['ad'] == deger)) {
                _diller.add({'ad': deger, 'seviye': g['seviye'] ?? 'B1', 'zorunlu': zorunlu});
              }
            case 'sertifika':
              if (!_sertifikalar.any((d) => d['ad'] == deger)) _sertifikalar.add({'ad': deger, 'zorunlu': zorunlu});
          }
        }
      });
      mesaj(context, 'Yapay zekâ formu doldurdu. Kontrol edip istediğin gibi düzenleyebilirsin.');
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _aiBekliyor = false);
    }
  }

  void _maddeEkle(String madde) {
    final mevcut = _aciklama.text.trim();
    _aciklama.text = mevcut.isEmpty ? '• $madde' : '$mevcut\n• $madde';
  }

  // ---------------- Beceri ----------------
  /// Listede varsa seç; yoksa sunucuya gönder (yapay zekâ kontrol edip ekler) ve seç.
  Future<void> _beceriEkle(String ad) async {
    final yazilan = ad.trim();
    if (yazilan.isEmpty) return;
    for (final b in _tumBeceriler) {
      if ('${b['ad']}'.toLowerCase() == yazilan.toLowerCase()) {
        setState(() => _secilen[(b['beceri_id'] as num).toInt()] = {'seviye': 'orta', 'zorunlu': true});
        return;
      }
    }
    setState(() => _beceriEkleniyor = true);
    try {
      final b = await Api.post('/api/beceriler', {'ad': yazilan});
      if (!mounted) return;
      final id = (b['beceri_id'] as num).toInt();
      setState(() {
        if (!_tumBeceriler.any((x) => (x['beceri_id'] as num).toInt() == id)) _tumBeceriler.add(b);
        _secilen[id] = {'seviye': 'orta', 'zorunlu': true};
      });
      mesaj(context, '"${b['ad']}" eklendi ve seçildi');
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _beceriEkleniyor = false);
    }
  }

  String _beceriAdi(int id) {
    for (final b in _tumBeceriler) {
      if ((b['beceri_id'] as num).toInt() == id) return '${b['ad']}';
    }
    return '#$id';
  }

  // ---------------- Yayınla ----------------
  String? _eksik() {
    if (_baslik.text.trim().length < 3) return 'Pozisyon başlığını yaz';
    if (_calismaTuru.isEmpty) return 'Çalışma türünü seç (staj, tam zamanlı...)';
    if (_calismaSekli.isEmpty) return 'Çalışma şeklini seç (ofisten, hibrit, uzaktan)';
    if (_deneyim == null) return 'Beklenen deneyimi seç';
    if (_egitim.isEmpty) return 'En az bir eğitim durumu seç';
    if (_secilen.isEmpty) return 'En az bir aranan beceri seç';
    if (_aciklama.text.trim().length < _minAciklama) {
      return 'İş tanımı en az $_minAciklama karakter olmalı (şu an ${_aciklama.text.trim().length}). '
          'Yapay zekâ önerisini kullanabilirsin.';
    }
    return null;
  }

  Future<void> _yayinla() async {
    final eksik = _eksik();
    if (eksik != null) {
      mesaj(context, eksik, hata: true);
      return;
    }
    final gereksinimler = <Map<String, dynamic>>[
      for (final d in _calismaTuru) {'tur': 'calisma_turu', 'deger': d, 'zorunlu_mu': true},
      for (final d in _calismaSekli) {'tur': 'calisma_sekli', 'deger': d, 'zorunlu_mu': true},
      {'tur': 'deneyim', 'deger': _deneyim, 'zorunlu_mu': true},
      for (final d in _egitim) {'tur': 'egitim', 'deger': d, 'zorunlu_mu': _egitimZorunlu},
      for (final d in _bolum) {'tur': 'bolum', 'deger': d, 'zorunlu_mu': _bolumZorunlu},
      for (final d in _diller) {'tur': 'dil', 'deger': d['ad'], 'seviye': d['seviye'], 'zorunlu_mu': d['zorunlu']},
      for (final d in _sertifikalar) {'tur': 'sertifika', 'deger': d['ad'], 'zorunlu_mu': d['zorunlu']},
    ];
    setState(() => _yayinliyor = true);
    try {
      await Api.post('/api/ilanlar', {
        'baslik': _baslik.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'konum': _konum.text.trim(),
        'kriterler': [
          for (final e in _secilen.entries) {'beceri_id': e.key, 'seviye': e.value['seviye'], 'zorunlu_mu': e.value['zorunlu']},
        ],
        'gereksinimler': gereksinimler,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      mesaj(context, 'İlanın yayınlandı');
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _yayinliyor = false);
    }
  }

  // ---------------- Arayüz parçaları ----------------
  Widget _baslikSatiri(String yazi, {String? alt, bool zorunlu = false, Widget? sag}) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: yazi, style: serif(17)),
                if (zorunlu) const TextSpan(text: '  *', style: TextStyle(color: Renk.kil, fontWeight: FontWeight.w700)),
              ])),
              if (alt != null) Text(alt, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
            ]),
          ),
          if (sag != null) sag,
        ]),
      );

  Widget _cokluSecim(List<String> secenekler, Set<String> secili) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in {...secenekler, ...secili})
          FilterChip(
            label: Text(s),
            selected: secili.contains(s),
            selectedColor: Renk.adacayi,
            checkmarkColor: Renk.yesil,
            onSelected: (v) => setState(() => v ? secili.add(s) : secili.remove(s)),
          ),
      ]);

  Widget _zorunluAnahtari(bool deger, ValueChanged<bool> degisti) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(deger ? 'Zorunlu' : 'Tercih sebebi', style: TextStyle(fontSize: 12, color: deger ? Renk.yesil : Renk.soluk)),
        Switch(value: deger, activeColor: Renk.yesil, onChanged: degisti),
      ]);

  @override
  Widget build(BuildContext context) {
    final aciklamaUzunluk = _aciklama.text.trim().length;
    final tumBeceriAdlari = [for (final b in _tumBeceriler) '${b['ad']}'];

    return Dialog(
      backgroundColor: Renk.kart,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text('Yeni ilan', style: serif(26))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const Text('İhtiyacını ne kadar net tanımlarsan o kadar doğru adaylarla eşleşirsin. * işaretli alanlar zorunlu.',
                  style: TextStyle(fontSize: 12, color: Renk.soluk)),
              const SizedBox(height: 14),
              TextField(controller: _baslik, decoration: const InputDecoration(labelText: 'Pozisyon başlığı * (örn. Backend Developer Stajyeri)')),
              const SizedBox(height: 12),
              TextField(controller: _konum, decoration: const InputDecoration(labelText: 'Konum (örn. İstanbul / Maslak)')),
              const SizedBox(height: 12),
              // Yapay zekâ kutusu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: Renk.yesil),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Başlığı yaz, yapay zekâ iş tanımını, becerileri, eğitim/dil/sertifika ve deneyim beklentilerini önersin.',
                        style: TextStyle(fontSize: 13, height: 1.4)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _aiBekliyor || !_yuklendi ? null : _aiOner,
                    child: _aiBekliyor
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Doldur'),
                  ),
                ]),
              ),
              if (_yuklemeHatasi != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(_yuklemeHatasi!, style: const TextStyle(color: Renk.kil)))
              else if (!_yuklendi)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Renk.yesil)))
              else ...[
                // ---- İş tanımı ----
                _baslikSatiri('İş tanımı', alt: 'Ne yapılacak, hangi araçlarla, kiminle çalışılacak?', zorunlu: true),
                TextField(
                  controller: _aciklama,
                  maxLines: 7,
                  decoration: InputDecoration(
                    alignLabelWithHint: true,
                    hintText: 'Örn. Ödeme altyapımızın REST API\'lerini geliştiren ekibe katılacaksın. Java/Spring Boot ile yeni servisler yazacak, '
                        'PostgreSQL sorgularını optimize edecek ve birim testleri yazacaksın...',
                    helperText: aciklamaUzunluk < _minAciklama
                        ? 'En az $_minAciklama karakter · şu an $aciklamaUzunluk'
                        : '$aciklamaUzunluk karakter ✓',
                    helperStyle: TextStyle(color: aciklamaUzunluk < _minAciklama ? Renk.kil : Renk.yesil),
                  ),
                ),
                if (_oneriler.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Yapay zekâ önerileri (dokunarak iş tanımına ekle):', style: TextStyle(fontSize: 12, color: Renk.soluk)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in _oneriler) ActionChip(label: Text(m, style: const TextStyle(fontSize: 12)), onPressed: () => _maddeEkle(m)),
                  ]),
                ],

                // ---- Çalışma koşulları ----
                _baslikSatiri('Çalışma türü', alt: 'Birden fazla seçebilirsin', zorunlu: true),
                _cokluSecim(_liste('calisma_turu'), _calismaTuru),
                _baslikSatiri('Çalışma şekli', alt: 'Birden fazla seçebilirsin', zorunlu: true),
                _cokluSecim(_liste('calisma_sekli'), _calismaSekli),
                _baslikSatiri('Beklenen deneyim', zorunlu: true),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final d in _liste('deneyim'))
                    ChoiceChip(
                      label: Text(d),
                      selected: _deneyim == d,
                      selectedColor: Renk.adacayi,
                      onSelected: (_) => setState(() => _deneyim = d),
                    ),
                ]),

                // ---- Eğitim ----
                _baslikSatiri('Eğitim durumu', alt: 'Kabul ettiğin tüm durumları seç', zorunlu: true,
                    sag: _zorunluAnahtari(_egitimZorunlu, (v) => setState(() => _egitimZorunlu = v))),
                _cokluSecim(_liste('egitim'), _egitim),
                _baslikSatiri('Bölüm', alt: 'İsteğe bağlı · listede yoksa yazıp ekle',
                    sag: _zorunluAnahtari(_bolumZorunlu, (v) => setState(() => _bolumZorunlu = v))),
                _cokluSecim(_liste('bolum'), _bolum),
                const SizedBox(height: 8),
                _EkleAlani(ipucu: 'Başka bölüm yaz...', oneriler: const [], ekle: (t) => setState(() => _bolum.add(t))),

                // ---- Yabancı dil ----
                _baslikSatiri('Yabancı dil', alt: 'İsteğe bağlı · her dil için seviye ve zorunluluk seç',
                    sag: TextButton.icon(
                      onPressed: () => setState(() {
                        final diller = _liste('dil');
                        final bos = diller.firstWhere((d) => !_diller.any((x) => x['ad'] == d), orElse: () => diller.first);
                        _diller.add({'ad': bos, 'seviye': 'B1', 'zorunlu': true});
                      }),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Dil ekle'),
                    )),
                for (final d in _diller)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
                      DropdownButton<String>(
                        value: d['ad'],
                        underline: const SizedBox(),
                        items: [for (final x in {..._liste('dil'), d['ad'] as String}) DropdownMenuItem(value: x, child: Text(x))],
                        onChanged: (v) => setState(() => d['ad'] = v),
                      ),
                      DropdownButton<String>(
                        value: d['seviye'],
                        underline: const SizedBox(),
                        items: [for (final x in _liste('dil_seviye')) DropdownMenuItem(value: x, child: Text('Seviye: $x'))],
                        onChanged: (v) => setState(() => d['seviye'] = v),
                      ),
                      _zorunluAnahtari(d['zorunlu'] == true, (v) => setState(() => d['zorunlu'] = v)),
                      IconButton(
                          tooltip: 'Kaldır',
                          onPressed: () => setState(() => _diller.remove(d)),
                          icon: const Icon(Icons.close, size: 18, color: Renk.soluk)),
                    ]),
                  ),

                // ---- Sertifikalar ----
                _baslikSatiri('Sertifikalar', alt: 'İsteğe bağlı · listeden seç ya da kendin yaz'),
                _EkleAlani(
                  ipucu: 'Sertifika ara veya yaz (örn. AWS, CCNA, TOEFL)...',
                  oneriler: _liste('sertifika'),
                  ekle: (t) => setState(() {
                    if (!_sertifikalar.any((s) => '${s['ad']}'.toLowerCase() == t.toLowerCase())) {
                      _sertifikalar.add({'ad': t, 'zorunlu': false});
                    }
                  }),
                ),
                for (final c in _sertifikalar)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.workspace_premium_outlined, size: 18, color: Renk.adacayiKoyu),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${c['ad']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      _zorunluAnahtari(c['zorunlu'] == true, (v) => setState(() => c['zorunlu'] = v)),
                      IconButton(
                          tooltip: 'Kaldır',
                          onPressed: () => setState(() => _sertifikalar.remove(c)),
                          icon: const Icon(Icons.close, size: 18, color: Renk.soluk)),
                    ]),
                  ),

                // ---- Beceriler ----
                _baslikSatiri('Aranan beceriler', alt: 'Programlama dilleri, araçlar, programlar · listede yoksa yaz, yapay zekâ kontrol edip ekler', zorunlu: true),
                _EkleAlani(
                  ipucu: _beceriEkleniyor ? 'Ekleniyor...' : 'Beceri ara veya yeni beceri yaz (örn. Docker, Figma, Excel)...',
                  oneriler: tumBeceriAdlari,
                  ekle: _beceriEkle,
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 170),
                  child: SingleChildScrollView(
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final b in _tumBeceriler)
                        FilterChip(
                          label: Text('${b['ad']}'),
                          selected: _secilen.containsKey((b['beceri_id'] as num).toInt()),
                          selectedColor: Renk.adacayi,
                          checkmarkColor: Renk.yesil,
                          onSelected: (v) => setState(() {
                            final id = (b['beceri_id'] as num).toInt();
                            if (v) {
                              _secilen[id] = {'seviye': 'orta', 'zorunlu': true};
                            } else {
                              _secilen.remove(id);
                            }
                          }),
                        ),
                    ]),
                  ),
                ),
                // Seçilen her beceri için seviye ve zorunluluk
                for (final e in _secilen.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Expanded(child: Text(_beceriAdi(e.key), style: const TextStyle(fontWeight: FontWeight.w600))),
                      DropdownButton<String>(
                        value: e.value['seviye'],
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'baslangic', child: Text('Başlangıç')),
                          DropdownMenuItem(value: 'orta', child: Text('Orta')),
                          DropdownMenuItem(value: 'ileri', child: Text('İleri')),
                        ],
                        onChanged: (v) => setState(() => e.value['seviye'] = v),
                      ),
                      const SizedBox(width: 8),
                      _zorunluAnahtari(e.value['zorunlu'] == true, (v) => setState(() => e.value['zorunlu'] = v)),
                    ]),
                  ),
                const SizedBox(height: 22),
                if (_eksik() != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 16, color: Renk.kil),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_eksik()!, style: const TextStyle(fontSize: 12, color: Renk.kil))),
                    ]),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _yayinliyor ? null : _yayinla,
                    child: Text(_yayinliyor ? 'Yayınlanıyor...' : 'İlanı yayınla'),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Yazarken öneri gösteren, Enter veya + ile ekleyen küçük alan (bölüm, sertifika, beceri için).
class _EkleAlani extends StatefulWidget {
  final String ipucu;
  final List<String> oneriler;
  final void Function(String) ekle;
  const _EkleAlani({required this.ipucu, required this.oneriler, required this.ekle});
  @override
  State<_EkleAlani> createState() => _EkleAlaniState();
}

class _EkleAlaniState extends State<_EkleAlani> {
  TextEditingController? _kontrol;

  void _ekle(String t) {
    final yazi = t.trim();
    if (yazi.isEmpty) return;
    widget.ekle(yazi);
    // Seçimden sonra alanı temizle (Autocomplete seçilen metni alana yazdığı için bir sonraki karede)
    WidgetsBinding.instance.addPostFrameCallback((_) => _kontrol?.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return widget.oneriler.where((o) => o.toLowerCase().contains(q)).take(8);
      },
      onSelected: _ekle,
      fieldViewBuilder: (context, kontrol, odak, gonder) {
        _kontrol = kontrol;
        return TextField(
          controller: kontrol,
          focusNode: odak,
          decoration: InputDecoration(
            hintText: widget.ipucu,
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: IconButton(icon: const Icon(Icons.add), tooltip: 'Ekle', onPressed: () => _ekle(kontrol.text)),
          ),
          onSubmitted: _ekle,
        );
      },
    );
  }
}
