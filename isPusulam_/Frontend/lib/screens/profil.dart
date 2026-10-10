import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';

/// Beceri rozetleri: doğrulanmış olanların yanında yeşil tik görünür.
class BeceriRozetleri extends StatelessWidget {
  final List<dynamic> beceriler;
  const BeceriRozetleri(this.beceriler, {super.key});

  @override
  Widget build(BuildContext context) {
    if (beceriler.isEmpty)
      return const Text('Henüz beceri eklenmemiş.',
          style: TextStyle(color: Renk.soluk, fontSize: 13));
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final b in beceriler)
        Etiket(
          b['ad'],
          zemin:
              b['dogrulanmis'] == true ? Renk.adacayi : const Color(0xFFF0EFE8),
          renk: b['dogrulanmis'] == true ? Renk.yesil : Renk.soluk,
          ikon: b['dogrulanmis'] == true ? Icons.verified_outlined : null,
        ),
    ]);
  }
}

/// Adayın KENDİ profilini düzenlediği pencere.
Future<void> profilDuzenleAc(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _ProfilDuzenle());
}

class _ProfilDuzenle extends StatelessWidget {
  const _ProfilDuzenle();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Renk.kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Yukle(
            getir: () => Api.get('/api/profil'),
            yap: (context, profil, yenile) =>
                _Form(profil: Map<String, dynamic>.from(profil)),
          ),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  final Map<String, dynamic> profil;
  const _Form({required this.profil});
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController _unvan, _bio, _telefon, _cv, _github;
  bool _bekliyor = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profil;
    _unvan = TextEditingController(text: p['unvan'] ?? '');
    _bio = TextEditingController(text: p['biyografi'] ?? '');
    _telefon = TextEditingController(text: p['telefon'] ?? '');
    _cv = TextEditingController(text: p['cv_url'] ?? '');
    _github = TextEditingController(text: p['github_url'] ?? '');
  }

  Future<void> _kaydet() async {
    setState(() => _bekliyor = true);
    try {
      await Api.put('/api/profil', {
        'unvan': _unvan.text,
        'biyografi': _bio.text,
        'telefon': _telefon.text,
        'cv_url': _cv.text,
        'github_url': _github.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      mesaj(context, 'Profilin güncellendi');
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profil;
    return SingleChildScrollView(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Avatar(
                  '${p['ad']} ${p['soyad']}'
                      .split(' ')
                      .map((e) => e.isEmpty ? '' : e[0])
                      .take(2)
                      .join(),
                  boyut: 52),
              const SizedBox(width: 14),
              Expanded(
                  child: Text('${p['ad']} ${p['soyad']}', style: serif(24))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 18),
            TextField(
                controller: _unvan,
                decoration: const InputDecoration(
                    labelText: 'Unvan (örn. Junior Product Designer)')),
            const SizedBox(height: 12),
            TextField(
                controller: _bio,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Kısa biyografi', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            TextField(
                controller: _telefon,
                decoration: const InputDecoration(labelText: 'Telefon')),
            const SizedBox(height: 12),
            TextField(
              controller: _cv,
              decoration: const InputDecoration(
                  labelText: 'CV (PDF) bağlantısı',
                  prefixIcon: Icon(Icons.description_outlined, size: 20),
                  hintText: 'https://drive.google.com/...',
                  helperText:
                      'CV PDF\'ini Google Drive\'a yükle, "bağlantıya sahip herkes görüntüleyebilir" yapıp linki yapıştır.\nBeceri sınavlarına girmek için gerekir.',
                  helperMaxLines: 3),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _github,
              decoration: const InputDecoration(
                  labelText: 'GitHub profili (isteğe bağlı)',
                  prefixIcon: Icon(Icons.code, size: 20),
                  hintText: 'https://github.com/kullaniciadi',
                  helperText: 'İşverenler projelerini görebilir'),
            ),
            const SizedBox(height: 18),
            Text('Becerilerin', style: serif(18)),
            const SizedBox(height: 8),
            BeceriRozetleri(p['becerileri'] ?? []),
            const SizedBox(height: 4),
            const Text(
                'Beceri eklemek ve doğrulamak için "Becerilerim" sayfasını kullan.',
                style: TextStyle(color: Renk.soluk, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _bekliyor ? null : _kaydet,
                  child: Text(_bekliyor ? 'Kaydediliyor...' : 'Kaydet')),
            ),
          ]),
    );
  }
}

/// İşverenin bir adayın profiline baktığı pencere (gizlilik kuralları sunucuda uygulanır).
Future<void> adayProfiliAc(BuildContext context, int adayId) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Renk.kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Yukle(
            getir: () => Api.get('/api/profil/$adayId'),
            yap: (context, p, yenile) => SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Avatar('${p['ad']} ${p['soyad']}', boyut: 52),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${p['ad']} ${p['soyad']}', style: serif(24)),
                            if (p['unvan'] != null)
                              Text(p['unvan'],
                                  style: const TextStyle(color: Renk.soluk)),
                          ])),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ]),
                    if (p['biyografi'] != null) ...[
                      const SizedBox(height: 16),
                      Text(p['biyografi'], style: const TextStyle(height: 1.5)),
                    ],
                    if (p['cv_url'] != null || p['github_url'] != null)
                      const SizedBox(height: 12),
                    if (p['cv_url'] != null)
                      _Baglanti(ikon: Icons.description_outlined, etiket: 'CV', adres: '${p['cv_url']}'),
                    if (p['github_url'] != null)
                      _Baglanti(ikon: Icons.code, etiket: 'GitHub', adres: '${p['github_url']}'),
                    const SizedBox(height: 18),
                    Text('Beceriler', style: serif(18)),
                    const SizedBox(height: 8),
                    BeceriRozetleri(p['becerileri'] ?? []),
                    const SizedBox(height: 6),
                    const Text('Yeşil tikli beceriler sınavla doğrulanmıştır.',
                        style: TextStyle(color: Renk.soluk, fontSize: 12)),
                  ]),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Aday profilindeki bir bağlantı satırı (CV, GitHub). Seçilebilir ve tek tıkla kopyalanabilir.
class _Baglanti extends StatelessWidget {
  final IconData ikon;
  final String etiket, adres;
  const _Baglanti({required this.ikon, required this.etiket, required this.adres});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(ikon, size: 18, color: Renk.soluk),
        const SizedBox(width: 8),
        Text('$etiket: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Expanded(child: SelectableText(adres, style: const TextStyle(fontSize: 13, color: Renk.yesil))),
        IconButton(
          tooltip: 'Bağlantıyı kopyala',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 16, color: Renk.soluk),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: adres));
            mesaj(context, '$etiket bağlantısı kopyalandı');
          },
        ),
      ]),
    );
  }
}
