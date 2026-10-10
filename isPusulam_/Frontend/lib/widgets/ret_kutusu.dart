import 'package:flutter/material.dart';
import '../core/tema.dart';

/// İstediğin "kutucuk": işveren reddetmeden önce gerekçe yazmak ZORUNDA.
/// Boşsa veya çok kısaysa "Reddet" kapanmaz, hata gösterir. Geriye gerekçeyi döndürür (vazgeçerse null).
Future<String?> retGerekcesiIste(BuildContext context,
    {required String aday, required String asama}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false, // dışarı dokununca kapanmasın
    builder: (_) => _RetKutusu(aday: aday, asama: asama),
  );
}

class _RetKutusu extends StatefulWidget {
  final String aday, asama;
  const _RetKutusu({required this.aday, required this.asama});
  @override
  State<_RetKutusu> createState() => _RetKutusuState();
}

class _RetKutusuState extends State<_RetKutusu> {
  final _form = GlobalKey<FormState>();
  final _gerekce = TextEditingController();

  // Tek dokunuşla doldurulabilen hazır sebepler (işveren değiştirebilir)
  static const _oneriler = [
    'Aranan teknik yetkinlikler profilinle yeterince örtüşmedi.',
    'Bu pozisyon için daha fazla deneyim aranıyor.',
    'Mülakatta teknik bilgi düzeyi beklentimizin altında kaldı.',
  ];

  @override
  void dispose() {
    _gerekce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Renk.kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Kabul etmeme gerekçesi', style: serif(22)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${widget.aday} için ${widget.asama} aşamasında kabul etmiyorsun. Aday bu gerekçeyi bildirim olarak görecek; '
                      'kendini geliştirmesine yardımcı olur.',
                      style: const TextStyle(
                          color: Renk.soluk, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _gerekce,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                        hintText:
                            'Örn. React deneyimi beklentimizin altında kaldı...'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Gerekçe yazmak zorunludur';
                      if (v.trim().length < 10)
                        return 'Gerekçe en az 10 karakter olmalı';
                      return null;
                    },
                  ),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final o in _oneriler)
                      ActionChip(
                          label: Text(o, style: const TextStyle(fontSize: 11)),
                          onPressed: () => setState(() => _gerekce.text = o)),
                  ]),
                ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Renk.kil),
          onPressed: () {
            if (_form.currentState!.validate())
              Navigator.pop(context, _gerekce.text.trim());
          },
          child: const Text('Kabul etme'),
        ),
      ],
    );
  }
}
