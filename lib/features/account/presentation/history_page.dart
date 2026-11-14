import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../order/data/order_repository.dart';

/// Riwayat Transaksi — mengikuti token desain Figma "Pemrograman-Mobile"
/// (frame Customer · Riwayat transaksi).
///
/// Daftar semua pesanan milik user, terbaru dulu. Tap baris untuk
/// membuka Lacak Pesanan.
class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.auth,
    required this.orders,
  });

  final AuthRepository auth;
  final OrderRepository orders;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = widget.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Sesi berakhir, silakan masuk lagi.';
      });
      return;
    }
    try {
      final orders = await widget.orders.fetchOrdersByUser(uid);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _orders = orders;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _dateText(String? raw) {
    final dt = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · ${hhmm(dt)}';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'selesai' => CafeColors.accent,
      'dibatalkan' => CafeColors.danger,
      'menunggu_bayar' => CafeColors.warnText,
      _ => CafeColors.ink,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CafeColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('Riwayat transaksi', style: CafeText.pageTitle),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Perbarui',
            icon: const Icon(Icons.refresh, color: CafeColors.ink),
            onPressed: _load,
          ),
        ],
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
                        Text('Gagal memuat riwayat:\n$_error',
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
              : _orders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: CafeColors.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada transaksi',
                              style: CafeText.cardTitle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pesananmu akan tercatat di sini.',
                              style: CafeText.cardSub,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => context.go('/'),
                              style: FilledButton.styleFrom(
                                backgroundColor: CafeColors.accent,
                              ),
                              child: const Text('Lihat menu'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _orders.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: CafeColors.border,
                        height: 1,
                      ),
                      itemBuilder: (context, i) {
                        final order = _orders[i];
                        final status =
                            order['status'] as String? ?? '';
                        final mode = order['mode'] as String? ?? '';
                        final tableKode = (order['tables'] is Map)
                            ? (order['tables'] as Map)['kode'] as String? ??
                                ''
                            : '';
                        final total =
                            (order['total_harga'] as num?)?.toInt() ?? 0;
                        return InkWell(
                          onTap: () => context.go(
                            '/tracking/${order['kode']}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${order['kode']} · '
                                        '${mode == 'dine_in' ? 'Dine-in' : 'Takeaway'}'
                                        '${tableKode.isNotEmpty ? ' · Meja $tableKode' : ''}',
                                        style: CafeText.menuName,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _dateText(
                                          order['dibuat_pada'] as String?,
                                        ),
                                        style: CafeText.menuMeta,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        orderStatusLabel(status),
                                        style: CafeText.menuMeta.copyWith(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  rupiah(total),
                                  style: CafeText.menuName,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
