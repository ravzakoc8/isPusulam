import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/oturum.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';

/// Giriş ve kayıt tek ekranda: üstteki düğmeyle değişir.
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});
  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _form = GlobalKey<FormState>();
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  final _ad = TextEditingController();
  final _soyad = TextEditingController();
  final _telefon = TextEditingController();
  final _sirket = TextEditingController();
  final _vergiNo = TextEditingController();
  bool _kayitMi = false;
  String _tip = 'aday';
  bool _gizli = true;
  bool _bekliyor = false;

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _bekliyor = true);
    try {
      final oturum = context.read<Oturum>();
      if (_kayitMi) {
        await oturum.kayit({
          'eposta': _eposta.text.trim(),
          'sifre': _sifre.text,
          'ad': _ad.text.trim(),
          'soyad': _soyad.text.trim(),
          'telefon': _telefon.text.trim(),
          'tip': _tip,
          'sirket_adi': _sirket.text.trim(),
          'vergi_no': _vergiNo.text.trim(),
        });
      } else {
        await oturum.giris(_eposta.text.trim(), _sifre.text);
      }
      // Başarılıysa main.dart otomatik olarak ana yapıya geçirir
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Row(children: [
        // Sol: tanıtım paneli (sadece geniş ekranda)
        if (genis)
          Expanded(
            child: Container(
              color: Renk.yesil,
              padding: const EdgeInsets.all(56),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.explore_outlined,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 32),
                    Text('Yeteneğin, CV\'nin ötesinde görünsün.',
                        style: serif(40, renk: Colors.white)),
                    const SizedBox(height: 18),
                    Text(
                        'Doğrulanmış becerilerle, net tanımlı ilanlarla ve gerekçeli geri dönüşlerle şeffaf bir işe alım süreci.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            height: 1.5)),
                    const SizedBox(height: 28),
                    for (final m in const [
                      'Beceri sınavlarıyla profilini kanıtla',
                      'Kabul edilmezsen sebebini öğren',
                      'Profil görünürlüğünü sen belirle'
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline,
                              color: Color(0xFFBFD8CB), size: 20),
                          const SizedBox(width: 10),
                          Text(m, style: const TextStyle(color: Colors.white)),
                        ]),
                      ),
                  ]),
            ),
          ),
        // Sağ: form
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!genis)
                          Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                                color: Renk.yesil,
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.explore_outlined,
                                color: Colors.white),
                          ),
                        Text(
                            _kayitMi
                                ? 'Hesabını oluştur.'
                                : 'Tekrar hoş geldin.',
                            style: serif(34)),
                        const SizedBox(height: 8),
                        Text(
                            _kayitMi
                                ? 'Profilini sen kontrol edersin.'
                                : 'işPusulam hesabınla giriş yap.',
                            style: const TextStyle(color: Renk.soluk)),
                        const SizedBox(height: 24),
                        if (_kayitMi) ...[
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'aday',
                                    label: Text('Adayım'),
                                    icon: Icon(Icons.school_outlined)),
                                ButtonSegment(
                                    value: 'isveren',
                                    label: Text('İşverenim'),
                                    icon: Icon(Icons.business_outlined)),
                              ],
                              selected: {_tip},
                              onSelectionChanged: (s) =>
                                  setState(() => _tip = s.first),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                                child: TextFormField(
                                    controller: _ad,
                                    decoration:
                                        const InputDecoration(labelText: 'Ad'),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Zorunlu'
                                            : null)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: TextFormField(
                                    controller: _soyad,
                                    decoration: const InputDecoration(
                                        labelText: 'Soyad'),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Zorunlu'
                                            : null)),
                          ]),
                          const SizedBox(height: 14),
                          if (_tip == 'isveren') ...[
                            TextFormField(
                                controller: _sirket,
                                decoration: const InputDecoration(
                                    labelText: 'Şirket adı'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Şirket adı zorunlu'
                                        : null),
                            const SizedBox(height: 14),
                            TextFormField(
                                controller: _vergiNo,
                                decoration: const InputDecoration(
                                    labelText: 'Vergi no (isteğe bağlı)')),
                            const SizedBox(height: 14),
                          ],
                        ],
                        TextFormField(
                          controller: _eposta,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: Icon(Icons.mail_outline)),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Geçerli bir e-posta gir'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        if (_kayitMi) ...[
                          TextFormField(
                              controller: _telefon,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'Telefon (isteğe bağlı)',
                                  prefixIcon: Icon(Icons.phone_outlined))),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _sifre,
                          obscureText: _gizli,
                          decoration: InputDecoration(
                            labelText:
                                _kayitMi ? 'Şifre (en az 6 karakter)' : 'Şifre',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_gizli
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _gizli = !_gizli),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Şifreni gir';
                            if (_kayitMi && v.length < 6)
                              return 'Şifre en az 6 karakter olmalı';
                            return null;
                          },
                          onFieldSubmitted: (_) => _gonder(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _bekliyor ? null : _gonder,
                            child: _bekliyor
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(_kayitMi ? 'Kayıt ol' : 'Giriş yap'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _kayitMi = !_kayitMi),
                            child: Text(_kayitMi
                                ? 'Zaten hesabın var mı? Giriş yap'
                                : 'Hesabın yok mu? Kayıt ol'),
                          ),
                        ),
                      ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
