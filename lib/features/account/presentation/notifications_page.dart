import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../order/data/order_repository.dart';
import '../../order/data/table_repository.dart';

/// Notifikasi — mengikuti token desain Figma "Pemrograman-Mobile"
/// (frame Customer · Notifikasi).
///
/// Belum ada tabel notifikasi khusus di database, jadi daftar ini
/// diturunkan dari data yang ada: update status pesanan milik user
/// + info meja tersedia (kalau user berlangganan "Kabari saya").
/// Tap item pesanan untuk membuka Lacak Pesanan.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.config,
    required this.auth,
    required this.orders,
  });

  final AppConfig config;
  final AuthRepository auth;
  final OrderRepository orders;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotifItem {
  _NotifItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    this.kode,
  });

  final IconData icon;
  final String title;
  final String body;
  final DateTime time;
  final String? kode;
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _tables = TableRepository();
  bool _loading = true;
  String? _error;
  List<_NotifItem> _items = [];

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
      final items = <_NotifItem>[];
      for (final order in orders) {
        final status = order['status'] as String? ?? '';
        final kode = order['kode'] as String? ?? '';
        final estimasiRaw = order['estimasi_siap_pada'] as String?;
        final dibuatRaw = order['dibuat_pada'] as String?;
        final estimasi = estimasiRaw == null
            ? null
            : DateTime.tryParse(estimasiRaw)?.toLocal();
        final dibuat = dibuatRaw == null
            ? DateTime.now()
            : DateTime.tryParse(dibuatRaw)?.toLocal() ?? DateTime.now();
        final (title, body, time) = switch (status) {
          'menunggu_bayar' => (
              'Menunggu pembayaran $kode',
              'Selesaikan pembayaran QRIS sebelum waktu habis.',
              dibuat,
            ),
          'masuk' => (
              'Pesanan $kode masuk',
              'Bar & dapur bersiap mengerjakan pesananmu.',
              dibuat,
            ),
          'sedang_dibuat' => (
              'Pesanan $kode sedang dibuat',
              'Satu paket, satu waktu siap.',
              dibuat,
            ),
          'siap_diambil' => (
              'Pesanan $kode siap diambil',
              'Silakan ambil di tempat penyimpanan.',
              estimasi ?? dibuat,
            ),
          'selesai' => (
              'Pesanan $kode selesai',
              'Terima kasih sudah memesan.',
              dibuat,
            ),
          'dibatalkan' => (
              'Pesanan $kode dibatalkan',
              'Pesanan tidak lagi diproses.',
              dibuat,
            ),
          _ => ('Pesanan $kode', orderStatusLabel(status), dibuat),
        };
        items.add(
          _NotifItem(
            icon: Icons.receipt_long_outlined,
            title: title,
            body: body,
            time: time,
            kode: kode,
          ),
        );
      }

      // Info meja tersedia — hanya kalau user berlangganan "Kabari saya".
      final sub = await widget.orders.client
          .from('table_notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('aktif', true)
          .maybeSingle();
      if (sub != null) {
        final tables = await _tables.fetchTables();
        final free =
            tables.where((t) => t['status'] == 'kosong').length;
        if (free > 0) {
          items.insert(
            0,
            _NotifItem(
              icon: Icons.table_restaurant_outlined,
              title: 'Ada meja tersedia',
              body:
                  '±$free meja tersedia di ${widget.config.cafeName}. Datang dan scan QR meja yang kosong.',
              time: DateTime.now(),
            ),
          );
        }
      }

      items.sort((a, b) => b.time.compareTo(a.time));
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _timeText(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24 && dt.day == now.day) return hhmm(dt);
    return '${dt.day}/${dt.month}/${dt.year} ${hhmm(dt)}';
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
        title: Text('Notifikasi', style: CafeText.pageTitle),
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
                        Text('Gagal memuat notifikasi:\n$_error',
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
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              size: 48,
                              color: CafeColors.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada notifikasi',
                              style: CafeText.cardTitle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Update pesanan dan info meja akan muncul di sini.',
                              style: CafeText.cardSub,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: CafeColors.border,
                        height: 1,
                      ),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return InkWell(
                          onTap: item.kode == null
                              ? null
                              : () => context.go('/tracking/${item.kode}'),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: CafeColors.cream,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 20,
                                    color: CafeColors.ink,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: CafeText.menuName,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.body,
                                        style: CafeText.menuMeta,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _timeText(item.time),
                                        style: CafeText.menuMeta.copyWith(
                                          color: CafeColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
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
