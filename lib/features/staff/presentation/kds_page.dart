import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../data/staff_repository.dart';

/// KDS Bar / Dapur — sesuai Alur Layar B3–B4.
///
/// Satu kartu per `order_items` milik stasiun, urut waktu pesan (FIFO).
/// Aksi: Mulai Buat (masuk → sedang_dibuat), Tandai Siap
/// (sedang_dibuat → siap_diambil), Tandai Selesai (siap_diambil →
/// selesai, saat pesanan diambil customer). Refresh otomatis tiap
/// 20 detik + tarik untuk refresh.
///
/// Stasiun dipilih lewat query `?station=bar|dapur` (lihat router).
class KdsPage extends StatefulWidget {
  const KdsPage({
    super.key,
    required this.station,
    required this.auth,
  });

  /// 'bar' atau 'dapur'.
  final String station;
  final AuthRepository auth;

  @override
  State<KdsPage> createState() => _KdsPageState();
}

class _KdsPageState extends State<KdsPage> {
  final _repo = StaffRepository();
  Timer? _timer;

  String? _stationId;
  String? _stationName;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'semua';
  bool _loading = true;
  String? _error;
  String? _busyItemId;

  bool get _isBar => widget.station == 'bar';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final stations = await _repo.fetchStations();
      final match = stations.firstWhere(
        (s) => (s['nama'] as String? ?? '').toLowerCase() ==
            (_isBar ? 'bar' : 'dapur'),
        orElse: () => <String, dynamic>{},
      );
      final items = match['id'] == null
          ? <Map<String, dynamic>>[]
          : await _repo.fetchQueueItems(stationId: match['id'] as String);
      if (!mounted) return;
      setState(() {
        _stationId = match['id'] as String?;
        _stationName = match['nama'] as String?;
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat antrean: $e';
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'semua') return _items;
    return _items.where((i) => i['status'] == _filter).toList();
  }

  Future<void> _advance(Map<String, dynamic> item, String toStatus) async {
    setState(() => _busyItemId = item['id'] as String);
    try {
      await _repo.advanceItemStatus(
        itemId: item['id'] as String,
        orderId: item['order_id'] as String,
        toStatus: toStatus,
      );
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'KDS ${_stationName ?? (_isBar ? 'Bar' : 'Dapur')}';
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(title, style: CafeText.pageTitle),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: CafeColors.ink),
            onPressed: () => _load(),
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
                  onRefresh: () => _load(silent: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      _filterRow(),
                      const SizedBox(height: 16),
                      if (_stationId == null)
                        const Text(
                          'Stasiun belum ada di database. Tambahkan '
                          'stasiun Bar/Dapur di tabel stations.',
                        )
                      else if (_filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Text(
                            'Tidak ada antrean. Pesanan baru yang sudah '
                            'dibayar akan muncul di sini.',
                            style: CafeText.cardSub,
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        for (final item in _filtered) ...[
                          _itemCard(item),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 8),
                      Text(
                        'Refresh otomatis tiap 20 detik.',
                        style: CafeText.menuMeta,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _filterRow() {
    const filters = [
      ('semua', 'Semua'),
      ('masuk', 'Antre'),
      ('sedang_dibuat', 'Sedang Dibuat'),
      ('siap_diambil', 'Siap'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in filters) ...[
            ChoiceChip(
              label: Text(label),
              selected: _filter == value,
              onSelected: (_) => setState(() => _filter = value),
              selectedColor: CafeColors.accent,
              labelStyle: TextStyle(
                color: _filter == value ? Colors.white : CafeColors.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final order = item['orders'] as Map<String, dynamic>? ?? {};
    final kode = order['kode'] as String? ?? '-';
    final waktuPesan = DateTime.tryParse(order['waktu_pesan'] as String? ?? '');
    final tables = order['tables'] as Map<String, dynamic>?;
    final mode = order['mode'] as String? ?? '';
    final options =
        (item['order_item_options'] as List? ?? []).map((o) {
      final oMap = o as Map<String, dynamic>;
      return '${oMap['nama_opsi_snapshot']}: '
          '${oMap['nama_value_snapshot']}';
    }).join(' · ');
    final status = item['status'] as String? ?? '';
    final qty = item['jumlah'] as int? ?? 1;
    final catatan = item['catatan'] as String?;
    final elapsed = waktuPesan == null
        ? ''
        : '${DateTime.now().difference(waktuPesan.toLocal()).inMinutes} mnt lalu';
    final busy = _busyItemId == item['id'];

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
              Text(kode, style: CafeText.toggleTitle),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  orderStatusLabel(status),
                  style: CafeText.menuMeta.copyWith(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                waktuPesan == null ? '' : hhmm(waktuPesan.toLocal()),
                style: CafeText.menuMeta,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item['nama_snapshot']} × $qty',
            style: CafeText.orderTitle.copyWith(fontSize: 16),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(options, style: CafeText.cardSub),
          ],
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('"$catatan"', style: CafeText.itemNote),
          ],
          const SizedBox(height: 8),
          Text(
            [
              mode == 'dine_in'
                  ? 'Dine-in${tables == null ? '' : ' · Meja ${tables['kode']}'}'
                  : 'Takeaway',
              if (elapsed.isNotEmpty) elapsed,
            ].join(' · '),
            style: CafeText.menuMeta,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy ? null : () => _advance(item, _nextStatus(status)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_actionLabel(status), style: CafeText.buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  String _nextStatus(String status) => switch (status) {
        'masuk' => 'sedang_dibuat',
        'sedang_dibuat' => 'siap_diambil',
        'siap_diambil' => 'selesai',
        _ => status,
      };

  String _actionLabel(String status) => switch (status) {
        'masuk' => 'Mulai Buat',
        'sedang_dibuat' => 'Tandai Siap',
        'siap_diambil' => 'Tandai Selesai',
        _ => 'Selesai',
      };

  Color _statusColor(String status) => switch (status) {
        'masuk' => CafeColors.warnText,
        'sedang_dibuat' => CafeColors.accent,
        'siap_diambil' => CafeColors.accent,
        _ => CafeColors.muted,
      };
}
