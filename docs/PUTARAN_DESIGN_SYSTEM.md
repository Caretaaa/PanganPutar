# Putaran Kebaikan — design system

## Arah

Warm and bright surfaces make food photography the focus. The circle is the
signature shape: large-radius cards, round price stickers, and a progress ring
for pickup deadlines. Montserrat is bundled locally and remains the only font
family, keeping Android, iOS, and web rendering consistent.

## Color tokens

| Purpose | Token | Value | Use |
| --- | --- | --- | --- |
| App background | `cream` | `#FFFBF3` | Main light surface |
| Surface | `paper` | `#FFFFFF` | Cards and controls |
| Main text | `ink` | `#12261B` | Headings and body |
| Secondary text | `textSecondaryLight` | `#4B5B51` | Labels and supporting copy |
| Brand accent | `leaf` | `#1F9D55` | Decorative accents and soft tints |
| Filled action | `forest` | `#176B3A` | Primary buttons and free badge |
| Paid badge | `sunshine` | `#FFB020` | Dark text on price sticker |
| Warning | `sunshineSoft` / `warnFgLight` | `#FFF1CC` / `#684200` | Urgent and pending states |
| Error | `coralSoft` / `coral` | `#FCE1DA` / `#A6382A` | Error states |

Contrast ratios for normal text: ink on cream **15.43:1**; secondary on cream
**6.98:1**; white on forest **6.56:1**; ink on sunshine **8.71:1**; warning text
on warning surface **7.90:1**; coral text on coral surface **5.25:1**. The bright
leaf brand green is reserved for non-text accents; filled buttons use forest.

## Shape, spacing, and interaction

- Cards: 22 px radius, soft 1 px outline, light elevation.
- Inputs and buttons: 14 px radius; button minimum height and touch target 44 px.
- Page padding: 20 px on phones and 24 px on tablets; section gap 24 px.
- Fast feedback: 180 ms; standard transitions: 280 ms.
- Light mode is the default. Dark mode remains available as a user preference.

## Shared UI foundations

- `PutaranCountdownRing`: compact remaining-time ring with an accessible full
  duration label and color escalation near the pickup deadline.
- `PutaranPriceBadge`: circular badge with separate accessible styles for free
  and paid offers.
- `ThemeData` and `AppTokens`: shared text, surface, control, shape, and touch
  styles for existing and upcoming screens.

## Katalog — implementasi 29 Oktober 2026

Dokumen ini adalah acuan visual terkini (sesuai README). Spesifikasi radius,
warna, dan elevasi lama di `DESIGN.md` adalah riwayat, bukan pengganti token di
atas. Aturan produk, keamanan pangan, DEMO, SIMULASI, dan transaksi lokal tetap
berlaku; pass ini tidak mengubah layanan maupun aturan pemesanan.

- Beranda memakai header dengan tinggi mengikuti isi. Judul, deskripsi singkat
  cara pesan–ambil, dan dua aksi dapat membungkus pada ponsel/font besar. Tidak
  ada flexible header setinggi tetap yang menimpa konten ketika digulir.
- Tombol muat ulang terlihat di samping jumlah hasil, selain tarik-untuk-muat.
  Penanda `Data contoh` di daftar hanya tampil bila hasil mengandung ID contoh;
  penanda per kartu dan `Foto ilustrasi` tetap dipertahankan.
- `ListingTile` mengukur **ruang kartu**, bukan jenis perangkat: di bawah 440 px
  foto berada di atas; pada kartu lebih lebar foto berada di kiri. Font besar
  juga memakai susunan atas–bawah bila ruang kurang dari 600 px. Kartu tanpa foto
  tidak memaksakan area gambar kosong pada ponsel.
- Stok dan batas ambil berada di baris terpisah agar waktu tidak hilang menjadi
  elipsis. Ring memakai sisa waktu dan jendela ambil dari listing, memperbarui
  setiap 30 detik, dengan label aksesibel. Harga dan aksi tidak menimpa metadata.
- Aksi Pesan menggunakan callback pesan/detail yang tersedia; tanpa callback,
  kontrol nonaktif, bukan tombol yang seolah bekerja. Simpan tetap per sesi.
- Skeleton loading membungkus baris placeholder pada ruang sempit; label foto
  memakai `labelSmall` dari tema, bukan teks mikro 9 px.

### Pemeriksaan terfokus

`test/catalog_surface_test.dart` menguji kartu pada lebar 360/600/840 px, terang
dan gelap, dengan teks 1,3×; menekan Pesan/Simpan dan memeriksa exception layout.
Capture opsional memakai font Montserrat, ikon Material, dan foto aset yang
benar-benar dimuat:

```sh
flutter test test/catalog_surface_test.dart --update-goldens \
  --dart-define=UI_CAPTURE_DIR=/tmp/opencode/pangan-ui-after
flutter test test/redesign_feed_test.dart test/redesign_beranda_test.dart
```

Tes beranda menambah lebar 320×740 dan 600×960 pada teks 1,3×, termasuk setelah
gulir. Ini bukti render Flutter/widget, **bukan** bukti browser atau perangkat
Android. Uji perangkat fisik, navigasi shell lengkap, dan build web tetap perlu
lane verifikasi akhir. Foto dan lisensinya tidak diganti pada pass ini.

## Penguatan runtime lintas layar — 29 Oktober 2026

- `AppContentFrame` menyatukan lebar baca shell, detail, pembayaran, dan hub
  penyedia. Padding halaman hanya mengurus jarak tepi; jangan lagi menghitung
  margin desktop dari lebar jendela penuh di dalam area yang sudah memakai rail.
- Perubahan bar↔rail mempertahankan subtree halaman, input, scroll, dan request.
  Rail expanded memakai `labelType.none`, rail ringkas memakai label penuh.
- `AdaptiveSectionHeader` menumpuk badge/aksi **setelah** judul pada ruang sempit,
  bukan memampatkan judul sampai tersisa beberapa huruf.
- Kontrol dasar memakai Montserrat dan tinggi dasar 48 px. Pilihan tema memakai
  chip utuh yang dapat pindah baris; dropdown dibatasi ruang aktual.
- Panel pencarian dapat bergulir bersama header ketika viewport pendek; aksi
  reset/terapkan dan aksi simulasi membungkus antar tombol, bukan antar huruf.
- State kosong, galat, dan hasil pembayaran dapat bergulir bila ruang pendek.
  Badge kejujuran mempertahankan teks lengkap dengan pembungkusan bila perlu.

Audit kini memiliki bukti **Chromium nyata**, bukan hanya render kartu widget:
lihat [UI_RUNTIME_AUDIT.md](UI_RUNTIME_AUDIT.md) untuk temuan sebelum/sesudah,
matriks layar, 86 tes terfokus, log error, dan batas pemeriksaan produksi.

## Audit lanjutan — 2 November 2026

Pemeriksaan pada Flutter web Chromium setelah pass UI lanjutan tercatat di
[ui-redesign-2026-11-02/README.md](ui-redesign-2026-11-02/README.md).
Ini pemeriksaan terpisah dari hasil historis 29 Oktober di atas. Perubahan
visual/copy terbatas pada tiket dan form penyedia: hasil QR toko kini bernama **“QR toko cocok”**;
teksnya tidak lagi menyamakan kecocokan identitas QR dengan posisi fisik,
pelunasan, kesiapan pesanan, atau keamanan makanan. Kode manual dan aksi pindai
tetap ada. Copy di QR toko penyedia juga menyebut kecocokan ID, bukan posisi
fisik atau jaminan keamanan pangan. Petunjuk NIB/NPWP pada form verifikasi sekarang dapat membungkus
dua baris pada 320 px sehingga penyangkalan verifikasi resmi tidak terpotong.
Tidak ada token warna, tipografi, radius, atau aturan transaksi yang
diganti pada pass ini.
