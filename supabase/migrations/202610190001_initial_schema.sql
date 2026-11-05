-- PanganPutar: foundation only. Apply through Supabase migrations/SQL Editor.
-- Demo objects in Flutter are NOT synchronized into these production tables.
-- Orders, payments, verification and stock reservation require a trusted server.
begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Pengguna'
    check (char_length(btrim(display_name)) between 3 and 40),
  role text not null default 'penerima' check (role in ('penerima', 'penyedia')),
  created_at timestamptz not null default now()
);

-- OAuth/SMS accounts receive an ordinary recipient profile. Never trust
-- user-editable metadata for admin, verification or payment authorization.
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  proposed_name text;
begin
  proposed_name := btrim(coalesce(
    new.raw_user_meta_data ->> 'display_name',
    new.raw_user_meta_data ->> 'full_name',
    'Pengguna'
  ));
  if char_length(proposed_name) < 3 then proposed_name := 'Pengguna'; end if;
  insert into public.profiles (id, display_name)
  values (new.id, left(proposed_name, 40));
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Also support an existing project whose users predate this migration.
insert into public.profiles (id)
select id from auth.users on conflict (id) do nothing;

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 3 and 60),
  business_type text not null check (business_type in (
    'warung', 'roti', 'restoran', 'petani', 'kelontong', 'lainnya'
  )),
  address text not null check (char_length(btrim(address)) >= 10),
  city text not null check (char_length(btrim(city)) >= 3),
  verification_status text not null default 'belum_diajukan'
    check (verification_status in (
      'belum_diajukan', 'menunggu_review', 'terverifikasi', 'ditolak'
    )),
  created_at timestamptz not null default now(),
  unique (owner_id)
);

-- Sensitive business identifiers and phone numbers MUST NOT live in the
-- publicly readable store row. Evidence remains private to owner/server.
create table public.store_applications (
  store_id uuid primary key references public.stores(id) on delete cascade,
  business_number text not null check (business_number ~ '^[0-9]{13,20}$'),
  phone text not null check (phone ~ '^[0-9]{9,15}$'),
  photo_prepared boolean not null default false,
  location_prepared boolean not null default false,
  submitted_at timestamptz not null default now()
);

create table public.food_listings (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete restrict,
  title text not null check (char_length(btrim(title)) >= 3),
  category text not null default 'lainnya' check (category in (
    'nasi', 'roti', 'lauk', 'sayur', 'buah', 'minuman', 'paket', 'jajanan', 'lainnya'
  )),
  description text,
  quantity_total integer not null check (quantity_total > 0),
  quantity_available integer not null check (
    quantity_available >= 0 and quantity_available <= quantity_total
  ),
  unit text not null default 'porsi',
  price_rupiah integer not null default 0 check (price_rupiah >= 0),
  pickup_start timestamptz not null,
  pickup_end timestamptz not null,
  storage_note text,
  allergen_info text,
  image_path text,
  status text not null default 'draft'
    check (status in ('draft', 'tersedia', 'habis', 'ditutup')),
  created_at timestamptz not null default now(),
  check (pickup_end > pickup_start and pickup_end <= pickup_start + interval '24 hours'),
  unique (id, store_id)
);

-- Server-owned transaction snapshots. No client INSERT/UPDATE/DELETE grants.
-- The future order endpoint must atomically enforce stock, device quota,
-- ownership, verification, price and pickup window; not merely insert rows.
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete restrict,
  store_id uuid not null references public.stores(id) on delete restrict,
  listing_id uuid not null,
  quantity integer not null check (quantity > 0),
  unit_price_rupiah integer not null check (unit_price_rupiah >= 0),
  total_rupiah bigint generated always as (quantity::bigint * unit_price_rupiah) stored,
  status text not null default 'menunggu' check (status in (
    'menunggu', 'dikonfirmasi', 'siap_diambil', 'selesai', 'dibatalkan'
  )),
  payment_status text not null default 'belum_dibayar' check (payment_status in (
    'tidak_perlu', 'belum_dibayar', 'menunggu', 'dibayar', 'gagal', 'kedaluwarsa', 'dikembalikan'
  )),
  created_at timestamptz not null default now(),
  picked_up_at timestamptz,
  foreign key (listing_id, store_id) references public.food_listings(id, store_id)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  amount_rupiah bigint not null check (amount_rupiah >= 0),
  status text not null check (status in (
    'menunggu', 'dibayar', 'gagal', 'kedaluwarsa', 'dikembalikan'
  )),
  method text,
  gateway_reference text unique,
  created_at timestamptz not null default now()
);

create index stores_verification_idx on public.stores (verification_status);
create index listings_store_idx on public.food_listings (store_id);
create index listings_available_idx on public.food_listings (status, pickup_end);
create index orders_recipient_idx on public.orders (recipient_id);
create index orders_store_idx on public.orders (store_id);
create index payments_order_idx on public.payments (order_id);

alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.store_applications enable row level security;
alter table public.food_listings enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;

revoke all on public.profiles, public.stores, public.store_applications,
  public.food_listings, public.orders, public.payments from public, anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, role) on public.profiles to authenticated;
create policy profiles_read_self on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- All published store columns are public business information. Column grants
-- deliberately exclude verification_status so clients cannot self-approve.
grant select on public.stores to anon, authenticated;
grant insert (owner_id, name, business_type, address, city) on public.stores to authenticated;
create policy stores_read_verified on public.stores for select to anon, authenticated
  using (verification_status = 'terverifikasi');
create policy stores_read_owner on public.stores for select to authenticated
  using (owner_id = (select auth.uid()));
create policy stores_create_owner on public.stores for insert to authenticated
  with check (
    owner_id = (select auth.uid()) and exists (
      select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'penyedia'
    )
  );

grant select on public.store_applications to authenticated;
grant insert (store_id, business_number, phone, photo_prepared, location_prepared)
  on public.store_applications to authenticated;
create policy applications_read_owner on public.store_applications for select to authenticated
  using (exists (select 1 from public.stores s where s.id = store_id and s.owner_id = (select auth.uid())));
create policy applications_submit_owner on public.store_applications for insert to authenticated
  with check (exists (select 1 from public.stores s where s.id = store_id and s.owner_id = (select auth.uid())));

-- Publishing/editing listings is intentionally server-owned in this foundation.
-- No direct stock updates can bypass the future atomic ordering boundary.
grant select on public.food_listings to anon, authenticated;
create policy listings_read_available on public.food_listings for select to anon, authenticated
  using (
    status = 'tersedia' and quantity_available > 0 and pickup_end > now()
    and exists (select 1 from public.stores s where s.id = store_id and s.verification_status = 'terverifikasi')
  );
create policy listings_read_owner on public.food_listings for select to authenticated
  using (exists (select 1 from public.stores s where s.id = store_id and s.owner_id = (select auth.uid())));

grant select on public.orders, public.payments to authenticated;
create policy orders_read_recipient on public.orders for select to authenticated
  using (recipient_id = (select auth.uid()));
create policy orders_read_store_owner on public.orders for select to authenticated
  using (exists (select 1 from public.stores s where s.id = store_id and s.owner_id = (select auth.uid())));
create policy payments_read_recipient on public.payments for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.recipient_id = (select auth.uid())));

-- Explicit trusted-server privileges. Never put a service-role key in Flutter.
grant all on public.profiles, public.stores, public.store_applications,
  public.food_listings, public.orders, public.payments to service_role;

-- Food photos are PRIVATE until a trusted publication flow is implemented.
-- Path convention: <auth user UUID>/<random filename>. No identity documents.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('food-photos', 'food-photos', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']);

create policy food_photos_read_owner on storage.objects for select to authenticated
  using (bucket_id = 'food-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy food_photos_upload_owner on storage.objects for insert to authenticated
  with check (bucket_id = 'food-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy food_photos_update_owner on storage.objects for update to authenticated
  using (bucket_id = 'food-photos' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'food-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy food_photos_delete_owner on storage.objects for delete to authenticated
  using (bucket_id = 'food-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

commit;
