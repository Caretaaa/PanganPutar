# PanganPutar

Aplikasi Flutter Android dan Web untuk menemukan makanan berlebih, memesan, dan mengambilnya langsung di toko. Fitur mengikuti `FITUR_APLIKASI.md`; design system terbaru ada di [`docs/PUTARAN_DESIGN_SYSTEM.md`](docs/PUTARAN_DESIGN_SYSTEM.md).

## Menjalankan

Memerlukan Flutter stable dengan Dart ≥3.13.2. Lingkungan pengembangan memakai Flutter 3.47.7.

```sh
flutter pub get
flutter run -d chrome
```

Android: sambungkan perangkat dengan USB debugging atau nyalakan emulator, kemudian:

```sh
flutter devices
flutter run -d <id-perangkat>
```

## Membuat paket

### Release dengan Supabase

Di VS Code, pilih **PanganPutar (Release Supabase)**. Konfigurasi ini memakai
`dartMode: release`, bukan sekadar menyembunyikan banner DEBUG. Hentikan aplikasi
yang lama lalu jalankan kembali; release tidak mendukung hot reload.

```sh
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/supabase.production.json
# Hasil: build/web/ — unggah ke hosting HTTPS.

flutter build apk --release --dart-define-from-file=config/supabase.production.json
# Hasil: build/app/outputs/flutter-apk/app-release.apk
```

File tersebut hanya berisi konfigurasi publik. Jangan tambahkan secret key atau
Google Client Secret. Di web, callback mengikuti alamat halaman aplikasi;
daftarkan URL HTTPS deploy yang tepat pada Supabase **Authentication → URL
Configuration → Redirect URLs**, serta gunakan domain produksi sebagai **Site URL**.
Untuk Android, izinkan `id.panganputar.app://auth/callback`.

Build release berbeda dari penandatanganan produksi: atur keystore sendiri
sebelum mendistribusikan APK. Lihat [panduan Supabase](SUPABASE_SETUP.md#agar-supabase-tidak-terjeda)
untuk ketersediaan layanan dan pemeriksaan login.

### Build pengujian/demo

```sh
flutter build web --no-web-resources-cdn
# Hasil: build/web/ — sajikan melalui server HTTP/HTTPS, bukan file://.

flutter build apk --debug
# Hasil: build/app/outputs/flutter-apk/app-debug.apk
```

APK debug ditujukan untuk pengujian. Konfigurasi sumber masih memakai debug signing untuk release; atur keystore sendiri sebelum distribusi produksi.

Jika `flutter doctor -v` melaporkan Android command-line tools belum tersedia, instal **Android SDK Command-line Tools (latest)** melalui SDK Manager Android Studio. Setelah itu jalankan `flutter doctor --android-licenses` dan baca/penuhi lisensinya. Tidak ada penerimaan lisensi otomatis di proyek ini.

## Demo dan penyimpanan

- Masuk demo memakai nama dan peran penerima/penyedia, tanpa kata sandi atau autentikasi produksi.
- Katalog memakai data contoh bila backend gagal atau kosong.
- Kuota: **4 porsi dan 2 pesanan per perangkat per hari**. Keluar akun, pembatalan, dan pembayaran gagal tidak mengembalikan kuota.
- Sesi, panduan awal, tema, identitas instalasi, kuota, dan verifikasi toko disimpan lokal.
- Pesanan, pembayaran, pengambilan, dan penawaran baru hanya tersimpan dalam memori. Memulai ulang aplikasi menghapusnya; kuota tetap terpakai. Di web, memuat ulang halaman juga memulai ulang aplikasi.
- Saat backend pembayaran tidak tersedia, pembayaran menjadi **simulasi tanpa uang nyata**. Jangan melakukan transfer berdasarkan ilustrasi simulasi.
- Untuk mencoba alur dua peran pada satu perangkat: pesan sebagai penerima, keluar, lalu masuk sebagai penyedia tanpa memuat ulang aplikasi. Verifikasi toko dan pemindaian manual tersedia untuk demo.
- Pemindaian kamera memerlukan izin dan perangkat/platform yang mendukung; input QR/kode manual tetap tersedia. Web kamera memerlukan HTTPS atau localhost.
- Verifikasi toko, kuota, dan QR lokal bukan jaminan keamanan produksi. Pemeriksaan kelayakan makanan tetap diperlukan.

## Backend opsional

### Supabase: persiapan akun nyata

Database/Auth/Storage Supabase dipilih untuk tahap berikutnya, dengan email/kata sandi, Google, dan nomor HP + OTP SMS. Ikuti `SUPABASE_SETUP.md` untuk migrasi, konfigurasi publik, callback, SMTP, Google OAuth, dan SMS. Contoh konfigurasi tersedia di `config/supabase.example.json`.

Tanpa konfigurasi, aplikasi tetap dalam demo. Akun Supabase terpisah dari sesi demo; integrasi ini belum menjadikan pesanan atau pembayaran lokal sebagai transaksi produksi.

### API katalog dan pembayaran yang sudah ada

Backend tidak disertakan. Alamat bawaan sumber adalah `http://10.0.2.2:3000` (host Android emulator). Untuk Chrome atau perangkat fisik, tentukan alamat yang sesuai:

```sh
flutter run -d chrome --dart-define=PANGANPUTAR_API_BASE=http://localhost:3000
flutter build web --no-web-resources-cdn --dart-define=PANGANPUTAR_API_BASE=https://api.example.com
```

Endpoint yang digunakan:

- `GET /api/health`
- `GET /api/listings` (`q`, `kategori`, `kota`, `gratisSaja`, `limit`)
- `GET /api/listings/:id`
- `GET /api/impact`
- `POST /api/payments/midtrans/snap`
- `GET /api/payments/midtrans/status/:orderId`

Backend web perlu mengizinkan origin aplikasi melalui CORS. Gunakan HTTPS untuk produksi; jangan menaruh server key Midtrans dalam Flutter. Validasi server atas pembayaran, otorisasi, stok, kuota, dan pengambilan harus diimplementasikan terpisah. Refund dan sinkronisasi pesanan antarperangkat belum tersedia.

## Pemeriksaan

```sh
flutter analyze
flutter test
```

Lihat `VERIFICATION.md` untuk hasil dan batas pengujian aktual.

## Font

Montserrat dibundel lokal dari [repositori resmi Montserrat](https://github.com/JulietaUla/Montserrat), berlisensi SIL Open Font License. Lisensi: `assets/fonts/OFL.txt`.
