import 'package:supabase_flutter/supabase_flutter.dart';

/// Operasi KDS (bar/dapur) ke Supabase.
///
/// Kartu antrean = satu `order_items` milik stasiun, diurutkan
/// `orders.waktu_pesan` (FIFO). Aksi: Mulai Buat → Tandai Siap →
/// Tandai Selesai. Setelah tiap aksi, status order dihitung ulang
/// dari semua itemnya (aturan agregat di Skema Database):
/// semua selesai → selesai; semua siap_diambil → siap_diambil;
/// ada yang sedang dibuat/siap → sedang_dibuat; selain itu masuk.
class StaffRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Stasiun cafe (Bar, Dapur) dengan id-nya.
  Future<List<Map<String, dynamic>>> fetchStations() async {
    final res = await _client
        .from('stations')
        .select('id, nama')
        .order('nama');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Antrean KDS satu stasiun: item berstatus masuk/sedang_dibuat/
  /// siap_diambil, urut waktu pesan (FIFO).
  Future<List<Map<String, dynamic>>> fetchQueueItems({
    required String stationId,
  }) async {
    final res = await _client
        .from('order_items')
        .select(
          'id, order_id, menu_id, nama_snapshot, jumlah, subtotal, '
          'catatan, status, waktu_mulai_dibuat, waktu_siap, '
          'orders!inner(kode, waktu_pesan, mode, tables(kode)), '
          'order_item_options(nama_opsi_snapshot, nama_value_snapshot)',
        )
        .eq('station_id', stationId)
        .inFilter('status', const ['masuk', 'sedang_dibuat', 'siap_diambil'])
        .order('waktu_pesan', referencedTable: 'orders', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Pindahkan satu item ke status berikutnya + hitung ulang status
  /// ordernya. [toStatus]: sedang_dibuat / siap_diambil / selesai.
  Future<void> advanceItemStatus({
    required String itemId,
    required String orderId,
    required String toStatus,
  }) async {
    final updates = <String, dynamic>{'status': toStatus};
    if (toStatus == 'sedang_dibuat') {
      updates['waktu_mulai_dibuat'] = DateTime.now().toUtc().toIso8601String();
    }
    if (toStatus == 'siap_diambil') {
      updates['waktu_siap'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client.from('order_items').update(updates).eq('id', itemId);
    await _recomputeOrderStatus(orderId);
  }

  Future<void> _recomputeOrderStatus(String orderId) async {
    final rows = await _client
        .from('order_items')
        .select('status')
        .eq('order_id', orderId);
    final statuses =
        (rows as List).map((r) => r['status'] as String? ?? '').toList();
    if (statuses.isEmpty) return;
    String next;
    if (statuses.every((s) => s == 'selesai' || s == 'dibatalkan')) {
      next = 'selesai';
    } else if (statuses.every((s) => s == 'siap_diambil')) {
      next = 'siap_diambil';
    } else if (statuses.any(
      (s) => s == 'sedang_dibuat' || s == 'siap_diambil',
    )) {
      next = 'sedang_dibuat';
    } else {
      next = 'masuk';
    }
    await _client
        .from('orders')
        .update({'status': next})
        .eq('id', orderId)
        .neq('status', 'dibatalkan');
  }
}
