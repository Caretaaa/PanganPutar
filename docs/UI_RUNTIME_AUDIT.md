# Audit UI runtime — 29 Oktober 2026

## Koreksi terbatas setelah review parent: lokasi Beranda 320 px

Review parent menemukan status default terpotong menjadi “Lokasi belum dip...”
di capture Beranda sebelumnya. Ini cacat keterbacaan, meskipun tidak menimbulkan
exception layout. Koreksi hanya menyentuh bagian lokasi di `home_screen.dart`:

- Belum memilih: satu aksi berikon **Pilih lokasi**, tanpa status redundan.
- Sudah memilih: nama lokasi utuh, tanpa `maxLines: 1`/elipsis. Nama dan tombol
  memakai `Wrap`, sehingga tombol berpindah baris bila ruang tidak cukup.
- Menu, callback pemilihan, penyimpanan preferensi, dan filter tidak diubah.

Bukti Chromium 320×740 yang benar-benar diperiksa:
[sebelum](ui-audit-2026-10-29/before-location-320.png),
[default sesudah](ui-audit-2026-10-29/after-Beranda-320.png), dan
[lokasi terpilih utuh](ui-audit-2026-10-29/after-location-selected-320.png).
Capture Beranda 320 pada laporan ini telah diganti dengan bukti terbaru.

Validasi koreksi: **13 tes di `test/redesign_feed_test.dart` lulus**, termasuk
default→pilih `Kota Bandung (pusat)` pada lebar 320 dengan teks 1×, 1,3×, dan 2×.
Assertion memeriksa teks tidak terpotong, batas kanan, aksi tetap tersedia,
dan tidak ada exception. Harness memakai tema serta Montserrat bundel aplikasi.
Font besar dibuktikan melalui widget test; capture Chromium memakai teks 1×.
Tidak menjalankan ulang full suite, analyze, atau build final pada koreksi ini.

## Lingkungan dan hasil

Flutter web **debug**, Chromium headless nyata (`/usr/bin/chromium`), bukan
golden widget yang diperlakukan sebagai browser. Aplikasi dijalankan dengan:

```sh
/usr/bin/flutter run -d web-server --web-hostname=127.0.0.1 \
  --web-port=8765 --no-web-resources-cdn
```

Navigasi, input, resize, screenshot, dan console ditangkap melalui Chrome
DevTools Protocol. Profil browser terisolasi di `/tmp/opencode/pangan-chrome-audit`.
Data/nama dalam capture adalah sesi demo audit, bukan pelanggan nyata.

**Konfirmasi terakhir dari fresh reload: 0 exception Flutter dan 0 exception
JavaScript tak tertangani** pada empat tab di 320/375/600/1280 px dan melanjutkan
pembayaran simulasi. [Ringkasan error](ui-audit-2026-10-29/error-summary.json).
Ini bukan klaim bahwa semua integrasi produksi sudah lolos.

## Temuan dan koreksi

| Temuan runtime | Koreksi | Bukti |
| --- | --- | --- |
| Header landing overflow 76 px; tautan masuk keluar layar 320 px | Identitas fleksibel; tautan masuk pindah ke kelompok aksi yang membungkus | [Sebelum](ui-audit-2026-10-29/before-landing-320.png) · [Sesudah](ui-audit-2026-10-29/after-landing-320.png) |
| Dropdown peran overflow 92 px; kategori juga meluber di 320 px | Dropdown mengisi ruang tersedia; label terpilih peran singkat, pilihan lengkap tetap di menu | [Sebelum](ui-audit-2026-10-29/before-Akun-320.png) · [Sesudah](ui-audit-2026-10-29/after-account-guest-320.png) |
| Preferensi tema pecah menjadi “Ter/an/g”, “Gel/ap” | ChoiceChip membungkus **antar pilihan**, bukan di tengah kata | [Sesudah](ui-audit-2026-10-29/after-theme-320.png) |
| Badge toko mendesak judul makanan menjadi kolom sempit | `AdaptiveSectionHeader`: judul lebar penuh, badge di bawah pada ruang sempit | [Sebelum](ui-audit-2026-10-29/before-detail-320.png) · [Sesudah](ui-audit-2026-10-29/after-detail-320.png) |
| Judul Pesanan demo di area penyedia tersisa beberapa huruf per baris | Judul dan aksi pindai beralih vertikal pada ponsel | [Sebelum](ui-audit-2026-10-29/before-provider-bottom-320.png) · [Sesudah](ui-audit-2026-10-29/after-provider-bottom-320.png) |
| Akun, pembayaran, dan area penyedia meregang selebar desktop | `AppContentFrame` membatasi kanvas; tabel pembayaran tetap rata kanan | [Sebelum](ui-audit-2026-10-29/before-payment-1280.png) · [Sesudah](ui-audit-2026-10-29/after-payment-1280.png) |
| Label tombol simulasi pecah di tengah kata | Kelompok aksi `Wrap`, tanpa memaksakan dua setengah kolom | [Sesudah](ui-audit-2026-10-29/after-simulation-bottom-320.png) |
| Pergantian bar↔rail menginisialisasi ulang halaman dan request | GlobalKey mempertahankan subtree halaman saat reparent; pencarian “roti” tetap ada setelah resize 375→600→320 | [Query dipertahankan](ui-audit-2026-10-29/after-search-retained-600.png) |

Koreksi terkait: filter pencarian memakai `NestedScrollView` agar panel dapat
bergulir pada ruang pendek; reset terlihat saat pengguna mengetik; header
beranda lebih ringkas; tombol bertema memakai Montserrat dan target dasar 48 px;
tombol tutup banner mempunyai tooltip dan target 48 px. Empty/error serta hasil
pembayaran dapat bergulir di viewport pendek. Badge kejujuran dapat membungkus.
Guest pesanan/penyedia memiliki tombol masuk ke alur demo yang sudah ada.

Tidak ada layanan, endpoint, model data, kuota, atau keputusan pembayaran yang
diganti. Label DEMO, Data contoh, Foto ilustrasi, SIMULASI/tanpa uang nyata,
serta konsekuensi kuota tidak kembali dipertahankan.

## Cakupan browser yang benar-benar dijalankan

- Onboarding pertama pada 320×740, 375×812, 600×960, 1280×900; tiga langkah
  dilalui pada 320 px. Landing diperiksa pada keempat ukuran.
- Beranda, Jelajahi, Pesanan, Akun pada keempat ukuran, termasuk fresh-reload
  smoke terakhir setelah data contoh selesai dimuat, bukan hanya skeleton.
- Pencarian “roti”, Terapkan, hasil contoh, dan retensi input saat bar↔rail.
- Masuk demo penerima; detail pada 320/1280; pesan berbayar; pembayaran fallback
  simulasi; simulasi lunas; pesanan bertanda SIMULASI; tiket QR; simulasi gagal
  dan coba lagi. Failure state juga dilihat pada landscape 740×360.
- Masuk demo penyedia; verifikasi, QR toko, penawaran, pesanan masuk pada
  320/1280; membuka formulir verifikasi pada 320. Tidak mengirim verifikasi.
- Tema gelap pada beranda/akun desktop dan beranda/pencarian ponsel/tablet.
  [Desktop gelap](ui-audit-2026-10-29/after-home-dark-1280.png).
- Contoh akhir: [Beranda 320](ui-audit-2026-10-29/after-Beranda-320.png),
  [pesanan 375](ui-audit-2026-10-29/after-Pesanan-375.png),
  [tiket 320](ui-audit-2026-10-29/after-ticket-320.png).

## Pemeriksaan widget terfokus

**86 tes lulus**, bukan full suite:

```sh
flutter test test/app_surface_test.dart test/redesign_feed_test.dart \
  test/redesign_beranda_test.dart test/onboarding_screen_test.dart \
  test/detail_security_test.dart test/catalog_surface_test.dart
```

`app_surface_test.dart` mencakup sepuluh layar di 320/375/600/1280 dan landscape
740×360, teks sampai 1,3×, tema gelap, scroll konten bawah, viewport pencarian
yang dipendekkan seperti saat keyboard terbuka, guest→login, retry galat, dan
simulasi sukses/gagal. Assertion layout dibaca, bukan disembunyikan. Screenshot
widget dari pass terdahulu tidak digunakan sebagai pengganti bukti browser ini.

## Error lingkungan dan batas

- API bawaan `http://10.0.2.2:3000` tidak tersedia. Chromium mencatat timeout
  untuk katalog/detail/pembayaran. Katalog jatuh ke **Data contoh**, pembayaran
  jatuh ke **SIMULASI**. Error jaringan tersebut tidak diklaim sudah diperbaiki.
- Satu assertion engine `Trying to render a disposed EngineFlutterView` terlihat
  sewaktu **hot restart** debug. Tidak muncul pada konfirmasi fresh reload tanpa
  hot restart; bukan exception dari layout layar. Peringatan software WebGL/GPU
  headless juga tercatat. Uji release akhir tetap milik lane parent.
- Belum diuji: Supabase/akun produksi dengan kredensial, transaksi uang nyata,
  kamera/izin QR, Android fisik, keyboard native, submit verifikasi dan penawaran
  produksi, semua halaman bacaan statis. Jangan memperluas klaim ke area ini.
- Final `flutter analyze`, full suite, dan build web sengaja tidak dijalankan
  di lane UI. Parent menjalankannya setelah rekonsiliasi writer.

## Provenansi artefak

PNG di `ui-audit-2026-10-29/` adalah screenshot Chromium dari aplikasi lokal,
bukan gambar promosi atau aset baru yang dikirim di bundle aplikasi. Foto
makanan di dalamnya memakai aset proyek yang sudah berlisensi; tidak diganti.
Log mentah dan skrip CDP sesi tersedia di `/tmp/opencode/pangan-runtime/` dan
`/tmp/opencode/pangan_cdp.py`; hasil tes di
`/tmp/opencode/pangan-focused-final.log`.
