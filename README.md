# cafe_order

Aplikasi order cafe (dine-in) — Flutter, Android-first, **white-label-ready**.
Dijual sebagai framework ke owner cafe (ala Moodle): satu codebase,
tiap cafe dapat branding & build sendiri (Model B).

Dokumen rancangan: `../user/files/`
- `Ringkasan_Project_Aplikasi_Order_Cafe__Dine-in.md`
- `Skema_Database_Aplikasi_Order_Cafe.md`
- `Alur_Layar_Aplikasi_Order_Cafe.md`

## Struktur

```
lib/
  main.dart            # entry point -> AppConfig.fromEnvironment()
  app.dart             # root widget (theme + router dinamis)
  config/
    app_config.dart    # white-label config via --dart-define (TIDAK boleh hard-code identitas cafe di tempat lain)
  core/
    theme/             # ThemeData dari AppConfig
    router/            # go_router: route per layar + deep link QR meja (/t/:tableCode)
    widgets/          # widget bersama
  features/
    auth/              # A1: splash, login, daftar
    customer/          # A2-A9: beranda, menu, keranjang, checkout, lacak, riwayat, profil
    staff/             # B2-B4: waitress (meja), KDS bar & dapur
    admin/             # C1-C7: dashboard, menu, meja+QR, pesanan, laporan, staf, kustomisasi
android/
  app/
    build.gradle.kts   # productFlavors: dev, prod, + per cafe via tools/new_cafe_flavor.sh
docs/
  WHITE_LABEL.md       # panduan white-label (Model B)
tools/
  new_cafe_flavor.sh   # tambah flavor cafe baru
```

## Mulai cepat

```bash
# dev
flutter run --flavor dev

# dengan config cafe contoh
flutter run --flavor dev \
  --dart-define=APP_NAME="Kopi Kenangan" \
  --dart-define=API_BASE_URL=https://api.contoh.id \
  --dart-define=PRIMARY_COLOR=#6F4E37
```

## Tambah cafe baru (white-label)

```bash
tools/new_cafe_flavor.sh kopikenangan "Kopi Kenangan" com.serve.kopikenangan
```

Lihat `docs/WHITE_LABEL.md` untuk build, signing, dan checklist Play Store.

## Status

Struktur + routing skeleton. Layar masih placeholder — implementasi mengikuti
`Alur_Layar_Aplikasi_Order_Cafe.md`. Backend belum diputuskan
(Supabase / Firebase / Laravel).
