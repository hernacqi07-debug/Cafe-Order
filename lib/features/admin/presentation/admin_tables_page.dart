import 'package:flutter/material.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_repository.dart';
import 'admin_scaffold.dart';

/// Kelola Meja admin (C3): daftar meja + status, tambah meja (kode)
/// dengan QR otomatis, hapus meja.
///
/// QR yang di-encode = `qr_code` (mis. KAFECONTOH-A7). Awalan diambil
/// dari nama cafe di database (huruf besar, tanpa spasi) — untuk
/// Kafe Contoh hasilnya KAFECONTOH-A7. Nilai inilah yang harus
/// tercetak di stiker QR meja.
class AdminTablesPage extends StatefulWidget {
  const AdminTablesPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AdminTablesPage> createState() => _AdminTablesPageState();
}

class _AdminTablesPageState extends State<AdminTablesPage> {
  final _repo = AdminRepository();
  List<Map<String, dynamic>> _tables = [];
  String? _cafeId;
  String _cafePrefix = 'CAFE';
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
      final cafe = await _repo.fetchCafe();
      final tables = await _repo.fetchTablesAdmin();
      final prefix = ((cafe?['nama'] as String?) ?? 'Cafe')
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (!mounted) return;
      setState(() {
        _cafeId = cafe?['id'] as String?;
        _cafePrefix = prefix.isEmpty ? 'CAFE' : prefix;
        _tables = tables;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat meja: $e';
      });
    }
  }

  Future<void> _addTable() async {
    final kode = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah meja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: kode,
              textCapitalization: TextCapitalization.characters,
              style: CafeText.body,
              decoration: const InputDecoration(
                hintText: 'Kode meja, mis. A7',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'QR otomatis: $_cafePrefix-{kode}. Cetak nilai ini di '
              'stiker QR meja.',
              style: CafeText.cardSub,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.accent,
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (ok != true || kode.text.trim().isEmpty || _cafeId == null) return;
    final code = kode.text.trim().toUpperCase();
    try {
      await _repo.addTable(
        cafeId: _cafeId!,
        kode: code,
        qrCode: '$_cafePrefix-$code',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meja $code ditambah (QR: $_cafePrefix-$code).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambah meja: $e')),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> table) async {
    if (table['status'] == 'terisi') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meja sedang terisi — tandai kosong dulu.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus meja ${table['kode']}?'),
        content: const Text('Meja akan hilang dari daftar.'),
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
      await _repo.deleteTable(table['id'] as String);
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
      title: 'Kelola Meja',
      currentRoute: '/admin/tables',
      auth: widget.auth,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: CafeColors.ink),
          onPressed: _load,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTable,
        backgroundColor: CafeColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah meja',
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
              : _tables.isEmpty
                  ? const Center(child: Text('Belum ada meja.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: _tables.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final table = _tables[i];
                          final occupied = table['status'] == 'terisi';
                          final since = DateTime.tryParse(
                            table['ditempati_pada'] as String? ?? '',
                          )?.toLocal();
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: CafeColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: occupied
                                        ? CafeColors.warnBg
                                        : CafeColors.softGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    table['kode'] as String? ?? '?',
                                    style: CafeText.toggleTitle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Meja ${table['kode']}',
                                        style: CafeText.toggleTitle,
                                      ),
                                      Text(
                                        'QR: ${table['qr_code'] ?? '-'}',
                                        style: CafeText.cardSub,
                                      ),
                                      Text(
                                        occupied
                                            ? 'Terisi${since == null ? '' : ' sejak ${hhmm(since)}'}'
                                            : 'Kosong',
                                        style: CafeText.cardSub,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: CafeColors.danger,
                                  ),
                                  onPressed: () => _delete(table),
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
