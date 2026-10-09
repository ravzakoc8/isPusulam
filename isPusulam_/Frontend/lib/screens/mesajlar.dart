import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/bildirim_sayaci.dart';
import '../core/tema.dart';
import '../core/yardimci.dart';
import '../widgets/bilesenler.dart';

/// Mesajlar panelini sağdan açar. [kisiId] verilirse doğrudan o kişiyle yazışma açılır
/// (örn. başvuru kartındaki "Mesaj yaz" düğmesi). Panel kapanınca rozet güncellenir.
Future<void> mesajlasmaAc(BuildContext context,
    {int? kisiId, int? basvuruId}) async {
  final sayac = context.read<BildirimSayaci>();
  await panelAc(context,
      (ctx) => MesajlarPaneli(baslangicKisi: kisiId, basvuruId: basvuruId),
      genislik: 520);
  sayac.yenile();
}

class MesajlarPaneli extends StatefulWidget {
  final int? baslangicKisi;
  final int? basvuruId;
  const MesajlarPaneli({super.key, this.baslangicKisi, this.basvuruId});
  @override
  State<MesajlarPaneli> createState() => _MesajlarPaneliState();
}

class _MesajlarPaneliState extends State<MesajlarPaneli> {
  int? _secili;

  @override
  void initState() {
    super.initState();
    _secili = widget.baslangicKisi;
  }

  @override
  Widget build(BuildContext context) {
    if (_secili != null) {
      return _Sohbet(
        key: ValueKey(_secili),
        karsiId: _secili!,
        basvuruId: _secili == widget.baslangicKisi ? widget.basvuruId : null,
        geri: () => setState(() => _secili = null),
      );
    }
    return _KonusmaListesi(sec: (id) => setState(() => _secili = id));
  }
}

// =====================================================================
//  KONUŞMA LİSTESİ
// =====================================================================
class _KonusmaListesi extends StatefulWidget {
  final void Function(int) sec;
  const _KonusmaListesi({required this.sec});
  @override
  State<_KonusmaListesi> createState() => _KonusmaListesiState();
}

class _KonusmaListesiState extends State<_KonusmaListesi> {
  List<dynamic> _liste = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final j = await Api.get('/api/mesajlar');
      if (mounted)
        setState(() {
          _liste = j;
          _yukleniyor = false;
          _hata = null;
        });
    } on ApiHata catch (e) {
      if (mounted)
        setState(() {
          _hata = e.mesaj;
          _yukleniyor = false;
        });
    }
  }

  /// Daha önce yazışılmamış biriyle konuşma başlat (başvuru ilişkisi olan kişiler listelenir).
  Future<void> _yeniMesaj() async {
    final secilen = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Renk.kart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('Yeni mesaj', style: serif(22))),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ]),
                  const Text('Başvuru üzerinden bağlantın olan kişiler',
                      style: TextStyle(color: Renk.soluk, fontSize: 12)),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Yukle(
                        getir: () => Api.get('/api/mesajlar/kisiler'),
                        yap: (context, veri, yenile) {
                          final kisiler = veri as List;
                          if (kisiler.isEmpty)
                            return const BosDurum(
                                'Henüz başvuru üzerinden bağlantın yok.');
                          return Column(children: [
                            for (final k in kisiler)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading:
                                    Avatar('${k['gorunen_ad']}', boyut: 38),
                                title: Text('${k['gorunen_ad']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: k['alt_yazi'] == null
                                    ? null
                                    : Text('${k['alt_yazi']}',
                                        style: const TextStyle(fontSize: 12)),
                                onTap: () => Navigator.pop(
                                    ctx, (k['karsi_id'] as num).toInt()),
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
    if (secilen != null) widget.sec(secilen);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          const Spacer(),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Renk.soluk)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 20, 0),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Renk.adacayi, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.chat_bubble_outline, color: Renk.yesil),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('İŞPUSULAM', style: ustYazi()),
              Text('Mesajlar', style: serif(30)),
            ]),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _yeniMesaj,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Yeni'),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      const Divider(height: 1),
      Expanded(
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator(color: Renk.yesil))
            : _hata != null
                ? Center(child: Text(_hata!))
                : _liste.isEmpty
                    ? const BosDurum(
                        'Henüz mesajın yok.\nBaşvuru kartlarındaki "Mesaj yaz" ile ya da "Yeni" düğmesiyle yazışma başlatabilirsin.')
                    : RefreshIndicator(
                        onRefresh: _yukle,
                        child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                            children: [
                              for (final k in _liste)
                                _KonusmaSatiri(
                                    k: k,
                                    tikla: () => widget
                                        .sec((k['karsi_id'] as num).toInt())),
                            ]),
                      ),
      ),
    ]);
  }
}

class _KonusmaSatiri extends StatelessWidget {
  final Map k;
  final VoidCallback tikla;
  const _KonusmaSatiri({required this.k, required this.tikla});

  @override
  Widget build(BuildContext context) {
    final okunmamis = ((k['okunmamis'] ?? 0) as num).toInt();
    final benden = k['benden'] == true;
    return Kart(
      tikla: tikla,
      renk: okunmamis > 0 ? const Color(0xFFF3F7F3) : Renk.kart,
      ic: const EdgeInsets.all(12),
      dis: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Avatar('${k['gorunen_ad']}', boyut: 42),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text('${k['gorunen_ad']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis)),
              Text(zamanOnce(k['son_tarih']),
                  style: const TextStyle(fontSize: 11, color: Renk.soluk)),
            ]),
            if (k['alt_yazi'] != null)
              Text('${k['alt_yazi']}',
                  style: const TextStyle(fontSize: 11, color: Renk.soluk),
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Expanded(
                child: Text('${benden ? 'Sen: ' : ''}${k['son_mesaj']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            okunmamis > 0 ? FontWeight.w700 : FontWeight.w400)),
              ),
              if (okunmamis > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: Renk.kil, borderRadius: BorderRadius.circular(10)),
                  child: Text('$okunmamis',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
//  SOHBET
// =====================================================================
class _Sohbet extends StatefulWidget {
  final int karsiId;
  final int? basvuruId;
  final VoidCallback geri;
  const _Sohbet(
      {super.key, required this.karsiId, required this.geri, this.basvuruId});
  @override
  State<_Sohbet> createState() => _SohbetState();
}

class _SohbetState extends State<_Sohbet> {
  final _yazi = TextEditingController();
  Map<String, dynamic>? _veri;
  String? _hata;
  bool _gonderiliyor = false;
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    _yukle();
    // Karşı taraf yazarsa görünsün diye 5 saniyede bir yenile
    _zamanlayici = Timer.periodic(const Duration(seconds: 5), (_) => _yukle());
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _yazi.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final j = await Api.get('/api/mesajlar/${widget.karsiId}');
      if (mounted)
        setState(() {
          _veri = Map<String, dynamic>.from(j);
          _hata = null;
        });
    } on ApiHata catch (e) {
      if (mounted && _veri == null) setState(() => _hata = e.mesaj);
    }
  }

  Future<void> _gonder() async {
    final metin = _yazi.text.trim();
    if (metin.isEmpty || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    try {
      final m = await Api.post('/api/mesajlar/${widget.karsiId}', {
        'icerik': metin,
        if (widget.basvuruId != null) 'basvuru_id': widget.basvuruId,
      });
      _yazi.clear();
      if (mounted) {
        setState(() => (_veri!['mesajlar'] as List).add(m));
      }
    } on ApiHata catch (e) {
      if (mounted) mesaj(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final karsi = _veri?['karsi'] as Map?;
    final mesajlar = (_veri?['mesajlar'] ?? []) as List;
    final yazabilir = _veri?['yazabilir'] == true;
    final ad = karsi == null ? '' : '${karsi['gorunen_ad']}';

    return Column(children: [
      // Üst çubuk
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(children: [
          IconButton(
              onPressed: widget.geri,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Konuşmalar'),
          if (karsi != null) ...[
            Avatar(ad, boyut: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      karsi['alt_yazi'] != null
                          ? '${karsi['alt_yazi']}'
                          : (karsi['kullanici_tipi'] == 'isveren'
                              ? 'İşveren'
                              : 'Aday'),
                      style: const TextStyle(fontSize: 12, color: Renk.soluk),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            ),
          ] else
            const Spacer(),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Renk.soluk)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _hata != null
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_hata!, textAlign: TextAlign.center)))
            : _veri == null
                ? const Center(
                    child: CircularProgressIndicator(color: Renk.yesil))
                : mesajlar.isEmpty
                    ? BosDurum(yazabilir
                        ? 'Henüz mesaj yok. İlk mesajı sen yaz 👋'
                        : 'Henüz mesaj yok.')
                    : ListView.builder(
                        reverse:
                            true, // en yeni mesaj altta, liste otomatik aşağıda başlar
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: mesajlar.length,
                        itemBuilder: (_, i) =>
                            _Balon(m: mesajlar[mesajlar.length - 1 - i]),
                      ),
      ),
      const Divider(height: 1),
      if (_veri != null && !yazabilir)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('${_veri!['engel'] ?? 'Bu kişiye mesaj gönderemezsin.'}',
              style: const TextStyle(color: Renk.soluk, fontSize: 13),
              textAlign: TextAlign.center),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _yazi,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _gonder(),
                decoration: const InputDecoration(
                    hintText: 'Mesajını yaz...',
                    counterText: '',
                    isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Renk.yesil),
              onPressed: _gonderiliyor ? null : _gonder,
              icon: _gonderiliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ]),
        ),
    ]);
  }
}

class _Balon extends StatelessWidget {
  final Map m;
  const _Balon({required this.m});

  @override
  Widget build(BuildContext context) {
    final benden = m['benden'] == true;
    final t = tarihCoz(m['tarih']);
    final saat =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: benden ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: benden ? Renk.yesil : Renk.kart,
            border: benden ? null : Border.all(color: Renk.cizgi),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(benden ? 14 : 4),
              bottomRight: Radius.circular(benden ? 4 : 14),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SelectableText('${m['icerik']}',
                style: TextStyle(
                    color: benden ? Colors.white : Renk.yazi,
                    height: 1.4,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  '${gunGrubu(m['tarih']) == 'BUGÜN' ? '' : '${t.day}.${t.month.toString().padLeft(2, '0')} '}$saat',
                  style: TextStyle(
                      fontSize: 10,
                      color: benden ? Colors.white70 : Renk.soluk)),
              if (benden) ...[
                const SizedBox(width: 4),
                Icon(m['okundu'] == true ? Icons.done_all : Icons.done,
                    size: 13, color: Colors.white70),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
