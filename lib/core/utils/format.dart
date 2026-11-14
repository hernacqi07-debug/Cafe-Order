/// Format angka/waktu yang dipakai di banyak layar customer.
String rupiah(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final rev = s.length - 1 - i;
    buf.write(s[rev]);
    if (i % 3 == 2 && i != s.length - 1) buf.write('.');
  }
  return 'Rp${buf.toString().split('').reversed.join()}';
}

String hhmm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Label status pesanan (enum DB -> Bahasa Indonesia).
String orderStatusLabel(String status) {
  return switch (status) {
    'menunggu_bayar' => 'Menunggu Bayar',
    'masuk' => 'Masuk',
    'sedang_dibuat' => 'Sedang Dibuat',
    'siap_diambil' => 'Siap Diambil',
    'selesai' => 'Selesai',
    'dibatalkan' => 'Dibatalkan',
    _ => status,
  };
}
