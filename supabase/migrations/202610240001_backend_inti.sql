-- PanganPutar: backend inti (tahap 3).
-- Menambah: reservasi stok TTL 10 menit, pembuatan pesanan atomik dengan
-- kunci baris, token QR serah-terima (hash di server), ulasan, laporan,
-- notifikasi, PostGIS lokasi toko, serta job terjadwal.
--
-- Terapkan MELALUI Supabase SQL Editor / CLI (klien Flutter tidak boleh
-- memegang kunci service-role). pg_cron & postgis mungkin perlu diaktifkan
-- lebih dulu di Dashboard (Database > Extensions / Integrations).
begin;

-- ============================================================
-- A. RESERVASI STOK (TTL 10 menit)
-- Server-owned snapshot: klien TIDAK diberi akses apa pun.
-- ============================================================
create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  listing_id uuid not null,
  store_id uuid not null,
  quantity integer not null check (quantity > 0),
  status text not null default 'aktif'
    check (status in ('aktif', 'tuntas', 'kadaluwarsa', 'dilepas')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (listing_id, store_id)
    references public.food_listings(id, store_id) on delete restrict
);

create index reservations_expired_idx on public.reservations (status, expires_at)
  where status = 'aktif';

alter table public.reservations enable row level security;
revoke all on public.reservations from public, anon, authenticated;

-- Kolom hash token QR serah-terima (plaintext tidak pernah disimpan).
alter table public.orders add column if not exists pickup_token_hash text;
create index orders_token_hash_idx on public.orders (store_id, pickup_token_hash);
-- Tidak ada revoke tambahan: tabel orders sudah kunci ke authenticated read;
-- kolom hash sangat tidak bermanfaat tanpa plaintext.

-- ============================================================
-- B. PEMBUATAN PESANAN ATOMIK (stok dikunci FOR UPDATE)
-- Kuota harian paritas dengan klien (lib/core/security_rules.dart):
--   maks 4 porsi/hari, maks 2 pesanan/hari — nilai TIDAK dibaca dari
--   klien; server memegangnya sendiri agar tidak bisa direnteh.
-- ============================================================
create or replace function public.create_order(
  p_listing_id uuid,
  p_store_id uuid,
  p_quantity integer
)
returns table (order_id uuid, pickup_token text, reservation_expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_status public.food_listings.status%type;
  v_pickup_start timestamptz;
  v_pickup_end timestamptz;
  v_price integer;
  v_sisa integer;
  v_store_status public.stores.verification_status%type;
  v_orders integer;
  v_porsi bigint;
  v_token text;
  v_hash text;
  v_order_id uuid;
  v_expiry timestamptz;
begin
  if v_uid is null then
    raise exception 'belum masuk';
  end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 4 then
    raise exception 'jumlah tidak wajar (1..4)';
  end if;

  -- Kuota harian (cermin DailyClaimLedger di klien).
  select count(*), coalesce(sum(o.quantity), 0)
    into v_orders, v_porsi
  from public.orders o
  where o.recipient_id = v_uid
    and o.created_at >= date_trunc('day', now())
    and o.status <> 'dibatalkan';
  if v_orders >= 2 then
    raise exception 'kuota pesanan harian habis (maks 2/hari)';
  end if;
  if v_porsi + p_quantity > 4 then
    raise exception 'kuota porsi harian tidak cukup (maks 4/hari)';
  end if;

  -- Toko harus terverifikasi.
  select s.verification_status into v_store_status
  from public.stores s where s.id = p_store_id;
  if v_store_status is null or v_store_status <> 'terverifikasi' then
    raise exception 'toko belum terverifikasi';
  end if;

  -- KUNCILAH baris listing dengan FOR UPDATE: satu-satunya penangkal
  -- pesaing-update antar sesi (overselling).
  select l.status, l.pickup_start, l.pickup_end, l.price_rupiah,
         l.quantity_available
    into v_status, v_pickup_start, v_pickup_end, v_price, v_sisa
  from public.food_listings l
  where l.id = p_listing_id and l.store_id = p_store_id
  for update;
  if not found then
    raise exception 'penawaran tidak ditemukan';
  end if;
  if v_status <> 'tersedia' then
    raise exception 'penawaran tidak tersedia';
  end if;
  if v_pickup_end <= now() then
    raise exception 'window pengambilan sudah berakhir';
  end if;
  if v_sisa < p_quantity then
    raise exception 'stok tidak cukup';
  end if;

  update public.food_listings
    set quantity_available = quantity_available - p_quantity
    where id = p_listing_id and store_id = p_store_id;

  -- Token QR acak di SISI SERVER; plaintext dikirim sekali di respons,
  -- basis data hanya menyimpan hash-nya.
  v_token := 'PP-' || upper(encode(gen_random_bytes(6), 'hex'));
  v_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');

  insert into public.orders (recipient_id, store_id, listing_id, quantity,
    unit_price_rupiah, status, payment_status, pickup_token_hash)
  values (v_uid, p_store_id, p_listing_id, p_quantity, v_price,
    'menunggu',
    case when v_price > 0 then 'belum_dibayar' else 'tidak_perlu' end,
    v_hash)
  returning id into v_order_id;

  -- Reservasi aktif 10 menit (default). Pelepas tuntas dilakukan oleh
  -- pembayaran/webhook (tuntas) atau oleh cron (kadaluwarsa).
  v_expiry := now() + interval '10 minutes';
  insert into public.reservations (order_id, listing_id, store_id, quantity,
    status, expires_at)
  values (v_order_id, p_listing_id, p_store_id, p_quantity, 'aktif', v_expiry);

  return query select v_order_id, v_token, v_expiry;
end;
$$;

revoke all on function public.create_order(uuid, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.create_order(uuid, uuid, integer) to authenticated;

-- ============================================================
-- C. PELEPASAN & KEDALUWARSA (dipanggil cron setiap menit)
-- Reservasi kedaluwarsa → stok kembali; jika pesanan berbayar masih
-- belum dibayar, pesanan dibatalkan. Pesanan gratis juga kadaluwarsa
-- (jujur: stok tidak menghilang diam-diam untuk pembeli yang hilang).
-- ============================================================
create or replace function public.release_expired_reservations()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  r record;
begin
  for r in
    select rs.order_id, rs.listing_id, rs.store_id, rs.quantity
    from public.reservations rs
    where rs.status = 'aktif' and rs.expires_at <= now()
    for update skip locked
  loop
    update public.reservations
      set status = 'kadaluwarsa', updated_at = now()
      where order_id = r.order_id and status = 'aktif';

    update public.orders o
      set status = 'dibatalkan'
      where o.id = r.order_id
        and o.payment_status in ('belum_dibayar', 'menunggu')
        and o.status <> 'dibatalkan'
        and o.status <> 'selesai';

    update public.food_listings
      set quantity_available = quantity_available + r.quantity,
          status = case
            when status = 'habis' and pickup_end > now() then 'tersedia'
            else status
          end
      where id = r.listing_id and store_id = r.store_id;

    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.release_expired_reservations()
  from public, anon, authenticated;

-- Tutup listing yang window-nya lewat (backup walau cron belum jalan).
create or replace function public.expire_listings()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
begin
  with selesai as (
    update public.food_listings
      set status = case
            when quantity_available <= 0 then 'habis'
            else 'ditutup'
          end
      where status = 'tersedia' and pickup_end <= now()
    returning 1
  )
  select count(*) into v_count from selesai;
  return v_count;
end;
$$;
revoke all on function public.expire_listings() from public, anon, authenticated;

-- ============================================================
-- D. REDEEM QR (pemindaian penyedia — server yang memutus, bukan isi QR)
-- ============================================================
create or replace function public.claim_pickup(
  p_store_id uuid,
  p_token text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_order_id uuid;
  v_status public.orders.status%type;
  v_payment public.orders.payment_status%type;
begin
  select s.owner_id into v_owner from public.stores s where s.id = p_store_id;
  if v_owner is null or v_owner <> v_uid then
    raise exception 'bukan pemilik toko';
  end if;

  select o.id, o.status, o.payment_status
    into v_order_id, v_status, v_payment
  from public.orders o
  where o.store_id = p_store_id
    and o.pickup_token_hash =
      encode(extensions.digest(btrim(upper(p_token)), 'sha256'), 'hex');
  if not found then
    raise exception 'token tidak dikenal';
  end if;

  if v_payment in ('gagal', 'kedaluwarsa') then
    raise exception 'pembayaran tidak sah';
  end if;
  if v_status in ('selesai', 'dibatalkan') then
    raise exception 'pesanan sudah ditutup (QR bekas tidak berlaku)';
  end if;

  update public.orders
    set status = 'selesai', picked_up_at = now()
    where id = v_order_id;

  update public.reservations
    set status = 'tuntas', updated_at = now()
    where order_id = v_order_id and status = 'aktif';

  return v_order_id;
end;
$$;
revoke all on function public.claim_pickup(uuid, text) from public, anon, authenticated;
grant execute on function public.claim_pickup(uuid, text) to authenticated;

-- ============================================================
-- E. ULASAN (dua arah), LAPORAN, NOTIFIKASI
-- ============================================================
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  target_role text not null check (target_role in ('penyedia', 'penerima')),
  rating smallint not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 400),
  created_at timestamptz not null default now(),
  unique (order_id, target_role) -- satu ulasan per arah per pesanan
);

alter table public.reviews enable row level security;
grant select on public.reviews to anon, authenticated;
grant insert (order_id, reviewer_id, target_id, target_role, rating, comment)
  on public.reviews to authenticated;
create policy reviews_read_published on public.reviews for select to anon, authenticated
  using (exists (
    select 1 from public.orders o
    where o.id = order_id and o.status = 'selesai'));
create policy reviews_insert_participant on public.reviews for insert to authenticated
  with check (
    reviewer_id = (select auth.uid())
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and o.status = 'selesai'
        and (o.recipient_id = (select auth.uid())
             or exists (select 1 from public.stores s
                        where s.id = o.store_id and s.owner_id = (select auth.uid())))
    )
  );
revoke all on public.reviews from public;

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('listing', 'store', 'user')),
  target_id uuid not null,
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  status text not null default 'baru' check (status in ('baru', 'ditinjau', 'selesai')),
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;
grant insert (reporter_id, target_type, target_id, reason) on public.reports to authenticated;
create policy reports_insert_anyone_in on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));
-- Isi laporan hanya dibaca server/admin — tidak ada grant select ke klien.
revoke all on public.reports from public, anon, authenticated;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in (
    'pesanan_dikonfirmasi', 'siap_diambil', 'pengingat_ambil', 'info'
  )),
  title text not null,
  body text not null check (char_length(body) <= 300),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.notifications enable row level security;
revoke all on public.notifications from public, anon, authenticated;
-- Penulisan dilakukan server (notifikasi masuk dari endpoint terjadwal);
-- klien boleh membaca miliknya dan menandai baca.
grant select, update (read_at) on public.notifications to authenticated;
create policy notifications_read_own on public.notifications for select to authenticated
  using (profile_id = (select auth.uid()));
create policy notifications_mark_read_own on public.notifications for update to authenticated
  using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));

-- ============================================================
-- F. LOKASI TOKO (POSTGIS) & CARA TERDEKAT
-- Koordinat di-set oleh server pada proses verifikasi — klien hanya
-- membaca hasil pencarian, bukan menulis lokasi.
-- ============================================================
create extension if not exists postgis;

alter table public.stores add column if not exists location
  geography(point, 4326);
create index if not exists stores_location_idx on public.stores using gist (location);

create or replace function public.nearby_listings(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer default 8000,
  p_limit integer default 50
)
returns table (
  listing_id uuid,
  store_id uuid,
  title text,
  category text,
  unit text,
  price_rupiah integer,
  quantity_available integer,
  pickup_start timestamptz,
  pickup_end timestamptz,
  allergen_info text,
  storage_note text,
  distance_m numeric
)
language sql
security definer
set search_path = ''
as $$
  select l.id, l.store_id, l.title, l.category, l.unit, l.price_rupiah,
         l.quantity_available, l.pickup_start, l.pickup_end,
         l.allergen_info, l.storage_note,
         round(st_distance(s.location::geography,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography)) as distance_m
  from public.food_listings l
  join public.stores s on s.id = l.store_id
  where l.status = 'tersedia'
    and l.quantity_available > 0
    and l.pickup_end > now()
    and s.verification_status = 'terverifikasi'
    and s.location is not null
    and st_dwithin(s.location, st_setsrid(st_makepoint(p_lng, p_lat), 4326), p_radius_m)
  order by distance_m asc, l.pickup_end asc
  limit least(p_limit, 100);
$$;

revoke all on function public.nearby_listings(double precision, double precision,
  integer, integer) from public, anon, authenticated;
grant execute on function public.nearby_listings(double precision, double precision,
  integer, integer) to anon, authenticated;

-- ============================================================
-- G. JOB TERJADWAL (pg_cron) — aktifkan extension di Dashboard dulu
-- ============================================================
create extension if not exists pg_cron;

do $$
begin
  if to_regclass('cron.job') is not null then
    if not exists (select 1 from cron.job where jobname = 'pp-reservasi-lepas') then
      perform cron.schedule(
        'pp-reservasi-lepas', '* * * * *',
        'select public.release_expired_reservations();'
      );
    end if;
    if not exists (select 1 from cron.job where jobname = 'pp-listing-kedaluwarsa') then
      perform cron.schedule(
        'pp-listing-kedaluwarsa', '*/5 * * * *',
        'select public.expire_listings();'
      );
    end if;
  end if;
end $$;

-- ============================================================
-- H. HAK SERVICE-ROLE ( trusted server)
-- ============================================================
grant all on public.reservations, public.reviews, public.reports,
  public.notifications to service_role;
grant all on function public.release_expired_reservations(),
  public.expire_listings() to service_role;

commit;
