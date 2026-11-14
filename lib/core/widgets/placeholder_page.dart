import 'package:flutter/material.dart';

/// Temporary page used by the router until real screens are implemented.
/// Each feature folder's README maps these placeholders to the agreed
/// screen flows (see Alur_Layar_Aplikasi_Order_Cafe.md).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            subtitle ?? 'Layar "$title" belum diimplementasikan.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
