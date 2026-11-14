import 'package:flutter/material.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_repository.dart';
import 'admin_scaffold.dart';

/// Laporan (C5): omzet 7 hari terakhir, total pesanan, menu terlaris,
/// rata-rata waktu penyelesaian per stasiun.
///
/// Semua dihitung di aplikasi dari data Supabase (skala MVP).
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final _repo = AdminRepository();
  bool _loading = true;
  String? _error;

  List<_DayOmzet> _days = [];
  int _totalOmzet = 0;
  int _totalOrders = 0;
  int _cancelledOrders = 0;
  List<MapEntry<String, int>> _bestSellers = [];
  String _avgBar = '-';
  String _avgDapur = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payments = await _repo.fetchPaymentsSukses();
      final orders = await _repo.fetchOrdersForReport();
      final items = await _repo.fetchItemsForReport();
      final stations = await _repo.fetchStations();
      final stationName = {
        for (final s in stations) s['id'] as String: s['nama'] as String,
      };

      final now = DateTime.now();
      final days = <_DayOmzet>[];
      var totalOmzet = 0;
      for (var i = 6; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i));
        final next = day.add(const Duration(days: 1));
        var sum = 0;
        var count = 0;
        for (final p in payments) {
          final paid =
              DateTime.tryParse(p['dibayar_pada'] as String? ?? '')
                  ?.toLocal();
          if (paid != null &&
              !paid.isBefore(day) &&
              paid.isBefore(next)) {
            sum += (p['jumlah'] as int? ?? 0);
            count++;
          }
        }
        totalOmzet += sum;
        days.add(_DayOmzet(day: day, omzet: sum, orders: count));
      }

      final cancelled =
          orders.where((o) => o['status'] == 'dibatalkan').length;

      final sold = <String, int>{};
      for (final item in items) {
        final orderStatus =
            (item['orders'] as Map?)?['status'] as String?;
        if (orderStatus == 'dibatalkan') continue;
        final name = item['nama_snapshot'] as String? ?? '';
        sold[name] = (sold[name] ?? 0) + (item['jumlah'] as int? ?? 0);
      }
      final best = sold.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      String avgFor(String stationLabel) {
        final durations = <int>[];
        for (final item in items) {
          final name = stationName[item['station_id'] as String?];
          if (name != stationLabel) continue;
          final start = DateTime.tryParse(
            item['waktu_mulai_dibuat'] as String? ?? '',
          );
          final end =
              DateTime.tryParse(item['waktu_siap'] as String? ?? '');
          if (start != null && end != null) {
            durations.add(end.difference(start).inMinutes);
          }
        }
        if (durations.isEmpty) return '-';
        final avg =
            durations.reduce((a, b) => a + b) / durations.length;
        return '±${avg.round()} mnt';
      }

      if (!mounted) return;
      setState(() {
        _days = days;
        _totalOmzet = totalOmzet;
        _totalOrders = orders.length;
        _cancelledOrders = cancelled;
        _bestSellers = best.take(5).toList();
        _avgBar = avgFor('Bar');
        _avgDapur = avgFor('Dapur');
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat laporan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Laporan',
      currentRoute: '/admin/reports',
      auth: widget.auth,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: CafeColors.ink),
          onPressed: _load,
        ),
      ],
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
                      Text('7 hari terakhir', style: CafeText.sectionTitle),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'Omzet 7 hari',
                              rupiah(_totalOmzet),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              'Total pesanan',
                              '$_totalOrders',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'Dibatalkan',
                              '$_cancelledOrders',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              'Rata-rata Bar',
                              _avgBar,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _statCard('Rata-rata Dapur', _avgDapur),
                      const SizedBox(height: 24),
                      Text('Omzet per hari', style: CafeText.sectionTitle),
                      const SizedBox(height: 12),
                      for (final d in _days) ...[
                        _dayRow(d),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 24),
                      Text('Menu terlaris', style: CafeText.sectionTitle),
                      const SizedBox(height: 12),
                      if (_bestSellers.isEmpty)
                        Text(
                          'Belum ada penjualan tercatat.',
                          style: CafeText.cardSub,
                        )
                      else
                        for (var i = 0; i < _bestSellers.length; i++) ...[
                          Row(
                            children: [
                              Text(
                                '${i + 1}. ',
                                style: CafeText.toggleTitle,
                              ),
                              Expanded(
                                child: Text(
                                  _bestSellers[i].key,
                                  style: CafeText.body,
                                ),
                              ),
                              Text(
                                '${_bestSellers[i].value} terjual',
                                style: CafeText.menuPrice,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      const SizedBox(height: 8),
                      Text(
                        'Rata-rata waktu = dari "Mulai Buat" sampai '
                        '"Tandai Siap" di KDS.',
                        style: CafeText.menuMeta,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String label, String value) {
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
          Text(label, style: CafeText.menuMeta),
          const SizedBox(height: 4),
          Text(value, style: CafeText.totalValue.copyWith(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _dayRow(_DayOmzet d) {
    final maxOmzet =
        _days.map((e) => e.omzet).fold(0, (a, b) => a > b ? a : b);
    final frac = maxOmzet == 0 ? 0.0 : d.omzet / maxOmzet;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '${d.day.day}/${d.day.month}',
            style: CafeText.body,
          ),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: CafeColors.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac == 0 ? 0.02 : frac,
              child: Container(
                decoration: BoxDecoration(
                  color: CafeColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: Text(
            rupiah(d.omzet),
            style: CafeText.menuPrice,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _DayOmzet {
  _DayOmzet({required this.day, required this.omzet, required this.orders});

  final DateTime day;
  final int omzet;
  final int orders;
}
