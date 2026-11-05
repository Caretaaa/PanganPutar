# Audit sebelum redesign — Putaran Kebaikan

## Bukti dan batas (sebelum edit UI)

Kode saat ini dibaca kembali, termasuk cabang produksi. Chromium nyata dari
`flutter run -d web-server --web-port=8765 --no-web-resources-cdn` diperiksa ulang
pada **320×740, 375×812, 600×960, 1280×900**, **terang dan gelap**. Capture baru
landing dan empat tab: `/tmp/opencode/pangan-redesign-before/`; bukan screenshot
historis. Audit langsung sebelumnya pada kode yang sama juga menjalankan detail,
guest pesan, masuk penerima/penyedia, ringkasan bayar, tiket belum lunas, verifikasi,
loading dan hasil pencarian kosong: `/tmp/opencode/pangan-audit-readonly/`.

Tidak menguji uang nyata, Supabase terkonfigurasi, Android fisik/kamera, maupun
RLS secara langsung. Temuan produksi berikut berasal kode dan temuan fungsional
parent; tidak dianggap integrasi operasional. Audit ini selesai sebelum UI diedit.

## Prioritas yang harus diperbaiki

1. **P1 error reload nyata:** `home_screen.dart:148` mengembalikan Future dari
   callback setState. Browser mencatat `setState() callback argument returned a
   Future`, lalu dua error ClickDebouncer. Pola sama pada provider:779,
   orders:179–180, info:33 (tiga terakhir risiko kode). Bukan masalah backend.
2. **Blocker kejujuran produksi:** orders:213–224 QR/bayar hanya snackbar;
   account:625–656 menawarkan login demo di cabang produksi; detail:94–108
   memakai registry/ledger demo. Pembatalan produksi:226–246 memanggil update
   langsung tanpa pemulihan; parent menemukan penolakan RLS. Dashboard penyedia
   produksi tidak memiliki antrean. Aksi tak terbukti harus nonaktif dengan
   alasan, tidak memindahkan data demo ke produksi atau menampilkan sukses palsu.
3. **P1 discovery terlambat:** Beranda 320 belum memperlihatkan nama/harga
   makanan pertama sebelum navigasi bawah. Header, filter dan foto menekan isi;
   kartu:71–154. Jelajahi menampilkan bookmark nonaktif dan tidak memberi nama
   toko. Utamakan makanan, harga, stok dan waktu ambil, bukan pengantar berulang.
4. **P1 checkout dan akses:** CTA detail berada setelah seluruh kartu dan kuota
   (detail:112–177). Tamu hanya mendapat snackbar untuk pindah Akun (:573–581).
   Penyedia:55–67 → login:75–79 tidak menyelesaikan pindah peran bagi penerima
   yang sudah masuk. Buat aksi kontekstual tanpa mengubah aturan kuota/peran.
5. **P1 trust/readiness:** tiket:113–148 menyuruh mengambil meskipun belum lunas
   atau belum dikonfirmasi. Onboarding:37–58 mengesankan semua toko lolos validasi;
   detail:187–255 mencentang info kebersihan/ulasan yang belum ada. Bedakan bukti,
   informasi belum tersedia, dan langkah pesanan berikutnya.
6. **P2 hierarki/filter/state:** form pencarian terlalu dominan, hasil tanpa
   ringkasan jumlah/filter. Header Beranda di dalam builder data hilang pada
   loading/empty/error (home:171–196). Skeleton generik dan retry tidak cukup
   kontekstual. Pertahankan kontrol dan sediakan pemulihan yang relevan.
7. **P2 operasional/responsif:** QR toko dan uraian mendahului antrean;
   detail perangkat mendahului tugas akun. Form verifikasi dan tiket meregang
   penuh di desktop (provider:619, ticket:44). Satu arah tata letak belum selesai.
8. **P2 visual/a11y:** landing kurang berorientasi makanan dan memprioritaskan
   CTA penyedia di atas jelajah. Ikon dark onboarding hijau muda di abu terang
   sekitar 1,30:1. Spasi/kartu dan istilah demo tidak konsisten lintas route.

Referensi di atas berada di `lib/screens/`, selain kartu di
`lib/widgets/listing_tile.dart`; angka adalah kondisi sebelum implementasi.

## Peta fungsi yang harus dipertahankan

- Panduan → landing → jelajah sebagai tamu atau masuk demo nama/peran.
- Penerima: katalog/filter → detail keamanan + stok/kuota → jumlah → pesanan
  gratis atau pembayaran → pesanan → tiket; QR manual tetap tersedia.
- Demo: 4 porsi/2 pesanan per perangkat/hari; batal/gagal/keluar tidak memulihkan
  kuota. Simulasi tidak memindahkan uang; sampel/foto selalu ditandai.
- Penyedia demo: verifikasi lokal → tambah penawaran setelah terverifikasi →
  konfirmasi/siap/selesai, QR dan cadangan manual. Jangan memalsukan data toko.
- Akun: sesi, preferensi tema, kuota, bantuan/dampak/legal; tamu tetap bisa melihat
  katalog. Produksi adalah cabang lain, tidak boleh disamakan dengan demo.

## Arah dan batas implementasi

**Putaran Kebaikan: makanan lebih dahulu, langkah berikutnya selalu jelas.**
Pertahankan Montserrat lokal, forest/hijau pada krem, putih untuk permukaan,
foto aset berlisensi dan ring batas ambil yang bermakna. Tanpa dependensi berat,
glow/animasi berlebihan atau statistik fiktif. Target 44 dp minimum, kontras teks
4,5:1, font sistem dan form bergulir. Desktop tetap memiliki lebar baca terukur.

Kelompok terpisah: (A) fondasi/landing/katalog, (B) detail/transaksi/tiket dan
state umum, (C) akun/login/penyedia/bacaan. Tidak ada perubahan layanan, backend,
migrasi atau aturan transaksi. Produksi yang tidak dapat dibuktikan ditampilkan
sebagai belum tersedia, bukan diisi demo. Pemeriksaan berikutnya terfokus pada
widget yang berubah dan browser nyata; parent pemilik final analyze/full test/build.

## Rekonsiliasi dokumen

`docs/PUTARAN_DESIGN_SYSTEM.md` adalah arah visual terbaru; DESIGN/desain.md
memuat token/grid/sheet lama yang belum sesuai kode. PRODUCT/FITUR menyebut
pesanan hanya memori, padahal DemoStore kini mempersist pesanan. DESIGN §4a
menggambarkan kartu auth yang berbeda dari pemisahan cabang akun sekarang.
FITUR §19 tentang tombol mati/tujuan penyedia salah sudah historis. Ada sebagian
jalur produksi dalam kode, tetapi bukan bukti UI produksi lengkap. Hasil tes dan
capture di UI_RUNTIME_AUDIT.md adalah historis, bukan sertifikasi pass baru ini.

## Hasil implementasi dan verifikasi

Bagian 1–89 adalah **audit historis sebelum edit UI**, bukan klaim hasil akhir.
Pada 2 November 2026, pass desain ini membaca ulang layar yang sudah diedit
oleh pass sebelumnya dan membuka aplikasi nyata di Chromium. Bukti viewport,
state, log, dan batasnya berada di [ui-redesign-2026-11-02/README.md](ui-redesign-2026-11-02/README.md).
Secara visual katalog 320 px kini memperlihatkan nama, harga, stok, batas ambil,
dan aksi Pesan pada viewport pertama; contoh/simulasi tetap diberi label.
Form verifikasi 320 px semula memotong petunjuk NIB sehingga frasa “bukan
pemeriksaan resmi” tersembunyi; helper kini diizinkan dua baris.
Pemindaian QR toko tetap bisa dilakukan secara manual pada tiket menunggu,
namun teks tiket sekarang menjelaskan bahwa kecocokan QR **bukan bukti GPS,
pelunasan, kesiapan pesanan, atau keamanan pangan**. Jalur dan aturan transaksi
tidak diubah; penjelasan QR di halaman penyedia juga diselaraskan. Tes terfokus `pickup_screens_test.dart` dan
`detail_security_test.dart`: 14 lulus sesudah perubahan; bukan pengganti
analyze, suite penuh, atau build akhir yang dimiliki parent.

### Hasil per layar pada kode yang diperiksa

| Layar | Perubahan/keadaan yang diamati | Alasan desain dan batas |
| --- | --- | --- |
| Landing dan onboarding | Jelajah menjadi aksi utama, peran penyedia dan masuk demo tersedia; foto contoh ditandai. | Makanan dan tujuan aplikasi terlihat lebih dahulu; klaim keamanan toko tidak dilebihkan. |
| Beranda dan kartu | Lokasi, kategori, jumlah hasil dan muat ulang terlihat; kartu pertama 320 px memperlihatkan foto, harga, stok, batas ambil dan aksi. | Mempercepat penemuan makanan; `Data contoh` dan `Foto ilustrasi` tetap terlihat. |
| Jelajahi | Pencarian, filter aktif, hasil kosong dan aksi `Hapus semua filter` tersedia. | Pengguna dapat mengerti mengapa daftar kosong lalu memulihkannya. |
| Detail | Informasi harga/pengambilan/alergen/toko, konsekuensi kuota dan aksi pemesanan dibedakan; transaksi produksi yang belum lengkap dinonaktifkan dengan alasan. | Keputusan pemesanan dapat diperiksa tanpa menganggap status demo sebagai kebenaran server. |
| Pembayaran | Ringkasan dan status ditampilkan; jalur tanpa backend memakai `SIMULASI` tanpa uang nyata. | Tidak menyamakan keberhasilan demo dengan uang masuk. |
| Pesanan dan tiket | Status, langkah berikutnya, waktu/kode pengambilan tersedia; QR menunggu dilunasi/dikonfirmasi diredupkan. Copy QR toko menjelaskan hanya kecocokan identitas, bukan lokasi atau keamanan. | Mengurangi risiko datang terlalu dini dan salah memahami arti pemindaian. |
| Penyedia | Antrean demo, penawaran dan QR toko dapat dipindai; form 320 px kini menampilkan utuh penjelasan verifikasi bukan pemeriksaan resmi. | Tugas operasional mudah dipindai tanpa klaim verifikasi usaha/pangan produksi. |
| Akun | Akses demo, tema, bantuan dan perangkat dikelompokkan; cabang produksi tanpa autentikasi UI lengkap menyebut keterbatasannya. | Memisahkan sesi perangkat dari akun produksi. |

Klaim layar di atas didukung kode dan cakupan bukti browser pada
`ui-redesign-2026-11-02/README.md`, **bukan** uji semua kondisi tiap layar.
Verifikasi parent pada kode akhir: `flutter analyze` 0 temuan, 214 tes lulus,
build web release dan APK debug berhasil. Build Android bukan uji perangkat.
