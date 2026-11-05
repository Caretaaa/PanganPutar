# Menyiapkan Supabase

## Status dan batas integrasi

Proyek Supabase belum dibuat. Aplikasi menyediakan fondasi auth email/kata sandi, Google OAuth, dan nomor HP + OTP SMS. Tanpa konfigurasi, auth nyata nonaktif dan mode demo tetap dapat digunakan.

**Identitas Supabase terpisah dari sesi demo.** Masuk akun nyata tidak mengubah pesanan lokal menjadi transaksi server. Katalog HTTP, pemesanan, kuota perangkat, pembayaran Midtrans, verifikasi toko, dan pengambilan demo masih mengikuti batas `FITUR_APLIKASI.md`. Skema berikut belum menghubungkan alur tersebut ke Supabase.

Tidak ada kredensial, pembuatan proyek cloud, pengiriman SMS, atau penerimaan biaya otomatis dalam penyiapan ini.

## 1. Buat proyek dan terapkan migrasi

1. Buat proyek pada [Supabase](https://supabase.com/dashboard).
2. Simpan kata sandi database di pengelola kata sandi, bukan di aplikasi.
3. Pada proyek baru, jalankan `supabase/migrations/202610190001_initial_schema.sql` melalui SQL Editor, atau gunakan Supabase CLI untuk menerapkan migrasi.
4. Periksa hasil migrasi sebelum menghubungkan aplikasi.

Migrasi bukan skrip yang perlu dijalankan berulang kali pada database yang sama. Untuk proyek berisi data, tinjau nama tabel, trigger, dan kebijakan yang sudah ada, lalu buat cadangan terlebih dahulu.

### Yang disiapkan

- `profiles`: nama dan peran penerima/penyedia; profil dibuat otomatis setelah signup.
- `stores`: identitas publik toko; verifikasi hanya dapat diubah oleh server tepercaya.
- `store_applications`: nomor usaha dan telepon, hanya terbaca oleh pemilik/server.
- `food_listings`: penawaran, saat ini hanya dapat diterbitkan/diperbarui oleh server.
- `orders` dan `payments`: transaksi yang hanya dapat ditulis oleh server.
- Bucket **private** `food-photos`: JPEG/PNG/WebP hingga 5 MB, jalur `<user-id>/<nama-file>`.

Pengguna boleh memilih peran penerima/penyedia sendiri. Peran penyedia **tidak berarti toko terverifikasi**. Peran admin tidak dapat dipilih dan tidak termasuk kolom peran publik. Metadata signup tidak dipercaya untuk memberi hak istimewa.

Foto bucket belum dapat dibaca oleh pembeli; penerbitan foto memerlukan alur signed URL/server yang belum dihubungkan. Foto makanan demo yang dibundel lokal tidak menggunakan bucket ini. Jangan simpan dokumen identitas dalam bucket foto makanan.

## 2. Konfigurasi aplikasi

Salin `config/supabase.example.json` menjadi `config/supabase.local.json` (sudah diabaikan Git), lalu isi:

- `SUPABASE_URL`: URL proyek, misalnya `https://PROJECT.supabase.co`.
- `SUPABASE_PUBLISHABLE_KEY`: publishable key proyek. Legacy anon key juga didukung melalui `SUPABASE_ANON_KEY`.
- `SUPABASE_AUTH_REDIRECT_URL`: biarkan `id.panganputar.app://auth/callback` untuk Android.
- `SUPABASE_WEB_REDIRECT_URL`: alamat web yang diizinkan; gunakan `http://localhost:8080/` untuk pengembangan.

**Jangan masukkan secret key (`sb_secret_*`), service-role key, kata sandi database, Google client secret, atau kredensial SMS ke Flutter.** Publishable/anon key memang dapat terlihat di aplikasi; perlindungan data tetap bergantung pada RLS, bukan kerahasiaan key publik.

```sh
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define-from-file=config/supabase.local.json
flutter run -d <id-android> --dart-define-from-file=config/supabase.local.json
```

Untuk deploy web, ubah URL callback web ke domain HTTPS yang sebenarnya, lalu:

```sh
flutter build web --no-web-resources-cdn --dart-define-from-file=config/supabase.local.json
```

Jika callback Android diubah, sesuaikan juga scheme/host/path pada `android/app/src/main/AndroidManifest.xml` dan daftar redirect Supabase. Konfigurasi bawaan sudah menggunakan `app_links`; Flutter route deep-linking dinonaktifkan agar tidak berebut callback.

## 3. Izinkan URL callback

Pada **Authentication → URL Configuration**:

- **Site URL**: domain web produksi yang benar.
- **Redirect URLs**: `id.panganputar.app://auth/callback`, `http://localhost:8080/` untuk pengembangan, serta URL HTTPS deploy yang tepat (termasuk subdirektori bila ada).

Hindari wildcard redirect luas di produksi. Jalankan pengembangan web dengan port tetap agar tautan konfirmasi/reset kembali ke origin yang sama. PKCE membutuhkan browser/perangkat yang memiliki verifier saat alur dimulai.

## 4. Email dan kata sandi

1. Aktifkan provider Email dan **Confirm email** di Supabase.
2. Atur template konfirmasi dan pemulihan kata sandi menggunakan tautan resmi Supabase.
3. Untuk pengguna nyata, hubungkan SMTP sendiri dan atur batas pengiriman; email bawaan Supabase dibatasi dan bukan pengganti layanan email produksi.
4. Uji daftar, verifikasi email, masuk, kirim ulang konfirmasi, lupa kata sandi, buka tautan recovery, ubah kata sandi, lalu keluar.

Signup tanpa session harus menampilkan permintaan verifikasi, bukan mengklaim pengguna sudah masuk. Tautan pemulihan yang gagal/kedaluwarsa perlu diminta ulang.

## 5. Google OAuth

1. Di Google Cloud, konfigurasi consent screen dan buat OAuth client jenis **Web application** untuk integrasi Supabase.
2. Tambahkan redirect URI `https://PROJECT.supabase.co/auth/v1/callback` (ambil nilai tepat dari dashboard Supabase).
3. Masukkan Client ID dan Client Secret hanya ke provider Google pada Supabase.
4. Tambahkan akun penguji saat aplikasi OAuth masih berstatus testing.
5. Uji pembukaan browser, pembatalan, dan kembali ke aplikasi pada Android serta web.

Membuka halaman Google bukan bukti login berhasil. Aplikasi harus menerima session dari Supabase terlebih dahulu. Jalur ini memakai browser OAuth, bukan paket native `google_sign_in`.

## 6. Nomor HP dan OTP SMS

1. Aktifkan provider Phone pada Supabase.
2. Hubungkan penyedia SMS yang tersedia di dashboard, misalnya Twilio atau Vonage, dengan dukungan pengiriman ke Indonesia.
3. Atur anggaran, negara tujuan, batas pengiriman, dan perlindungan penyalahgunaan di Supabase/penyedia SMS.
4. Gunakan nomor E.164, misalnya `+6281234567890`, bukan `0812…`.
5. Uji kode benar, salah, kedaluwarsa, pengiriman ulang, dan batas permintaan.

Aplikasi menerapkan jeda pengiriman ulang lokal 60 detik, tetapi ini **bukan pembatasan keamanan server** dan dapat dilewati dengan instalasi/perangkat lain. Sebelum layanan publik dibuka, siapkan proteksi abuse dan integrasi CAPTCHA jika kebijakan proyek mewajibkannya. UI token CAPTCHA belum disertakan; mengaktifkan kewajiban CAPTCHA tanpa integrasi klien akan menolak permintaan.

SMS adalah layanan berbayar. Tidak ada SMS sungguhan yang diuji atau dikirim selama pengembangan tanpa konfigurasi pengguna.

## 7. Verifikasi aturan akses

`supabase/tests/rls.sql` menyediakan fixture sementara dan assertion untuk profil lintas pengguna, data pengajuan privat, akses pesanan, penolakan eskalasi admin, verifikasi toko, dan perubahan stok/pembayaran oleh klien. Jalankan hanya pada database Supabase pengujian setelah migrasi, bukan proyek produksi:

```sh
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls.sql
```

Fixture dibungkus transaksi dan di-rollback. Skrip SQL ini belum dijalankan di lingkungan pengembangan saat penulisan karena PostgreSQL/Supabase CLI/Docker tidak tersedia. Pemeriksaan statis bukan bukti RLS berfungsi pada proyek aktual. Uji upload/read Storage lintas pengguna juga perlu dilakukan melalui API Storage pada proyek pengujian.

## Sebelum transaksi produksi

Implementasikan endpoint/fungsi server untuk reservasi stok dan kuota atomik, kepemilikan pesanan, pembatalan, moderasi/verifikasi toko, webhook Midtrans terverifikasi, signed QR pickup, signed URL foto, audit, dan kebijakan penghapusan akun/data. Jangan membuka INSERT/UPDATE pesanan atau pembayaran langsung kepada klien untuk menghindari tahap ini.

## Agar Supabase tidak terjeda

Supabase hosted berjalan di cloud; laptop, VS Code, dan Flutter tidak harus terus
menyala. Mode debug/release tidak menentukan apakah server Supabase aktif.

1. Buka proyek pada dashboard Supabase. Jika berstatus **Paused**, pilih
   **Restore project** dan tunggu sampai proyek aktif kembali.
2. Paket **Free** dapat terjeda setelah satu minggu tidak aktif. Untuk produksi
   tanpa jeda otomatis karena tidak aktif, pemilik organisasi dapat memilih paket
   **Pro** melalui halaman Billing. Harga dasar resmi saat diperiksa mulai
   **US$25/bulan**; pajak, compute tambahan, dan pemakaian di luar kuota dapat
   menambah biaya. Periksa rincian sebelum menyetujui pembayaran.
3. Paket berbayar tidak terjeda karena tidak aktif, tetapi bukan jaminan uptime
   100% atau jaminan login berhasil. Jangan mengandalkan ping/cron sebagai jaminan
   always-on paket Free.

Jika proyek aktif tetapi login gagal:

- Pastikan build memakai `config/supabase.production.json` sesuai petunjuk README.
- Aktifkan Google di **Authentication → Providers** dengan Web Client ID dan
  Client Secret yang benar. Secret hanya disimpan di dashboard Supabase.
- Di Google Cloud, daftarkan **Authorized redirect URI**:
  `https://xhllsohvlhfmkthywmcq.supabase.co/auth/v1/callback`.
- Di Supabase **URL Configuration**, daftarkan URL aplikasi web yang sebenarnya
  atau `id.panganputar.app://auth/callback` untuk Android. Callback Google di atas
  berbeda dari URL tujuan kembali ke aplikasi.
- Jika Google OAuth masih **Testing**, tambahkan email pada daftar test users;
  untuk akses publik, sesuaikan status publikasi dan persyaratan verifikasi Google.
- Untuk email, periksa konfirmasi akun dan SMTP. Untuk OTP, aktifkan Phone dan
  penyedia SMS beserta saldo/kuotanya. Pro saja tidak mengonfigurasi layanan ini.
- Periksa **Auth Logs** di dashboard dan [status layanan](https://status.supabase.com/).

Rujukan resmi: [harga dan aturan pause](https://supabase.com/pricing),
[Google OAuth](https://supabase.com/docs/guides/auth/social-login/auth-google),
[redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).
