import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cafe_bottom_nav.dart';
import '../../auth/data/auth_repository.dart';
import '../data/table_repository.dart';
import '../data/table_session.dart';

/// Lokasi & Meja — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Lokasi & meja).
///
/// Data live: nama cafe, jumlah meja kosong/total, status langganan
/// notifikasi meja, dan kartu meja aktif (kalau ada meja terhubung).
/// Alamat & jam buka berasal dari AppConfig (per cafe, white-label);
/// kalau kosong, ditampilkan "belum diatur" — bukan alamat karangan.
class LocationPage extends StatefulWidget {
  const LocationPage({
    super.key,
    required this.config,
    required this.auth,
    required this.tables,
  });

  final AppConfig config;
  final AuthRepository auth;
  final TableSession tables;

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _repo = TableRepository();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tables = [];
  bool _notifyMe = false;
  DateTime _updatedAt = DateTime.now();

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
      final tables = await _repo.fetchTables();
      final uid = widget.auth.currentUser?.id;
      var notify = false;
      if (uid != null) {
        final row = await _repo.client
            .from('table_notifications')
            .select('id')
            .eq('user_id', uid)
            .eq('aktif', true)
            .maybeSingle();
        notify = row != null;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _tables = tables;
        _notifyMe = notify;
        _updatedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _onNotifyChanged(bool value) async {
    final previous = _notifyMe;
    setState(() => _notifyMe = value);
    final uid = widget.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final client = _repo.client;
      if (value) {
        final existing = await client
            .from('table_notifications')
            .select('id')
            .eq('user_id', uid)
            .order('diminta_pada', ascending: false)
            .limit(1)
            .maybeSingle();
        if (existing == null) {
          await client.from('table_notifications').insert({'user_id': uid});
        } else {
          await client
              .from('table_notifications')
              .update({'aktif': true})
              .eq('id', existing['id']);
        }
      } else {
        await client
            .from('table_notifications')
            .update({'aktif': false})
            .eq('user_id', uid)
            .eq('aktif', true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _notifyMe = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan preferensi: $e')),
      );
    }
  }

  Future<void> _releaseTable() async {
    final uid = widget.auth.currentUser?.id;
    final tableId = widget.tables.tableId;
    if (uid == null || tableId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai meja kosong?'),
        content: const Text(
          'Meja akan tersedia lagi untuk pengunjung berikutnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, kosongkan'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.releaseTable(tableId: tableId, userId: uid);
      widget.tables.unlink();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meja ditandai kosong. Terima kasih!'),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal melepas meja: $e')),
      );
    }
  }

  Future<void> _openDirections() async {
    final alamat = widget.config.alamat.trim();
    if (alamat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat cafe belum diatur.'),
        ),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeComponent('$alamat, ${widget.config.cafeName}')}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka peta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final freeCount =
        _tables.where((t) => t['status'] == 'kosong').length;
    final total = _tables.length;
    final activeTable = widget.tables.hasTable
        ? _tables.where((t) => t['id'] == widget.tables.tableId).toList()
        : <Map<String, dynamic>>[];
    final occupiedAtRaw = activeTable.isNotEmpty
        ? activeTable.first['ditempati_pada'] as String?
        : null;
    final occupiedAt = occupiedAtRaw == null
        ? null
        : DateTime.tryParse(occupiedAtRaw)?.toLocal();

    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CafeColors.ink),
          onPressed: () => context.go('/'),
        ),
        title: Text('Lokasi & meja', style: CafeText.pageTitle),
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
                        Text('Gagal memuat meja:\n$_error',
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.config.cafeName,
                          style: CafeText.cardTitle),
                      const SizedBox(height: 4),
                      Text(
                        widget.config.alamat.isEmpty
                            ? 'Alamat belum diatur'
                            : widget.config.alamat,
                        style: CafeText.cardSub,
                      ),
                      Text(
                        widget.config.jamBuka.isEmpty
                            ? 'Jam buka belum diatur'
                            : widget.config.jamBuka,
                        style: CafeText.cardSub,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _openDirections,
                        child: Text('Buka petunjuk arah →',
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '±$freeCount meja tersedia / $total',
                              style: CafeText.cardTitle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pembaruan ${hhmm(_updatedAt)} WIB · perkiraan, bukan jaminan.',
                              style: CafeText.cardSub,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kabari saya kalau ada meja',
                                        style: CafeText.toggleTitle,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tidak ada reservasi atau daftar tunggu.',
                                        style: CafeText.toggleSub,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _notifyMe,
                                  activeThumbColor: CafeColors.accent,
                                  onChanged: _onNotifyChanged,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ketersediaan tidak dijamin. Meja tidak '
                              'ditahan; datang dan scan QR meja yang kosong.',
                              style: CafeText.cardSub,
                            ),
                          ],
                        ),
                      ),
                      if (widget.tables.hasTable) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: CafeColors.softGreen,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meja aktif ${widget.tables.tableKode}',
                                style: CafeText.toggleTitle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                occupiedAt == null
                                    ? 'Terisi. Sudah selesai? Bantu pengunjung berikutnya.'
                                    : 'Terisi sejak ${hhmm(occupiedAt)}. Sudah selesai? Bantu pengunjung berikutnya.',
                                style: CafeText.cardSub,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 46,
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _releaseTable,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: CafeColors.ink,
                                    side: const BorderSide(
                                      color: CafeColors.border,
                                    ),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Tandai meja kosong'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/scan'),
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: Text('Scan QR meja',
                              style: CafeText.buttonLabel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CafeColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: const CafeBottomNav(currentIndex: 1),
    );
  }
}
