import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cafe_bottom_nav.dart';
import '../data/order_repository.dart';
import 'widgets/order_item_tile.dart';

/// Lacak Pesanan — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Lacak pesanan).
///
/// Satu paket, satu ETA (stasiun terlama). Timeline: Masuk → Sedang
/// Dibuat → Siap Diambil → Selesai. Jumlah antrean dihitung dari
/// pesanan lain yang masih masuk/sedang_dibuat dan dipesan lebih dulu.
/// Pembatalan hanya saat status Menunggu Bayar atau Masuk.
///
/// Tanpa kode, halaman menampilkan pesanan aktif terbaru milik user,
/// atau empty state kalau tidak ada.
class TrackOrderPage extends StatefulWidget {
  const TrackOrderPage({
    super.key,
    this.kode,
    required this.orders,
    required this.userId,
  });

  final String? kode;
  final OrderRepository orders;
  final String? userId;

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;
  int _queueAhead = 0;
  String _userName = '';

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
    try {
      Map<String, dynamic>? order;
      if (widget.kode != null) {
        order = await widget.orders.fetchOrderByKode(widget.kode!);
        if (order == null) {
          throw Exception('Pesanan ${widget.kode} tidak ditemukan');
        }
      } else {
        final uid = widget.userId;
        if (uid == null) throw Exception('Sesi berakhir, silakan masuk lagi');
        final active = await widget.orders.fetchActiveOrder(uid);
        if (active == null) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _order = null;
          });
          return;
        }
        order = await widget.orders.fetchOrderByKode(
          active['kode'] as String,
        );
      }
      final waktuPesanRaw = order!['waktu_pesan'] as String?;
      final waktuPesan = waktuPesanRaw == null
          ? DateTime.now()
          : DateTime.tryParse(waktuPesanRaw)?.toLocal() ?? DateTime.now();
      final queue = await widget.orders.countQueueAhead(
        orderId: order['id'] as String,
        waktuPesan: waktuPesan,
      );
      var userName = '';
      final orderUserId = order['user_id'] as String?;
      if (orderUserId != null) {
        final profile = await widget.orders.client
            .from('users')
            .select('nama')
            .eq('id', orderUserId)
            .maybeSingle();
        userName = (profile?['nama'] as String?)?.trim() ?? '';
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _order = order;
        _queueAhead = queue;
        _userName = userName;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Pesanan yang dibatalkan tidak bisa dikembalikan. '
          'Pembayaran QRIS yang sudah berhasil akan diproses refund '
          'oleh cafe.',
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
      await widget.orders.cancelOrder(orderId: _order!['id'] as String);
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

  static const _steps = [
    ('Masuk', 'pembayaran berhasil'),
    ('Sedang Dibuat', 'bar & dapur mengerjakan'),
    ('Siap Diambil', 'tunggu notifikasi'),
    ('Selesai', 'staf mengonfirmasi setelah diambil'),
  ];

  int _statusIndex(String status) {
    return switch (status) {
      'masuk' => 0,
      'sedang_dibuat' => 1,
      'siap_diambil' => 2,
      'selesai' => 3,
      _ => -1,
    };
  }

  String _headline(String status) {
    return switch (status) {
      'masuk' => 'Pesananmu masuk',
      'sedang_dibuat' => 'Sedang Dibuat',
      'siap_diambil' => 'Siap Diambil',
      'selesai' => 'Selesai',
      'dibatalkan' => 'Pesanan dibatalkan',
      _ => orderStatusLabel(status),
    };
  }

  String _subHeadline(String status) {
    return switch (status) {
      'masuk' => 'Bar & dapur bersiap mengerjakan pesananmu.',
      'sedang_dibuat' =>
        'Sedikit lagi${_userName.isEmpty ? '' : ', $_userName'}.',
      'siap_diambil' => 'Silakan ambil di tempat penyimpanan.',
      'selesai' => 'Terima kasih sudah memesan.',
      'dibatalkan' => 'Pesanan ini tidak lagi diproses.',
      _ => 'Satu paket, satu waktu siap.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        leading: widget.kode == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: CafeColors.ink),
                onPressed: () => context.pop(),
              ),
        title: Text('Lacak pesanan', style: CafeText.pageTitle),
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
              : _order == null
                  ? _emptyState()
                  : _buildContent(),
      bottomNavigationBar: const CafeBottomNav(currentIndex: 3),
    );
  }

  Widget _emptyState() {
    return Center(
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
            Text('Belum ada pesanan aktif', style: CafeText.cardTitle),
            const SizedBox(height: 8),
            Text(
              'Pesanan yang sedang diproses akan muncul di sini.',
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
    final items = List<Map<String, dynamic>>.from(
      (order['order_items'] as List?) ?? [],
    );
    final estimasiRaw = order['estimasi_siap_pada'] as String?;
    final estimasi = estimasiRaw == null
        ? null
        : DateTime.tryParse(estimasiRaw)?.toLocal();

    if (status == 'menunggu_bayar') {
      return _statePage(
        icon: Icons.qr_code_outlined,
        title: 'Menunggu pembayaran',
        desc: 'Selesaikan pembayaran QRIS untuk memasukkan pesanan '
            'ke antrean bar & dapur.',
        buttonLabel: 'Lanjut bayar',
        onButton: () => context.go('/pay/${order['kode']}'),
      );
    }
    if (status == 'dibatalkan') {
      return _statePage(
        icon: Icons.cancel_outlined,
        title: 'Pesanan dibatalkan',
        desc: (order['alasan_batal'] as String?)?.isNotEmpty == true
            ? order['alasan_batal'] as String
            : 'Pesanan ini dibatalkan dan tidak lagi diproses.',
        buttonLabel: 'Kembali ke Beranda',
        onButton: () => context.go('/'),
      );
    }

    final etaText = estimasi == null
        ? 'Estimasi belum tersedia'
        : status == 'siap_diambil'
            ? 'Siap diambil · ${hhmm(estimasi)}'
            : (() {
                final mins = estimasi.difference(DateTime.now()).inMinutes;
                return mins <= 0
                    ? 'Siap diambil · ${hhmm(estimasi)}'
                    : '±$mins menit · ${hhmm(estimasi)}';
              })();

    final paidAtRaw = (order['payments'] is Map)
        ? (order['payments'] as Map)['dibayar_pada'] as String?
        : null;
    final paidAt = paidAtRaw == null
        ? null
        : DateTime.tryParse(paidAtRaw)?.toLocal();
    final waktuPesanRaw = order['waktu_pesan'] as String?;
    final waktuPesan = waktuPesanRaw == null
        ? null
        : DateTime.tryParse(waktuPesanRaw)?.toLocal();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: CafeText.cardSub),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CafeColors.softGreen,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              orderStatusLabel(status),
              style:
                  CafeText.toggleTitle.copyWith(color: CafeColors.accent),
            ),
          ),
          const SizedBox(height: 12),
          Text(_headline(status), style: CafeText.cardTitle),
          const SizedBox(height: 4),
          Text('Satu paket, satu waktu siap.', style: CafeText.cardSub),
          Text(_subHeadline(status), style: CafeText.cardSub),
          const SizedBox(height: 12),
          Text(etaText, style: CafeText.totalLabel),
          const SizedBox(height: 4),
          Text(
            _queueAhead <= 0
                ? 'Tidak ada pesanan di depanmu'
                : 'Ada $_queueAhead pesanan di depanmu',
            style: CafeText.cardSub,
          ),
          const SizedBox(height: 4),
          Text(
            'Estimasi seluruh paket mengikuti stasiun yang paling lama. '
            'Kami kabari saat semua item siap.',
            style: CafeText.cardSub,
          ),
          const SizedBox(height: 20),
          Text('Perjalanan pesananmu', style: CafeText.sectionTitle),
          const SizedBox(height: 12),
          _buildTimeline(
            status: status,
            paidAt: paidAt ?? waktuPesan,
            estimasi: estimasi,
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            OrderItemTile(
              qty: (item['jumlah'] as num?)?.toInt() ?? 1,
              nama: item['nama_snapshot'] as String? ?? '-',
              hargaSatuan:
                  (item['harga_satuan_snapshot'] as num?)?.toInt() ?? 0,
              optionsSummary: _itemOptionsSummary(item),
              catatan: item['catatan'] as String? ?? '',
            ),
            const Divider(color: CafeColors.border, height: 1),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CafeColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dibayar dengan QRIS', style: CafeText.body),
                Text(rupiah(total), style: CafeText.totalLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CafeColors.warnBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == 'masuk'
                      ? 'Pesanan baru masuk'
                      : 'Pesanan sedang dibuat',
                  style: CafeText.toggleTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  'Pembatalan hanya tersedia saat Menunggu Bayar atau '
                  'Masuk. Untuk kendala saat proses pembuatan, hubungi staf.',
                  style: CafeText.cardSub,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text('Hubungi staf di kasir untuk bantuan'),
                    ),
                  ),
                  icon: const Icon(Icons.support_agent_outlined, size: 18),
                  label: const Text('Hubungi staf'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CafeColors.ink,
                    side: const BorderSide(color: CafeColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (status == 'masuk') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CafeColors.danger,
                      side: const BorderSide(color: CafeColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Batalkan pesanan'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _itemOptionsSummary(Map<String, dynamic> item) {
    final opts = List<Map<String, dynamic>>.from(
      (item['order_item_options'] as List?) ?? [],
    );
    return opts.map((o) {
      final v = o['nama_value_snapshot'] as String? ?? '';
      final d = (o['tambahan_harga_snapshot'] as num?)?.toInt() ?? 0;
      return d == 0 ? v : '$v (+${rupiah(d)})';
    }).join(' · ');
  }

  Widget _buildTimeline({
    required String status,
    required DateTime? paidAt,
    required DateTime? estimasi,
  }) {
    final current = _statusIndex(status);
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          _timelineRow(
            title: _steps[i].$1,
            sub: _timelineSub(i, paidAt: paidAt, estimasi: estimasi),
            done: i <= current,
            isCurrent: i == current,
            isLast: i == _steps.length - 1,
          ),
      ],
    );
  }

  String _timelineSub(
    int index, {
    required DateTime? paidAt,
    required DateTime? estimasi,
  }) {
    return switch (index) {
      0 => paidAt == null
          ? 'pembayaran berhasil'
          : '${hhmm(paidAt)} · pembayaran berhasil',
      1 => 'bar & dapur mengerjakan',
      2 => estimasi == null
          ? 'tunggu notifikasi'
          : 'Estimasi ${hhmm(estimasi)} · tunggu notifikasi',
      _ => 'staf mengonfirmasi setelah diambil',
    };
  }

  Widget _timelineRow({
    required String title,
    required String sub,
    required bool done,
    required bool isCurrent,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done ? CafeColors.accent : Colors.white,
                border: Border.all(
                  color:
                      done ? CafeColors.accent : CafeColors.border,
                ),
                shape: BoxShape.circle,
              ),
              child: done
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: done ? CafeColors.accent : CafeColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: isCurrent
                      ? CafeText.toggleTitle
                      : CafeText.body,
                ),
                const SizedBox(height: 2),
                Text(sub, style: CafeText.menuMeta),
              ],
            ),
          ),
        ),
      ],
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
