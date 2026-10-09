import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';

/// "Becerilerini kanıtla" sayfası:
///  1) Profilindeki beceriler ve sınavla doğrulama
///  2) Yetenek Görevleri: kısa bir problemi çöz, yapay zekâ puanlasın
class BecerilerEkrani extends StatefulWidget {
  const BecerilerEkrani({super.key});
  @override
  State<BecerilerEkrani> createState() => _BecerilerEkraniState();
}

class _BecerilerEkraniState extends State<BecerilerEkrani> {
  Map? _sinavBeceri;   // doluysa sınav ekranı açık (hangi beceri)
  bool _sureli = false; // sağdaki "Süre tercihi"
  int _anahtar = 0;    // listeyi yeniden çektirmek için

  void _yenile() => setState(() => _anahtar++);

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.of(context).size.width >= 1000;

    final ana = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PROFİL KANITLARI / BECERİ DOĞRULAMA', style: ustYazi(renk: Renk.kil)),
      const SizedBox(height: 6),
      Text('Becerilerini kanıtla', style: serif(genis ? 46 : 34)),
      const SizedBox(height: 6),
      const Text('İstediğin beceriyi ekle, yapay zekânın hazırladığı sınavla doğrula, adil bir değerlendirmeyle görünür ol.', style: TextStyle(color: Renk.soluk)),
      const SizedBox(height: 20),
      // Üstteki büyük kart
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BECERİ KANITLARI', style: ustYazi(renk: Renk.kil)),
            const SizedBox(height: 8),
            Text('Bildiklerini, güven veren bir kanıta dönüştür.', style: serif(genis ? 32 : 24)),
            const SizedBox(height: 10),
            const Text('Burada doğru cevap ezber değil; nasıl düşündüğün ölçülür.', style: TextStyle(color: Renk.soluk)),
          ])),
          if (genis)
            Container(
              margin: const EdgeInsets.only(left: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Renk.kart, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tahmini süre', style: TextStyle(fontSize: 12, color: Renk.soluk)),
                Text('8–12 dk', style: serif(26)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 22),
      if (_sinavBeceri != null)
        _Sinav(
          key: ValueKey(_sinavBeceri!['beceri_id']),
          beceri: _sinavBeceri!,
          sureli: _sureli,
          kapat: () {
            setState(() => _sinavBeceri = null);
            _yenile();
          },
        )
      else ...[
        Text('Becerilerim', style: serif(26)),
        const SizedBox(height: 12),
        Yukle(
          key: ValueKey('b$_anahtar'),
          getir: () => Api.get('/api/becerilerim'),
          yap: (context, veri, yenile) {
            final liste = veri as List;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (liste.isEmpty) const BosDurum('Henüz beceri eklemedin. Aşağıdan ekleyebilirsin.'),
              for (final b in liste) _BeceriSatiri(b: b, sinavBaslat: () => setState(() => _sinavBeceri = b), yenile: _yenile),
              _BeceriEkle(eklendi: _yenile),
            ]);
          },
        ),
        const SizedBox(height: 26),
        Text('Yetenek Görevleri', style: serif(26)),
        const SizedBox(height: 6),
        const Text('Alanınla ilgili kısa bir problemi nasıl çözdüğün yapay zekâ tarafından değerlendirilir. Deneyimin olmasa bile yeteneğini gösterebilirsin.',
            style: TextStyle(color: Renk.soluk, height: 1.4)),
        const SizedBox(height: 12),
        Yukle(
          key: ValueKey('g$_anahtar'),
          getir: () => Api.get('/api/gorevler'),
          yap: (context, veri, yenile) {
            final liste = veri as List;
            if (liste.isEmpty) return const BosDurum('Şu an görev yok.');
            return Column(children: [for (final g in liste) _GorevKarti(g: g, yenile: _yenile)]);
          },
        ),
      ],
    ]);

    final sag = Column(children: [
      Kart(
        ic: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SÜRE TERCİHİ', style: ustYazi()),
          const SizedBox(height: 10),
          _SecimKutusu(yazi: 'Süreli', alt: 'Soru başına 1 dk · önerilen', secili: _sureli, tikla: () => setState(() => _sureli = true)),
          const SizedBox(height: 8),
          _SecimKutusu(yazi: 'Serbest tempo', alt: 'Sayaç olmadan', secili: !_sureli, tikla: () => setState(() => _sureli = false)),
        ]),
      ),
      Kart(
        ic: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SONUÇTA NE OLUR?', style: ustYazi()),
          const SizedBox(height: 8),
          Text('Beceri kanıtı', style: serif(22)),
          const SizedBox(height: 10),
          for (final m in const [
            'Sınava başlamadan geçme notunu ve kaç doğru gerektiğini görürsün.',
            'Baraj puanını geçersen beceri profilinde doğrulanmış görünür.',
            'Sınav sonunda yanlışlarını, doğru cevapları ve açıklamalarını görürsün.',
            'Sorular her denemede yapay zekâ ile yeniden üretilir; tekrar deneyebilirsin.',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline, size: 16, color: Renk.adacayiKoyu),
                const SizedBox(width: 8),
                Expanded(child: Text(m, style: const TextStyle(fontSize: 13, height: 1.4))),
              ]),
            ),
        ]),
      ),
    ]);

    return SayfaGovdesi(
      child: genis
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ana), const SizedBox(width: 24), SizedBox(width: 300, child: sag)])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ana, const SizedBox(height: 16), sag]),
    );
  }
}

class _SecimKutusu extends StatelessWidget {
  final String yazi, alt;
  final bool secili;
  final VoidCallback tikla;
  const _SecimKutusu({required this.yazi, required this.alt, required this.secili, required this.tikla});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tikla,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: secili ? Renk.adacayi : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: secili ? Renk.adacayiKoyu : Renk.cizgi),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(yazi, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(alt, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ]),
        ),
      );
}

String seviyeYazisi(dynamic s) => switch (s) { 'baslangic' => 'Başlangıç', 'ileri' => 'İleri', _ => 'Orta' };

/// Barajı geçmek için gereken en az doğru sayısı (sunucudaki hesapla aynı). Örn. %70 ve 10 soru -> 7.
int gerekenDogru(int baraj, int toplam) {
  for (var d = 0; d <= toplam; d++) {
    if ((d * 100 / toplam).round() >= baraj) return d;
  }
  return toplam;
}

/// Profildeki tek beceri satırı.
class _BeceriSatiri extends StatelessWidget {
  final Map b;
  final VoidCallback sinavBaslat;
  final VoidCallback yenile;
  const _BeceriSatiri({required this.b, required this.sinavBaslat, required this.yenile});

  @override
  Widget build(BuildContext context) {
    final dogrulandi = b['dogrulanmis'] == true;
    final baraj = ((b['baraj'] ?? 70) as num).toInt();
    final sonPuan = b['son_puan'];
    final deneme = ((b['deneme_sayisi'] ?? 0) as num).toInt();
    return Kart(
      ic: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      dis: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: dogrulandi ? Renk.adacayi : const Color(0xFFF0EFE8), borderRadius: BorderRadius.circular(12)),
          child: Icon(dogrulandi ? Icons.verified_outlined : Icons.psychology_outlined, color: dogrulandi ? Renk.yesil : Renk.soluk, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['ad'], style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            'Kendi seviyem: ${seviyeYazisi(b['kendi_seviyesi'])} · Geçme notu %$baraj'
            '${sonPuan != null ? ' · Son sınav: %$sonPuan' : ''}',
            style: const TextStyle(fontSize: 12, color: Renk.soluk),
          ),
        ])),
        if (dogrulandi)
          const Etiket('Doğrulandı', ikon: Icons.check)
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: sinavBaslat,
            icon: const Icon(Icons.quiz_outlined, size: 16),
            label: Text(deneme > 0 ? 'Tekrar dene' : 'Sınava gir'),
          ),
        IconButton(
          tooltip: 'Kaldır',
          icon: const Icon(Icons.close, size: 18, color: Renk.soluk),
          onPressed: () async {
            try {
              await Api.delete('/api/becerilerim/${b['beceri_id']}');
              yenile();
            } on ApiHata catch (e) {
              if (context.mounted) mesaj(context, e.mesaj, hata: true);
            }
          },
        ),
      ]),
    );
  }
}

/// Profiline yeni beceri ekleme satırı. Listede olmayan bir beceri de yazılabilir:
/// yapay zekâ gerçek bir beceri olup olmadığını kontrol edip ekler.
class _BeceriEkle extends StatelessWidget {
  final VoidCallback eklendi;
  const _BeceriEkle({required this.eklendi});

  @override
  Widget build(BuildContext context) {
    return Yukle(
      getir: () => Api.get('/api/beceriler'),
      yap: (context, veri, yenile) => _EkleForm(tumu: veri as List, eklendi: eklendi),
    );
  }
}

class _EkleForm extends StatefulWidget {
  final List tumu;
  final VoidCallback eklendi;
  const _EkleForm({required this.tumu, required this.eklendi});
  @override
  State<_EkleForm> createState() => _EkleFormState();
}

class _EkleFormState extends State<_EkleForm> {
  TextEditingController? _kontrol;
  String _seviye = 'orta';
  bool _bekliyor = false;

  Future<void> _ekle() async {
    final yazi = (_kontrol?.text ?? '').trim();
    if (yazi.isEmpty) {
      mesaj(context, 'Önce bir beceri yaz veya listeden seç', hata: true);
      return;
    }
    // Listede birebir varsa id ile, yoksa adıyla gönder (sunucu yapay zekâ ile kontrol edip ekler)
    int? id;
    for (final b in widget.tumu) {
      if ('${b['ad']}'.toLowerCase() == yazi.toLowerCase()) id = (b['beceri_id'] as num).toInt();
    }
    setState(() => _bekliyor = true);
    try {
      final b = await Api.post('/api/becerilerim', {
        if (id != null) 'beceri_id': id else 'ad': yazi,
        'kendi_seviyesi': _seviye,
      });
      _kontrol?.clear();
      if (mounted) mesaj(context, '"${b['ad']}" profiline eklendi. "Sınava gir" ile doğrulayabilirsin.');
      widget.eklendi();
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adlar = [for (final b in widget.tumu) '${b['ad']}'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Renk.cizgi), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Beceri ekle', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Listede olmayan bir beceriyi de yazabilirsin (örn. Kubernetes, Figma, Power BI); yapay zekâ kontrol edip ekler.',
            style: TextStyle(fontSize: 12, color: Renk.soluk)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 280,
            child: Autocomplete<String>(
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return adlar.where((a) => a.toLowerCase().contains(q)).take(8);
              },
              fieldViewBuilder: (context, kontrol, odak, gonder) {
                _kontrol = kontrol;
                return TextField(
                  controller: kontrol,
                  focusNode: odak,
                  decoration: const InputDecoration(labelText: 'Beceri ara veya yaz', isDense: true, prefixIcon: Icon(Icons.search, size: 18)),
                  onSubmitted: (_) => _ekle(),
                );
              },
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: _seviye,
              decoration: const InputDecoration(labelText: 'Seviyem', isDense: true),
              items: const [
                DropdownMenuItem(value: 'baslangic', child: Text('Başlangıç')),
                DropdownMenuItem(value: 'orta', child: Text('Orta')),
                DropdownMenuItem(value: 'ileri', child: Text('İleri')),
              ],
              onChanged: (v) => setState(() => _seviye = v!),
            ),
          ),
          FilledButton.icon(
            onPressed: _bekliyor ? null : _ekle,
            icon: _bekliyor
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add, size: 18),
            label: Text(_bekliyor ? 'Kontrol ediliyor...' : 'Ekle'),
          ),
        ]),
      ]),
    );
  }
}

// =====================================================================
//  YAPAY ZEKÂ İLE SINAV: hazırlık -> sorular -> sonuç (yanlışlar + açıklamalar)
// =====================================================================
class _Sinav extends StatefulWidget {
  final Map beceri;
  final bool sureli;
  final VoidCallback kapat;
  const _Sinav({super.key, required this.beceri, required this.sureli, required this.kapat});
  @override
  State<_Sinav> createState() => _SinavState();
}

class _SinavState extends State<_Sinav> {
  // Hazırlık
  late String _seviye;
  int _soruSayisi = 10;
  bool _hazirlaniyor = false;

  // Sınav
  Map<String, dynamic>? _test;
  int _i = 0;
  final Map<String, String> _cevaplar = {}; // soru no -> seçilen harf
  Timer? _zamanlayici;
  int _kalan = 0;
  bool _gonderiliyor = false;

  // Sonuç
  Map<String, dynamic>? _sonuc;

  int get _baraj => ((widget.beceri['baraj'] ?? 70) as num).toInt();

  @override
  void initState() {
    super.initState();
    final s = widget.beceri['kendi_seviyesi'];
    _seviye = (s == 'baslangic' || s == 'ileri') ? s : 'orta';
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  Future<void> _baslat() async {
    setState(() => _hazirlaniyor = true);
    try {
      final j = await Api.post('/api/sinav/baslat', {
        'beceri_id': widget.beceri['beceri_id'],
        'soru_sayisi': _soruSayisi,
        'seviye': _seviye,
      });
      if (!mounted) return;
      setState(() {
        _test = Map<String, dynamic>.from(j);
        _i = 0;
        _cevaplar.clear();
        _sonuc = null;
        _kalan = ((j['sure_saniye'] ?? 600) as num).toInt();
      });
      if (j['kaynak'] == 'hazir') {
        mesaj(context, 'Yapay zekâya ulaşılamadı; hazır soru bankasından ${j['soru_sayisi']} soru getirildi.');
      }
      if (widget.sureli) {
        _zamanlayici?.cancel();
        _zamanlayici = Timer.periodic(const Duration(seconds: 1), (t) {
          if (_kalan <= 1) {
            t.cancel();
            _gonder(); // süre bitti: o ana kadarki cevaplarla gönder
          } else {
            setState(() => _kalan--);
          }
        });
      }
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _hazirlaniyor = false);
    }
  }

  Future<void> _bitir() async {
    final sorular = _test!['sorular'] as List;
    final bos = sorular.length - _cevaplar.length;
    if (bos > 0) {
      final tamam = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Renk.kart,
          title: const Text('Sınavı bitir?'),
          content: Text('$bos soruyu boş bıraktın. Boş sorular yanlış sayılır.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Geri dön')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yine de bitir')),
          ],
        ),
      );
      if (tamam != true) return;
    }
    await _gonder();
  }

  Future<void> _gonder() async {
    if (_gonderiliyor || _sonuc != null || _test == null) return;
    _zamanlayici?.cancel();
    setState(() => _gonderiliyor = true);
    try {
      final j = await Api.post('/api/sinav/${_test!['oturum_id']}/gonder', {'cevaplar': _cevaplar});
      if (mounted) setState(() => _sonuc = Map<String, dynamic>.from(j));
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  void _tekrar() {
    _zamanlayici?.cancel();
    setState(() {
      _test = null;
      _sonuc = null;
      _cevaplar.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sonuc != null) return _sonucEkrani();
    if (_test != null) return _soruEkrani();
    return _hazirlikEkrani();
  }

  // ---------------- 1) HAZIRLIK ----------------
  Widget _hazirlikEkrani() {
    final gereken = gerekenDogru(_baraj, _soruSayisi);
    Widget bilgi(IconData ikon, String yazi) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ikon, size: 18, color: Renk.yesil),
            const SizedBox(width: 8),
            Expanded(child: Text(yazi, style: const TextStyle(fontSize: 13, height: 1.4))),
          ]),
        );
    return Kart(
      ic: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BECERİ SINAVI', style: ustYazi()),
        const SizedBox(height: 4),
        Text('${widget.beceri['ad']}', style: serif(26)),
        const SizedBox(height: 16),
        const Text('Zorluk seviyesi', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final s in const ['baslangic', 'orta', 'ileri'])
            ChoiceChip(
              label: Text(seviyeYazisi(s)),
              selected: _seviye == s,
              selectedColor: Renk.adacayi,
              onSelected: _hazirlaniyor ? null : (_) => setState(() => _seviye = s),
            ),
        ]),
        const SizedBox(height: 14),
        const Text('Soru sayısı', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final n in const [5, 10, 15])
            ChoiceChip(
              label: Text('$n soru'),
              selected: _soruSayisi == n,
              selectedColor: Renk.adacayi,
              onSelected: _hazirlaniyor ? null : (_) => setState(() => _soruSayisi = n),
            ),
        ]),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Geçme notu: %$_baraj', style: serif(20)),
            const SizedBox(height: 4),
            Text('$_soruSayisi sorudan en az $gereken doğru yapmalısın (en fazla ${_soruSayisi - gereken} yanlış).',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            bilgi(Icons.timer_outlined,
                widget.sureli ? 'Süre: $_soruSayisi dakika (soru başına 1 dk). Süre bitince cevapların otomatik gönderilir.' : 'Serbest tempo: süre sınırı yok.'),
            bilgi(Icons.auto_awesome, 'Sorular seçtiğin beceri ve seviyeye göre yapay zekâ tarafından her denemede yeniden üretilir.'),
            bilgi(Icons.fact_check_outlined, 'Sınav sonunda yanlışlarını, doğru cevapları ve açıklamalarını göreceksin.'),
            bilgi(Icons.verified_outlined, 'Geçersen beceri profilinde "doğrulanmış" görünür ve ilan eşleşmen güçlenir.'),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          TextButton(onPressed: _hazirlaniyor ? null : widget.kapat, child: const Text('Vazgeç', style: TextStyle(color: Renk.soluk))),
          const Spacer(),
          FilledButton.icon(
            onPressed: _hazirlaniyor ? null : _baslat,
            icon: _hazirlaniyor
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow),
            label: Text(_hazirlaniyor ? 'Sorular hazırlanıyor...' : 'Sınavı başlat'),
          ),
        ]),
      ]),
    );
  }

  // ---------------- 2) SORULAR ----------------
  Widget _soruEkrani() {
    final sorular = _test!['sorular'] as List;
    final soru = sorular[_i];
    final secenekler = soru['secenekler'] as List;
    final soruNo = '${soru['no']}';
    final son = _i == sorular.length - 1;
    final dakika = (_kalan ~/ 60).toString().padLeft(2, '0');
    final saniye = (_kalan % 60).toString().padLeft(2, '0');

    return Kart(
      ic: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BECERİ DEĞERLENDİRMESİ · ${seviyeYazisi(_test!['seviye']).toUpperCase()}', style: ustYazi()),
            Text('${_test!['beceri_ad']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Geçme notu %${_test!['baraj']} · en az ${_test!['gereken_dogru']} doğru',
                style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          ])),
          Text(widget.sureli ? '$dakika:$saniye' : 'Serbest tempo',
              style: TextStyle(color: widget.sureli && _kalan < 60 ? Renk.kil : Renk.soluk, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        // Soru noktaları: tıklayıp soruya atla; cevaplananlar dolu
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var k = 0; k < sorular.length; k++)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _i = k),
              child: Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cevaplar.containsKey('${sorular[k]['no']}') ? Renk.adacayiKoyu : Renk.adacayi,
                  borderRadius: BorderRadius.circular(8),
                  border: k == _i ? Border.all(color: Renk.yesil, width: 2) : null,
                ),
                child: Text('${k + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _cevaplar.containsKey('${sorular[k]['no']}') ? Colors.white : Renk.yazi)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text('${_cevaplar.length} / ${sorular.length} cevaplandı', style: const TextStyle(fontSize: 12, color: Renk.soluk)),
        const SizedBox(height: 18),
        Text('SORU ${_i + 1}', style: ustYazi()),
        const SizedBox(height: 8),
        SelectableText('${soru['soru']}', style: serif(20)),
        const SizedBox(height: 18),
        for (final s in secenekler)
          Builder(builder: (context) {
            final yazi = s.toString();
            final harf = yazi.isNotEmpty ? yazi[0] : '?';
            final secili = _cevaplar[soruNo] == harf;
            return Kart(
              tikla: () => setState(() => _cevaplar[soruNo] = harf),
              kenar: secili ? Renk.yesil : Renk.cizgi,
              renk: secili ? Renk.adacayi : Renk.kart,
              ic: const EdgeInsets.all(14),
              dis: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 26, height: 26, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: secili ? Renk.yesil : Renk.cizgi)),
                  child: Text(harf, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(yazi.length > 3 ? yazi.substring(3) : yazi)),
              ]),
            );
          }),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton(onPressed: _i == 0 ? null : () => setState(() => _i--), child: const Text('Geri')),
          const Spacer(),
          if (!son)
            FilledButton(onPressed: () => setState(() => _i++), child: const Text('İleri'))
          else
            FilledButton(onPressed: _gonderiliyor ? null : _bitir, child: Text(_gonderiliyor ? 'Gönderiliyor...' : 'Sınavı bitir')),
        ]),
        if (!son)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _gonderiliyor ? null : _bitir, child: const Text('Sınavı şimdi bitir')),
          ),
        TextButton(
          onPressed: () {
            _zamanlayici?.cancel();
            widget.kapat();
          },
          child: const Text('Vazgeç (sonuç kaydedilmez)', style: TextStyle(color: Renk.soluk)),
        ),
      ]),
    );
  }

  // ---------------- 3) SONUÇ ----------------
  Widget _sonucEkrani() {
    final r = _sonuc!;
    final gecti = r['gecti'] == true;
    final dogru = (r['dogru'] as num).toInt();
    final toplam = (r['toplam'] as num).toInt();
    final eksik = ((r['eksik_dogru'] ?? 0) as num).toInt();
    final detay = (r['detay'] ?? []) as List;
    final yanlislar = detay.where((d) => d['dogru_mu'] != true).toList();

    String secenekYazisi(List secenekler, dynamic harf) {
      if (harf == null) return 'Boş bıraktın';
      for (final s in secenekler) {
        if ('$s'.startsWith('$harf')) return '$s';
      }
      return '$harf';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Kart(
        ic: const EdgeInsets.all(28),
        child: Column(children: [
          YuzdeHalka((r['puan'] as num).toInt(), boyut: 96),
          const SizedBox(height: 16),
          Text(gecti ? 'Beceri doğrulandı!' : 'Bu sefer olmadı', style: serif(28)),
          const SizedBox(height: 8),
          Text('$toplam sorudan $dogru doğru · Geçme notu %${r['baraj']} (en az ${r['gereken_dogru']} doğru)',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
              gecti
                  ? '${_test!['beceri_ad']} becerin profilinde doğrulanmış olarak görünecek.'
                  : 'Geçmek için $eksik doğru daha gerekiyordu. Aşağıdaki açıklamalara göz atıp tekrar deneyebilirsin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Renk.soluk)),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            if (!gecti) OutlinedButton.icon(onPressed: _tekrar, icon: const Icon(Icons.refresh), label: const Text('Tekrar dene')),
            FilledButton(onPressed: widget.kapat, child: const Text('Tamam')),
          ]),
        ]),
      ),
      const SizedBox(height: 6),
      Text(yanlislar.isEmpty ? 'Tüm soruları doğru yaptın 🎉' : 'Yanlış / boş bıraktığın sorular (${yanlislar.length})', style: serif(22)),
      const SizedBox(height: 10),
      for (final d in detay)
        Kart(
          kenar: d['dogru_mu'] == true ? Renk.adacayiKoyu : Renk.kil.withOpacity(0.6),
          ic: const EdgeInsets.all(16),
          dis: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(d['dogru_mu'] == true ? Icons.check_circle : Icons.cancel,
                  color: d['dogru_mu'] == true ? Renk.adacayiKoyu : Renk.kil, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${(d['no'] as num).toInt() + 1}. ${d['soru']}', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))),
            ]),
            if (d['dogru_mu'] != true) ...[
              const SizedBox(height: 8),
              Text('Senin cevabın: ${secenekYazisi(d['secenekler'] as List, d['verilen'])}',
                  style: const TextStyle(color: Renk.kil, fontSize: 13)),
            ],
            const SizedBox(height: 4),
            Text('Doğru cevap: ${secenekYazisi(d['secenekler'] as List, d['dogru'])}',
                style: const TextStyle(color: Renk.yesil, fontSize: 13, fontWeight: FontWeight.w600)),
            if ('${d['aciklama'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(10)),
                child: Text('${d['aciklama']}', style: const TextStyle(fontSize: 13, height: 1.45)),
              ),
            ],
          ]),
        ),
    ]);
  }
}

// =====================================================================
//  YETENEK GÖREVLERİ
// =====================================================================
class _GorevKarti extends StatelessWidget {
  final Map g;
  final VoidCallback yenile;
  const _GorevKarti({required this.g, required this.yenile});

  @override
  Widget build(BuildContext context) {
    final puan = g['son_puan'];
    return Kart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Etiket(g['beceri_ad'], ikon: Icons.psychology_outlined),
          const Spacer(),
          if (puan != null)
            Etiket('Son puan: %$puan', zemin: g['gecti_mi'] == true ? Renk.adacayi : Renk.kilAcik, renk: g['gecti_mi'] == true ? Renk.yesil : Renk.kil),
        ]),
        const SizedBox(height: 10),
        Text(g['problem'], style: const TextStyle(height: 1.5)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
          onPressed: () async {
            await showDialog(context: context, builder: (_) => _GorevDialog(g: g));
            yenile();
          },
          child: Text(puan == null ? 'Görevi çöz' : 'Tekrar dene'),
        ),
      ]),
    );
  }
}

class _GorevDialog extends StatefulWidget {
  final Map g;
  const _GorevDialog({required this.g});
  @override
  State<_GorevDialog> createState() => _GorevDialogState();
}

class _GorevDialogState extends State<_GorevDialog> {
  final _cevap = TextEditingController();
  bool _bekliyor = false;
  Map<String, dynamic>? _sonuc;

  Future<void> _gonder() async {
    if (_cevap.text.trim().isEmpty) {
      mesaj(context, 'Önce cevabını yaz', hata: true);
      return;
    }
    setState(() => _bekliyor = true);
    try {
      final j = await Api.post('/api/gorevler/${widget.g['test_id']}/cevap', {'cevap': _cevap.text});
      if (mounted) setState(() => _sonuc = Map<String, dynamic>.from(j));
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Renk.kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Yetenek Görevi', style: serif(24))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              Text(widget.g['problem'], style: const TextStyle(height: 1.5)),
              const SizedBox(height: 16),
              if (_sonuc == null) ...[
                TextField(controller: _cevap, maxLines: 7, decoration: const InputDecoration(hintText: 'Cevabını buraya yaz...')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _bekliyor ? null : _gonder, child: Text(_bekliyor ? 'Yapay zekâ değerlendiriyor...' : 'Gönder')),
                ),
              ] else ...[
                Row(children: [
                  YuzdeHalka((_sonuc!['puan'] as num).toInt(), boyut: 72),
                  const SizedBox(width: 16),
                  Expanded(child: Text(_sonuc!['gecti'] == true ? 'Harika! Beceri doğrulandı.' : 'Baraj puanına ulaşamadın, tekrar deneyebilirsin.',
                      style: serif(20))),
                ]),
                if ((_sonuc!['geri_bildirim'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(14)),
                    child: Text(_sonuc!['geri_bildirim'], style: const TextStyle(height: 1.5)),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
