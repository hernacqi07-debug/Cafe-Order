# staff/ — B2–B4 (selesai 7 Nov 2026)

| Layar | Route | File |
|---|---|---|
| Kelola Meja (Waitress) | `/staff/tables` | `presentation/waitress_tables_page.dart` |
| Scan QR fallback (Waitress) | `/staff/scan` | `presentation/waitress_scan_page.dart` |
| KDS Bar (Barista) | `/staff/kds?station=bar` | `presentation/kds_page.dart` |
| KDS Dapur | `/staff/kds?station=dapur` | `presentation/kds_page.dart` |

Data: `data/staff_repository.dart` (antrean per stasiun FIFO,
Mulai Buat → Tandai Siap → Tandai Selesai, hitung ulang status order).
KDS refresh otomatis tiap 20 detik + tarik untuk refresh.
Status `selesai` ditandai staf — bukan customer.
Arah peran: `AuthRepository.roleHome` (login staf langsung ke layarnya).
