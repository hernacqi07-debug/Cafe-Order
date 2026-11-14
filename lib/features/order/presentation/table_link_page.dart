import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../auth/data/auth_repository.dart';
import '../data/table_repository.dart';
import '../data/table_session.dart';

/// Deep link dari QR meja (`/t/:tableCode`).
///
/// Isi QR adalah kode meja (mis. "KAFECONTOH-A1"). Halaman ini
/// menghubungkan meja lalu membuka Beranda. Dipakai juga oleh QR
/// Model B (polos) yang hanya berisi URL.
class TableLinkPage extends StatefulWidget {
  const TableLinkPage({
    super.key,
    required this.tableCode,
    required this.auth,
    required this.tables,
  });

  final String tableCode;
  final AuthRepository auth;
  final TableSession tables;

  @override
  State<TableLinkPage> createState() => _TableLinkPageState();
}

class _TableLinkPageState extends State<TableLinkPage> {
  final _repo = TableRepository();
  bool _loading = true;
  String? _error;
  String? _linkedKode;

  @override
  void initState() {
    super.initState();
    _link();
  }

  Future<void> _link() async {
    final uid = widget.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Sesi berakhir, silakan masuk lagi.';
      });
      return;
    }
    try {
      final table =
          await _repo.linkByQrCode(qrCode: widget.tableCode, userId: uid);
      widget.tables.link(
        tableId: table['id'] as String,
        tableKode: table['kode'] as String? ?? '',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _linkedKode = table['kode'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Menghubungkan meja...'),
                  ],
                )
              : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_outlined,
                          size: 48,
                          color: CafeColors.warnText,
                        ),
                        const SizedBox(height: 16),
                        Text('Meja tidak terhubung',
                            style: CafeText.cardTitle),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: CafeText.cardSub,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => context.go('/scan'),
                          style: FilledButton.styleFrom(
                            backgroundColor: CafeColors.accent,
                          ),
                          child: const Text('Scan ulang'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 48,
                          color: CafeColors.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Meja ${_linkedKode ?? ''} berhasil terhubung',
                          style: CafeText.cardTitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pesanan dine-in menggunakan meja ini.',
                          style: CafeText.cardSub,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          style: FilledButton.styleFrom(
                            backgroundColor: CafeColors.accent,
                          ),
                          child: const Text('Lanjut pilih menu'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
