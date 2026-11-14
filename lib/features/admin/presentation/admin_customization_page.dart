import 'package:flutter/material.dart';

import '../../../core/theme/cafe_design.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_repository.dart';
import 'admin_scaffold.dart';

/// Kustomisasi cafe (C7): nama, logo (URL), warna primer & sekunder,
/// batas penyimpanan default + preview tampilan customer.
///
/// Catatan: tema aplikasi saat ini memakai warna aksen hijau Figma
/// (#355D4C) yang dikunci di `cafe_design.dart`. Warna yang disimpan
/// di sini adalah data kustomisasi cafe (dipakai preview + disiapkan
/// untuk tema dinamis) — mengganti tema aplikasi secara penuh dari
/// database adalah langkah lanjutan.
class AdminCustomizationPage extends StatefulWidget {
  const AdminCustomizationPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AdminCustomizationPage> createState() =>
      _AdminCustomizationPageState();
}

class _AdminCustomizationPageState extends State<AdminCustomizationPage> {
  final _repo = AdminRepository();
  final _nama = TextEditingController();
  final _logo = TextEditingController();
  final _primer = TextEditingController();
  final _sekunder = TextEditingController();
  final _batasSimpan = TextEditingController();

  String? _cafeId;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cafe = await _repo.fetchCafe();
      if (!mounted) return;
      _nama.text = cafe?['nama'] as String? ?? '';
      _logo.text = cafe?['logo_url'] as String? ?? '';
      _primer.text = cafe?['warna_primer'] as String? ?? '';
      _sekunder.text = cafe?['warna_sekunder'] as String? ?? '';
      _batasSimpan.text =
          (cafe?['batas_penyimpanan_default_menit'] as int?)?.toString() ??
              '';
      setState(() {
        _cafeId = cafe?['id'] as String?;
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

  Color? _parseHex(String text) {
    final hex = text.trim().replaceAll('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 + value);
  }

  Future<void> _save() async {
    if (_cafeId == null || _nama.text.trim().isEmpty) {
      setState(() => _error = 'Nama cafe wajib diisi.');
      return;
    }
    final primer = _primer.text.trim();
    final sekunder = _sekunder.text.trim();
    if ((primer.isNotEmpty && _parseHex(primer) == null) ||
        (sekunder.isNotEmpty && _parseHex(sekunder) == null)) {
      setState(() => _error = 'Warna harus format hex, mis. #7B3F00.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });
    try {
      await _repo.updateCafe(
        cafeId: _cafeId!,
        values: {
          'nama': _nama.text.trim(),
          'logo_url':
              _logo.text.trim().isEmpty ? null : _logo.text.trim(),
          'warna_primer': primer.isEmpty ? null : primer,
          'warna_sekunder': sekunder.isEmpty ? null : sekunder,
          'batas_penyimpanan_default_menit':
              _batasSimpan.text.trim().isEmpty
                  ? null
                  : int.tryParse(_batasSimpan.text.trim()),
        },
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = 'Kustomisasi tersimpan.';
      });
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
    _logo.dispose();
    _primer.dispose();
    _sekunder.dispose();
    _batasSimpan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primerColor = _parseHex(_primer.text);
    final sekunderColor = _parseHex(_sekunder.text);
    return AdminScaffold(
      title: 'Kustomisasi',
      currentRoute: '/admin/customization',
      auth: widget.auth,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview tampilan customer',
                    style: CafeText.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CafeColors.background,
                      border: Border.all(color: CafeColors.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primerColor ?? CafeColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_cafe_outlined,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nama.text.isEmpty
                                      ? 'Nama Cafe'
                                      : _nama.text,
                                  style: CafeText.cardTitle
                                      .copyWith(fontSize: 22),
                                ),
                                Text(
                                  'KOPI & CERITA',
                                  style: CafeText.eyebrow()
                                      .copyWith(fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _swatch('Primer', primerColor),
                            const SizedBox(width: 12),
                            _swatch('Sekunder', sekunderColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _field('Nama cafe', _nama, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 16),
                  _field(
                    'Logo (URL gambar)',
                    _logo,
                    hint: 'https://...',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Warna primer (hex)',
                          _primer,
                          hint: '#7B3F00',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Warna sekunder (hex)',
                          _sekunder,
                          hint: '#E0671F',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'Batas simpan default (mnt)',
                    _batasSimpan,
                    hint: '30',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dipakai bila menu tidak punya batas simpan sendiri.',
                    style: CafeText.cardSub,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: CafeText.cardSub
                          .copyWith(color: CafeColors.danger),
                    ),
                  ],
                  if (_saved != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _saved!,
                      style: CafeText.cardSub
                          .copyWith(color: CafeColors.accent),
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
                          : Text('Simpan', style: CafeText.buttonLabel),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Catatan: tema aplikasi saat ini memakai aksen hijau '
                    'Figma. Warna di atas tersimpan sebagai data '
                    'kustomisasi cafe.',
                    style: CafeText.menuMeta,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _swatch(String label, Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color ?? CafeColors.border,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: CafeColors.border),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: CafeText.cardSub),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CafeText.toggleTitle),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: CafeText.body,
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }
}
