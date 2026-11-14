-- ============================================================
-- APLIKASI ORDER CAFE — Migrasi Supabase v1
-- 12 tabel sesuai Skema_Database_Aplikasi_Order_Cafe.md (9 Okt 2026)
--
-- CARA PAKAI:
-- 1. Buat project gratis di https://supabase.com (New Project)
-- 2. Buka SQL Editor > New Query di dashboard project
-- 3. Copy SELURUH isi file ini, paste, klik Run
-- 4. Selesai — tabel + seed data "Kafe Contoh" langsung jadi
-- ============================================================

-- ---------------- ENUMS ----------------
create type user_role as enum ('customer', 'waitress', 'barista', 'dapur', 'admin');
create type table_status as enum ('kosong', 'terisi');
create type order_mode as enum ('dine_in', 'takeaway');
create type order_status as enum ('menunggu_bayar', 'masuk', 'sedang_dibuat', 'siap_diambil', 'selesai', 'dibatalkan');
create type order_item_status as enum ('masuk', 'sedang_dibuat', 'siap_diambil', 'selesai', 'dibatalkan');
create type payment_status as enum ('pending', 'sukses', 'gagal', 'kadaluarsa', 'refund');
create type option_type as enum ('single', 'multiple');

-- ---------------- TABEL ----------------
create table cafes (
  id uuid primary key default gen_random_uuid(),
  nama varchar not null,
  logo_url varchar,
  warna_primer varchar(7),
  warna_sekunder varchar(7),
  pemesanan_ditutup boolean not null default false,
  batas_penyimpanan_default_menit int
);

-- Kredensial login TIDAK disimpan di sini — pakai Supabase Auth.
-- Saat signup, buat baris users dengan id = id user dari auth.users.
create table users (
  id uuid primary key default gen_random_uuid(),
  nama varchar not null,
  email varchar unique,
  no_hp varchar unique,
  role user_role not null default 'customer',
  member_code varchar unique,
  dibuat_pada timestamptz not null default now()
);

create table stations (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references cafes(id) on delete cascade,
  nama varchar not null,
  deskripsi text
);

create table menus (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references cafes(id) on delete cascade,
  station_id uuid not null references stations(id) on delete restrict,
  nama varchar not null,
  deskripsi text,
  kategori varchar,
  harga int not null check (harga >= 0),
  foto_url varchar,
  waktu_produksi_menit int not null default 5,
  batas_penyimpanan_menit int,
  is_available boolean not null default true,
  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now()
);

create table menu_options (
  id uuid primary key default gen_random_uuid(),
  menu_id uuid not null references menus(id) on delete cascade,
  nama varchar not null,
  tipe option_type not null default 'single',
  wajib boolean not null default false,
  urutan int not null default 0
);

create table menu_option_values (
  id uuid primary key default gen_random_uuid(),
  option_id uuid not null references menu_options(id) on delete cascade,
  nama varchar not null,
  tambahan_harga int not null default 0,
  tambahan_waktu_menit int not null default 0
);

create table tables (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references cafes(id) on delete cascade,
  kode varchar not null unique,
  qr_code varchar not null unique,
  status table_status not null default 'kosong',
  ditempati_oleh uuid references users(id) on delete set null,
  ditempati_pada timestamptz,
  diubah_pada timestamptz not null default now()
);

create table table_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  diminta_pada timestamptz not null default now(),
  aktif boolean not null default true,
  dinotifikasi_pada timestamptz
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  kode varchar not null unique,
  user_id uuid not null references users(id) on delete cascade,
  mode order_mode not null,
  table_id uuid references tables(id) on delete set null,
  status order_status not null default 'menunggu_bayar',
  total_harga int not null default 0 check (total_harga >= 0),
  waktu_pesan timestamptz not null default now(),
  estimasi_siap_pada timestamptz,
  batas_ambil_pada timestamptz,
  alasan_batal text,
  dibatalkan_oleh varchar,
  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now()
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  menu_id uuid references menus(id) on delete set null,
  station_id uuid references stations(id) on delete set null,
  nama_snapshot varchar not null,
  harga_satuan_snapshot int not null,
  jumlah int not null default 1 check (jumlah > 0),
  subtotal int not null,
  catatan text,
  status order_item_status not null default 'masuk',
  waktu_mulai_dibuat timestamptz,
  waktu_siap timestamptz
);

create table order_item_options (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references order_items(id) on delete cascade,
  option_id uuid references menu_options(id) on delete set null,
  value_id uuid references menu_option_values(id) on delete set null,
  nama_opsi_snapshot varchar not null,
  nama_value_snapshot varchar not null,
  tambahan_harga_snapshot int not null default 0
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references orders(id) on delete cascade,
  metode varchar not null default 'qris',
  jumlah int not null check (jumlah >= 0),
  status payment_status not null default 'pending',
  referensi_gateway varchar,
  dibayar_pada timestamptz,
  dibuat_pada timestamptz not null default now()
);

-- ---------------- INDEX ----------------
create index idx_menus_cafe on menus(cafe_id);
create index idx_menus_station on menus(station_id);
create index idx_menu_options_menu on menu_options(menu_id);
create index idx_option_values_option on menu_option_values(option_id);
create index idx_tables_cafe on tables(cafe_id);
create index idx_tables_status on tables(status);
create index idx_orders_user on orders(user_id);
create index idx_orders_status on orders(status);
create index idx_orders_waktu on orders(waktu_pesan);
create index idx_order_items_order on order_items(order_id);
create index idx_order_items_station_status on order_items(station_id, status);
create index idx_notifications_user on table_notifications(user_id);

-- ---------------- TRIGGER diubah_pada ----------------
create or replace function set_ubah_pada() returns trigger as $$
begin
  new.diubah_pada = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_menus_ubah before update on menus
  for each row execute function set_ubah_pada();
create trigger trg_orders_ubah before update on orders
  for each row execute function set_ubah_pada();
create trigger trg_tables_ubah before update on tables
  for each row execute function set_ubah_pada();

-- ---------------- ROW LEVEL SECURITY ----------------
-- DEV: kebijakan longgar supaya aplikasi langsung bisa jalan.
-- TODO SEBELUM PRODUKSI: ketatkan per role
--   (customer hanya data miliknya, staf hanya data cafenya).
alter table cafes enable row level security;
alter table users enable row level security;
alter table stations enable row level security;
alter table menus enable row level security;
alter table menu_options enable row level security;
alter table menu_option_values enable row level security;
alter table tables enable row level security;
alter table table_notifications enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table order_item_options enable row level security;
alter table payments enable row level security;

create policy "dev_all" on cafes for all using (true) with check (true);
create policy "dev_all" on users for all using (true) with check (true);
create policy "dev_all" on stations for all using (true) with check (true);
create policy "dev_all" on menus for all using (true) with check (true);
create policy "dev_all" on menu_options for all using (true) with check (true);
create policy "dev_all" on menu_option_values for all using (true) with check (true);
create policy "dev_all" on tables for all using (true) with check (true);
create policy "dev_all" on table_notifications for all using (true) with check (true);
create policy "dev_all" on orders for all using (true) with check (true);
create policy "dev_all" on order_items for all using (true) with check (true);
create policy "dev_all" on order_item_options for all using (true) with check (true);
create policy "dev_all" on payments for all using (true) with check (true);

-- ---------------- SEED: Kafe Contoh ----------------
insert into cafes (id, nama, warna_primer, warna_sekunder, batas_penyimpanan_default_menit)
values ('11111111-1111-1111-1111-111111111111', 'Kafe Contoh', '#7B3F00', '#E0671F', 30);

insert into stations (id, cafe_id, nama) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Bar'),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Dapur');

insert into menus (id, cafe_id, station_id, nama, deskripsi, kategori, harga, waktu_produksi_menit, batas_penyimpanan_menit) values
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'Kopi Susu Aren', 'Manis pas, creamy', 'Kopi', 22000, 5, 60),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'Americano', 'Bold dan pahit nikmat', 'Kopi', 18000, 3, 60),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'Butter Croissant', 'Renyah, baru dipanggang', 'Roti', 18000, 10, 30),
  ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'Pisang Goreng Coklat', 'Manis, topping coklat lumer', 'Snack', 15000, 8, 30);

insert into menu_options (id, menu_id, nama, tipe, wajib, urutan) values
  ('88888888-8888-8888-8888-888888888888', '44444444-4444-4444-4444-444444444444', 'Ukuran', 'single', true, 1),
  ('99999999-9999-9999-9999-999999999999', '44444444-4444-4444-4444-444444444444', 'Es', 'single', true, 2),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', 'Gula', 'single', false, 3);

insert into menu_option_values (option_id, nama, tambahan_harga) values
  ('88888888-8888-8888-8888-888888888888', 'Reguler', 0),
  ('88888888-8888-8888-8888-888888888888', 'Large', 5000),
  ('99999999-9999-9999-9999-999999999999', 'Es Normal', 0),
  ('99999999-9999-9999-9999-999999999999', 'Es Sedikit', 0),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Gula Normal', 0),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Less Sugar', 0),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Tanpa Gula', 0);

insert into tables (cafe_id, kode, qr_code) values
  ('11111111-1111-1111-1111-111111111111', 'A1', 'KAFECONTOH-A1'),
  ('11111111-1111-1111-1111-111111111111', 'A2', 'KAFECONTOH-A2'),
  ('11111111-1111-1111-1111-111111111111', 'A3', 'KAFECONTOH-A3'),
  ('11111111-1111-1111-1111-111111111111', 'A4', 'KAFECONTOH-A4'),
  ('11111111-1111-1111-1111-111111111111', 'A5', 'KAFECONTOH-A5'),
  ('11111111-1111-1111-1111-111111111111', 'A6', 'KAFECONTOH-A6');
