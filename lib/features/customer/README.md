# customer/ — A2–A9

| Layar | Route | Tabel utama |
|---|---|---|
| Beranda (estimasi meja, tombol "kabari saya", scan QR, daftar menu) | `/` | `tables`, `table_notifications`, `menus` |
| Detail Menu (+ opsi terstruktur) | `/menu/:id` | `menus`, `menu_options`, `menu_option_values` |
| Keranjang | `/cart` | — (state lokal) |
| Checkout (mode dine-in/takeaway, QR meja **wajib** utk dine-in, bayar QRIS) | `/checkout` | `orders`, `order_items`, `order_item_options`, `payments` |
| Lacak Pesanan (1 ETA per paket + jumlah antrean + timeline) | `/tracking`, `/tracking/:code` | `orders`, `order_items` |
| Riwayat Transaksi | `/history` | `orders`, `payments` |
| Profil (data diri, kode member) | `/profile` | `users` |
| Notifikasi | `/notifications` | — |

Deep link QR meja: `/t/:tableCode`.
