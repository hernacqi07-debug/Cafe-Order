import 'package:flutter/material.dart';

import '../../../../core/theme/cafe_design.dart';
import '../../../../core/utils/format.dart';

/// Satu baris ringkasan item pesanan — dipakai Keranjang, Checkout, dan
/// Lacak Pesanan. Menampilkan jumlah, nama, opsi, catatan, dan subtotal,
/// sesuai desain Figma.
class OrderItemTile extends StatelessWidget {
  const OrderItemTile({
    super.key,
    required this.qty,
    required this.nama,
    required this.hargaSatuan,
    this.optionsSummary = '',
    this.catatan = '',
    this.unitLabel = '',
    this.trailing,
  });

  final int qty;
  final String nama;
  final int hargaSatuan;

  /// Mis. "Large (+Rp5.000) · Less ice · Gula 50%".
  final String optionsSummary;
  final String catatan;

  /// Mis. "/ gelas" atau "/ porsi" — ditampilkan sesudah harga satuan.
  final String unitLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$qty× $nama',
                  style: CafeText.menuName,
                ),
                if (optionsSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(optionsSummary, style: CafeText.menuMeta),
                ],
                if (catatan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Catatan: $catatan', style: CafeText.itemNote),
                ],
                if (unitLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${rupiah(hargaSatuan)} $unitLabel',
                    style: CafeText.menuMeta,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupiah(qty * hargaSatuan),
                style: CafeText.menuName,
              ),
              if (trailing != null) ...[
                const SizedBox(height: 6),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris total (Subtotal / Biaya tambahan / Total pembayaran).
class TotalRow extends StatelessWidget {
  const TotalRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final int value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? CafeText.totalLabel : CafeText.body),
          Text(
            rupiah(value),
            style: isTotal ? CafeText.totalValue : CafeText.body,
          ),
        ],
      ),
    );
  }
}
