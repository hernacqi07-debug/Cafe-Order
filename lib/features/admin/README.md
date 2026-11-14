# admin/ — C1–C7 (selesai 7 Nov 2026)

| Layar | Route | File |
|---|---|---|
| Dashboard (omzet, pesanan aktif, toggle tutup pemesanan) | `/admin` | `presentation/admin_dashboard_page.dart` |
| Kelola Menu (+ opsi, toggle tersedia/habis) | `/admin/menus` | `presentation/admin_menus_page.dart` (+ `menu_form_page.dart`, `menu_options_page.dart`) |
| Kelola Meja (+ generate QR) | `/admin/tables` | `presentation/admin_tables_page.dart` |
| Kelola Pesanan (batal + alasan → refund) | `/admin/orders` | `presentation/admin_orders_page.dart` |
| Laporan (omzet, menu terlaris) | `/admin/reports` | `presentation/admin_reports_page.dart` |
| Kelola Staf (ubah peran, nonaktifkan) | `/admin/staff` | `presentation/admin_staff_page.dart` |
| Kustomisasi (nama, logo, warna) | `/admin/customization` | `presentation/admin_customization_page.dart` |

Kerangka bersama: `presentation/admin_scaffold.dart` (AppBar + Drawer).
Data: `data/admin_repository.dart`.

Catatan:
- Akun Auth staf dibuat di dashboard Supabase (Authentication → Users),
  lalu perannya diubah di Kelola Staf (pembuatan akun butuh service_role
  key — tidak boleh ada di aplikasi).
- Toggle "Tutup pemesanan" mematikan checkout customer
  (`cafes.pemesanan_ditutup`).
- Warna kustomisasi tersimpan di `cafes`; tema aplikasi masih memakai
  aksen hijau Figma (langkah lanjutan: tema dinamis dari database).
