import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bildirim_sayaci.dart';
import '../core/oturum.dart';
import '../core/tema.dart';
import '../widgets/bilesenler.dart';

/// Sağdan açılan "Kontrol sende." paneli: profil görünürlüğü ve çıkış.
/// Görünürlük, kullanicilar.profil_gizliligi sütununa yazılır:
///   Açık                          -> herkese_acik
///   Özel + doğrulanmış işverenler -> sadece_isverenler
///   Özel (işverenler kapalı)      -> gizli
class AyarlarPaneli extends StatelessWidget {
  const AyarlarPaneli({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
        child: Row(children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18, color: Renk.soluk),
            label: const Text('Kapat', style: TextStyle(color: Renk.soluk)),
          ),
          const Spacer(),
          Text('HESAP AYARLARI', style: ustYazi()),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: Yukle(
            getir: () => Api.get('/api/profil'),
            yap: (context, profil, yenile) => _Icerik(profil: Map<String, dynamic>.from(profil)),
          ),
        ),
      ),
    ]);
  }
}

class _Icerik extends StatefulWidget {
  final Map<String, dynamic> profil;
  const _Icerik({required this.profil});
  @override
  State<_Icerik> createState() => _IcerikState();
}

class _IcerikState extends State<_Icerik> {
  late bool _ozel;
  late bool _isverenlerGorsun;

  @override
  void initState() {
    super.initState();
    final giz = widget.profil['profil_gizliligi'] ?? 'herkese_acik';
    _ozel = giz != 'herkese_acik';
    _isverenlerGorsun = giz == 'sadece_isverenler';
  }

  Future<void> _kaydet() async {
    final deger = !_ozel ? 'herkese_acik' : (_isverenlerGorsun ? 'sadece_isverenler' : 'gizli');
    try {
      await Api.put('/api/profil/gizlilik', {'profil_gizliligi': deger});
      if (mounted) mesaj(context, 'Gizlilik ayarın güncellendi');
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isveren = widget.profil['kullanici_tipi'] == 'isveren';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('GÜVENLİ ALAN', style: ustYazi()),
      const SizedBox(height: 6),
      Text('Kontrol sende.', style: serif(40)),
      const SizedBox(height: 10),
      Text(isveren ? 'Hesap bilgilerin aşağıda.' : 'Profilini kimlerin göreceğine sen karar verirsin.',
          style: const TextStyle(color: Renk.soluk, height: 1.4)),
      const SizedBox(height: 20),
      if (isveren) ...[
        Kart(child: Row(children: [
          Avatar(widget.profil['sirket_adi'] ?? '', boyut: 46),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.profil['sirket_adi'] ?? '', style: serif(20)),
            Text(widget.profil['eposta'] ?? '', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
          ])),
          if (widget.profil['dogrulanmis'] == true) const Etiket('Doğrulanmış', ikon: Icons.verified_outlined)
          else const Etiket('Doğrulama bekliyor', zemin: Renk.kilAcik, renk: Renk.kil),
        ])),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Renk.adacayi, borderRadius: BorderRadius.circular(16)),
          child: const Row(children: [
            Icon(Icons.lock_outline, color: Renk.yesil),
            SizedBox(width: 12),
            Expanded(child: Text('Gizlilik senin elinde. Bilgilerin yalnızca seçtiğin kişilere görünür.', style: TextStyle(height: 1.4))),
          ]),
        ),
        const SizedBox(height: 26),
        Text('Görünürlük', style: serif(20, renk: Renk.yesil)),
        const SizedBox(height: 10),
        Kart(child: Column(children: [
          Row(children: [
            const Icon(Icons.visibility_outlined, color: Renk.soluk),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Profil görünürlüğü', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('Özel: sadece izin verdiklerin görür. Açık: herkes görür.', style: TextStyle(color: Renk.soluk, fontSize: 12)),
            ])),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: true, label: Text('Özel')), ButtonSegment(value: false, label: Text('Açık'))],
              selected: {_ozel},
              onSelectionChanged: (s) {
                setState(() => _ozel = s.first);
                _kaydet();
              },
            ),
          ]),
          if (_ozel) ...[
            const Divider(height: 28),
            Row(children: [
              const Icon(Icons.verified_user_outlined, color: Renk.soluk),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Doğrulanmış işverenler', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Açıksa doğrulanmış işverenler profilini görebilir. Kapalıysa profilin tamamen gizli kalır.',
                    style: TextStyle(color: Renk.soluk, fontSize: 12)),
              ])),
              Switch(
                value: _isverenlerGorsun,
                activeColor: Renk.yesil,
                onChanged: (v) {
                  setState(() => _isverenlerGorsun = v);
                  _kaydet();
                },
              ),
            ]),
          ],
        ])),
        const SizedBox(height: 6),
        const Text('Not: Bir ilana başvurduysan, o ilanın işvereni gizlilik ayarından bağımsız olarak profilini görebilir.',
            style: TextStyle(color: Renk.soluk, fontSize: 12, height: 1.4)),
      ],
      const SizedBox(height: 28),
      OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          context.read<BildirimSayaci>().durdur();
          context.read<Oturum>().cikis();
        },
        icon: const Icon(Icons.logout),
        label: const Text('Çıkış yap'),
      ),
    ]);
  }
}
