import 'package:flutter/material.dart';

import '../../../../core/theme/cafe_design.dart';

/// Header auth: logo lingkaran hijau + nama cafe (Lora) +
/// tagline "KOPI & CERITA" — sesuai desain Figma Masuk/Daftar.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.cafeName});

  final String cafeName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: CafeColors.accent,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_cafe_outlined,
            size: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cafeName,
              style: CafeText.cardTitle.copyWith(fontSize: 22),
            ),
            Text(
              'KOPI & CERITA',
              style: CafeText.eyebrow().copyWith(fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }
}
