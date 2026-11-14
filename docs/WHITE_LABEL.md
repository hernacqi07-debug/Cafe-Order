# White-label Guide (Model B)

Satu codebase, N aplikasi cafe. Setiap cafe mendapat varian build sendiri
(nama, application ID, ikon, warna, server) via **Android flavors** +
**--dart-define**.

## Konsep

| | Model A (platform) | Model B (white-label) |
|---|---|---|
| Flavor | `prod` | satu flavor per cafe |
| Nama di Play Store/HP | "CafeOrder"/"Serve" | nama cafe ("Kopi Kenangan") |
| applicationId | `com.cafeorder.cafe_order` | `com.serve.<slugcafe>` |
| Backend | dipilih via QR pintar | fix per aplikasi |

## Menambah cafe baru

```bash
tools/new_cafe_flavor.sh <slug> "<App Name>" <application_id> \
    [api_base_url] [primary_color] [secondary_color]
```

Contoh:

```bash
tools/new_cafe_flavor.sh kopikenangan "Kopi Kenangan" com.serve.kopikenangan \
    https://api.kopikenangan.serve.id "#6F4E37" "#C8A97E"
```

Script akan:
1. Menambahkan `productFlavor` ke `android/app/build.gradle.kts`
2. Membuat folder `android/app/src/<slug>/` untuk resource per-flavor (ikon dsb.)

Ikon launcher per flavor: generate dengan `flutter_launcher_icons`
per flavor, atau taruh manual di `android/app/src/<slug>/res/mipmap-*/`.

## Runtime config (--dart-define)

| Define | Contoh | Keterangan |
|---|---|---|
| `APP_NAME` | `"Kopi Kenangan"` | nama tampil di dalam aplikasi |
| `APP_ID` | `com.serve.kopikenangan` | harus sama dengan flavor |
| `API_BASE_URL` | `https://api.kopikenangan.serve.id` | backend cafe (1 DB per cafe) |
| `PRIMARY_COLOR` | `#6F4E37` | warna primer |
| `SECONDARY_COLOR` | `#C8A97E` | warna sekunder |
| `CAFE_NAME` | `"Kopi Kenangan"` | nama cafe tampil |
| `LOGO_URL` | `https://...` | logo (opsional, bisa via admin) |
| `SUPABASE_URL` | `https://xyz.supabase.co` | project Supabase cafe ini (1 DB per cafe) |
| `SUPABASE_ANON_KEY` | `sb_publishable_...` | publishable key — public-safe, ikut ke-build di aplikasi |

**Aturan keras**: tidak boleh ada identitas cafe yang di-hard-code di `lib/`.
Semua lewat `AppConfig.fromEnvironment()`.

## Build

```bash
# APK per cafe
flutter build apk --flavor kopikenangan --release --dart-define=APP_NAME="Kopi Kenangan" ...

# App Bundle untuk Play Store
flutter build appbundle --flavor kopikenangan --release --dart-define=...
```

Flavor `dev` untuk development (`applicationIdSuffix .dev`, label "CafeOrder Dev").

## Signing (wajib sebelum rilis)

1. Buat **keystore per cafe** (jangan pakai satu keystore untuk semua):
   `keytool -genkey -v -keystore ~/keystores/kopikenangan.jks ...`
2. Buat `android/key-kopikenangan.properties` (jangan commit!) berisi
   `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
3. Daftarkan `signingConfigs` per flavor di `build.gradle.kts`.

## Checklist listing Play Store per cafe

- [ ] Nama aplikasi, ikon 512px, feature graphic
- [ ] Deskripsi + screenshot per cafe
- [ ] Privacy policy URL
- [ ] Application ID unik (tidak bentrok)
- [ ] **Risiko spam policy**: sampaikan di awal negosiasi (keputusan owner
      mau listing atau distribusi APK langsung)

## Catatan

- Flavor iOS (schemes) belum disiapkan — project ini Android-first.
  Tambahkan bila dibutuhkan mengikuti pola yang sama.
- Update framework: perbaiki di codebase ini → rebuild per flavor →
  serahkan ke tim cafe (dengan pemberitahuan terlebih dahulu).
