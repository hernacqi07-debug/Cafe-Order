import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../cart/cart_controller.dart';
import '../data/order_repository.dart';
import '../data/table_session.dart';
import 'widgets/order_item_tile.dart';

/// Checkout — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Checkout).
///
/// Mode: Dine-in wajib scan QR meja (alur Scan QR, flow berikutnya);
/// tanpa meja yang terhubung, dine-in tidak bisa dipilih dan customer
/// diarahkan ke takeaway atau pesan di kasir. Pembayaran hanya QRIS,
/// dibayar di awal; pesanan masuk antrean setelah pembayaran berhasil.
/// CTA membuat pesanan (status menunggu_bayar) lalu membuka layar Bayar QRIS.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.cart,
    required this.tables,
    required this.auth,
    required this.orders,
  });

  final CartController cart;
  final TableSession tables;
  final AuthRepository auth;
  final OrderRepository orders;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isDineIn = false;
  bool _submitting = false;

  /// True bila admin menutup pemesanan sementara (cafes.pemesanan_ditutup).
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Default: takeaway kalau belum ada meja, dine-in kalau sudah scan.
    _isDineIn = widget.tables.hasTable;
    _checkClosed();
  }

  Future<void> _checkClosed() async {
    try {
      final row = await widget.orders.client
          .from('cafes')
          .select('pemesanan_ditutup')
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _closed = row?['pemesanan_ditutup'] as bool? ?? false;
      });
    } catch (_) {
      // Gagal cek = anggap buka (checkout tetap jalan).
    }
  }

  Future<void> _createOrder() async {
    if (_closed) return;
    final uid = widget.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi berakhir, silakan masuk lagi')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final kode = await widget.orders.createOrder(
        userId: uid,
        mode: _isDineIn ? 'dine_in' : 'takeaway',
        tableId: _isDineIn ? widget.tables.tableId : null,
        lines: widget.cart.lines,
      );
      widget.cart.clear();
      if (!mounted) return;
      context.go('/pay/$kode');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat pesanan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTable = widget.tables.hasTable;
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CafeColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('Checkout', style: CafeText.pageTitle),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.cart, widget.tables]),
        builder: (context, _) {
          if (widget.cart.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Keranjang masih kosong',
                        style: CafeText.cardTitle),
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
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_closed) ...[
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
                          'Pemesanan ditutup sementara',
                          style: CafeText.toggleTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cafe sedang terlalu ramai. Coba lagi nanti, '
                          'atau pesan langsung di kasir.',
                          style: CafeText.cardSub,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _modeChip(
                        label: 'Dine-in',
                        selected: _isDineIn,
                        onTap: hasTable
                            ? () => setState(() => _isDineIn = true)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _modeChip(
                        label: 'Takeaway',
                        selected: !_isDineIn,
                        onTap: () => setState(() => _isDineIn = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isDineIn && hasTable)
                  _infoRow(
                    Icons.check_circle_outline,
                    CafeColors.accent,
                    'Meja ${widget.tables.tableKode} · sudah di-scan',
                  )
                else if (_isDineIn)
                  _infoRow(
                    Icons.info_outline,
                    CafeColors.warnText,
                    'Tanpa meja, pesan dine-in di kasir',
                  )
                else
                  _infoRow(
                    Icons.takeout_dining_outlined,
                    CafeColors.muted,
                    'Takeaway tidak membutuhkan meja',
                  ),
                const SizedBox(height: 8),
                Text(
                  'Dine-in wajib scan QR meja. Takeaway tidak membutuhkan '
                  'meja. Mode tidak dapat diubah setelah pesanan dibuat.',
                  style: CafeText.cardSub,
                ),
                const SizedBox(height: 20),
                Text('Ringkasan pesanan', style: CafeText.sectionTitle),
                const SizedBox(height: 8),
                for (final line in widget.cart.lines) ...[
                  OrderItemTile(
                    qty: line.qty,
                    nama: line.nama,
                    hargaSatuan: line.hargaSatuan,
                    optionsSummary: line.optionsSummary,
                    catatan: line.catatan,
                    unitLabel:
                        line.kategori == 'Kopi' ? '/ gelas' : '/ porsi',
                  ),
                  const Divider(color: CafeColors.border, height: 1),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: CafeColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      TotalRow(
                        label: 'Subtotal (${widget.cart.totalItems} item)',
                        value: widget.cart.totalPrice,
                      ),
                      const TotalRow(label: 'Biaya tambahan', value: 0),
                      const Divider(color: CafeColors.border),
                      TotalRow(
                        label: 'Total pembayaran',
                        value: widget.cart.totalPrice,
                        isTotal: true,
                      ),
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
                      Text('Ambil tepat waktu', style: CafeText.toggleTitle),
                      const SizedBox(height: 4),
                      Text(
                        'Makanan maksimal 30 menit, minuman 60 menit di '
                        'tempat penyimpanan. Keterlambatan pengambilan '
                        'tanggung jawab customer.',
                        style: CafeText.cardSub,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CafeColors.softGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QRIS · satu-satunya metode pembayaran',
                        style: CafeText.toggleTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bayar di awal. Pesanan masuk antrean setelah '
                        'pembayaran berhasil.',
                        style: CafeText.cardSub,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_submitting || _closed) ? null : _createOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CafeColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: CafeColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _closed
                                ? 'Pemesanan ditutup sementara'
                                : 'Buat pesanan & bayar · '
                                    '${rupiah(widget.cart.totalPrice)}',
                            style: CafeText.buttonLabel,
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? CafeColors.accent : Colors.white,
          border: selected
              ? null
              : Border.all(color: CafeColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: selected
              ? CafeText.chipActive.copyWith(fontSize: 14)
              : CafeText.chipInactive.copyWith(fontSize: 14),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: CafeText.toggleTitle)),
      ],
    );
  }
}
