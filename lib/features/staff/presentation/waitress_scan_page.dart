import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../order/data/table_repository.dart';

/// Scan QR fallback untuk waitress (Alur Layar B2).
///
/// Scan meja yang terisi → konfirmasi "Customer lupa menandai?
/// Tandai kosong". Meja yang sudah kosong hanya diinfokan.
/// Ada input kode manual untuk tes (emulator / kamera bermasalah).
class WaitressScanPage extends StatefulWidget {
  const WaitressScanPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<WaitressScanPage> createState() => _WaitressScanPageState();
}

class _WaitressScanPageState extends State<WaitressScanPage> {
  final _repo = TableRepository();
  final _codeController = TextEditingController();
  late final MobileScannerController _scanner;

  bool _busy = false;
  Map<String, dynamic>? _found;
  String? _error;
  String? _doneMessage;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _lookup(String qrCode) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
      _doneMessage = null;
    });
    try {
      final table = await _repo.fetchTableByQrCode(qrCode);
      if (table == null) {
        throw Exception('QR tidak dikenali.');
      }
      await _scanner.stop();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _found = table;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
      await _scanner.start();
    }
  }

  Future<void> _release() async {
    final table = _found;
    if (table == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tandai meja ${table['kode']} kosong?'),
        content: const Text(
          'Customer lupa menandai pulang? Meja akan kembali tersedia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.accent,
            ),
            child: const Text('Tandai kosong'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.releaseTableByStaff(tableId: table['id'] as String);
      if (!mounted) return;
      setState(() {
        _found = null;
        _doneMessage = 'Meja ${table['kode']} kini kosong.';
      });
      await _scanner.start();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _lookup(code);
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
          onPressed: () => context.go('/staff/tables'),
        ),
        title: Text('Scan QR meja', style: CafeText.pageTitle),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan QR meja yang ditinggalkan customer. Meja terisi '
              'bisa ditandai kosong dari sini.',
              style: CafeText.cardSub,
            ),
            const SizedBox(height: 16),
            if (_doneMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CafeColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: CafeColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_doneMessage!, style: CafeText.toggleTitle),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_found != null) ...[
              _foundCard(),
            ] else ...[
              _buildScanner(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: CafeText.cardSub.copyWith(color: CafeColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Atau masukkan kode meja manual',
                style: CafeText.toggleTitle,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: CafeText.body,
                      decoration: InputDecoration(
                        hintText: 'KAFECONTOH-A1',
                        hintStyle: CafeText.searchHint,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: CafeColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: CafeColors.border,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed:
                        _busy ? null : () => _lookup(_codeController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CafeColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cari'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 320,
        width: double.infinity,
        color: const Color(0xFF252F29),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Kamera tidak tersedia (${error.errorCode}). '
                    'Gunakan input kode manual di bawah.',
                    style: CafeText.cardSub.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (_busy)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _foundCard() {
    final table = _found!;
    final occupied = table['status'] == 'terisi';
    final since = DateTime.tryParse(
      table['ditempati_pada'] as String? ?? '',
    )?.toLocal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CafeColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meja ${table['kode']}', style: CafeText.cardTitle),
          const SizedBox(height: 4),
          Text(
            occupied
                ? 'Terisi${since == null ? '' : ' sejak ${hhmm(since)}'}'
                : 'Sudah kosong.',
            style: CafeText.cardSub,
          ),
          const SizedBox(height: 16),
          if (occupied)
            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _release,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CafeColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Tandai kosong',
                  style: CafeText.buttonLabel,
                ),
              ),
            )
          else
            SizedBox(
              height: 50,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  setState(() => _found = null);
                  await _scanner.start();
                },
                child: const Text('Scan meja lain'),
              ),
            ),
        ],
      ),
    );
  }
}
