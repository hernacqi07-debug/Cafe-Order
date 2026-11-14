import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../order/data/table_repository.dart';

/// Waitress — Kelola Meja (Alur Layar B2).
///
/// Daftar meja + status (kosong/terisi, waktu update terakhir).
/// Tap meja terisi → konfirmasi "Customer lupa menandai? Tandai
/// kosong". Scan QR sebagai fallback (tombol di bawah). Tidak ada
/// aksi lain di MVP — pemesanan & pembayaran murni lewat HP customer.
class WaitressTablesPage extends StatefulWidget {
  const WaitressTablesPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<WaitressTablesPage> createState() => _WaitressTablesPageState();
}

class _WaitressTablesPageState extends State<WaitressTablesPage> {
  final _repo = TableRepository();
  List<Map<String, dynamic>> _tables = [];
  Map<String, String> _occupants = {};
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
      final tables = await _repo.fetchTables();
      final ids = tables
          .map((t) => t['ditempati_oleh'] as String?)
          .whereType<String>()
          .toList();
      var occupants = <String, String>{};
      if (ids.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('users')
            .select('id, nama')
            .inFilter('id', ids);
        for (final r in (rows as List)) {
          occupants[r['id'] as String] = r['nama'] as String? ?? '';
        }
      }
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _occupants = occupants;
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

  Future<void> _confirmRelease(Map<String, dynamic> table) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tandai meja ${table['kode']} kosong?'),
        content: const Text(
          'Customer lupa menandai pulang? Meja akan kembali tersedia.',
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
            child: const Text('Tandai kosong'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.releaseTableByStaff(tableId: table['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meja ${table['kode']} kini kosong.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final occupied = _tables.where((t) => t['status'] == 'terisi').length;
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Kelola Meja', style: CafeText.pageTitle),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: CafeColors.ink),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: CafeColors.danger),
            onPressed: () async {
              await widget.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Text(
                        '±${_tables.length - occupied} meja tersedia / '
                        '${_tables.length}',
                        style: CafeText.sectionTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap meja terisi untuk menandainya kosong bila '
                        'customer lupa.',
                        style: CafeText.cardSub,
                      ),
                      const SizedBox(height: 16),
                      for (final table in _tables) ...[
                        _tableCard(table),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/staff/scan'),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(
                            'Scan QR meja',
                            style: CafeText.buttonLabel,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CafeColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _tableCard(Map<String, dynamic> table) {
    final occupied = table['status'] == 'terisi';
    final occupiedBy = table['ditempati_oleh'] as String?;
    final name = occupiedBy == null ? '' : (_occupants[occupiedBy] ?? '');
    final since = DateTime.tryParse(
      table['ditempati_pada'] as String? ?? '',
    )?.toLocal();
    return InkWell(
      onTap: occupied ? () => _confirmRelease(table) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                color: occupied ? CafeColors.warnBg : CafeColors.softGreen,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meja ${table['kode']}',
                    style: CafeText.toggleTitle,
                  ),
                  Text(
                    occupied
                        ? 'Terisi${name.isEmpty ? '' : ' · $name'}'
                            '${since == null ? '' : ' · sejak ${hhmm(since)}'}'
                        : 'Kosong',
                    style: CafeText.cardSub,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: occupied
                    ? CafeColors.warnBg
                    : CafeColors.softGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                occupied ? 'Terisi' : 'Kosong',
                style: CafeText.menuMeta.copyWith(
                  color: occupied ? CafeColors.warnText : CafeColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
