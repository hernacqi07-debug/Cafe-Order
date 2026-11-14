import 'package:flutter/material.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_repository.dart';
import 'admin_scaffold.dart';

/// Kelola Pesanan admin (C4): semua pesanan + filter status, detail
/// (item, opsi, pembayaran, meja), batalkan dengan alasan (→ refund
/// bila sudah dibayar), tandai selesai manual.
class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _repo = AdminRepository();
  List<Map<String, dynamic>> _orders = [];
  String? _filter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await _repo.fetchAllOrders(status: _filter);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat pesanan: $e';
      });
    }
  }

  Future<void> _showDetail(Map<String, dynamic> summary) async {
    final detail =
        await _repo.fetchOrderDetail(summary['id'] as String);
    if (!mounted || detail == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _OrderDetailDialog(
        detail: detail,
        onCancel: () async {
          Navigator.of(ctx).pop();
          await _askCancel(summary);
        },
        onComplete: () async {
          Navigator.of(ctx).pop();
          await _repo.completeOrderAdmin(summary['id'] as String);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesanan ditandai selesai.')),
          );
          await _load();
        },
      ),
    );
  }

  Future<void> _askCancel(Map<String, dynamic> order) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batalkan pesanan ${order['kode']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reason,
              style: CafeText.body,
              decoration: const InputDecoration(
                hintText: 'Alasan pembatalan',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pembayaran yang sudah sukses dicatat sebagai refund.',
              style: CafeText.cardSub,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.danger,
            ),
            child: const Text('Batalkan pesanan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancelOrderAdmin(
        orderId: order['id'] as String,
        reason: reason.text.trim().isEmpty
            ? 'Dibatalkan admin'
            : reason.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan dibatalkan.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      (null, 'Semua'),
      ('masuk', 'Masuk'),
      ('sedang_dibuat', 'Sedang Dibuat'),
      ('siap_diambil', 'Siap Diambil'),
      ('selesai', 'Selesai'),
      ('dibatalkan', 'Dibatalkan'),
    ];
    return AdminScaffold(
      title: 'Kelola Pesanan',
      currentRoute: '/admin/orders',
      auth: widget.auth,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: CafeColors.ink),
          onPressed: _load,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(24, 8, 0, 8),
                      child: Row(
                        children: [
                          for (final (value, label) in filters) ...[
                            ChoiceChip(
                              label: Text(label),
                              selected: _filter == value,
                              onSelected: (_) {
                                setState(() => _filter = value);
                                _load();
                              },
                              selectedColor: CafeColors.accent,
                              labelStyle: TextStyle(
                                color: _filter == value
                                    ? Colors.white
                                    : CafeColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: _orders.isEmpty
                          ? const Center(
                              child: Text('Tidak ada pesanan.'),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 8, 24, 24),
                                itemCount: _orders.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final order = _orders[i];
                                  final status =
                                      order['status'] as String? ?? '';
                                  final user =
                                      order['users'] as Map<String, dynamic>?;
                                  final tables = order['tables']
                                      as Map<String, dynamic>?;
                                  final waktu = DateTime.tryParse(
                                    order['dibuat_pada'] as String? ?? '',
                                  )?.toLocal();
                                  return InkWell(
                                    onTap: () => _showDetail(order),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: CafeColors.border,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                order['kode'] as String? ??
                                                    '-',
                                                style: CafeText.toggleTitle,
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: CafeColors.softGreen,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    20,
                                                  ),
                                                ),
                                                child: Text(
                                                  orderStatusLabel(status),
                                                  style: CafeText.menuMeta
                                                      .copyWith(
                                                    color: CafeColors.accent,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                rupiah(
                                                  order['total_harga']
                                                          as int? ??
                                                      0,
                                                ),
                                                style: CafeText.menuPrice,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              user?['nama'] as String? ??
                                                  'Customer',
                                              order['mode'] == 'dine_in'
                                                  ? 'Dine-in${tables == null ? '' : ' · Meja ${tables['kode']}'}'
                                                  : 'Takeaway',
                                              if (waktu != null)
                                                '${waktu.day}/${waktu.month}/${waktu.year} ${hhmm(waktu)}',
                                            ].join(' · '),
                                            style: CafeText.cardSub,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _OrderDetailDialog extends StatelessWidget {
  const _OrderDetailDialog({
    required this.detail,
    required this.onCancel,
    required this.onComplete,
  });

  final Map<String, dynamic> detail;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final status = detail['status'] as String? ?? '';
    final items =
        (detail['order_items'] as List? ?? []).cast<Map<String, dynamic>>();
    final payments = detail['payments'] as Map<String, dynamic>?;
    final user = detail['users'] as Map<String, dynamic>?;
    final tables = detail['tables'] as Map<String, dynamic>?;
    final canAct = status != 'selesai' && status != 'dibatalkan';
    return AlertDialog(
      title: Text('Pesanan ${detail['kode']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${orderStatusLabel(status)}',
              style: CafeText.toggleTitle,
            ),
            Text(
              'Pemesan: ${user?['nama'] ?? '-'}'
              '${user?['no_hp'] != null ? ' · ${user!['no_hp']}' : ''}',
              style: CafeText.cardSub,
            ),
            Text(
              'Mode: ${detail['mode'] == 'dine_in' ? 'Dine-in${tables == null ? '' : ' · Meja ${tables['kode']}'}' : 'Takeaway'}',
              style: CafeText.cardSub,
            ),
            Text(
              'Pembayaran: ${payments?['metode'] ?? 'qris'} · '
              '${payments?['status'] ?? '-'}',
              style: CafeText.cardSub,
            ),
            if ((detail['alasan_batal'] as String?)?.isNotEmpty == true)
              Text(
                'Alasan batal: ${detail['alasan_batal']}',
                style: CafeText.cardSub,
              ),
            const SizedBox(height: 12),
            const Divider(color: CafeColors.border),
            for (final item in items) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['nama_snapshot']} × ${item['jumlah']}',
                      style: CafeText.body,
                    ),
                  ),
                  Text(
                    rupiah(item['subtotal'] as int? ?? 0),
                    style: CafeText.menuPrice,
                  ),
                ],
              ),
              ...((item['order_item_options'] as List? ?? [])
                      .cast<Map<String, dynamic>>())
                  .map(
                (o) => Text(
                  '${o['nama_opsi_snapshot']}: ${o['nama_value_snapshot']}',
                  style: CafeText.cardSub,
                ),
              ),
              if ((item['catatan'] as String?)?.isNotEmpty == true)
                Text('"${item['catatan']}"', style: CafeText.itemNote),
              const SizedBox(height: 4),
            ],
            const Divider(color: CafeColors.border),
            Row(
              children: [
                Text('Total', style: CafeText.totalLabel),
                const Spacer(),
                Text(
                  rupiah(detail['total_harga'] as int? ?? 0),
                  style: CafeText.totalValue,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        if (canAct) ...[
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Batalkan',
              style: CafeText.body.copyWith(color: CafeColors.danger),
            ),
          ),
          FilledButton(
            onPressed: onComplete,
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.accent,
            ),
            child: const Text('Tandai selesai'),
          ),
        ],
      ],
    );
  }
}
