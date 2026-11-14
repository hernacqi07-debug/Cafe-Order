import 'package:supabase_flutter/supabase_flutter.dart';

/// Operasi admin ke Supabase (C1–C7).
///
/// Satu cafe per database, jadi baris `cafes` diambil dengan limit 1.
/// Catatan: pembuatan akun Auth staf TIDAK bisa dari aplikasi
/// (butuh service_role key) — admin membuat akun di dashboard
/// Supabase (Authentication → Users), lalu peran diatur di sini
/// (lihat Kelola Staf).
class AdminRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // ── Cafe ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchCafe() async {
    return _client
        .from('cafes')
        .select(
          'id, nama, logo_url, warna_primer, warna_sekunder, '
          'pemesanan_ditutup, batas_penyimpanan_default_menit',
        )
        .limit(1)
        .maybeSingle();
  }

  Future<void> updateCafe({
    required String cafeId,
    required Map<String, dynamic> values,
  }) async {
    await _client.from('cafes').update(values).eq('id', cafeId);
  }

  // ── Menu ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMenus() async {
    final res = await _client
        .from('menus')
        .select(
          'id, cafe_id, station_id, nama, deskripsi, kategori, harga, '
          'foto_url, waktu_produksi_menit, batas_penyimpanan_menit, '
          'is_available, stations(nama)',
        )
        .order('kategori')
        .order('nama');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchStations() async {
    final res = await _client.from('stations').select('id, nama').order('nama');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<String> upsertMenu({
    String? id,
    required String cafeId,
    required String stationId,
    required String nama,
    String? deskripsi,
    String? kategori,
    required int harga,
    String? fotoUrl,
    required int waktuProduksiMenit,
    int? batasSimpanMenit,
    required bool isAvailable,
  }) async {
    final values = {
      'cafe_id': cafeId,
      'station_id': stationId,
      'nama': nama.trim(),
      'deskripsi': deskripsi?.trim().isEmpty == true ? null : deskripsi?.trim(),
      'kategori': kategori?.trim().isEmpty == true ? null : kategori?.trim(),
      'harga': harga,
      'foto_url': fotoUrl?.trim().isEmpty == true ? null : fotoUrl?.trim(),
      'waktu_produksi_menit': waktuProduksiMenit,
      'batas_penyimpanan_menit': batasSimpanMenit,
      'is_available': isAvailable,
    };
    if (id == null) {
      final row =
          await _client.from('menus').insert(values).select('id').single();
      return row['id'] as String;
    }
    await _client.from('menus').update(values).eq('id', id);
    return id;
  }

  Future<void> toggleMenuAvailable({
    required String menuId,
    required bool available,
  }) async {
    await _client
        .from('menus')
        .update({'is_available': available})
        .eq('id', menuId);
  }

  Future<void> deleteMenu(String menuId) async {
    await _client.from('menus').delete().eq('id', menuId);
  }

  // ── Opsi menu ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMenuOptions(String menuId) async {
    final res = await _client
        .from('menu_options')
        .select(
          'id, nama, tipe, wajib, urutan, '
          'menu_option_values(id, nama, tambahan_harga)',
        )
        .eq('menu_id', menuId)
        .order('urutan');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addOption({
    required String menuId,
    required String nama,
    required String tipe,
    required bool wajib,
    required int urutan,
  }) async {
    await _client.from('menu_options').insert({
      'menu_id': menuId,
      'nama': nama.trim(),
      'tipe': tipe,
      'wajib': wajib,
      'urutan': urutan,
    });
  }

  Future<void> deleteOption(String optionId) async {
    await _client.from('menu_options').delete().eq('id', optionId);
  }

  Future<void> addOptionValue({
    required String optionId,
    required String nama,
    required int tambahanHarga,
  }) async {
    await _client.from('menu_option_values').insert({
      'option_id': optionId,
      'nama': nama.trim(),
      'tambahan_harga': tambahanHarga,
    });
  }

  Future<void> deleteOptionValue(String valueId) async {
    await _client.from('menu_option_values').delete().eq('id', valueId);
  }

  // ── Meja ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchTablesAdmin() async {
    final res = await _client
        .from('tables')
        .select('id, kode, qr_code, status, ditempati_oleh, ditempati_pada')
        .order('kode');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addTable({
    required String cafeId,
    required String kode,
    required String qrCode,
  }) async {
    await _client.from('tables').insert({
      'cafe_id': cafeId,
      'kode': kode.trim().toUpperCase(),
      'qr_code': qrCode.trim(),
    });
  }

  Future<void> deleteTable(String tableId) async {
    await _client.from('tables').delete().eq('id', tableId);
  }

  // ── Pesanan ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAllOrders({String? status}) async {
    final select = _client.from('orders').select(
          'id, kode, user_id, mode, table_id, status, total_harga, '
          'waktu_pesan, estimasi_siap_pada, alasan_batal, dibuat_pada, '
          'users(nama), tables(kode), payments(metode, status, dibayar_pada)',
        );
    final res = status == null
        ? await select.order('dibuat_pada', ascending: false).limit(100)
        : await select
            .eq('status', status)
            .order('dibuat_pada', ascending: false)
            .limit(100);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>?> fetchOrderDetail(String orderId) async {
    return _client
        .from('orders')
        .select(
          'id, kode, user_id, mode, table_id, status, total_harga, '
          'waktu_pesan, estimasi_siap_pada, batas_ambil_pada, '
          'alasan_batal, dibatalkan_oleh, dibuat_pada, '
          'users(nama, email, no_hp), tables(kode), '
          'payments(metode, jumlah, status, dibayar_pada), '
          'order_items(id, nama_snapshot, harga_satuan_snapshot, jumlah, '
          'subtotal, catatan, status, '
          'order_item_options(nama_opsi_snapshot, nama_value_snapshot))',
        )
        .eq('id', orderId)
        .maybeSingle();
  }

  /// Batalkan pesanan oleh admin/staf dengan alasan. Pembayaran yang
  /// sudah sukses dicatat `refund`; yang masih pending jadi `gagal`.
  Future<void> cancelOrderAdmin({
    required String orderId,
    required String reason,
  }) async {
    await _client
        .from('orders')
        .update({
          'status': 'dibatalkan',
          'alasan_batal': reason,
          'dibatalkan_oleh': 'staf',
        })
        .eq('id', orderId)
        .neq('status', 'selesai')
        .neq('status', 'dibatalkan');
    await _client
        .from('order_items')
        .update({'status': 'dibatalkan'})
        .eq('order_id', orderId)
        .neq('status', 'selesai');
    final payment = await _client
        .from('payments')
        .select('status')
        .eq('order_id', orderId)
        .maybeSingle();
    final payStatus = payment?['status'] as String?;
    if (payStatus == 'sukses') {
      await _client
          .from('payments')
          .update({'status': 'refund'})
          .eq('order_id', orderId);
    } else if (payStatus == 'pending') {
      await _client
          .from('payments')
          .update({'status': 'gagal'})
          .eq('order_id', orderId);
    }
  }

  /// Tandai pesanan selesai manual (mis. diambil tanpa lewat KDS).
  Future<void> completeOrderAdmin(String orderId) async {
    await _client
        .from('orders')
        .update({'status': 'selesai'})
        .eq('id', orderId)
        .neq('status', 'dibatalkan');
    await _client
        .from('order_items')
        .update({'status': 'selesai'})
        .eq('order_id', orderId)
        .neq('status', 'dibatalkan');
  }

  // ── Laporan ───────────────────────────────────────────────────

  /// Pembayaran sukses (untuk omzet) + pesanan + item (terlaris &
  /// rata-rata waktu penyelesaian per stasiun). Dihitung di layar.
  Future<List<Map<String, dynamic>>> fetchPaymentsSukses() async {
    final res = await _client
        .from('payments')
        .select('jumlah, dibayar_pada')
        .eq('status', 'sukses')
        .order('dibayar_pada', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchOrdersForReport() async {
    final res = await _client
        .from('orders')
        .select('id, status, total_harga, dibuat_pada')
        .order('dibuat_pada', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchItemsForReport() async {
    final res = await _client
        .from('order_items')
        .select(
          'nama_snapshot, jumlah, station_id, status, '
          'waktu_mulai_dibuat, waktu_siap, orders!inner(status)',
        )
        .order('waktu_siap', ascending: false)
        .limit(1000);
    return List<Map<String, dynamic>>.from(res);
  }

  // ── Staf / pengguna ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final res = await _client
        .from('users')
        .select('id, nama, email, no_hp, role, member_code, dibuat_pada')
        .order('dibuat_pada', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    await _client.from('users').update({'role': role}).eq('id', userId);
  }

  /// Nonaktifkan akun: hapus baris profil. Akun Auth tetap ada, tapi
  /// tanpa profil ia tidak punya peran dan tidak bisa masuk layar staf.
  /// (Untuk menghapus total, hapus juga di dashboard Authentication.)
  Future<void> deleteUserProfile(String userId) async {
    await _client.from('users').delete().eq('id', userId);
  }
}
