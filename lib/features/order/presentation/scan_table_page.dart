import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/cafe_design.dart';
import '../../../core/widgets/cafe_bottom_nav.dart';
import '../../auth/data/auth_repository.dart';
import '../data/table_repository.dart';
import '../data/table_session.dart';

/// Scan QR meja — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Scan QR meja).
///
/// Kamera membaca QR meja (isi QR = kode di tabel `tables`, mis.
/// "KAFECONTOH-A1"). Setelah terhubung, meja berstatus Terisi dan
/// pesanan dine-in memakai meja itu. Emulator tidak punya kamera yang
/// praktis, jadi ada input kode manual sebagai jalan tes.
class ScanTablePage extends StatefulWidget {
  const ScanTablePage({
    super.key,
    required this.config,
    required this.auth,
    required this.tables,
  });

  final AppConfig config;
  final AuthRepository auth;
  final TableSession tables;

  @override
  State<ScanTablePage> createState() => _ScanTablePageState();
}

class _ScanTablePageState extends State<ScanTablePage> {
  final _repo = TableRepository();
  final _codeController = TextEditingController();
  late final MobileScannerController _scanner;

  bool _busy = false;
  bool _linked = false;
  String? _linkedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _linked = widget.tables.hasTable;
  }

  @override
  void dispose() {
    _scanner.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _link(String qrCode) async {
    final uid = widget.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi berakhir, silakan masuk lagi')),
      );
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final table = await _repo.linkByQrCode(qrCode: qrCode, userId: uid);
      widget.tables.link(
        tableId: table['id'] as String,
        tableKode: table['kode'] as String? ?? '',
      );
      await _scanner.stop();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _linked = true;
        _linkedAt = table['ditempati_pada'] as String?;
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

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _link(code);
  }

  String get _linkedAtText {
    if (_linkedAt == null) return '';
    final dt = DateTime.tryParse(_linkedAt!)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
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
          onPressed: () => context.go('/'),
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
              'Arahkan kamera ke QR di meja yang kamu tempati. '
              'Scan wajib untuk pesan dine-in.',
              style: CafeText.cardSub,
            ),
            const SizedBox(height: 16),
            if (_linked)
              _buildSuccess()
            else ...[
              _buildScanner(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CafeColors.warnBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                        size: 18,
                        color: CafeColors.warnText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: CafeText.cardSub),
                      ),
                    ],
                  ),
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
                    onPressed: _busy
                        ? null
                        : () => _link(_codeController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CafeColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Hubungkan'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'QR tidak terbaca? Minta bantuan staf.',
              style: CafeText.cardSub,
            ),
            const SizedBox(height: 4),
            Text(
              'Tanpa meja, pesan dine-in di kasir.',
              style: CafeText.cardSub,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CafeBottomNav(currentIndex: 2),
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
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
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

  Widget _buildSuccess() {
    final kode = widget.tables.tableKode ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CafeColors.softGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 22,
                color: CafeColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meja $kode berhasil terhubung',
                  style: CafeText.toggleTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _linkedAtText.isEmpty
                ? 'Meja Terisi. Pesanan dine-in menggunakan meja ini.'
                : 'Meja Terisi sejak $_linkedAtText. Pesanan dine-in '
                    'menggunakan meja ini.',
            style: CafeText.cardSub,
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.config.cafeName} · $kode · Terverifikasi',
            style: CafeText.toggleTitle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Lanjut pilih menu', style: CafeText.buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
