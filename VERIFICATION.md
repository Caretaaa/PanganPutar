# Rencana verifikasi

## Klaim dan pemilik bukti

1. **Aturan bisnis tetap berlaku — implementasi core dan orchestrator.** Jalankan pengujian kuota, sesi, validasi toko, pemesanan, pembayaran, pembatalan, dan pengambilan QR yang tersedia; tambahkan pengujian terfokus untuk perubahan logika.
2. **Desain dan navigasi dapat dipakai — designer.** Periksa semua pintu masuk fitur, tema, keadaan loading/error/empty, serta ukuran 360×800, 375×667, 600×960, landscape, dan desktop. Gunakan pengujian widget dan tangkapan layar browser jika lingkungan mendukung.
3. **Proyek mandiri dapat dibangun — orchestrator.** Setelah semua perubahan digabungkan, jalankan `flutter analyze`, seluruh `flutter test`, dan build web. Coba build APK bila Android SDK tersedia; laporkan batas lingkungan bila tidak.

## Batas kesimpulan

Uji lokal tidak membuktikan Midtrans produksi, sinkronisasi antarperangkat, keamanan server, kamera pada perangkat fisik, atau performa 60 fps pada HP low-end. Jangan menyatakan integrasi produksi teruji tanpa backend dan perangkat yang sesuai.

## Hasil

### Klaim 2 — Desain & navigasi (designer) — 19 Okt 2026

- Pintu masuk fitur ditelusuri lewat kode: panduan (awal + ulang dari Akun), masuk demo (Akun + pengantar), 4 destinasi + rute push (detail, pembayaran, tiket, area penyedia dari **Akun dan pengantar**, bantuan, dampak, privasi, syarat, admin). Tidak ada tombol mati yang tersisa dari daftar bug sumber ("Masuk aplikasi", "Cari makanan", "Jadi penyedia" sudah beraksi nyata; label "Live" dihapus).
- Tema terang/gelap/sistem tersimpan; badge DEMO/SIMULASI/Foto ilustrasi/Data contoh terpasang di semua permukaan yang menyentuh data/uang.
- State loading/error/empty seragam lewat `AsyncView` (Beranda, Jelajahi, Dampak); gambar rusak/hilang → placeholder (`ListingImage`).
- Pengujian widget terkait UI lulus semua: onboarding (3), detail+keamanan (6), pickup/QR (13). Seluruh `flutter test`: **114 lulus, 1 gagal** — kegagalan di `supabase_auth_service_test` (lane parent/layanan distaging, di luar klaim ini).
- Batasan: tangkapan layar multi-ukuran (360×800 dst.) belum diambil — otomasi browser tidak tersedia di lingkungan ini; diserahkan ke klaim 3 saat build final.

### Klaim 3 — Build (orchestrator) — data sementara dari designer

- `flutter analyze` seluruh proyek: nol temuan.
- `flutter build web --release`: **berhasil** (`✓ Built build/web`, tree-shaking ikon normal).
- Build APK: belum dicoba (cmdline-tools/licensing Android SDK absen di lingkungan — batasan lingkungan yang diketahui).

### Pass katalog dan beranda — 29 Okt 2026

- UI: header mengikuti isi, kartu katalog menyesuaikan lebar dan skala teks, countdown dari jadwal listing, muat ulang terlihat, label data contoh kondisional. Enam render Flutter kartu (360/600/840 px, tema terang/gelap, teks 1,3×) ada di `/tmp/opencode/pangan-ui-after/`; dua ukuran beranda juga diuji (320×740, 600×960). Ini bukan bukti browser atau perangkat fisik.
- `flutter analyze`: **lulus, nol temuan**. `flutter build web --release --no-web-resources-cdn`: **berhasil**.
- `flutter test`: **154 lulus** sesudah membetulkan satu ekspektasi usang di `test/api_services_test.dart`. Respons katalog backend sukses namun kosong tetap kosong (tidak diisi data contoh); data contoh dipakai ketika backend rusak/tidak tersedia di mode demo. Uji layanan tersebut dan seluruh suite lulus. Hasil 114 lulus, 1 gagal di atas adalah catatan historis, bukan status terbaru.
- Belum membuktikan layanan produksi, perangkat Android fisik, kamera, maupun seluruh ukuran di matriks layar. Build APK tidak dijalankan pada pass ini.

### Audit runtime lintas layar — 29 Okt 2026

- Browser Chromium headless **benar-benar dijalankan**, bukan hanya render widget. Pemeriksaan 320/375/600/1280 px mencakup onboarding, empat tab, detail, pembayaran simulasi sukses/gagal, tiket, dan area penyedia. Tangkapan sebelum/sesudah serta daftar temuan ada di [`docs/UI_RUNTIME_AUDIT.md`](docs/UI_RUNTIME_AUDIT.md). Fresh reload terakhir mencatat **0 exception Flutter dan 0 exception JavaScript tak tertangani** pada cakupan audit tersebut.
- Setelah perubahan lintas layar digabung, `flutter analyze`: **nol temuan**; seluruh `flutter test`: **210 lulus**; `flutter build web --release --no-web-resources-cdn`: **berhasil**. Angka 154 tes di atas adalah hasil pass sebelumnya.
- Backend bawaan `10.0.2.2:3000` tidak tersedia di browser audit; timeout jaringan tetap terjadi dan aplikasi memakai Data contoh/SIMULASI. Android fisik, kamera, Supabase produksi, pembayaran uang nyata, dan semua halaman statis belum diuji. Satu assertion engine saat hot restart debug pernah terlihat, tidak terulang pada fresh reload; tidak disamakan dengan nol error di seluruh kondisi.
- Koreksi pasca-audit: status lokasi redundan yang terpotong pada Beranda ponsel dihapus; lokasi terpilih tampil utuh dan pemilih tetap tersedia di baris berikutnya. Screenshot before/after di `docs/ui-audit-2026-10-29/`; 13 tes terfokus mencakup 320 px pada skala teks 1×/1,3×/2×. Pemeriksaan final setelah koreksi: `flutter analyze` bersih, **213 tes lulus**, build web release berhasil.

### Midtrans — pemeriksaan kesiapan koneksi — 29 Okt 2026

- Ditemukan klien HTTP Supabase Edge Function belum mengirim header `apikey` publishable/anon, yang dibutuhkan bersama Bearer JWT; ditambahkan pada `MidtransPaymentService` dari `SupabaseAuthService.settings` dan diizinkan pada CORS `payments-snap`. Tes layanan memeriksa kedua header; `flutter analyze`, `test/api_services_test.dart`, dan `test/detail_security_test.dart` lulus.
- Proyek Supabase yang ada di `config/supabase.production.json` diuji read-only: `OPTIONS /functions/v1/payments-snap`, `payments-status`, dan `payments-webhook` semuanya **404**. `supabase projects list` tidak bisa dijalankan karena tidak ada access token CLI. Artinya integrasi belum terpasang/terverifikasi di proyek cloud; kunci Midtrans tidak tersedia dan tidak diminta/ditaruh di repo.
- Sesudah perubahan header: `flutter analyze` bersih, seluruh `flutter test` **213 lulus**, `flutter build web --release --no-web-resources-cdn` berhasil. Ini memverifikasi proyek lokal, bukan akun gateway atau pembayaran nyata.

### Putaran Kebaikan — audit visual lanjutan — 2 Nov 2026

- Audit sebelum perubahan dan hasil per layar: [`docs/UI_REDESIGN_AUDIT.md`](docs/UI_REDESIGN_AUDIT.md). Bukti Chromium nyata pada 320/375/600/1280 px terang dan gelap, alur demo penerima/penyedia, tiket, pencarian tanpa hasil, serta log browser: [`docs/ui-redesign-2026-11-02/README.md`](docs/ui-redesign-2026-11-02/README.md). Capture adalah viewport; sebagian kondisi setelah menggulir hanya dicatat secara terpisah. Backend contoh `10.0.2.2:3000` timeout sesuai batas demo.
- Koreksi sesudah pemeriksaan: petunjuk NIB/NPWP 320 px tidak lagi memotong penjelasan “bukan pemeriksaan resmi”; copy QR toko/tiket menjelaskan kecocokan identitas QR **bukan** bukti posisi fisik, pelunasan, kesiapan pesanan, atau keamanan pangan. Label dan aturan DEMO/SIMULASI/kuota/kode manual dipertahankan. Empat belas tes terfokus lulus sebelum verifikasi penuh.
- **Verifikasi final atas kode terkini:** `flutter analyze` **0 temuan**; seluruh `flutter test` **214 lulus**; `flutter build web --release --no-web-resources-cdn` **berhasil**; `flutter build apk --debug` **berhasil**. Log perintah final disimpan di `/tmp/opencode/pangan-final-{analyze,tests,build,android-build}.log` (berkas sementara, bukan artefak repo).
- Build APK **bukan** bukti fungsi pada ponsel: tidak ada perangkat/emulator tersambung untuk menguji kamera, keyboard Android, performa, atau aksesibilitas TalkBack. Audit kontras 4,5:1 dan seluruh target sentuh 44 dp belum diukur secara menyeluruh. Backend Supabase, Midtrans uang nyata, dan keamanan produksi tetap belum tervalidasi; tombol produksi yang belum berkontrak ditandai belum tersedia, tidak dipalsukan sebagai fitur aktif.
