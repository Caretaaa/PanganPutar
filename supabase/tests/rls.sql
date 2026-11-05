-- Run ONLY on a disposable/local Supabase database after the migration.
-- Example: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls.sql
-- Assertions raise on failure. All fixtures roll back; no production users.
begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-4111-8111-111111111111', 'rls-a@example.test', '{"display_name":"Pemilik A","role":"admin"}'),
  ('22222222-2222-4222-8222-222222222222', 'rls-b@example.test', '{"display_name":"Penerima B"}');

do $$ begin
  if (select role from public.profiles where id = '11111111-1111-4111-8111-111111111111') <> 'penerima' then
    raise exception 'FAIL: role metadata trusted by signup trigger';
  end if;
end $$;

update public.profiles set role = 'penyedia' where id = '11111111-1111-4111-8111-111111111111';
insert into public.stores (id, owner_id, name, business_type, address, city, verification_status)
values ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111',
  'Toko uji', 'warung', 'Jalan Pengujian Nomor 1', 'Bandung', 'terverifikasi');
insert into public.store_applications (store_id, business_number, phone)
values ('33333333-3333-4333-8333-333333333333', '1234567890123', '081234567890');
insert into public.food_listings (
  id, store_id, title, quantity_total, quantity_available, pickup_start, pickup_end, status
) values ('44444444-4444-4444-8444-444444444444', '33333333-3333-4333-8333-333333333333',
  'Makanan uji', 4, 4, now(), now() + interval '4 hours', 'tersedia');
insert into public.orders (id, recipient_id, store_id, listing_id, quantity, unit_price_rupiah)
values ('55555555-5555-4555-8555-555555555555', '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-444444444444', 2, 5000);
insert into public.payments (order_id, amount_rupiah, status)
values ('55555555-5555-4555-8555-555555555555', 10000, 'menunggu');

set local role anon;
do $$ begin
  if not exists (select 1 from public.food_listings where id = '44444444-4444-4444-8444-444444444444') then
    raise exception 'FAIL: public available listing hidden';
  end if;
  begin
    perform * from public.store_applications;
    raise exception 'FAIL: anonymous access to private application';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$ begin
  if exists (select 1 from public.profiles where id = '11111111-1111-4111-8111-111111111111') then
    raise exception 'FAIL: another profile visible';
  end if;
  if exists (select 1 from public.store_applications) then
    raise exception 'FAIL: another store application visible';
  end if;
  if not exists (select 1 from public.orders where id = '55555555-5555-4555-8555-555555555555') then
    raise exception 'FAIL: own order not readable';
  end if;
  if (select total_rupiah from public.orders where id = '55555555-5555-4555-8555-555555555555') <> 10000 then
    raise exception 'FAIL: total calculation';
  end if;
  begin
    update public.profiles set role = 'admin' where id = '22222222-2222-4222-8222-222222222222';
    raise exception 'FAIL: admin self elevation';
  exception when check_violation then null;
  end;
  begin
    update public.orders set payment_status = 'dibayar' where id = '55555555-5555-4555-8555-555555555555';
    raise exception 'FAIL: payment self approval';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.food_listings set quantity_available = 99 where id = '44444444-4444-4444-8444-444444444444';
    raise exception 'FAIL: direct client stock mutation';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $$ begin
  if not exists (select 1 from public.store_applications where store_id = '33333333-3333-4333-8333-333333333333') then
    raise exception 'FAIL: own store application hidden';
  end if;
  if not exists (select 1 from public.orders where id = '55555555-5555-4555-8555-555555555555') then
    raise exception 'FAIL: provider order hidden';
  end if;
  if exists (select 1 from public.payments where order_id = '55555555-5555-4555-8555-555555555555') then
    raise exception 'FAIL: recipient payment details exposed to provider';
  end if;
  begin
    update public.stores set verification_status = 'terverifikasi' where id = '33333333-3333-4333-8333-333333333333';
    raise exception 'FAIL: provider self verification';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
select 'RLS assertions passed; fixtures rolled back.' as result;
