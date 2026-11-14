import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cart/cart_controller.dart';

/// Semua operasi pesanan ke Supabase, terpusat di satu tempat supaya
/// layar (Detail/Keranjang/Checkout/Bayar/Lacak) tetap tipis.
///
/// Skema (migrasi 0001): orders, order_items, order_item_options, payments.
/// Status pesanan: menunggu_bayar → masuk → sedang_dibuat → siap_diambil
/// → selesai (+ dibatalkan). Pembayaran: pending → sukses/gagal/kadaluarsa.
class OrderRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Akses client untuk query baca tambahan (mis. waktu produksi menu).
  SupabaseClient get client => _client;

  /// Buat pesanan baru dari keranjang. Mengembalikan kode pesanan (A-0001).
  ///
  /// Satu insert berurutan: orders → order_items → order_item_options →
  /// payments (QRIS, pending). [estimasi] belum diisi di sini — baru diisi
  /// saat pembayaran berhasil (lihat [markPaid]).
  Future<String> createOrder({
    required String userId,
    required String mode,
    String? tableId,
    required List<CartLine> lines,
  }) async {
    final total = lines.fold(0, (sum, l) => sum + l.subtotal);
    final kode = await _nextKode();

    final order = await _client
        .from('orders')
        .insert({
          'kode': kode,
          'user_id': userId,
          'mode': mode,
          'table_id': tableId,
          'status': 'menunggu_bayar',
          'total_harga': total,
        })
        .select('id')
        .single();
    final orderId = order['id'] as String;

    for (final line in lines) {
      final item = await _client
          .from('order_items')
          .insert({
            'order_id': orderId,
            'menu_id': line.menuId,
            'station_id': line.stationId.isEmpty ? null : line.stationId,
            'nama_snapshot': line.nama,
            'harga_satuan_snapshot': line.hargaSatuan,
            'jumlah': line.qty,
            'subtotal': line.subtotal,
            'catatan': line.catatan.isEmpty ? null : line.catatan,
            'status': 'masuk',
          })
          .select('id')
          .single();
      final itemId = item['id'] as String;
      for (final opt in line.options) {
        await _client.from('order_item_options').insert({
          'order_item_id': itemId,
          'option_id': opt.optionId,
          'value_id': opt.valueId,
          'nama_opsi_snapshot': opt.optionName,
          'nama_value_snapshot': opt.valueName,
          'tambahan_harga_snapshot': opt.tambahanHarga,
        });
      }
    }

    await _client.from('payments').insert({
      'order_id': orderId,
      'metode': 'qris',
      'jumlah': total,
      'status': 'pending',
    });

    return kode;
  }

  /// Kode berikutnya hari ini: A-0001, A-0002, ... (per hari UTC).
  Future<String> _nextKode() async {
    final startOfDay = DateTime.now().toUtc();
    final dayStart = DateTime.utc(
      startOfDay.year,
      startOfDay.month,
      startOfDay.day,
    );
    final rows = await _client
        .from('orders')
        .select('id')
        .gte('dibuat_pada', dayStart.toIso8601String());
    final n = (rows as List).length + 1;
    return 'A-${n.toString().padLeft(4, '0')}';
  }

  /// Pesanan + item + opsi + pembayaran, dicari dari kode (A-0123).
  Future<Map<String, dynamic>?> fetchOrderByKode(String kode) async {
    return _client
        .from('orders')
        .select(
          'id, kode, user_id, mode, table_id, status, total_harga, '
          'waktu_pesan, estimasi_siap_pada, batas_ambil_pada, '
          'alasan_batal, dibuat_pada, '
          'tables(kode), '
          'payments(metode, jumlah, status, dibayar_pada), '
          'order_items(id, menu_id, station_id, nama_snapshot, '
          'harga_satuan_snapshot, jumlah, subtotal, catatan, status, '
          'order_item_options(nama_opsi_snapshot, nama_value_snapshot, '
          'tambahan_harga_snapshot))',
        )
        .eq('kode', kode)
        .maybeSingle();
  }

  /// Riwayat pesanan milik user, terbaru dulu (untuk layar Riwayat &
  /// Notifikasi).
  Future<List<Map<String, dynamic>>> fetchOrdersByUser(String userId) async {
    final res = await _client
        .from('orders')
        .select(
          'id, kode, mode, status, total_harga, waktu_pesan, '
          'estimasi_siap_pada, dibuat_pada, tables(kode)',
        )
        .eq('user_id', userId)
        .order('dibuat_pada', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Pesanan aktif terbaru milik user (dipakai tab Pesanan & Beranda).
  Future<Map<String, dynamic>?> fetchActiveOrder(String userId) async {
    return _client
        .from('orders')
        .select('kode, status, estimasi_siap_pada')
        .eq('user_id', userId)
        .inFilter('status', const [
          'menunggu_bayar',
          'masuk',
          'sedang_dibuat',
          'siap_diambil',
        ])
        .order('dibuat_pada', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// Jumlah pesanan di depan pesanan ini (status masuk/sedang_dibuat,
  /// dipesan lebih dulu) — untuk "Ada N pesanan di depanmu".
  Future<int> countQueueAhead({
    required String orderId,
    required DateTime waktuPesan,
  }) async {
    final rows = await _client
        .from('orders')
        .select('id')
        .inFilter('status', const ['masuk', 'sedang_dibuat'])
        .lt('waktu_pesan', waktuPesan.toIso8601String())
        .neq('id', orderId);
    return (rows as List).length;
  }

  /// Pembayaran berhasil (sementara: simulasi dev, sampai gateway QRIS
  /// diputuskan). Status pesanan → masuk, estimasi = sekarang + waktu
  /// produksi terlama, batas ambil = estimasi + batas simpan terlama.
  Future<void> markPaid({
    required String orderId,
    required int maxProductionMinutes,
    required int maxStorageMinutes,
  }) async {
    final now = DateTime.now().toUtc();
    final estimasi = now.add(Duration(minutes: maxProductionMinutes));
    final batasAmbil = estimasi.add(Duration(minutes: maxStorageMinutes));
    await _client
        .from('payments')
        .update({
          'status': 'sukses',
          'dibayar_pada': now.toIso8601String(),
        })
        .eq('order_id', orderId)
        .eq('status', 'pending');
    await _client
        .from('orders')
        .update({
          'status': 'masuk',
          'estimasi_siap_pada': estimasi.toIso8601String(),
          'batas_ambil_pada': batasAmbil.toIso8601String(),
        })
        .eq('id', orderId)
        .eq('status', 'menunggu_bayar');
  }

  /// Batalkan pesanan (customer). Hanya dipanggil saat status masih
  /// menunggu_bayar atau masuk — sesuai aturan pembatalan.
  Future<void> cancelOrder({
    required String orderId,
    String? reason,
  }) async {
    await _client
        .from('orders')
        .update({
          'status': 'dibatalkan',
          'alasan_batal': reason,
          'dibatalkan_oleh': 'customer',
        })
        .eq('id', orderId)
        .inFilter('status', const ['menunggu_bayar', 'masuk']);
    await _client
        .from('payments')
        .update({'status': 'gagal'})
        .eq('order_id', orderId)
        .eq('status', 'pending');
  }

  /// QR kedaluwarsa (countdown 5 menit habis sebelum bayar).
  Future<void> expireOrder(String orderId) async {
    await _client
        .from('orders')
        .update({
          'status': 'dibatalkan',
          'alasan_batal': 'QRIS kedaluwarsa',
          'dibatalkan_oleh': 'system',
        })
        .eq('id', orderId)
        .eq('status', 'menunggu_bayar');
    await _client
        .from('payments')
        .update({'status': 'kadaluarsa'})
        .eq('order_id', orderId)
        .eq('status', 'pending');
  }
}
