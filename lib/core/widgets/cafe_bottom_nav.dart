import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/cafe_design.dart';

/// Navigasi utama customer, sesuai desain Figma (5 item).
///
/// Dipakai Beranda dan layar customer lainnya. Item aktif diwarnai aksen,
/// sisanya abu-abu. Setiap item mengarah ke route-nya; layar yang belum
/// dibangun masih berupa placeholder.
class CafeBottomNav extends StatelessWidget {
  const CafeBottomNav({super.key, required this.currentIndex});

  /// 0 Beranda, 1 Lokasi, 2 Scan QR, 3 Pesanan, 4 Pengaturan.
  final int currentIndex;

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Beranda', '/'),
    (Icons.location_on_outlined, Icons.location_on, 'Lokasi', '/lokasi'),
    (Icons.qr_code_scanner_outlined, Icons.qr_code_scanner, 'Scan QR',
        '/scan'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Pesanan', '/tracking'),
    (Icons.settings_outlined, Icons.settings, 'Pengaturan', '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.only(top: 14, bottom: 20, left: 10, right: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CafeColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: i == currentIndex
                    ? null
                    : () => context.go(_items[i].$4),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      i == currentIndex ? _items[i].$2 : _items[i].$1,
                      size: 22,
                      color: i == currentIndex
                          ? CafeColors.accent
                          : CafeColors.muted,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _items[i].$3,
                      style: i == currentIndex
                          ? CafeText.navActive
                          : CafeText.navInactive,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
