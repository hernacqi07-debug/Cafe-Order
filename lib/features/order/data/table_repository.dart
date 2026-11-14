import 'package:supabase_flutter/supabase_flutter.dart';

/// Operasi meja ke Supabase.
///
/// Aturan (MVP): scan QR meja = Terisi; customer menandai pulang =
/// Kosong (final); waitress bisa scan sebagai fallback. Tanpa booking,
/// hold, atau waiting list.
class TableRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Akses client untuk query baca/tulis tambahan (mis. notifikasi meja).
  SupabaseClient get client => _client;

  /// Semua meja cafe, diurutkan berdasarkan kode (A1, A2, ...).
  Future<List<Map<String, dynamic>>> fetchTables() async {
    final res = await _client
        .from('tables')
        .select('id, kode, qr_code, status, ditempati_oleh, ditempati_pada')
        .order('kode');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Meja yang sedang ditempati user ini (untuk memulihkan sesi
  /// setelah aplikasi dibuka ulang).
  Future<Map<String, dynamic>?> fetchOccupiedByUser(String userId) async {
    return _client
        .from('tables')
        .select('id, kode, qr_code, status, ditempati_pada')
        .eq('ditempati_oleh', userId)
        .eq('status', 'terisi')
        .order('ditempati_pada', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// Hubungkan meja dari isi QR (mis. "KAFECONTOH-A1").
  ///
  /// Meja yang sudah terisi orang lain tidak bisa diambil.
  /// Mengembalikan baris meja yang terhubung.
  Future<Map<String, dynamic>> linkByQrCode({
    required String qrCode,
    required String userId,
  }) async {
    final code = qrCode.trim();
    final table = await _client
        .from('tables')
        .select('id, kode, qr_code, status, ditempati_oleh, ditempati_pada')
        .eq('qr_code', code)
        .maybeSingle();
    if (table == null) {
      throw Exception('QR tidak dikenali. Minta bantuan staf.');
    }
    final status = table['status'] as String? ?? '';
    final occupiedBy = table['ditempati_oleh'] as String?;
    if (status == 'terisi' && occupiedBy != null && occupiedBy != userId) {
      throw Exception('Meja ${table['kode']} sedang terisi.');
    }
    final updated = await _client
        .from('tables')
        .update({
          'status': 'terisi',
          'ditempati_oleh': userId,
          'ditempati_pada': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', table['id'])
        .select('id, kode, qr_code, status, ditempati_oleh, ditempati_pada')
        .single();
    return updated;
  }

  /// Tandai meja kosong (customer pulang). Hanya pemilik meja yang
  /// bisa melepasnya dari aplikasi.
  Future<void> releaseTable({
    required String tableId,
    required String userId,
  }) async {
    await _client
        .from('tables')
        .update({
          'status': 'kosong',
          'ditempati_oleh': null,
          'ditempati_pada': null,
        })
        .eq('id', tableId)
        .eq('ditempati_oleh', userId)
        .eq('status', 'terisi');
  }

  /// Tandai meja kosong oleh waitress (fallback bila customer lupa
  /// menandai pulang). Tanpa cek pemilik — hanya dipakai layar staf.
  Future<void> releaseTableByStaff({required String tableId}) async {
    await _client
        .from('tables')
        .update({
          'status': 'kosong',
          'ditempati_oleh': null,
          'ditempati_pada': null,
        })
        .eq('id', tableId)
        .eq('status', 'terisi');
  }

  /// Cari meja dari isi QR (untuk scan fallback waitress).
  Future<Map<String, dynamic>?> fetchTableByQrCode(String qrCode) async {
    return _client
        .from('tables')
        .select('id, kode, qr_code, status, ditempati_oleh, ditempati_pada')
        .eq('qr_code', qrCode.trim())
        .maybeSingle();
  }
}