import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_repository.dart';
import 'admin_scaffold.dart';

/// Dashboard admin (C1): ringkasan hari ini + toggle tutup pemesanan
/// + navigasi ke semua seksi admin.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _repo = AdminRepository();

  Map<String, dynamic>? _cafe;
  int _omzetHariIni = 0;
  int _pesananHariIni = 0;
  int _pesananAktif = 0;
  int _mejaTerisi = 0;
  int _mejaTotal = 0;
  bool _loading = true;
  String? _error;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cafe = await _repo.fetchCafe();
      final payments = await _repo.fetchPaymentsSukses();
      final orders = await _repo.fetchOrdersForReport();
      final tables = await _repo.fetchTablesAdmin();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      var omzet = 0;
      for (final p in payments) {
        final paid = DateTime.tryParse(p['dibayar_pada'] as String? ?? '');
        if (paid != null && paid.toLocal().isAfter(todayStart)) {
          omzet += (p['jumlah'] as int? ?? 0);
        }
      }
      final todayOrders = orders.where((o) {
        final d = DateTime.tryParse(o['dibuat_pada'] as String? ?? '');
        return d != null && d.toLocal().isAfter(todayStart);
      }).length;
      final active = orders
          .where((o) => const [
                'masuk',
                'sedang_dibuat',
                'siap_diambil',
                'menunggu_bayar',
              ].contains(o['status']))
          .length;
      if (!mounted) return;
      setState(() {
        _cafe = cafe;
        _omzetHariIni = omzet;
        _pesananHariIni = todayOrders;
        _pesananAktif = active;
        _mejaTerisi = tables.where((t) => t['status'] == 'terisi').length;
        _mejaTotal = tables.length;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat dashboard: $e';
      });
    }
  }

  Future<void> _toggleClosed(bool value) async {
    final cafeId = _cafe?['id'] as String?;
    if (cafeId == null) return;
    setState(() => _toggling = true);
    try {
      await _repo.updateCafe(
        cafeId: cafeId,
        values: {'pemesanan_ditutup': value},
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Pemesanan ditutup sementara. Customer tidak bisa checkout.'
                : 'Pemesanan dibuka kembali.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah: $e')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Dashboard',
      currentRoute: '/admin',
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
                      Text(
                        _cafe?['nama'] as String? ?? 'Cafe',
                        style: CafeText.sectionTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ringkasan hari ini',
                        style: CafeText.cardSub,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'Omzet hari ini',
                              rupiah(_omzetHariIni),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              'Pesanan hari ini',
                              '$_pesananHariIni',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'Pesanan aktif',
                              '$_pesananAktif',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              'Meja terisi',
                              '$_mejaTerisi / $_mejaTotal',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: CafeColors.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tutup pemesanan sementara',
                                    style: CafeText.toggleTitle,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Checkout customer dimatikan saat '
                                    'terlalu ramai.',
                                    style: CafeText.cardSub,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value:
                                  _cafe?['pemesanan_ditutup'] as bool? ?? false,
                              activeThumbColor: CafeColors.accent,
                              onChanged: _toggling ? null : _toggleClosed,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Kelola', style: CafeText.sectionTitle),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _navCard(
                            context,
                            Icons.restaurant_menu_outlined,
                            'Kelola Menu',
                            '/admin/menus',
                          ),
                          _navCard(
                            context,
                            Icons.table_restaurant_outlined,
                            'Kelola Meja',
                            '/admin/tables',
                          ),
                          _navCard(
                            context,
                            Icons.receipt_long_outlined,
                            'Kelola Pesanan',
                            '/admin/orders',
                          ),
                          _navCard(
                            context,
                            Icons.bar_chart_outlined,
                            'Laporan',
                            '/admin/reports',
                          ),
                          _navCard(
                            context,
                            Icons.people_outline,
                            'Kelola Staf',
                            '/admin/staff',
                          ),
                          _navCard(
                            context,
                            Icons.palette_outlined,
                            'Kustomisasi',
                            '/admin/customization',
                          ),
                        ],
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

  Widget _navCard(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CafeColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CafeColors.accent),
            const SizedBox(height: 8),
            Text(label, style: CafeText.toggleTitle),
          ],
        ),
      ),
    );
  }
}
