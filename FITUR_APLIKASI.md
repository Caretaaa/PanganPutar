# Fitur Aplikasi PanganPutar

Dokumen ini mencatat fitur, data, alur pengguna, aturan bisnis, dan batasan implementasi aplikasi Flutter PanganPutar. Gunakan sebagai acuan saat mengubah desain tanpa menghilangkan fungsi aplikasi.

Dokumen ini tidak menetapkan warna, tipografi, tata letak, bentuk komponen, atau animasi. Nama bagian mewakili fungsi; desain baru boleh mengatur ulang pengelompokannya.

**Cakupan:** aplikasi PanganPutar dalam direktori `lib/`. Proyek contoh pemesanan perjalanan dalam direktori `tiket/` merupakan aplikasi terpisah dan tidak termasuk.

## 1. Tujuan aplikasi dan status fitur

PanganPutar mempertemukan penyedia makanan berlebih dengan penerima. Penyedia menawarkan makanan gratis atau berbayar, penerima memesan, lalu mengambil makanan di toko.

Istilah dalam dokumen:

- **Tersedia:** fungsi sudah memiliki implementasi di aplikasi.
- **Demo lokal:** fungsi berjalan memakai data atau penyimpanan pada perangkat, bukan layanan produksi.
- **Bergantung backend:** aplikasi memiliki integrasi, tetapi membutuhkan server yang sesuai.
- **Belum tersedia:** informasi atau rencana yang belum menjadi fungsi operasional aplikasi mobile.

Pemesanan, pengelolaan penawaran, dan pengambilan saat ini memakai demo lokal. Pengambilan katalog dan pembayaran memiliki jalur integrasi backend. Jangan mengartikan seluruh fitur sebagai layanan produksi yang sudah terhubung.

## 2. Peran dan akses pengguna

| Peran | Kemampuan |
|---|---|
| Pengunjung | Membaca pengenalan, menjelajahi penawaran, membuka detail, membaca bantuan dan dampak, mengatur preferensi tema, serta masuk demo. |
| Penerima | Menggunakan fitur pengunjung, membuat pesanan, membayar, melihat pesanan, membatalkan pesanan yang memenuhi syarat, membuka tiket, dan memindai QR toko. |
| Penyedia | Mengajukan verifikasi toko, melihat QR toko, menambahkan penawaran setelah terverifikasi, mengonfirmasi pesanan, dan memproses pengambilan. |
| Admin | Peran dikenali oleh sesi dan memiliki akses fungsi penyedia, tetapi tidak tersedia dalam pendaftaran publik. Moderasi mobile belum tersedia. |

Catatan akses saat ini:

- Pengunjung harus masuk sebelum membuat atau melihat pesanan.
- Akun berperan penyedia tidak dapat membuat pesanan melalui alur penerima; pemeriksaan ini berlaku untuk peran penyedia, bukan hanya penawaran miliknya.
- Akun admin tidak terkena pembatasan pemesanan tersebut.
- Demo belum memisahkan data pesanan dan penawaran berdasarkan identitas akun pengguna.

## 3. Pengenalan dan akses awal

- Panduan awal menjelaskan makanan berlebih, toko terverifikasi, kuota perangkat, pembayaran, dan pengambilan.
- Pengguna dapat melanjutkan panduan, melewati panduan, atau menyelesaikannya.
- Aplikasi menyimpan penanda penyelesaian panduan agar tidak mengulanginya pada pembukaan berikutnya.
- Pengguna dapat membuka kembali panduan awal.
- Setelah panduan, pengguna dapat menuju pencarian makanan, fungsi penyedia, atau masuk demo.
- Halaman pengantar tetap menjadi pintu masuk pada pembukaan berikutnya; penyelesaian panduan tidak berarti langsung masuk ke katalog.

## 4. Akun dan sesi demo

### 4.1 Masuk atau daftar demo

- Pengguna mengisi nama tampilan dan memilih peran penerima atau penyedia.
- Nama wajib diisi, dengan panjang 3–40 karakter setelah menghapus spasi di awal dan akhir.
- Pilihan awal peran adalah penerima.
- Aplikasi menyimpan nama dan peran secara lokal untuk pembukaan berikutnya.
- Tidak ada kata sandi, OTP, verifikasi email, atau autentikasi akun produksi dalam alur ini.

### 4.2 Pengelolaan sesi dan perangkat

- Pengguna dapat melihat nama, peran, dan keterangan bahwa sesi merupakan demo.
- Pengguna dapat keluar dari sesi.
- Pengguna yang sudah masuk dapat melihat ID perangkat ringkas, sumber identitas, dan pemakaian kuota hari ini.
- Tersedia aksi **reset kuota demo** untuk pengujian.
- Tersedia aksi **reset verifikasi demo** untuk mengembalikan data verifikasi toko ke data contoh awal.
- Keluar atau mengganti akun tidak menambah kuota perangkat.

## 5. Daftar dan pencarian makanan

### 5.1 Penawaran di beranda

- Memuat daftar penawaran dari backend, dengan data contoh sebagai cadangan.
- Pengguna dapat memuat ulang daftar.
- Informasi ringkas penawaran mencakup nama makanan, sisa stok, kota, harga efektif, dan status terverifikasi jika toko tercatat terverifikasi.
- Pengguna dapat membuka detail penawaran.
- Tersedia penanganan kondisi memuat, gagal, dan daftar kosong.

### 5.2 Pencarian dan penyaringan

- Pencarian berdasarkan nama makanan.
- Penyaringan berdasarkan kategori, kota, dan makanan gratis saja.
- Kategori: semua, nasi, roti, lauk, sayur, buah, minuman, paket, jajanan, dan lainnya.
- Pengguna dapat menggabungkan beberapa filter.
- Pengguna menerapkan filter melalui aksi penerapan atau pengiriman pencarian.
- Pengguna dapat memuat ulang hasil dengan filter yang sedang dipakai.
- Jika hasil kosong, pengguna mendapat informasi bahwa tidak ada penawaran yang cocok dan dapat mengubah filter.
- Pencarian nama dan kota pada data contoh tidak membedakan huruf besar dan kecil serta menerima sebagian teks.
- Belum ada pengurutan berdasarkan jarak, pencarian GPS, favorit, atau pencarian berbasis peta.

## 6. Detail penawaran dan pemeriksaan keamanan

### 6.1 Informasi penawaran

- Nama dan deskripsi makanan.
- Harga efektif; penawaran gratis memiliki harga efektif nol.
- Stok tersedia beserta satuannya.
- Alamat pengambilan dan waktu mulai serta akhir pengambilan.
- Keterangan bahwa batas waktu penawaran sudah berakhir.
- Identitas toko yang tersedia, kota, dan status verifikasinya.
- Pemakaian dan sisa kuota harian perangkat.
- Total pesanan sesuai jumlah yang dipilih.
- Jika detail gagal diambil dari server, aplikasi dapat memakai data contoh atau data penawaran dari daftar sebelumnya.
- Jika tidak ada data pengganti, aplikasi memberi informasi bahwa penawaran tidak ditemukan.

### 6.2 Daftar periksa keamanan

Aplikasi mengevaluasi:

1. Status verifikasi toko.
2. Waktu pengambilan yang belum berakhir.
3. Stok positif dan status penawaran tersedia.
4. Kelengkapan alamat pengambilan, dengan pemeriksaan panjang minimal 8 karakter.
5. Ketersediaan catatan penyimpanan.
6. Ketersediaan informasi alergen.
7. Kewajaran durasi pengambilan berdasarkan pemeriksaan jam, lebih dari nol dan tidak melebihi 24 jam.

Pengguna mendapat hasil pemeriksaan dan keterangan kekurangan informasi. Pemeriksaan keberadaan catatan penyimpanan atau alergen tidak sama dengan menjamin keamanan makanan.

**Batas implementasi:** daftar periksa dan aturan pemblokiran pesanan belum sepenuhnya sama. Alamat yang tidak lengkap, catatan penyimpanan yang kosong, atau informasi alergen yang kosong tidak otomatis memblokir pemesanan pada kode saat ini.

## 7. Pembuatan pesanan

### 7.1 Memilih jumlah

- Pengguna dapat menambah atau mengurangi jumlah pesanan.
- Jumlah minimal satu.
- Batas penambahan mengikuti stok dan sisa kuota porsi perangkat.
- Total pembayaran = harga efektif per unit × jumlah.
- Satu pesanan berisi satu jenis penawaran dengan jumlah tertentu. Belum ada keranjang lintas penawaran.

### 7.2 Syarat pemesanan

Aplikasi memblokir pesanan apabila:

- Pengguna belum masuk atau menggunakan peran penyedia.
- Jumlah tidak valid atau melebihi stok.
- Status penawaran bukan `tersedia`.
- Batas akhir pengambilan sudah tercapai atau terlewati.
- Verifikasi toko berstatus ditolak.
- Kuota porsi atau jumlah pesanan harian perangkat tidak cukup.

Toko yang belum mengajukan verifikasi atau masih menunggu review menghasilkan peringatan, bukan pemblokiran pemesanan. Pembatasan ini berbeda dengan penerbitan penawaran baru yang mensyaratkan toko terverifikasi.

### 7.3 Hasil pemesanan

- Aplikasi membuat pesanan demo dengan status awal `menunggu` dan kode pengambilan.
- Aplikasi mencatat pemakaian kuota setelah membuat pesanan.
- Pesanan gratis tidak memerlukan proses pembayaran.
- Pesanan berbayar melanjutkan ke proses pembayaran.
- Pengguna menerima informasi kode pengambilan, status pembayaran, dan kebutuhan konfirmasi penyedia.
- Jika pengguna meninggalkan pembayaran sebelum lunas, pesanan tetap ada dan kuota tetap terpakai.

## 8. Kuota harian dan identitas perangkat

- Batas bawaan adalah **4 porsi dan 2 pesanan per perangkat per hari**.
- Aplikasi menghitung jumlah unit yang dipesan sebagai pemakaian kuota porsi, termasuk penawaran dengan satuan lain.
- Batas berlaku untuk makanan gratis maupun berbayar.
- Kuota mengikuti tanggal lokal perangkat dan memperhitungkan pergantian hari.
- Kuota terikat pada identitas perangkat/instalasi, bukan pada nama atau peran akun.
- Pembatalan dan kegagalan pembayaran tidak mengembalikan kuota.
- Aplikasi menyimpan catatan kuota secara lokal sehingga bertahan setelah restart.
- Identitas memakai hash dari informasi perangkat yang tersedia dan UUID instalasi; aplikasi tidak membaca MAC address.
- ID ini membantu pembatasan demo, tetapi tidak menjamin identitas perangkat tidak bisa dipalsukan atau berubah setelah penghapusan data instalasi.
- Untuk produksi, backend perlu memeriksa ulang kuota dan identitas perangkat. Reset demo bukan hak pengguna produksi.

## 9. Pembayaran

### 9.1 Ringkasan dan integrasi Midtrans

- Pengguna melihat makanan, jumlah, kode pengambilan, dan total sebelum memulai pembayaran.
- Aplikasi meminta sesi pembayaran Midtrans Snap melalui backend.
- Data permintaan mencakup identitas pesanan, item, nominal, nama pembeli, dan ID perangkat.
- Aplikasi membuka halaman pembayaran di dalam aplikasi pada platform yang mendukung, atau menyediakan pembukaan melalui browser.
- Pengguna dapat memeriksa status pembayaran; aplikasi juga memeriksanya setiap 4 detik selama proses pembayaran aktif.
- Metode transaksi nyata mengikuti konfigurasi Midtrans pada backend, misalnya QRIS, dompet digital, virtual account, dan kartu.
- Aplikasi tidak menyimpan data kartu atau kredensial dompet digital. Server key Midtrans merupakan tanggung jawab backend.
- Setelah sukses, pengguna dapat melihat nominal, metode, referensi transaksi, dan instruksi pengambilan.
- Jika gagal atau kedaluwarsa, pengguna dapat menutup proses atau mencoba lagi.

### 9.2 Simulasi pembayaran

- Jika pembuatan sesi pembayaran gagal, aplikasi beralih ke simulasi dengan keterangan **tanpa uang nyata**.
- Pilihan simulasi: QRIS, GoPay, OVO, DANA, ShopeePay, VA BCA, dan VA BNI.
- Pengguna dapat menyimulasikan pembayaran berhasil atau gagal.
- Nomor atau ilustrasi pembayaran simulasi bukan instruksi transfer nyata.
- Catatan pembayaran menyimpan penanda simulasi agar tidak disamakan dengan transaksi nyata.

### 9.3 Status pembayaran

Model mengenali status tidak perlu pembayaran, belum dibayar, menunggu, dibayar, gagal, kedaluwarsa, dan dikembalikan.

**Batas implementasi:** pengenalan status pengembalian dana dalam model belum menyediakan fitur pengajuan refund. Pemantauan pembayaran saat ini menindaklanjuti hasil lunas, gagal, dan kedaluwarsa; pembatalan pesanan tidak otomatis menjalankan refund.

## 10. Daftar pesanan dan pembatalan

- Pengguna yang sudah masuk dapat melihat pesanan demo selama sesi aplikasi berjalan.
- Informasi pesanan mencakup nama makanan, jumlah, waktu pembuatan, status pesanan, total atau gratis, status pembayaran, metode pembayaran jika ada, dan kode pengambilan.
- Aplikasi membedakan pembayaran simulasi dari pembayaran non-simulasi.
- Pesanan yang sudah diambil dapat memuat waktu pengambilan dan keterangan verifikasi QR atau penyelesaian manual.
- Pengguna dapat membuka tiket QR untuk pesanan yang tidak dibatalkan, termasuk melihat riwayat tiket pesanan selesai.
- Pengguna dapat melanjutkan pembayaran pesanan berbayar yang belum lunas. Aksi ini tidak tersedia jika catatan pembayaran berstatus menunggu atau pesanan dibatalkan.
- Pembatalan tersedia untuk status `menunggu` dan `dikonfirmasi`, setelah pengguna menyetujui konfirmasi pembatalan.
- Konfirmasi pembatalan menjelaskan bahwa kuota tidak kembali.
- Pesanan `siap_diambil`, `selesai`, atau `dibatalkan` tidak menawarkan aksi pembatalan kepada penerima.
- Pemeriksaan pembatalan pada alur saat ini berdasarkan status, belum memeriksa batas waktu pengambilan.

## 11. Tiket dan pengambilan QR dua arah

### 11.1 Tiket penerima

- Setiap pesanan memiliki tiket berisi identitas pesanan, kode pengambilan, dan identitas toko.
- Pengguna dapat menunjukkan QR tiket atau kode teks cadangannya.
- Tiket menyertakan makanan, jumlah, toko, status verifikasi toko, alamat, waktu pengambilan, dan informasi pembayaran.
- Tiket menjelaskan apakah pesanan sudah selesai atau dibatalkan dan apakah pengambilan menggunakan verifikasi QR.

### 11.2 Penyedia memindai tiket penerima

Aplikasi memeriksa:

1. Format tiket dapat dikenali dan pesanan ditemukan.
2. Kode pengambilan cocok dengan pesanan.
3. Identitas toko dalam tiket cocok dengan pesanan.
4. Pemindai memiliki hak atas toko penerima pesanan, dengan pengecualian operator demo satu perangkat.
5. Pesanan tidak dibatalkan dan belum selesai.
6. Pembayaran sudah lunas jika pesanan berbayar.
7. Penyedia sudah mengonfirmasi pesanan; status yang diterima adalah `dikonfirmasi` atau `siap_diambil`.

Jika lolos, aplikasi mengubah status menjadi `selesai`, mencatat waktu pengambilan, dan menandai pengambilan terverifikasi QR. Pemindaian ulang tiket selesai ditolak.

Jika batas akhir pengambilan sudah lewat, jalur QR tetap dapat memproses pengambilan dengan peringatan untuk memeriksa kelayakan makanan. Perilaku ini berbeda dengan pembuatan pesanan baru yang ditolak setelah batas waktunya.

### 11.3 Penerima memindai QR toko

- Toko memiliki QR identitas toko yang dapat ditunjukkan kepada penerima.
- Penerima memindai QR tersebut dari tiket pesanannya.
- QR toko yang cocok mencatat waktu verifikasi kedatangan.
- QR toko lain ditolak.
- Jika toko cocok tetapi belum terverifikasi, aplikasi memberi peringatan.
- Pesanan selesai atau dibatalkan tidak dapat memproses verifikasi kedatangan baru.
- Verifikasi ini mencocokkan identitas QR, bukan membuktikan koordinat GPS atau posisi fisik perangkat.
- Verifikasi kedatangan tidak menyelesaikan pesanan dan bukan syarat wajib sebelum penyedia memindai tiket.

### 11.4 Pemindaian dan cadangan manual

- Pemindaian kamera tersedia pada platform yang didukung dan dengan izin kamera.
- Jika kamera tidak tersedia atau izinnya ditolak, pengguna dapat memasukkan kode atau isi QR secara manual.
- Penyedia dapat memasukkan kode pengambilan tanpa tautan QR lengkap untuk mencari pesanan.
- Verifikasi toko membutuhkan isi QR toko yang valid, bukan sekadar nama toko.
- Input kosong tidak diproses; pengguna dapat membatalkan pemindaian.

## 12. Verifikasi toko penyedia

### 12.1 Pengajuan

| Data | Aturan |
|---|---|
| Nama toko | 3–60 karakter. |
| Jenis usaha | Wajib dipilih. |
| NIB/NPWP | 13–20 digit setelah membersihkan tanda pemisah yang diizinkan. |
| Nomor telepon | 9–15 digit setelah membersihkan tanda pemisah yang diizinkan. |
| Alamat fisik | Minimal 10 karakter. |
| Kota/kabupaten | Minimal 3 karakter. |
| Bukti foto toko | Konfirmasi bahwa foto depan toko sudah disiapkan dan asli. |
| Titik lokasi | Konfirmasi bahwa titik lokasi toko sudah disiapkan. |

Jenis usaha: warung makan, toko roti/kue, restoran/katering, petani/kebun, toko kelontong, dan lainnya.

**Batas demo:** bukti foto dan lokasi saat ini berupa konfirmasi pengguna. Belum ada unggah foto, pemilihan koordinat peta, pencocokan geotag, atau verifikasi NIB ke sumber resmi.

### 12.2 Penilaian dan status

- Status toko: belum diajukan, menunggu review, terverifikasi, atau ditolak.
- Penyedia dapat melihat status, identitas usaha, skor bukti, dan catatan peninjauan.
- Penilaian demo memberi bobot foto 30, lokasi 25, nomor usaha 25, telepon 10, dan alamat 10, dengan total maksimal 100.
- Pengajuan yang memenuhi validasi dan mencapai skor minimal 85 dapat langsung terverifikasi dalam demo lokal.
- Tersedia aksi persetujuan demo untuk pengajuan berstatus menunggu review; aksi ini bukan sistem otorisasi admin produksi.
- Penyedia yang belum terverifikasi tidak dapat menambahkan penawaran melalui alur aplikasi.
- Status toko ditolak memblokir pemesanan penawarannya.
- Data verifikasi tersimpan secara lokal dan bertahan setelah restart.

## 13. Penawaran dan operasional penyedia

### 13.1 Penawaran milik penyedia

- Penyedia dapat melihat daftar dan jumlah penawaran demo beserta nama, sisa jumlah, satuan, harga, dan statusnya.
- Penyedia terverifikasi dapat menambahkan penawaran dengan nama makanan, jumlah, dan harga rupiah.
- Nama makanan minimal 3 karakter; jumlah harus bilangan bulat positif.
- Harga nol berarti gratis. Implementasi demo juga menganggap harga negatif atau input harga yang tidak terbaca sebagai gratis; belum ada penolakan harga negatif secara khusus.
- Penawaran baru memakai kategori `lainnya`, satuan `porsi`, alamat dan kota profil toko, serta status `tersedia`.
- Waktu pengambilan demo otomatis mulai satu jam dan berakhir lima jam setelah penawaran dibuat.
- Deskripsi, petunjuk pengambilan, dan catatan penyimpanan memakai nilai bawaan; informasi alergen belum diisi melalui form ini.
- Belum ada pengubahan atau penghapusan penawaran, penyuntingan stok, pemilihan kategori, penjadwalan waktu ambil, atau unggah foto makanan dalam form penyedia.
- Penawaran baru hanya masuk daftar penyedia lokal. Belum ada pengiriman ke backend atau penggabungan otomatis ke katalog Beranda/Jelajahi.

### 13.2 Pemrosesan pesanan

- Penyedia dapat melihat pesanan demo dan memperbarui tahap pemrosesannya.
- Alur tindakan normal: `menunggu` → `dikonfirmasi` → `siap_diambil` → `selesai`.
- Penyedia dapat menyelesaikan pesanan terkonfirmasi melalui pemindaian tiket sesuai pemeriksaan QR.
- Setelah status siap diambil, tersedia penyelesaian manual tanpa QR sebagai cadangan.
- Penyelesaian manual mencatat waktu pengambilan tanpa menambahkan tanda terverifikasi QR.
- Jalur manual belum menerapkan ulang pemeriksaan pelunasan dan hak toko yang digunakan jalur QR.
- Demo memakai satu identitas penyedia dan daftar pesanan bersama. Mode operator demo memungkinkan satu perangkat memainkan peran penerima dan penyedia dari toko pesanan.
- Pembuatan pesanan demo belum mengurangi stok katalog secara otomatis.

## 14. Dampak dan SDG

- Pengguna dapat melihat jumlah porsi tersalurkan, pesanan selesai, dan penyedia aktif dari backend.
- Aplikasi menghitung estimasi berat makanan: `jumlah porsi × 0,4 kg`.
- Aplikasi menghitung estimasi CO2e: `estimasi berat makanan × 2,5`.
- Angka lingkungan merupakan estimasi berbasis asumsi internal, bukan sertifikasi atau klaim emisi resmi.
- Informasi tujuan mencakup SDG 2, SDG 12, dan SDG 13.
- Jika data dampak tidak tersedia, nilai yang tampil menggunakan nol.
- Aktivitas pesanan demo lokal belum otomatis memperbarui metrik dampak backend.

## 15. Bantuan, privasi, dan preferensi

- Panduan cara mencari makanan, memeriksa penawaran, memesan, membayar, dan mengambil makanan.
- Penjelasan QR dua arah dan penolakan tiket yang sudah dipakai.
- Penjelasan kuota per perangkat, verifikasi toko, serta kuota yang tidak kembali setelah pembatalan.
- Panduan keamanan pangan: memperhatikan kondisi makanan, kemasan, catatan penyimpanan, alergen, dan batas waktu.
- Informasi bahwa terdaftarnya makanan tidak menjamin kelayakan konsumsi.
- Pengguna dapat membaca kebijakan privasi dan syarat layanan yang tersedia dalam aplikasi.
- Pengguna dapat memilih mode terang, mode gelap, atau mengikuti pengaturan sistem. Aplikasi menyimpan preferensi tersebut; dokumen ini tidak menentukan desain masing-masing mode.
- Bahasa aplikasi adalah bahasa Indonesia, dengan format rupiah dan tanggal lokal Indonesia. Belum ada pemilih bahasa.
- Informasi bantuan bersifat bacaan; belum ada percakapan dukungan atau pengiriman tiket bantuan.

## 16. Admin dan fitur yang belum tersedia

- Bagian Admin saat ini hanya berisi keterangan bahwa moderasi dilakukan pada aplikasi web `/admin`.
- Aplikasi mobile belum menyediakan peninjauan laporan, penyembunyian penawaran, pengelolaan pengguna, atau penolakan verifikasi oleh admin melalui alur moderasi lengkap.
- Autentikasi produksi, penerbitan penawaran ke server, sinkronisasi pesanan antarperangkat, verifikasi toko resmi, serta pengesahan pengambilan oleh server belum terhubung dalam alur mobile ini.
- QR pengambilan belum memakai token bertanda tangan dari backend; pemeriksaan lokal bukan pengganti autentikasi server.
- Pengembalian dana, pengiriman makanan, pelacakan kurir, percakapan pembeli-penyedia, ulasan, notifikasi push, dan voucher belum tersedia pada aplikasi ini.

## 17. Sumber data, penyimpanan, dan batas demo

| Data/fungsi | Perilaku saat ini |
|---|---|
| Katalog penawaran | Membaca backend; menggunakan data contoh jika permintaan gagal atau hasil backend kosong. |
| Detail penawaran | Membaca backend; mencoba data contoh atau data sebelumnya jika tidak tersedia. |
| Dampak | Membaca backend; menggunakan nilai nol saat data tidak tersedia. |
| Nama dan peran demo | Tersimpan lokal setelah restart. |
| Penanda panduan awal | Tersimpan lokal setelah restart. |
| Preferensi tema | Tersimpan lokal setelah restart. |
| Identitas instalasi dan kuota | Tersimpan lokal setelah restart. |
| Profil dan verifikasi toko | Tersimpan lokal setelah restart. |
| Pesanan dan penawaran baru demo | Hanya di memori; tidak bertahan setelah proses aplikasi dimulai ulang. |
| Status pembayaran dan pengambilan demo | Mengikuti pesanan di memori; tidak bertahan setelah proses aplikasi dimulai ulang. |
| Pembayaran nyata | Bergantung ketersediaan backend pembayaran dan konfigurasi Midtrans. |

Akibatnya, pesanan demo dapat hilang setelah restart sementara pemakaian kuota harian tetap tersimpan. Mode data contoh bukan sinkronisasi offline atas transaksi produksi.

## 18. Alur pengguna utama

### Penerima makanan gratis

1. Masuk sebagai penerima.
2. Cari makanan, gunakan filter bila diperlukan, lalu buka detail.
3. Periksa toko, waktu ambil, informasi keamanan, stok, dan kuota.
4. Tentukan jumlah lalu buat pesanan gratis.
5. Tunggu konfirmasi penyedia.
6. Buka tiket dan datangi toko; pemindaian QR toko bersifat opsional.
7. Tunjukkan tiket agar penyedia memproses pengambilan.

### Penerima makanan berbayar

1. Ikuti pencarian dan pemeriksaan yang sama.
2. Buat pesanan, lalu lanjutkan pembayaran.
3. Selesaikan pembayaran nyata melalui backend atau simulasi yang berlabel.
4. Jika belum lunas, lanjutkan pembayaran melalui daftar pesanan saat aksi tersedia.
5. Ambil makanan setelah penyedia mengonfirmasi; jalur QR menolak pesanan berbayar yang belum lunas.

### Penyedia

1. Masuk sebagai penyedia.
2. Ajukan verifikasi toko dan penuhi data yang diminta.
3. Setelah terverifikasi, tambahkan penawaran demo.
4. Gunakan QR toko untuk pencocokan identitas oleh penerima.
5. Konfirmasi pesanan dan tandai siap diambil jika sesuai.
6. Pindai tiket penerima untuk menyelesaikan pesanan dengan verifikasi QR, atau gunakan penyelesaian manual sesuai batas demo.

## 19. Catatan fungsi yang perlu diperhatikan saat desain berubah

Catatan berikut merupakan kondisi implementasi, bukan arahan desain:

- Label **Live** pada beranda belum mengikuti pemeriksaan koneksi. Jangan menjadikannya bukti data waktu nyata.
- Teks **Masuk aplikasi** pada pengantar dan **Cari makanan** pada beranda belum memiliki aksi interaktif.
- Aksi berlabel **Jadi penyedia** pada beranda saat ini menuju Jelajahi; pintu masuk penyedia dari halaman pengantar menuju fungsi penyedia.
- Katalog belum menjamin penyembunyian semua penawaran kedaluwarsa pada sisi aplikasi. Pemeriksaan waktu tetap berjalan saat membuat pesanan.
- Aturan bantu pembatalan berdasarkan waktu dan tabel transisi status ada dalam kode, tetapi belum dipakai oleh seluruh jalur perubahan status demo.
- Data contoh dapat menggantikan hasil backend yang kosong tanpa penanda sumber data pada katalog.
- Produksi memerlukan pemeriksaan server untuk otorisasi, stok, kuota, pembayaran, verifikasi toko, dan pengambilan; perubahan desain tidak menyelesaikan batas integrasi tersebut.

## 20. Acuan pemeriksaan fungsi

Saat mengganti desain, pertahankan kemampuan pengguna untuk:

- [ ] Menyelesaikan, melewati, dan membuka kembali panduan.
- [ ] Masuk, memilih peran, melihat informasi akun, dan keluar.
- [ ] Menelusuri, menyaring, memuat ulang, dan membuka detail penawaran.
- [ ] Memahami keamanan penawaran, status toko, stok, waktu ambil, dan kuota.
- [ ] Memilih jumlah serta membuat pesanan gratis atau berbayar.
- [ ] Membedakan pembayaran nyata dan simulasi, memeriksa hasil, serta mencoba ulang.
- [ ] Melihat pesanan, melanjutkan pembayaran, dan membatalkan sesuai status.
- [ ] Mengakses tiket, memindai kedua jenis QR, dan menggunakan input manual.
- [ ] Mengajukan verifikasi, melihat hasilnya, dan menambahkan penawaran demo.
- [ ] Mengonfirmasi pesanan dan menyelesaikan pengambilan dengan atau tanpa QR.
- [ ] Membaca dampak, bantuan, privasi, syarat, dan keterbatasan demo.
- [ ] Mengatur preferensi tema tanpa mengubah aturan bisnis.
- [ ] Memahami kondisi memuat, data kosong, kegagalan, penolakan, dan keberhasilan.

Sumber pemeriksaan: `lib/main.dart`, `lib/screens/`, `lib/services/`, `lib/models/`, `lib/core/business_rules.dart`, `lib/core/security_rules.dart`, `lib/core/pickup_rules.dart`, dan `lib/core/theme_controller.dart`. Dokumen ini mengikuti fungsi kode, bukan spesifikasi desain atau janji fitur pada teks promosi.
