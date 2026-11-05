# Backend inti PanganPutar (tahap 3–6)

Status: **tahap 6 — pembayaran & notifikasi masuk**. Mode aktif aplikasi
tetap demo (`PRODUCTION_MODE: "false"`); jalur produksi memanggil RPC ini
otomatis bila SQL & Edge Functions diterapkan, dan jatuh jujur bila belum.

## Terapkan urut
1. `migrations/202610190001_initial_schema.sql` (sudah ada)
2. `migrations/202610240001_backend_inti.sql` ← tahap 3 (reservasi, RPC, data sosial)
3. `migrations/202610240002_penyedia_manajer.sql` ← tahap 5 (penerbitan penawaran
   oleh pemilik toko terverifikasi: insert/update/delete `food_listings` dengan
   guard stok — `quantity_total` tak berubah, `quantity_available` hanya boleh
   ke bawah, tak ada bypass `create_order`)
4. `migrations/202610240003_pembayaran_notifikasi.sql` ← tahap 6
   (`finalize_paid_order`/`fail_payment_order` untuk webhook; trigger
   orders → notifications; kolom `notifications.order_id`; pengingat
   `remind_pickup()` + jadwal cron; tabel `fcm_tokens`)
5. `migrations/202610240004_audit_pembayaran.sql` ← audit log wajib
   (`payment_events`: setiap notifikasi terverifikasi dicatat apa adanya
   — termasuk yang diabaikan — plus kolom `payments.raw_notification`)
6. Deploy Edge Functions (tahap 6):
   ```
   supabase functions deploy payments-snap
   supabase functions deploy payments-status
   supabase functions deploy payments-webhook --no-verify-jwt  # Midtrans tanpa JWT
   supabase functions deploy push-reminder
   supabase secrets set MIDTRANS_SERVER_KEY=...
   supabase secrets set MIDTRANS_IS_PRODUCTION=false   # true → app.midtrans.com
   supabase secrets set FCM_SERVER_KEY=...             # legacy key; HTTP v1 menyusul
   ```
   Pasang Payment Notification URL Midtrans =
   `https://<proj>.supabase.co/functions/v1/payments-webhook`
7. Aktifkan ekstensi bila Dashboard belum mengizinkan lewat SQL:
   `postgis`, `pg_cron`. Kalau organisation plan membatasi, aktifkan via
   Dashboard → Database → Extensions, lalu jalankan file migrasi lagi
   (idempoten: semua `if not exists` / `create or replace`).

## RPC yang tersedia (klien memakai di tahap 4)

| RPC | Dipanggil | Efek |
|---|---|---|
| `create_order(listing_id, store_id, quantity)` | pembeli masuk | transplantasi stok atomik `FOR UPDATE`, kutip kuota (maks 4 porsi / 2 pesanan per hari, server-owned), `orders` + `reservations TTL 10 mnt`; kembalikan `order_id`, `pickup_token` (plaintext sekali), `reservation_expires_at` |
| `claim_pickup(store_id, token)` | penyedia memindai QR | membandingkan SHA-256 token; menuntaskan pesanan (QR bekas ditolak) |
| `nearby_listings(lat, lng, radius_m, limit)` | feed "Dekat saya" | PostGIS `ST_DWithin`, urut jarak ↑ lalu `pickup_end` ↑; hanya toko terverifikasi |
| `release_expired_reservations()` | cron 1 menit | stok kembali, pesanan belum dibayar dibatalkan |
| `expire_listings()` | cron 5 menit | listing lewat window → `habis`/`ditutup` |

Tabel baru: `reservations` (server-only), `reviews` (dua arah, RLS peserta),
`reports` (klien hanya INSERT; sisa baca server), `notifications` (server
menulis; pemilik membaca/menandai baca).

## OTP + RBAC
- Supabase Auth Phone mengirim OTP via penyedia SMS — **butuh akun SMS**
  (Twilio/MessageBird/Vonage) yang belum kita punya; selama itu login
  lokal perangkat tetap dipakai (sesuai keputusan sementara).
- Peran: `profiles.role` (`penerima`/`penyedia`) + status verifikasi toko.
  Admin **selalu dari server** (SQL), tidak bisa dipilih dari klien —
  metadata pengguna tidak dipercaya (lihat di standar di migrasi awal).
- Blokir akun: tambahkan baris di `profiles` kolom `banned_until` nanti;
  RLS pengecualian lewat fungsi server, bukan klien.

## Pembayaran (tahap 6 — berjalan)
- **Nominal & keputusan uang ada di server**: `payments-snap` menolak
  nominal yang tidak sama dengan `total_rupiah` di orders;
  `item_details` dibangun dari data listing di server; `expiry` Snap =
  masa reservasi (10 menit) supaya tidak ada celah "Snap hidup lebih
  lama dari reservasi".
- Webhook memverifikasi `sha512(order_id+status_code+gross_amount+key)`,
  lalu **konfirmasi ulang lewat GET status API Midtrans sebelum mutasi**
  (payload notifikasi tidak dipercaya mentah); GET gagal → 502 tanpa
  mutasi, Midtrans akan mengulang.
- Idempoten + **tanpa transisi mundur**: order `dibayar` tidak bisa
  jadi gagal oleh notifikasi berikutnya, order gagal/`dibatalkan` tidak
  dibangkitkan jadi dibayar. `capture` hanya final bila
  `fraud_status = 'accept'`.
- Log audit wajib: `payment_events` (migrasi 004) menyimpan SETIAP
  notifikasi terverifikasi — termasuk yang diabaikan — dengan `raw`
  JSON; `payments.raw_notification` memuat payload yang mengubah status.
- Klien TIDAK PERNAH menandai lunas: UI hanya memantau
  `payments-status`; keputusan tak tergantung layar.
- Simulasi offline (berlabel jelas) tetap tersedia bila Edge Function
  belum terpasang — tanpa uang nyata.
- Klien: `MidtransPaymentService` (jalur `/functions/v1/payments-*`,
  Bearer JWT pengguna + `apikey` publishable/anon key Supabase);
  `PaymentScreen(produksi: true)` tidak menulis status lokal.
- Refund: tidak ada endpoint (jujur); butuh desain admin server.

## Notifikasi (tahap 6)
- Penulisan via trigger server (`orders_notify_change`) — tidak bisa
  dipalsukan dari klien; pemilik membaca `notifications` (RLS) dan
  menandai baca sendiri.
- Pengingat: `remind_pickup()` (cron tiap 10 menit) menulis pengingat
  satu kali per pesanan (idempoten dengan `order_id`).
- Push FCM: proyek Firebase milik pemilik aplikasi diperlukan;
  `push-reminder` mengirim notifikasi yang belum dibaca ke token di
  `fcm_tokens`. Tanpa proyek Firebase, fungsi menjawab jujur:
  "push belum dikonfigurasi". Catatan: kolom pushed_at belum ada —
  pemanggilan berulang bisa mengirim ulang notifikasi yang sama; lembut
  (tidak sampai hilang), migrasi HTTP v1 menambah kolom pushed_at.
- **Layar UI notifikasi dalam aplikasi belum dibangun** — datanya sudah
  tersedia lewat PostgREST; pengiriman push meminta proyek Firebase.

## Checklist pengujian (logika kritis — jalan di SQL editor uji)
1. **Reservasi stok atomik**: dua sesi `create_order` pada
   listing sisa 1 → tepat satu sukses, lain gagal `stok tidak cukup`;
   `quantity_available` pas berkurang satu kali.
2. **TTL kedaluwarsa**: buat order berbayar, `now()+11 menit`, jalankan
   `release_expired_reservations()` → stok kembali, order `dibatalkan`,
   reservasi `kadaluwarsa`.
3. **Kuota**: `create_order` ke-3 pada hari sama → gagal
   `kuota pesanan harian habis`; 5 porsi terpotong → gagal kuota porsi.
4. **QR bekas**: `claim_pickup` dua kali token sama → sukses pertama,
   kedua `QR bekas tidak berlaku`.
5. **Token salah**: token acak → `token tidak dikenal`.
6. **Terdekat**: `nearby_listings` mengurut jarak ↑; radius di luar →
   kosong; toko belum diverifikasi tak muncul.
7. **Ulasan**: INSERT untuk pesanan `selesai` oleh peserta saja;
   luar peserta → ditolak RLS.
8. **Webhook (tahap 6)**: kirim `capture` dua kali untuk order sama →
   pertama menerapkan perubahan, kedua dijawab `idempoten` (tidak ada
   stok dibuka dua kali); tanda tangan salah → 403; nominal beda
   dengan `total_rupiah` → `payments-snap` menolak.
9. **Pengingat**: `remind_pickup()` pada pesanan lunas window ≤ 2 jam →
   sekali tersisip; panggil lagi → tidak dobel (dedupe `order_id`).
10. **Notifications RLS**: pembeli lain tidak bisa membaca/baca tanda
    notifikasi milik orang lain.

## Yang belum (jujur)
- Penerapan SQL & deploy Edge Functions masih tangan pemilik proyek
  (kunci admin tidak dan tidak akan ada di repo).
- Layar UI notifikasi dalam aplikasi belum dibangun (datanya siap).
- Push FCM HTTP v1 (OAuth) susul di belakang legacy server key.

## Pasangan klien (tahap 4–6 — done)

| Layar/alur | Sekarang memanggil |
|---|---|
| Beranda + lokasi terpilih (produksi) | `fetchNearbyListings()` → `nearby_listings` (RPC PostGIS); jarak tampil per kartu dari hasil server, bila RPC belum ada jatuh ke feed biasa **tanpa** angka jarak lokal |
| Tombol Pesan (produksi) | `createOrder()` → `create_order`; plaintext token QR disimpan di perangkat (`pp_pickup_tokens_v1`, kelas `PickupTokenVault`); bila RPC belum ada → pesan jujur + arahan migrasi, TANPA fallback sukses palsu |
| Daftar pesanan (produksi) | `fetchMyOrders()`; kode pickup dari vault perangkat — server memang sengaja tidak menyimpan plaintext |
| Pemindai penyedia (produksi) | `claimPickup()` → `claim_pickup` dari dashboard penyedia produksi (`ProviderHubScreen` otomatis mode produksi bila `PRODUCTION_MODE=true`); hasil pindai dibaca `tokenDariPindai` (QR tiket panganputar://ambil atau token telanjang, dinormalisasi huruf besar) |
| Dashboard penyedia (produksi) | `getMyStore` + `fetchMyListings`; **Tambah** → `createListing` (butuh migrasi 002), **Tutup** → `updateListing` (status `ditutup`, angka stok tak diubah); alamat & nama toko dari profil server, foto belum didukung (jujur, tanpa gambar contoh) |
| Filter "Terdekat" | `applyFeedFilter(jarakLuar: ...)` — jarak server menggantikan jarak contoh demo |
| Detail → Pesan (mode produksi + masuk) | `_orderProduksi`: `create_order` → (berbayar) `PaymentScreen(produksi: true)` lewat `payments-snap`; gratis → dialog dengan kode + catatan reservasi server; status uang AKHIRNYA dari webhook, bukan UI |
| Pembayaran | `MidtransPaymentService` jalur Edge Functions (`/functions/v1/payments-snap`, `/payments-status`) + Bearer JWT pembeli; bila function belum terpasang → jatuh ke SIMULASI berlabel jelas (tanpa uang nyata) |

Catatan: kuota harian di jalur produksi DIEGAKAN SERVER (maks 4 porsi /
2 pesanan). Klien tidak memakai DailyClaimLedger di jalur produksi —
`create_order` gagal dengan pesan server.
