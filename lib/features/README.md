# features/

Struktur fitur mengikuti **Alur_Layar_Aplikasi_Order_Cafe.md** (3 peran).
Setiap folder peran berisi README pemetaan layar → tabel database.

```
features/
  auth/        # A1  - Splash, Login, Daftar (role customer; login staf/admin)
  customer/    # A2-A9 - Beranda, Menu, Keranjang, Checkout, Lacak, Riwayat, Profil, Notifikasi
  staff/       # B2-B4 - Waitress (meja), KDS Bar, KDS Dapur
  admin/       # C1-C7 - Dashboard, Menu, Meja+QR, Pesanan, Laporan, Staf, Kustomisasi
```

Aturan:
- Satu folder per layar di dalam folder peran saat implementasi dimulai,
  mis. `customer/checkout/` berisi `checkout_page.dart`, `checkout_controller.dart`, dst.
- Tidak ada hard-code identitas cafe di feature manapun — semua dari `AppConfig`.
- Model/domain (Order, MenuItem, ...) ditaruh di `features/<peran>/<layar>/` atau
  `core/models/` bila dipakai lintas peran.
