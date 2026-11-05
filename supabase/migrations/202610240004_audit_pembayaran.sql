-- PanganPutar: audit pembayaran (tahap 6, wajib rencana).
-- `payment_events` = log audit TANPA MUTASI: setiap notifikasi Midtrans yang
-- lewat verifikasi signature dicatat apa adanya, berurutan, bahkan bila
-- status tidak berubah (idempoten terlihat di sini, bukan hilang).
-- Server-only: klien tidak diberi akses apa pun.
begin;

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null,
  -- Referensi payments (boleh null bila event lebih dulu dari insert).
  payment_id uuid references public.payments(id) on delete set null,
  transaction_status text not null,
  transaction_id text,
  payment_type text,
  gross_amount bigint,
  raw jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists payment_events_order_idx
  on public.payment_events (order_id, created_at);

-- Jejak notifikasi mentah disimpan di payments (kolom audit).
alter table public.payments add column if not exists raw_notification jsonb;

alter table public.payment_events enable row level security;
revoke all on public.payment_events from public, anon, authenticated;

grant all on public.payment_events to service_role;

commit;
