# Pemeriksaan UI Chromium — 2 November 2026

Sumber: Flutter web-server debug `127.0.0.1:8765`, Chromium headless nyata
(CDP, software WebGL), DPR 1, viewport **320×740 / 375×812 / 600×960 /
1280×900**. Berkas `nama-layar-{320,375,600,1280}.png` berisi tangkapan
viewport (bukan full-scroll). Nama `light`/`dark` berarti tema yang benar-benar
ditampilkan. `browser-events.json` mencatat peringatan WebGL dan dua request
`10.0.2.2:3000/api/listings` timeout; fallback contoh muncul sesudahnya.
Tidak ada exception aplikasi pada event yang tertangkap dalam sesi ini;
pengumpulan log tidak mencakup semua siklus browser saat koneksi CDP berganti.

| Layar/alur | Bukti terang | Bukti gelap | Temuan langsung / batas |
| --- | --- | --- | --- |
| Landing | `landing-light-*` | `landing-dark-*` | Aksi jelajah mendahului penyedia; foto contoh berlabel; scroll untuk sisa informasi. |
| Jelajah tamu | `jelajahi-light-*` | `jelajahi-dark-*` | Nama/harga/ambil terlihat setelah data termuat. Capture skeleton loading awal disisihkan, tidak dipakai menilai hasil akhir. |
| Beranda tamu | `beranda-light-*` | `beranda-dark-*` | 320 px: kartu pertama menampilkan harga, stok, waktu dan Pesan sebelum nav bawah. |
| Pesanan tamu | `pesanan-light-*` | `pesanan-dark-*` | Empty state meminta masuk demo, bukan pesanan fiktif. |
| Akun tamu | `akun-light-*` | `akun-dark-*` | Form masuk serta informasi demo; desktop lebar baca dibatasi. |
| Detail | `detail-guest-light-*` | `detail-signed-dark-*` | Guest CTA masuk ada di bawah; gelap diuji setelah login demo. Status toko bukan jaminan pangan. Tidak tersedia perbandingan guest dark terpisah. |
| Masuk penerima | `login-recipient-light-*` | — | Nama/peran, scroll responsif; tidak ada otentikasi produksi yang diuji. |
| Ringkasan bayar | `payment-light-*` | `payment-dark-*` | Metode belum dipilih; simulasi berikutnya berlabel jelas. |
| Menunggu bayar | `payment-loading-*` | — | Spinner pemeriksaan server tampak selama timeout; bukan pembayaran berhasil. |
| Simulasi pembayaran | `simulation-light-*` | `simulation-dark-*` | QR ilustrasi dan tanpa uang nyata; backend 10.0.2.2 tidak tersambung. |
| Hasil simulasi | `payment-success-light-*` | — | SIMULASI ditampilkan bersama status lunas demo, bukan uang nyata. |
| Pesanan penerima | `orders-signed-light-*` | `orders-signed-dark-*` | Menunggu konfirmasi toko meskipun simulasi lunas. |
| Tiket | `ticket-light-*`, `ticket-after-light-*` | `ticket-dark-*`, `ticket-after-dark-*`, `ticket-final-dark-320.png` | QR diredupkan saat belum dikonfirmasi, kode manual tetap terlihat; konten bawah dapat digulir. `ticket-*` sebelum revisi kalimat QR; `ticket-after-*` sesudah revisi copy inti; `ticket-final-dark-320.png` sesudah koreksi heading **“Cocokkan QR toko”**. `ticket-after-scrolled-light-320.png` menunjukkan bagian bawah sebelum koreksi heading. |
| Penyedia | `provider-light-*` | `provider-dark-*` | Antrean pesan di atas penawaran, verifikasi demo dijelaskan; `provider-entry-dark-*` untuk gate akses. `provider-verification-dark-*` adalah form **sebelum perbaikan**: petunjuk NIB 320 px terpotong elipsis sehingga “bukan pemeriksaan resmi” tak terbaca. `provider-verification-final-dark-*` sesudah `helperMaxLines: 2`: kalimat utuh membungkus dua baris. |
| Filter tanpa hasil | `search-empty-light-*` | `search-empty-dark-*` | Pesan tidak cocok dan Hapus semua filter; query contoh acak, bukan stok nyata. |
| Pindai manual | `scanner-light-*` | — | Petunjuk menjelaskan cocok identitas QR, bukan GPS; input manual ada. |

`provider-login-dark-*` dan `provider-role-confirm-dark-*` adalah dialog
perpindahan peran demo, bukan layar login produksi. `search-light-*` adalah
keadaan sebelum submit. Berkas `browser-flow-events.json` berasal koneksi
CDP akhir (tidak memuat ulang riwayat awal); `browser-after-events.json`
sesudah muat ulang app pertama; `browser-final-events.json` sesudah reload
final. Jangkauan: pembacaan viewport,
klik navigasi, transaksi simulasi, empty, form penyedia; **tidak** menuntaskan
verifikasi toko, QR kamera/perangkat nyata, error jaringan terkontrol,
produksi Supabase, pembayaran sungguhan, atau audit kontras piksel seluruh teks.
Kontras 4,5:1 dan target 44 dp perlu pemeriksaan alat/layar fisik lanjutan;
tes widget tidak membuktikan keduanya.

Perubahan terbatas pada copy tiket/QR toko penyedia dan pembungkusan helper form: QR toko mengonfirmasi *identitas QR*
yang cocok, bukan keberadaan fisik atau keamanan pangan; judul hasil cocok
berubah dari “Lokasi terverifikasi” ke “QR toko cocok”. Pemindaian manual dan
status pesanan tidak diubah. `focused-tests.log`: 14 tes lulus sesudah edit
(termasuk form 320 px). Screenshot `provider-verification-final-dark-320.png`
memperlihatkan petunjuk NIB utuh secara visual; tes widget mengonfirmasi teks
dibangun dan tak ada exception layout. Screenshot final provider QR bawah dan
dialog sukses hasil scan belum dicapture ulang; kedua copy diperiksa lewat kode
dan tes terfokus, bukan diklaim sebagai bukti visual browser.
