import 'package:flutter/material.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_repository.dart';
import 'admin_scaffold.dart';
import 'menu_form_page.dart';
import 'menu_options_page.dart';

/// Kelola Menu (C2): daftar menu + toggle Tersedia/Habis.
/// Tambah/edit lewat [MenuFormPage]; kelola opsi lewat
/// [MenuOptionsPage].
class AdminMenusPage extends StatefulWidget {
  const AdminMenusPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AdminMenusPage> createState() => _AdminMenusPageState();
}

class _AdminMenusPageState extends State<AdminMenusPage> {
  final _repo = AdminRepository();
  List<Map<String, dynamic>> _menus = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final menus = await _repo.fetchMenus();
      if (!mounted) return;
      setState(() {
        _menus = menus;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat menu: $e';
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> menu) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${menu['nama']}"?'),
        content: const Text(
          'Menu dan semua opsinya akan terhapus. Pesanan lama tetap '
          'tersimpan (snapshot).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.danger,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteMenu(menu['id'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Kelola Menu',
      currentRoute: '/admin/menus',
      auth: widget.auth,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: CafeColors.ink),
          onPressed: _load,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const MenuFormPage()),
          );
          if (changed == true) _load();
        },
        backgroundColor: CafeColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah menu',
          style: CafeText.buttonLabel.copyWith(fontSize: 13),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _menus.isEmpty
                  ? const Center(
                      child: Text('Belum ada menu. Tambah menu pertama.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: _menus.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final menu = _menus[i];
                          final available =
                              menu['is_available'] as bool? ?? true;
                          final station =
                              (menu['stations'] as Map?)?['nama'] as String?;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: CafeColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            menu['nama'] as String? ?? '',
                                            style: CafeText.toggleTitle,
                                          ),
                                          Text(
                                            [
                                              if (menu['kategori']
                                                  case final String kategori)
                                                kategori,
                                              if (station
                                                  case final String s)
                                                s,
                                              '${menu['waktu_produksi_menit'] ?? 5} mnt',
                                            ].join(' · '),
                                            style: CafeText.cardSub,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      rupiah(menu['harga'] as int? ?? 0),
                                      style: CafeText.menuPrice,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Switch(
                                            value: available,
                                            activeThumbColor:
                                                CafeColors.accent,
                                            onChanged: (v) async {
                                              await _repo.toggleMenuAvailable(
                                                menuId:
                                                    menu['id'] as String,
                                                available: v,
                                              );
                                              await _load();
                                            },
                                          ),
                                          Text(
                                            available ? 'Tersedia' : 'Habis',
                                            style: CafeText.cardSub,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final changed =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) => MenuOptionsPage(
                                              menu: menu,
                                            ),
                                          ),
                                        );
                                        if (changed == true) _load();
                                      },
                                      child: const Text('Opsi'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final changed =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) => MenuFormPage(
                                              menu: menu,
                                            ),
                                          ),
                                        );
                                        if (changed == true) _load();
                                      },
                                      child: const Text('Edit'),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: CafeColors.danger,
                                      ),
                                      onPressed: () => _delete(menu),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
