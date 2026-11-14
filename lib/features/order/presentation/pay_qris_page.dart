import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../cart/cart_controller.dart';
import '../data/order_repository.dart';

/// Bayar dengan QRIS — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Bayar QRIS).
///
/// QR di sini ILUSTRATIF, bukan transaksi nyata (belum ada gateway —
/// keputusan Midtrans/Xendit masih terbuka). Countdown 5 menit sejak
/// pesanan dibuat; kalau habis, pesanan otomatis Dibatalkan.
///
/// Tombol "Simulasi: tandai sudah dibayar (dev)" hanya untuk menguji
/// alur sampai Lacak Pesanan — dihapus saat gateway QRIS sungguhan
/// dipasang.
class PayQrisPage extends StatefulWidget {
  const PayQrisPage({
    super.key,
    required this.kode,
    required this.orders,
    required this.cart,
  });

  final String kode;
  final OrderRepository orders;
  final CartController cart;

  @override
  State<PayQrisPage> createState() => _PayQrisPageState();
}

class _PayQrisPageState extends State<PayQrisPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;
  Timer? _timer;
  Duration _remaining = const Duration(minutes: 5);
  bool _expiring = false;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.orders.fetchOrderByKode(widget.kode);
      if (order == null) throw Exception('Pesanan ${widget.kode} tidak ditemukan');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _order = order;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    final createdRaw = _order?['dibuat_pada'] as String?;
    final created = createdRaw == null
        ? DateTime.now()
        : DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now();
    final expiry = created.add(const Duration(minutes: 5));
    void tick(_) {
      if (!mounted) return;
      final left = expiry.difference(DateTime.now());
      if (left <= Duration.zero) {
        _timer?.cancel();
        setState(() => _remaining = Duration.zero);
        _expire();
      } else {
        setState(() => _remaining = left);
      }
    }

    tick(null);
    _timer = Timer.periodic(const Duration(seconds: 1), tick);
  }

  Future<void> _expire() async {
    if (_expiring || _order == null) return;
    if ((_order!['status'] as String?) != 'menunggu_bayar') return;
    _expiring = true;
    try {
      await widget.orders.expireOrder(_order!['id'] as String);
      if (!mounted) return;
      setState(() => _order!['status'] = 'dibatalkan');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waktu pembayaran habis, pesanan dibatalkan')),
      );
    } catch (_) {
      _expiring = false;
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Pesanan dibatalkan sebelum dibayar. Kamu bisa membuat pesanan baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || _order == null) return;
    try {
      await widget.orders.cancelOrder(
        orderId: _order!['id'] as String,
        reason: 'Dibatalkan customer sebelum bayar',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan dibatalkan')),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan: $e')),
      );
    }
  }

  /// Simulasi pembayaran berhasil (DEV ONLY — sampai gateway dipasang).
  Future<void> _simulatePaid() async {
    if (_order == null || _paying) return;
    setState(() => _paying = true);
    try {
      // Waktu produksi & batas simpan terlama dari menu yang dipesan.
      var maxProduction = 5;
      var maxStorage = 30;
      final items = (_order!['order_items'] as List?) ?? [];
      final menuIds = items
          .map((i) => (i as Map)['menu_id'] as String?)
          .whereType<String>()
          .toList();
      if (menuIds.isNotEmpty) {
        final rows = await widget.orders.client
            .from('menus')
            .select('waktu_produksi_menit, batas_penyimpanan_menit')
            .inFilter('id', menuIds);
        for (final r in (rows as List)) {
          final p = (r['waktu_produksi_menit'] as num?)?.toInt() ?? 5;
          final s = (r['batas_penyimpanan_menit'] as num?)?.toInt() ?? 30;
          if (p > maxProduction) maxProduction = p;
          if (s > maxStorage) maxStorage = s;
        }
      }
      await widget.orders.markPaid(
        orderId: _order!['id'] as String,
        maxProductionMinutes: maxProduction,
        maxStorageMinutes: maxStorage,
      );
      if (!mounted) return;
      context.go('/tracking/${widget.kode}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menandai pembayaran: $e')),
      );
    }
  }

  String get _mmss {
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
        title: Text('Bayar dengan QRIS', style: CafeText.pageTitle),
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
                        Text('Gagal memuat pesanan:\n$_error',
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
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    final status = order['status'] as String? ?? '';
    final mode = order['mode'] as String? ?? '';
    final tableKode = (order['tables'] is Map)
        ? (order['tables'] as Map)['kode'] as String? ?? ''
        : '';
    final subtitle =
        '${order['kode']} · ${mode == 'dine_in' ? 'Dine-in' : 'Takeaway'}'
        '${tableKode.isNotEmpty ? ' · Meja $tableKode' : ''}';
    final total = (order['total_harga'] as num?)?.toInt() ?? 0;

    if (status == 'dibatalkan') {
      return _statePage(
        icon: Icons.cancel_outlined,
        title: 'Pesanan dibatalkan',
        desc: 'QR kedaluwarsa atau pesanan dibatalkan. Buat ulang pesanan '
            'untuk mendapatkan QR baru; jangan bayar QR lama.',
        buttonLabel: 'Kembali ke Beranda',
        onButton: () => context.go('/'),
      );
    }
    if (status != 'menunggu_bayar') {
      return _statePage(
        icon: Icons.check_circle_outline,
        title: 'Pembayaran berhasil',
        desc: 'Pesananmu sudah masuk antrean bar & dapur.',
        buttonLabel: 'Lacak pesanan',
        onButton: () => context.go('/tracking/${order['kode']}'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(subtitle, style: CafeText.cardSub),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CafeColors.warnBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              orderStatusLabel(status),
              style: CafeText.toggleTitle
                  .copyWith(color: CafeColors.warnText),
            ),
          ),
          const SizedBox(height: 12),
          Text(rupiah(total), style: CafeText.cardTitle),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CafeColors.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(
                    painter: _FakeQrPainter(seed: widget.kode),
                  ),
                ),
                const SizedBox(height: 12),
                Text('QRIS · Ruang Kopi', style: CafeText.toggleTitle),
                const SizedBox(height: 2),
                Text(
                  'QR ilustratif · bukan transaksi nyata',
                  style: CafeText.menuMeta,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 18,
                color: CafeColors.muted,
              ),
              const SizedBox(width: 6),
              Text('Sisa waktu pembayaran  ', style: CafeText.cardSub),
              Text(_mmss, style: CafeText.totalLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scan dari aplikasi pembayaran atau simpan QR di ponsel ini.',
            style: CafeText.cardSub,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Simpan QR segera hadir')),
            ),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Simpan QR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CafeColors.ink,
              side: const BorderSide(color: CafeColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CafeColors.softGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Menunggu konfirmasi pembayaran',
                    style: CafeText.toggleTitle),
                const SizedBox(height: 4),
                Text(
                  'Status diperbarui otomatis setelah QRIS berhasil.',
                  style: CafeText.cardSub,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CafeColors.warnBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pembayaran gagal / QR kedaluwarsa?',
                    style: CafeText.toggleTitle),
                const SizedBox(height: 4),
                Text(
                  'Pesanan otomatis Dibatalkan. Buat ulang pesanan untuk '
                  'mendapatkan QR baru; jangan bayar QR lama.',
                  style: CafeText.cardSub,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _load,
                  child: Text('Coba lagi jika gagal →',
                      style: CafeText.shortcut),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _cancel,
            child: Text(
              'Batalkan pesanan sebelum dibayar',
              style: CafeText.shortcut.copyWith(color: CafeColors.danger),
            ),
          ),
          const SizedBox(height: 8),
          // ── DEV ONLY: simulasi bayar, sampai gateway QRIS dipasang. ──
          OutlinedButton(
            onPressed: _paying ? null : _simulatePaid,
            style: OutlinedButton.styleFrom(
              foregroundColor: CafeColors.muted,
              side: const BorderSide(color: CafeColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _paying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simulasi: tandai sudah dibayar (dev)'),
          ),
        ],
      ),
    );
  }

  Widget _statePage({
    required IconData icon,
    required String title,
    required String desc,
    required String buttonLabel,
    required VoidCallback onButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: CafeColors.muted),
            const SizedBox(height: 16),
            Text(title, style: CafeText.cardTitle),
            const SizedBox(height: 8),
            Text(desc, style: CafeText.cardSub, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onButton,
              style: FilledButton.styleFrom(
                backgroundColor: CafeColors.accent,
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pola QR palsu yang deterministik dari kode pesanan — hanya hiasan
/// layar, bukan kode QR yang bisa di-scan.
class _FakeQrPainter extends CustomPainter {
  _FakeQrPainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    const modules = 25;
    final cell = size.width / modules;
    final paint = Paint()..color = CafeColors.ink;
    var hash = 0;
    for (final c in seed.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }

    bool filled(int x, int y) {
      // Pola finder 7x7 di tiga sudut.
      final inFinder = (x < 8 && y < 8) ||
          (x >= modules - 8 && y < 8) ||
          (x < 8 && y >= modules - 8);
      if (inFinder) {
        final lx = x < 8 ? x : x - (modules - 8);
        final ly = y < 8 ? y : y - (modules - 8);
        if (lx == 0 || lx == 6 || ly == 0 || ly == 6) return true;
        if (lx >= 2 && lx <= 4 && ly >= 2 && ly <= 4) return true;
        return false;
      }
      final v = (hash + x * 37 + y * 91 + x * y * 7) % 5;
      return v < 2;
    }

    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        if (filled(x, y)) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            paint,
          );
        }
      }
    }
    // Kotak tengah (tempat logo).
    final center = Rect.fromLTWH(
      size.width * 0.38,
      size.width * 0.38,
      size.width * 0.24,
      size.width * 0.24,
    );
    canvas.drawRect(center, Paint()..color = Colors.white);
    canvas.drawRect(
      center,
      Paint()
        ..color = CafeColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _FakeQrPainter old) => old.seed != seed;
}
