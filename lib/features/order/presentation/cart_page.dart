import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../cart/cart_controller.dart';
import '../data/table_session.dart';
import 'widgets/order_item_tile.dart';

/// Keranjang — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Keranjang).
///
/// Menampilkan tiap baris beserta opsi & catatannya, stepper jumlah,
/// subtotal, biaya tambahan (Rp0 — belum ada), dan total. Chip meja
/// hanya muncul kalau ada meja yang terhubung (alur Scan QR).
class CartPage extends StatelessWidget {
  const CartPage({
    super.key,
    required this.cart,
    required this.tables,
  });

  final CartController cart;
  final TableSession tables;

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
        title: Text('Keranjang', style: CafeText.pageTitle),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([cart, tables]),
        builder: (context, _) {
          if (cart.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Keranjang masih kosong',
                        style: CafeText.cardTitle),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih menu dari Beranda untuk mulai memesan.',
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
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cart.totalItems} item · dibuat segar untukmu',
                  style: CafeText.cardSub,
                ),
                const SizedBox(height: 12),
                if (tables.hasTable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: CafeColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.table_restaurant_outlined,
                          size: 18,
                          color: CafeColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meja ${tables.tableKode} terhubung',
                                style: CafeText.toggleTitle,
                              ),
                              Text(
                                'Pilihan dan catatan diteruskan ke bar & dapur.',
                                style: CafeText.toggleSub,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                for (final line in cart.lines) ...[
                  OrderItemTile(
                    qty: line.qty,
                    nama: line.nama,
                    hargaSatuan: line.hargaSatuan,
                    optionsSummary: line.optionsSummary,
                    catatan: line.catatan,
                    unitLabel:
                        line.kategori == 'Kopi' ? '/ gelas' : '/ porsi',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _stepButton(
                          Icons.remove,
                          () => cart.setQty(line.key, line.qty - 1),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${line.qty}',
                            textAlign: TextAlign.center,
                            style: CafeText.totalLabel,
                          ),
                        ),
                        _stepButton(
                          Icons.add,
                          () => cart.setQty(line.key, line.qty + 1),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: CafeColors.border, height: 1),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.go('/'),
                  child: Text('Tambah menu lain →',
                      style: CafeText.shortcut),
                ),
                const SizedBox(height: 20),
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
                        label: 'Subtotal (${cart.totalItems} item)',
                        value: cart.totalPrice,
                      ),
                      const TotalRow(label: 'Biaya tambahan', value: 0),
                      const Divider(color: CafeColors.border),
                      TotalRow(
                        label: 'Total pembayaran',
                        value: cart.totalPrice,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Periksa kembali ukuran, tambahan, dan catatan. '
                  'Menu Habis tidak dapat dipesan.',
                  style: CafeText.cardSub,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CafeColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Lanjut checkout · ${rupiah(cart.totalPrice)}',
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

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CafeColors.border),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: CafeColors.ink),
      ),
    );
  }
}
