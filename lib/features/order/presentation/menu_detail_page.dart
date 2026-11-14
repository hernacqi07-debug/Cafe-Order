import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../cart/cart_controller.dart';

/// Detail Menu — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Detail menu).
///
/// Grup opsi live dari `menu_options` + `menu_option_values`:
/// single wajib (pilih 1, default nilai pertama), single opsional,
/// dan multiple (boleh lebih dari 1). Harga satuan = harga dasar +
/// tambahan harga opsi yang dipilih; CTA menampilkan total (satuan × jumlah).
class MenuDetailPage extends StatefulWidget {
  const MenuDetailPage({
    super.key,
    required this.menuId,
    required this.cart,
  });

  final String menuId;
  final CartController cart;

  @override
  State<MenuDetailPage> createState() => _MenuDetailPageState();
}

class _MenuOptionGroup {
  _MenuOptionGroup({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.wajib,
    required this.values,
  });

  final String id;
  final String nama;
  final String tipe; // 'single' | 'multiple'
  final bool wajib;
  final List<Map<String, dynamic>> values;
}

class _MenuDetailPageState extends State<MenuDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _menu;
  List<_MenuOptionGroup> _groups = [];

  /// Pilihan per grup: id grup -> daftar id nilai yang dipilih.
  final Map<String, List<String>> _selected = {};
  final _noteController = TextEditingController();
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;
    try {
      final menu = await client
          .from('menus')
          .select(
            'id, nama, deskripsi, kategori, harga, foto_url, '
            'waktu_produksi_menit, is_available, station_id, stations(nama)',
          )
          .eq('id', widget.menuId)
          .maybeSingle();
      if (menu == null) throw Exception('Menu tidak ditemukan');

      final options = await client
          .from('menu_options')
          .select(
            'id, nama, tipe, wajib, urutan, '
            'menu_option_values(id, nama, tambahan_harga)',
          )
          .eq('menu_id', widget.menuId)
          .order('urutan');

      final groups = <_MenuOptionGroup>[];
      for (final row in (options as List)) {
        final values =
            List<Map<String, dynamic>>.from(row['menu_option_values'] ?? []);
        groups.add(
          _MenuOptionGroup(
            id: row['id'] as String,
            nama: row['nama'] as String? ?? '',
            tipe: row['tipe'] as String? ?? 'single',
            wajib: row['wajib'] as bool? ?? false,
            values: values,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _menu = menu;
        _groups = groups;
        // Grup single wajib langsung terpilih nilai pertamanya.
        for (final g in groups) {
          if (g.tipe == 'single' && g.wajib && g.values.isNotEmpty) {
            _selected[g.id] = [g.values.first['id'] as String];
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  int get _basePrice => (_menu?['harga'] as num?)?.toInt() ?? 0;

  int get _unitPrice {
    var price = _basePrice;
    for (final g in _groups) {
      for (final valueId in _selected[g.id] ?? const <String>[]) {
        final v = g.values.firstWhere(
          (e) => e['id'] == valueId,
          orElse: () => <String, dynamic>{},
        );
        price += (v['tambahan_harga'] as num?)?.toInt() ?? 0;
      }
    }
    return price;
  }

  List<CartOption> get _chosenOptions {
    final out = <CartOption>[];
    for (final g in _groups) {
      for (final valueId in _selected[g.id] ?? const <String>[]) {
        final v = g.values.firstWhere(
          (e) => e['id'] == valueId,
          orElse: () => <String, dynamic>{},
        );
        if (v.isEmpty) continue;
        out.add(
          CartOption(
            optionId: g.id,
            optionName: g.nama,
            valueId: valueId,
            valueName: v['nama'] as String? ?? '',
            tambahanHarga: (v['tambahan_harga'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return out;
  }

  void _toggleValue(_MenuOptionGroup group, String valueId) {
    setState(() {
      final current = _selected[group.id] ?? <String>[];
      if (group.tipe == 'multiple') {
        if (current.contains(valueId)) {
          current.remove(valueId);
        } else {
          current.add(valueId);
        }
        _selected[group.id] = current;
      } else {
        _selected[group.id] = [valueId];
      }
    });
  }

  String get _unitLabel =>
      (_menu?['kategori'] as String?) == 'Kopi' ? '/ gelas' : '/ porsi';

  void _addToCart() {
    final menu = _menu!;
    widget.cart.addLine(
      menuId: menu['id'] as String,
      nama: menu['nama'] as String? ?? '-',
      hargaSatuan: _unitPrice,
      stationId: menu['station_id'] as String? ?? '',
      stationName: (menu['stations'] is Map)
          ? (menu['stations'] as Map)['nama'] as String? ?? ''
          : '',
      kategori: menu['kategori'] as String? ?? '',
      waktuProduksiMenit:
          (menu['waktu_produksi_menit'] as num?)?.toInt() ?? 5,
      qty: _qty,
      catatan: _noteController.text.trim(),
      options: _chosenOptions,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${menu['nama']} ditambahkan ke keranjang'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Lihat keranjang',
          onPressed: () => context.go('/cart'),
        ),
      ),
    );
    context.pop();
  }

  Widget _photo() {
    final menu = _menu!;
    final available = menu['is_available'] as bool? ?? true;
    final fotoUrl = menu['foto_url'] as String?;
    final asset = !available
        ? 'assets/images/menu_unavailable.jpg'
        : (menu['kategori'] as String?) == 'Kopi'
            ? 'assets/images/menu_coffee.jpg'
            : 'assets/images/menu_food.jpg';
    final img = fotoUrl != null && fotoUrl.isNotEmpty
        ? Image.network(
            fotoUrl,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.asset(
              asset,
              height: 260,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        : Image.asset(
            asset,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: img,
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _menu?['is_available'] as bool? ?? true;
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CafeColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('Detail menu', style: CafeText.pageTitle),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gagal memuat menu:\n$_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _photo(),
                      const SizedBox(height: 16),
                      Text(
                        '${_menu!['kategori'] ?? ''} · '
                        '${(_menu!['stations'] is Map) ? (_menu!['stations'] as Map)['nama'] ?? '' : ''} · '
                        '±${(_menu!['waktu_produksi_menit'] as num?)?.toInt() ?? 5} menit',
                        style: CafeText.menuMeta,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _menu!['nama'] as String? ?? '-',
                        style: CafeText.cardTitle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _menu!['deskripsi'] as String? ?? '',
                        style: CafeText.cardSub,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mulai ${rupiah(_basePrice)}',
                        style: CafeText.menuPrice,
                      ),
                      const SizedBox(height: 20),
                      for (final g in _groups) _buildOptionGroup(g),
                      const SizedBox(height: 8),
                      Text(
                        'Catatan untuk barista (opsional)',
                        style: CafeText.toggleTitle,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CafeColors.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tidak pakai sedotan',
                          hintStyle: CafeText.searchHint,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: CafeColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: CafeColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _qtyButton(
                            Icons.remove,
                            _qty > 1 ? () => setState(() => _qty--) : null,
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$_qty',
                              textAlign: TextAlign.center,
                              style: CafeText.totalLabel,
                            ),
                          ),
                          _qtyButton(
                            Icons.add,
                            () => setState(() => _qty++),
                          ),
                          const Spacer(),
                          Text(
                            '${rupiah(_unitPrice)} $_unitLabel',
                            style: CafeText.totalLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: available ? _addToCart : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CafeColors.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: CafeColors.border,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            available
                                ? 'Tambah ke keranjang · ${rupiah(_unitPrice * _qty)}'
                                : 'Menu sedang habis',
                            style: CafeText.buttonLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOptionGroup(_MenuOptionGroup group) {
    final selected = _selected[group.id] ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.nama, style: CafeText.toggleTitle),
              const SizedBox(width: 8),
              Text(
                group.wajib
                    ? 'Wajib · pilih 1'
                    : group.tipe == 'multiple'
                        ? 'Opsional · boleh lebih dari 1'
                        : 'Opsional',
                style: CafeText.menuMeta,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in group.values)
                _optionChip(
                  label: v['nama'] as String? ?? '',
                  delta: (v['tambahan_harga'] as num?)?.toInt() ?? 0,
                  active: selected.contains(v['id'] as String),
                  onTap: () => _toggleValue(group, v['id'] as String),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionChip({
    required String label,
    required int delta,
    required bool active,
    required VoidCallback onTap,
  }) {
    final text = delta == 0 ? label : '$label (+${rupiah(delta)})';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? CafeColors.accent : Colors.white,
          border:
              active ? null : Border.all(color: CafeColors.border),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: active ? CafeText.chipActive : CafeText.chipInactive,
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CafeColors.border),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? CafeColors.border : CafeColors.ink,
        ),
      ),
    );
  }
}
