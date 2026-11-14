import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/cafe_design.dart';
import '../data/admin_repository.dart';

/// Tambah / edit menu (C2).
///
/// Field: nama, kategori, deskripsi, harga, stasiun (Bar/Dapur),
/// waktu produksi (menit), batas penyimpanan (menit, opsional —
/// kosong = pakai default cafe), foto (URL, opsional), tersedia.
class MenuFormPage extends StatefulWidget {
  const MenuFormPage({super.key, this.menu});

  /// Null = tambah baru; terisi = edit.
  final Map<String, dynamic>? menu;

  @override
  State<MenuFormPage> createState() => _MenuFormPageState();
}

class _MenuFormPageState extends State<MenuFormPage> {
  final _repo = AdminRepository();
  final _nama = TextEditingController();
  final _kategori = TextEditingController();
  final _deskripsi = TextEditingController();
  final _harga = TextEditingController();
  final _waktu = TextEditingController();
  final _batasSimpan = TextEditingController();
  final _foto = TextEditingController();

  List<Map<String, dynamic>> _stations = [];
  String? _stationId;
  String? _cafeId;
  bool _available = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.menu;
    if (m != null) {
      _nama.text = m['nama'] as String? ?? '';
      _kategori.text = m['kategori'] as String? ?? '';
      _deskripsi.text = m['deskripsi'] as String? ?? '';
      _harga.text = (m['harga'] as int? ?? 0).toString();
      _waktu.text = (m['waktu_produksi_menit'] as int? ?? 5).toString();
      _batasSimpan.text =
          (m['batas_penyimpanan_menit'] as int?)?.toString() ?? '';
      _foto.text = m['foto_url'] as String? ?? '';
      _stationId = m['station_id'] as String?;
      _available = m['is_available'] as bool? ?? true;
    } else {
      _waktu.text = '5';
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final cafe = await _repo.fetchCafe();
      final stations = await _repo.fetchStations();
      if (!mounted) return;
      setState(() {
        _cafeId = cafe?['id'] as String?;
        _stations = stations;
        _stationId ??= stations.isNotEmpty
            ? stations.first['id'] as String?
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat: $e';
      });
    }
  }

  Future<void> _save() async {
    final harga = int.tryParse(_harga.text.trim());
    final waktu = int.tryParse(_waktu.text.trim());
    final batasSimpan = _batasSimpan.text.trim().isEmpty
        ? null
        : int.tryParse(_batasSimpan.text.trim());
    if (_nama.text.trim().isEmpty || harga == null || waktu == null) {
      setState(() => _error = 'Isi nama, harga (angka), dan waktu produksi.');
      return;
    }
    if (_stationId == null || _cafeId == null) {
      setState(() => _error = 'Stasiun/cafe belum termuat. Coba lagi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.upsertMenu(
        id: widget.menu?['id'] as String?,
        cafeId: _cafeId!,
        stationId: _stationId!,
        nama: _nama.text,
        deskripsi: _deskripsi.text,
        kategori: _kategori.text,
        harga: harga,
        fotoUrl: _foto.text,
        waktuProduksiMenit: waktu,
        batasSimpanMenit: batasSimpan,
        isAvailable: _available,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _kategori.dispose();
    _deskripsi.dispose();
    _harga.dispose();
    _waktu.dispose();
    _batasSimpan.dispose();
    _foto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.menu != null;
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        title: Text(
          isEdit ? 'Edit Menu' : 'Tambah Menu',
          style: CafeText.pageTitle,
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Nama menu', _nama, hint: 'Kopi Susu Aren'),
                  const SizedBox(height: 16),
                  _field('Kategori', _kategori, hint: 'Kopi'),
                  const SizedBox(height: 16),
                  _field(
                    'Deskripsi',
                    _deskripsi,
                    hint: 'Manis pas, creamy',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'Harga (Rp)',
                    _harga,
                    hint: '22000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Stasiun', style: CafeText.toggleTitle),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _stationId,
                    decoration: _decoration(),
                    items: _stations
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s['id'] as String,
                            child: Text(s['nama'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _stationId = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Waktu produksi (mnt)',
                          _waktu,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Batas simpan (mnt)',
                          _batasSimpan,
                          hint: 'kosong = default',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'Foto (URL, opsional)',
                    _foto,
                    hint: 'https://...',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: _available,
                        activeThumbColor: CafeColors.accent,
                        onChanged: (v) =>
                            setState(() => _available = v),
                      ),
                      Text(
                        _available ? 'Tersedia' : 'Habis',
                        style: CafeText.toggleTitle,
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: CafeText.cardSub
                          .copyWith(color: CafeColors.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CafeColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEdit ? 'Simpan perubahan' : 'Tambah menu',
                              style: CafeText.buttonLabel,
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CafeText.toggleTitle),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: CafeText.body,
          decoration: _decoration(hint: hint),
        ),
      ],
    );
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: CafeText.searchHint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CafeColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CafeColors.border),
      ),
    );
  }
}
