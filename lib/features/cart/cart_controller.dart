import 'package:flutter/foundation.dart';

/// Satu nilai opsi yang dipilih customer di Detail Menu.
///
/// Disimpan sebagai snapshot (nama + tambahan harga saat dipilih), supaya
/// total keranjang tidak berubah kalau admin mengubah harga opsi di DB.
class CartOption {
  CartOption({
    required this.optionId,
    required this.optionName,
    required this.valueId,
    required this.valueName,
    required this.tambahanHarga,
  });

  final String optionId;
  final String optionName;
  final String valueId;
  final String valueName;
  final int tambahanHarga;

  /// Teks ringkas untuk ringkasan, mis. "Large (+Rp5.000)".
  String get label {
    if (tambahanHarga == 0) return valueName;
    return '$valueName (+Rp${_thousands(tambahanHarga)})';
  }

  static String _thousands(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - 1 - i;
      buf.write(s[rev]);
      if (i % 3 == 2 && i != s.length - 1) buf.write('.');
    }
    return buf.toString().split('').reversed.join();
  }
}

/// Satu baris keranjang.
///
/// Baris dibedakan oleh menu + kombinasi opsi + catatan: menu yang sama
/// dengan opsi berbeda (mis. Large vs Regular) jadi baris terpisah, sesuai
/// desain Keranjang yang menampilkan opsi tiap baris.
class CartLine {
  CartLine({
    required this.key,
    required this.menuId,
    required this.nama,
    required this.hargaSatuan,
    required this.stationId,
    required this.stationName,
    required this.kategori,
    required this.waktuProduksiMenit,
    this.qty = 1,
    this.catatan = '',
    this.options = const [],
  });

  /// Kunci unik baris: menuId + opsi + catatan.
  final String key;
  final String menuId;
  final String nama;

  /// Harga satuan SUDAH termasuk tambahan harga semua opsi.
  final int hargaSatuan;
  final String stationId;
  final String stationName;
  final String kategori;
  final int waktuProduksiMenit;
  int qty;
  final String catatan;
  final List<CartOption> options;

  int get subtotal => qty * hargaSatuan;

  /// Ringkasan opsi, mis. "Large (+Rp5.000) · Less ice · Gula 50%".
  String get optionsSummary => options.map((o) => o.label).join(' · ');
}

/// Keranjang belanja in-memory (satu instance untuk seluruh aplikasi,
/// dibuat di [CafeApp] dan diteruskan lewat router).
///
/// Menyimpan snapshot nama + harga saat item ditambahkan, supaya total
/// tidak berubah kalau admin mengubah harga di tengah jalan. Pesanan baru
/// dibuat dari sini saat checkout.
class CartController extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList();

  bool get isEmpty => _lines.isEmpty;

  int get totalItems => _lines.values.fold(0, (sum, l) => sum + l.qty);

  int get totalPrice => _lines.values.fold(0, (sum, l) => sum + l.subtotal);

  /// Waktu produksi terlama di antara semua baris — dipakai untuk ETA
  /// satu paket (satu ETA per pesanan = stasiun terlama).
  int get maxWaktuProduksiMenit {
    var max = 0;
    for (final l in _lines.values) {
      if (l.waktuProduksiMenit > max) max = l.waktuProduksiMenit;
    }
    return max;
  }

  int qtyOf(String menuId) =>
      _lines.values
          .where((l) => l.menuId == menuId)
          .fold(0, (sum, l) => sum + l.qty);

  /// Tambah cepat dari Beranda (tombol +): tanpa opsi, tanpa catatan.
  /// Kalau baris polos menu itu sudah ada, jumlahnya ditambah.
  void add({
    required String menuId,
    required String nama,
    required int harga,
    String stationId = '',
    String stationName = '',
    String kategori = '',
    int waktuProduksiMenit = 5,
  }) {
    final key = _plainKey(menuId);
    final line = _lines[key];
    if (line == null) {
      _lines[key] = CartLine(
        key: key,
        menuId: menuId,
        nama: nama,
        hargaSatuan: harga,
        stationId: stationId,
        stationName: stationName,
        kategori: kategori,
        waktuProduksiMenit: waktuProduksiMenit,
      );
    } else {
      line.qty += 1;
    }
    notifyListeners();
  }

  /// Tambah dari Detail Menu: dengan opsi + catatan + jumlah pilihan.
  void addLine({
    required String menuId,
    required String nama,
    required int hargaSatuan,
    required String stationId,
    required String stationName,
    required String kategori,
    required int waktuProduksiMenit,
    required int qty,
    required String catatan,
    required List<CartOption> options,
  }) {
    final key = _lineKey(menuId, options, catatan);
    final line = _lines[key];
    if (line == null) {
      _lines[key] = CartLine(
        key: key,
        menuId: menuId,
        nama: nama,
        hargaSatuan: hargaSatuan,
        stationId: stationId,
        stationName: stationName,
        kategori: kategori,
        waktuProduksiMenit: waktuProduksiMenit,
        qty: qty,
        catatan: catatan,
        options: List.of(options),
      );
    } else {
      line.qty += qty;
    }
    notifyListeners();
  }

  void setQty(String key, int qty) {
    final line = _lines[key];
    if (line == null) return;
    if (qty <= 0) {
      _lines.remove(key);
    } else {
      line.qty = qty;
    }
    notifyListeners();
  }

  void removeLine(String key) {
    if (_lines.remove(key) != null) notifyListeners();
  }

  void removeOne(String menuId) {
    final key = _plainKey(menuId);
    final line = _lines[key];
    if (line == null) return;
    if (line.qty > 1) {
      line.qty -= 1;
    } else {
      _lines.remove(key);
    }
    notifyListeners();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    notifyListeners();
  }

  static String _plainKey(String menuId) => '$menuId||';

  static String _lineKey(
    String menuId,
    List<CartOption> options,
    String catatan,
  ) {
    final sig = options.map((o) => o.valueId).join(',');
    return '$menuId|$sig|${catatan.trim()}';
  }
}
