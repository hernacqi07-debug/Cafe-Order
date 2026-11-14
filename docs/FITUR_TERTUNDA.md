# Fitur Tertunda — Aplikasi Order Cafe

Dicatat 7 Nov 2026 atas permintaan Rid.

## 1. Feedback saat mendaftar — SELESAI 7 Nov 2026

- **Masalah:** tidak ada feedback ketika user mendaftar.
- **Selesai:** setelah `signUp` sukses tampil SnackBar
  "Pendaftaran berhasil! Selamat datang, {nama}." (atau
  "Cek email untuk konfirmasi akun" kalau Confirm email aktif).
- **Lokasi:** `lib/features/auth/presentation/register_page.dart`.

## 2. Fitur lupa password — SEBAGIAN SELESAI 7 Nov 2026

- **Selesai:** tautan "Lupa password?" di halaman Masuk + dialog kirim
  link reset (`AuthRepository.resetPasswordForEmail`).
- **Tersisa:** layar buat kata sandi baru di dalam aplikasi. Penyelesaian
  reset saat ini lewat tautan di email (terbuka di browser). Butuh:
  deep link (intent-filter Android + URL scheme) + pengaturan redirect
  URL di dashboard Supabase (Authentication → URL Configuration),
  lalu tangkap event `passwordRecovery` dan tampilkan form kata sandi baru.

## 3. Konfirmasi kata sandi saat daftar — SELESAI 7 Nov 2026

- **Masalah:** halaman Daftar cuma punya satu kolom password tanpa
  konfirmasi — typo saat daftar tersimpan diam-diam (penyebab error
  login farideraser@gmail.com 7 Nov 2026).
- **Selesai:** kolom "Ulangi kata sandi" + validasi sama/tidak.
