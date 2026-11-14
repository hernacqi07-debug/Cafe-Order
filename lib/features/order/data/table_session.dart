import 'package:flutter/foundation.dart';

/// Meja yang sedang terhubung untuk sesi dine-in customer.
///
/// Diisi oleh alur Scan QR (flow berikutnya). Sementara ini selalu kosong:
/// checkout dine-in belum bisa dipakai sebelum scan, dan chip "Meja A1
/// terhubung" di Keranjang hanya muncul kalau ada meja yang terhubung.
class TableSession extends ChangeNotifier {
  String? _tableId;
  String? _tableKode;

  String? get tableId => _tableId;
  String? get tableKode => _tableKode;
  bool get hasTable => _tableId != null;

  void link({required String tableId, required String tableKode}) {
    _tableId = tableId;
    _tableKode = tableKode;
    notifyListeners();
  }

  void unlink() {
    _tableId = null;
    _tableKode = null;
    notifyListeners();
  }
}
