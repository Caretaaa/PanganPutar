-- PanganPutar: manajemen penawaran penyedia (tahap 5).
-- Membuka RLS agar PEMILIK TOKO TERVERIFIKASI bisa menerbitkan/menutup
-- penawaran lewat aplikasi — TANPA membuka jalur stok yang melewati
-- batas pesanan atomik create_order:
--   * insert: stok awal harus sama dengan stok tersedia (tidak ada
--     "tersedia 4 dari total 0" yang dikarang).
--   * update: quantity_total TIDAK boleh berubah; quantity_available hanya
--     boleh TURUN (penyedia tidak boleh menaikkan stok sendiri untuk
--     menghindari spirit kuota — reopen stok yang lewat window tidak ada;
--     penawaran baru dibuat ulang).
--   * delete: hanya baris tanpa riwayat orders (FK menolak sisanya).
-- Idempoten: drop policy dulu, lalu create ulang.
begin;

grant insert, update, delete on public.food_listings to authenticated;

drop policy if exists listings_insert_owner on public.food_listings;
create policy listings_insert_owner on public.food_listings for insert to authenticated
with check (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.owner_id = (select auth.uid())
      and s.verification_status = 'terverifikasi'
  )
  and quantity_total = quantity_available
  and quantity_available >= 0
);

drop policy if exists listings_update_owner on public.food_listings;
create policy listings_update_owner on public.food_listings for update to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = (select auth.uid())
  )
  -- Subquery mengambil kondisi SEBELUM update (snapshot lama):
  and quantity_total = (
    select l.quantity_total from public.food_listings l
    where l.id = id and l.store_id = store_id
  )
  and quantity_available = (
    select l.quantity_available from public.food_listings l
    where l.id = id and l.store_id = store_id
  )
);

drop policy if exists listings_delete_owner on public.food_listings;
create policy listings_delete_owner on public.food_listings for delete to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = (select auth.uid())
  )
);

commit;
