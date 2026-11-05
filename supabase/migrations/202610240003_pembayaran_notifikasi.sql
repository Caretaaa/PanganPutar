-- PanganPutar: pembayaran & notifikasi (tahap 6).
--
-- Keadaan uang TIDAK pernah diputus klien:
--   finalize_paid_order / fail_payment_order dipanggil HANYA oleh
--   Edge Function webhook Midtrans dengan service role, setelah
--   tanda tangan sha512 divalidasi. Klien hanya MEMANTAU status.
--
-- Notifikasi masuk otomatis dari perubahan orders lewat trigger (server),
-- sehingga tidak ada UI yang bisa menulis notification palsu.
begin;

-- ============================================================
-- A. PENYELESAIAN (webhook Midtrans → server)
-- ============================================================
create or replace function public.finalize_paid_order(p_order_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.orders
    set payment_status = 'dibayar',
        status = case when status = 'menunggu' then 'dikonfirmasi' else status end
    where id = p_order_id
      and payment_status in ('belum_dibayar', 'menunggu')
      and status <> 'dibatalkan';
  if not found then
    raise exception 'pesanan bukan kandidat pembayaran (idempoten)'
      with detail = 'orders tidak dalam status belum dibayar / sudah dibatalkan';
  end if;

  -- Stok milik pesanan lunas: reservasi disuntik 'tuntas' agar cron
  -- tidak melepasnya (pembeli yang membayar tidak digugurkan).
  update public.reservations
    set status = 'tuntas', updated_at = now()
    where order_id = p_order_id and status = 'aktif';

  return true;
end;
$$;

create or replace function public.fail_payment_order(p_order_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  select rs.listing_id, rs.store_id, rs.quantity into r
  from public.reservations rs
  where rs.order_id = p_order_id and rs.status = 'aktif';

  update public.reservations
    set status = case when r.listing_id is null then 'tuntas' else 'kadaluwarsa' end,
        updated_at = now()
    where order_id = p_order_id and status = 'aktif';

  update public.orders
    set payment_status = 'gagal', status = 'dibatalkan'
    where id = p_order_id
      and payment_status in ('belum_dibayar', 'menunggu')
      and status <> 'dibatalkan';
  if not found then
    raise exception 'pesanan bukan kandidat gagal-bayar '
      with detail = 'sudah dibayar / dibatalkan';
  end if;

  if r.listing_id is not null then
    update public.food_listings
      set quantity_available = quantity_available + r.quantity,
          status = case
            when status = 'habis' and pickup_end > now() then 'tersedia'
            else status
          end
      where id = r.listing_id and store_id = r.store_id;
  end if;

  return true;
end;
$$;

-- ============================================================
-- B. LAYAR NOTIFIKASI OTOMATIS (trigger orders → notifications)
-- ============================================================
alter table public.notifications
  add column if not exists order_id uuid references public.orders(id)
    on delete cascade;
create index if not exists notifications_order_idx
  on public.notifications (profile_id, order_id);

create or replace function public.orders_notify_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.notifications (profile_id, kind, title, body, order_id)
    values (
      NEW.recipient_id, 'info', 'Pesanan dibuat',
      case
        when NEW.unit_price_rupiah > 0 then
          'Selesaikan pembayaran dalam 10 menit agar reservasi stok tidak '
          || 'kedaluwarsa.'
        else 'Tunjukkan kode pengambilan saat mengambil pesanan.'
      end,
      NEW.id
    );
  elsif TG_OP = 'UPDATE' then
    if NEW.payment_status = 'dibayar' and OLD.payment_status <> 'dibayar' then
      insert into public.notifications (profile_id, kind, title, body, order_id)
      values (NEW.recipient_id, 'pesanan_dikonfirmasi', 'Pembayaran diterima',
        'Pesanan Anda telah dibayar. Tunjukkan QR saat pengambilan.',
        NEW.id);
    end if;
    if NEW.status = 'dibatalkan' and OLD.status <> 'dibatalkan' then
      insert into public.notifications (profile_id, kind, title, body, order_id)
      values (NEW.recipient_id, 'info', 'Pesanan dibatalkan',
        'Reservasi kadaluwarsa / pembayaran tidak selesai. Stok dibuka '
          || 'kembali untuk yang lain.', NEW.id);
    end if;
  end if;
  return coalesce(NEW, OLD);
end;
$$;

drop trigger if exists orders_notify_trigger on public.orders;
create trigger orders_notify_trigger
after insert or update on public.orders
for each row execute function public.orders_notify_change();

-- Pengingat ambil: pesanan lunas yang window pengambilannya tinggal
-- ≤ 2 jam. Idempoten per pesanan lewat kolom order_id (satu pengingat).
create or replace function public.remind_pickup()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
begin
  insert into public.notifications (profile_id, kind, title, body, order_id)
  select o.recipient_id, 'pengingat_ambil', 'Waktunya mengambil pesanan',
    'Pesanan "' || l.title || '" menunggu diambil. Ambil sebelum '
      || to_char(l.pickup_end, 'HH24:MI') || '.',
    o.id
  from public.orders o
  join public.food_listings l
    on l.id = o.listing_id and l.store_id = o.store_id
  where o.payment_status = 'dibayar'
    and o.status in ('menunggu', 'dikonfirmasi', 'siap_diambil')
    and l.pickup_end > now()
    and l.pickup_end <= now() + interval '2 hours'
    and not exists (
      select 1 from public.notifications n
      where n.kind = 'pengingat_ambil' and n.order_id = o.id
    );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Jalur terjadwal bila pg_cron aktif (aman bila belum).
do $$
begin
  if to_regclass('cron.job') is not null then
    if not exists (select 1 from cron.job where jobname = 'pp-pengingat-ambil') then
      perform cron.schedule(
        'pp-pengingat-ambil', '*/10 * * * *',
        'select public.remind_pickup();'
      );
    end if;
  end if;
end $$;

-- ============================================================
-- C. TOKEN PERANGKAT PUSH (buat tahap FCM — proyek Firebase milik
--    pemilik app; tanpa itu tabel ini tinggal kosong, tak masalah)
-- ============================================================
create table if not exists public.fcm_tokens (
  token text primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);

alter table public.fcm_tokens enable row level security;
revoke all on public.fcm_tokens from public, anon, authenticated;
grant select, insert, update, delete on public.fcm_tokens to authenticated;
drop policy if exists fcm_tokens_owner on public.fcm_tokens;
create policy fcm_tokens_owner on public.fcm_tokens for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- ============================================================
-- D. HAK SERVER
-- ============================================================
grant all on public.fcm_tokens to service_role;
grant execute on function public.finalize_paid_order(uuid),
  public.fail_payment_order(uuid),
  public.remind_pickup() to service_role;

commit;
