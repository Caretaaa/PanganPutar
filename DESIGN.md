# DESIGN.md — PanganPutar "Riset Minimalis"

> Riwayat desain awal. Untuk token dan komposisi visual terkini, ikuti
> [`docs/PUTARAN_DESIGN_SYSTEM.md`](docs/PUTARAN_DESIGN_SYSTEM.md), sebagaimana
> ditunjuk README. Aturan kejujuran data dan alur produk di bawah tetap berlaku;
> angka visual lama tidak mengesampingkan sistem terkini.

Kontrak visual untuk Flutter Android + Web. Otoritas: dokumen pengguna `desain.md` (ditempel salinan di repo ini) sebagai sumber estetika; `FITUR_APLIKASI.md` sebagai sumber fungsi; `PRODUCT.md` sebagai kejujuran produk. Estetika dipilih pengguna — perubahan identitas di luar dokumen ini butuh persetujuan pengguna.

Mode: **Operate**, code-led. Material 3 memerintah struktur navigasi & interaksi; merek diekspresikan lewat theming M3 (color roles, type scale, shape, motion). Tidak ada bayangan berat, glow, atau gradien di mana pun.

## 1. Prinsip tetap

1. Satu aksen: `pine`. Kategori hanya dot 6px — tanpa strip warna, tanpa pil warna per kategori.
2. Kartu flat: radius 16, border 2px `outlineVariant`, latar surface, **tanpa shadow**.
3. Semua warna/padding/radius/durasi lewat token — nol hex inline di `screens/`.
4. Maksimal 3 level nesting build; `AsyncView<T>` tunggal untuk loading/empty/error.
5. Data demo, simulasi pembayaran, dan ketergantungan backend **selalu bertanda jujur** di UI (lihat §7).
6. Semua fitur di `FITUR_APLIKASI.md` wajib punya pintu masuk yang dapat ditemukan (peta di §5).

## 2. Token

### Warna (light)

| Token | Nilai | Pemakaian |
|---|---|---|
| `cream` | `#FFFBF0` | scaffold light |
| `espresso` | `#1C2622` | teks utama, fill tombol primer, teks tombol isian krem |
| `pine` | `#047857` | aksen tunggal: link, status positif, CTA sekunder, dot kategori |
| `grayMedium` | `#6B7280` | label, border sekunder, teks sekunder (≥4.5:1 di krem terverifikasi) |
| `grayLight` | `#D1D5DB` | latar ringan, chip netral |
| `outlineVariant` | turunan `grayLight` gelap sedikit | border kartu 2px, divider 1px |
| `error` | M3 error | pemblokiran, gagal, penolakan |

Pemetaan ColorScheme (light): `surface=cream`, `onSurface=espresso`, `primary=espresso` (FilledButton), `secondary/tertiary=pine`, `outline=outlineVariant`. Dark theme **wajib dirancang, bukan invert**: scaffold `#121714`, surface `#1C2622`, teks krem `#FFF6E8`, aksen terang `#10B981` (pine `#047857` gagal kontras di gelap — `pineLight` adalah terjemahan token, bukan warna baru), border `#37413C`. Preferensi tema: terang/gelap/sistem, disimpan lokal.

### Tipografi (Montserrat via type scale M3)

| Peran M3 | Font | Catatan |
|---|---|---|
| Display Small / Headline | Montserrat **800** | judul header halaman (teks-only, tanpa gambar hero) |
| Title Large/Medium | Montserrat **800** | judul kartu 18/800 |
| Body | Montserrat **400** | 13–16, `onSurface` |
| Caption / Label | Montserrat **600** | label, badge, chip; `grayMedium` |

Angka (harga, kuota, kode) pakai `tabularFigures`. Ukuran dalam sp mengikuti skala sistem; jangan hardcode px per layar.

### Jarak & bentuk

`radiusCard=16`, `radiusInput=12`, `radiusBtn=8`, `pagePadPhone=12`, `pagePadTablet=18`, `gapCard=8`, `gapSection=16`, `maxWidthPhone=600`, `maxWidthTablet=840`, `animFast=180ms`, `minTouch=44` (usahakan 48 dp sentuh M3; floor 44). Divider 1px. Tombol: `FilledButton` (primer espresso) + `OutlinedButton` (aksen) standar M3, padding presisi.

## 3. Komposisi per perangkat & navigasi

`appSizeOf(width)`: `<500 → compact`, `<760 → medium`, `≥760 → expanded`.

**Resolusi kontradiksi spesifikasi (mengikat):** navigasi mengikuti kriteria penerimaan — **compact: `NavigationBar` bawah 4 destinasi; medium & expanded: `NavigationRail`** (rail tampil mulai 500, terekam di checklist "600×960 2 kolom + rail"). Tabel generik di §3.1 sumber yang menyebut NavigationBar tetap di medium diabaikan demi kriteria penerimaan.

| Lebar | Kolom grid | Pad | Navigasi | Catatan |
|---|---|---|---|---|
| <500 | 1 (`maxCrossAxisExtent 360`) | 12 | NavigationBar | AppBar compact; FAB hanya di Beranda |
| 500–759 | 2 (`280`) | 18 | NavigationRail | landscape HP = medium: 2 kolom, hero disembunyikan |
| ≥760 | 2 (maks 3) | center `maxWidth 840` | NavigationRail extended | detail: `Row(list 280 \| detail flex)` |

Shell tunggal `AdaptiveShell` memuat 4 destinasi: **Beranda, Jelajahi, Pesanan, Akun**. Sisanya route push (detail, tiket, pembayaran, area penyedia, bantuan, dampak, privasi, syarat). Sistem Back selalu dikerjakan (jangan trap gesture). Semua form: `SafeArea + SingleChildScrollView(viewInsets)` — keyboard tidak menutup input.

## 4. Struktur file (panduan, bukan kaku)

```
lib/core/tokens.dart        // AppTokens
lib/core/app_colors.dart    // warna terang + gelap (pineLight = terjemahan pine)
lib/core/adaptive.dart      // appSizeOf, pagePadding, gridExtentFor, useNavigationRail
lib/widgets/async_view.dart // AsyncView<T> + ErrorView + EmptyView
lib/widgets/status_chips.dart // StatusChip, statusColors, HonestyBadge, dot kategori
lib/widgets/listing_tile.dart
lib/widgets/listing_image.dart // foto listing + label ilustrasi + fallback rusak
lib/widgets/qr_panel.dart
lib/screens/<fitur>.dart    // widget `_` per bagian; build <120 baris
lib/main.dart               // Shell adaptif (nav bar <500, rail ≥500)
```

## 4a. Batas integrasi autentikasi (mengikat — keputusan pengguna)

Preferensi pengguna dikonfirmasi: **Supabase** dengan **email/password + Google + phone OTP**. Status: **integrasi UI terbatas sudah aktif** (pass desain 19 Okt 2026) — kartu "Akun Supabase" di tab Akun, **di atas** kartu sesi demo.

- **Pemisahan keras yang wajib dipertahankan**: `SessionState` (demo, peran bisa dipilih) ≠ `SupabaseAuthService` (identitas nyata). **Tidak ada jembatan ke `signInDemo`** — masuk Supabase tidak memengaruhi sesi demo, dan katalog/pesanan/kuota/pengambilan **tetap mode demo** (dinyatakan jujur di kartu).
- **Tanpa tombol palsu**: setiap tombol Google/OTP/email memanggil layanan nyata; "berhasil" hanya dengan sesi/server nyata. Google menyatakan eksplisit: *browser akan dibuka; berhasil hanya dengan sesi nyata*.
- **Jangan sentuh** `lib/services/supabase_auth_service.dart` / `supabase_settings.dart` dari UI selain pemakaian API yang sudah diekspos (initialize, isReady/isConfigured/isSignedIn/busy/recoveryRequired, metode masuk/keluar). Layanan tetap milik parent.
- **`main`**: `await SupabaseAuthService.instance.initialize()` sebelum `runApp`; bila gagal/belum dikonfigurasi, layanan menyimpan pesan jujur dan aplikasi tetap jalan mode demo.
- **Panel `recoveryRequired`**: alur pemulihan khusus (kata sandi baru → `updatePassword`; atau tautan via `resetPassword` + `resendConfirmation`) — tanpa jalan pintas.
- **Sesi demo dipertahankan**: "Masuk / Daftar demo", badge `DEMO`, teks "tanpa kata sandi/OTP/sinkronisasi" tetap benar untuk sesi demo itu sendiri; perbarui teks tersebut hanya bersamaan dengan penghapusan jalur demo nanti (bukan sebelumnya).

## 5. Peta layar & jalur setiap fitur

**Intro & akses awal** — Layar pengantar (panduan: makanan berlebih, verifikasi toko, kuota, pembayaran, pengambilan) + akhir panduan menawarkan: *Cari makanan*, *Masuk sebagai penyedia*, *Masuk demo*. Penanda panduan selesai disimpan lokal; pengantar tetap pintu masuk berikutnya (bukan langsung katalog); panduan dapat dibuka ulang dari Bantuan/Akun.

**Masuk demo** — nama tampilan (3–40 karakter, trim) + peran (default penerima). Tanpa sandi/OTP; label jelas bahwa ini sesi demo.

**Beranda (destinasi)** — header teks-only: eyebrow + Display Small; daftar penawaran (muat dari backend, fallback data contoh **bertanda "Data contoh"**); aksi muat ulang; kartu ringkas: nama, sisa stok, kota, harga efektif, badge toko terverifikasi, dot kategori. FAB **hanya di Beranda**, hanya untuk penyedia terverifikasi → Tambah penawaran; tidak ada FAB di layar lain. (Perbaiki jebakan lama: label "Live" jangan mengaku data realtime; tombol beranda harus punya aksi nyata.)

**Jelajahi (destinasi)** — `SliverAppBar.pinned` berisi pencarian nama + pemicu filter; filter: kategori (chips, dot warna), kota, gratis saja, kombinasi bebas; tombol Terapkan + Muat ulang hasil; empty state "Tidak ada penawaran yang cocok" + cara mengubah filter.

**Detail penawaran** — nama, deskripsi, harga efektif (gratis = Rp0), stok+satuan, alamat, jendela waktu ambil + status kedaluwarsa, identitas toko + status verifikasi, kuota harian terpakai/sisa, **daftar periksa keamanan** (7 pemeriksaan) dengan disclaimer tegas: *pemeriksaan keberadaan info ≠ jaminan keamanan pangan*; stepper jumlah (min 1, dibatasi stok & kuota); ringkasan total; CTA Pesan. Phone: form pesan via `DraggableScrollableSheet`. Pemblokiran pemesanan menampilkan alasan spesifik (belum masuk, peran penyedia, kuota habis, status, waktu, toko ditolak); toko belum diverifikasi = peringatan, bukan blokir.

**Pembayaran** — ringkasan (makanan, jumlah, kode, total); jalur Midtrans bila backend tersedia; fallback **simulasi** bertanda penuh (lihat §7): metode QRIS/GoPay/OVO/DANA/ShopeePay/VA BCA/VA BNI; aksi simulasikan berhasil/gagal; pantau status (polling 4 detik saat aktif); hasil sukses (nominal, metode, referensi, instruksi ambil) / gagal-kedaluwarsa (tutup atau coba lagi). Pengguna yang meninggalkan pembayaran: pesanan tetap ada, kuota tetap terpakai — sampaikan di UI.

**Pesanan (destinasi)** — perlu masuk; tamu melihat panel "Masuk untuk melihat pesanan". Kartu pesanan: makanan, jumlah, waktu, status pesanan, total/gratis, status bayar, **badge SIMULASI bila pembayaran simulasi**, kode pengambilan. Aksi sesuai status: Lanjutkan pembayaran (berbayar belum lunas; disembunyikan jika catatan bayar menunggu/batal), Batalkan (hanya `menunggu`/`dikonfirmasi`, dialog konfirmasi menyatakan **kuota tidak kembali**), Buka tiket (semua kecuali batal, termasuk riwayat selesai).

**Tiket** — QR + kode teks cadangan, identitas pesanan/toko, status verifikasi toko, alamat, waktu ambil, info pembayaran, penanda selesai/batal & apakah pakai verifikasi QR. Aksi: Pindai QR toko (opsional, kedatangan tercatat; bukan syarat wajib; bukan bukti GPS).

**Area Penyedia** (dari Akun dan dari intro — dua pintu wajib; jangan dialihkan ke Jelajahi):
- **Verifikasi toko**: form (nama 3–60, jenis usaha dropdown, NIB/NPWP 13–20 digit, telepon 9–15 digit, alamat ≥10, kota ≥3, konfirmasi foto & titik lokasi) dengan label jujur "konfirmasi demo, bukan unggah/peta resmi"; status + skor bukti + catatan peninjau; aksi persetujuan demo (bukan otorisasi admin nyata).
- **Penawaran saya**: daftar (nama, sisa, satuan, harga, status) + Tambah (terverifikasi saja; nama ≥3, jumlah bulat positif, harga ≥0; gratis=0; kategori `lainnya`, waktu ambil otomatis +1jam/+5jam; batasan form dicatat di UI sebagai batas demo).
- **Proses pesanan**: daftar masuk; alur `menunggu → dikonfirmasi → siap_diambil → selesai`; Pindai tiket (7 pemeriksaan QR, penolakan ber-alasan, peringatan kedaluwarsa tetap bisa proses dengan cek kelayakan); Selesai manual (cadangan tanpa QR, tanpa tanda terverifikasi QR).
- **QR toko**: tampilkan QR identitas toko untuk dipindai penerima.

**Akun (destinasi)** — nama, peran, badge sesi demo; ID perangkat ringkas + sumber identitas + pemakaian kuota (4 porsi / 2 pesanan, kuota tidak kembali saat keluar/batal); aksi: Reset kuota demo, Reset verifikasi demo, Keluar; **pintu Area Penyedia**; preferensi tema; tautan Dampak, Bantuan, Privasi, Syarat; catatan admin: "Moderasi dilakukan di aplikasi web /admin".

**Dampak** — porsi tersalurkan, pesanan selesai, penyedia aktif; estimasi berat (porsi×0,4 kg) & CO2e (×2,5) **berlabel estimasi, bukan sertifikasi**; SDG 2/12/13; nol saat data tak tersedia.

**Bantuan** — bacaan statis: cara cari/pesan/bayar/ambil, penjelasan QR dua arah & tiket terpakai, kuota perangkat & tanpa pengembalian, verifikasi toko, keamanan pangan + disclaimer terdaftar ≠ layak konsumsi; pintu buka ulang panduan.

**Privasi & Syarat** — halaman bacaan. **Admin** — hanya keterangan (tidak ada moderasi mobile).

## 6. Komponen inti & state

- `AsyncView<T>`: waiting → `CircularProgressIndicator` center; error → `ErrorView` (judul "Gagal memuat", pesan + tombol Coba lagi); no data → `EmptyView` (judul + deskripsi spesifik per konteks, bukan "Kosong" generik). Semua layar data lewat ini — tanpa duplikasi if-loading di screen.
- `ListingTile`: kartu flat M3, dot kategori 6px, judul max 2 baris, sub "Sisa N • Kota", harga tabular di trailing. Thumbnail 80px bila listing punya foto, dengan lencana mini "Foto ilustrasi" untuk aset data contoh. Satu widget untuk Beranda & Jelajahi & grid provider.
- `ListingImage`: sumber `imageAsset` (lokal, selalu berlabel ilustrasi) atau `imageUrl` (foto penyedia); gagal/hilang → placeholder bertepi lembut, tanpa layout error.
- `LabelDemo`/badge: `DEMO` (sesi/data demo), `SIMULASI` (pembayaran tanpa uang nyata), `Data contoh` (fallback katalog), `Terverifikasi` (hanya status verifikasi toko tersimpan — bukan klaim keamanan).
- Snackbar untuk umpan balik singkat (berhasil dibuat, diperbarui); dialog Material hanya untuk keputusan terputus (batal pesanan, konfirmasi keluar). Umpan balik aksi <300ms.
- Semua kontrol: disabled/loading/error state nyata; input manual QR/kode selalu tersedia sebagai jalur kamera gagal.

## 7. Kejujuran demo vs produksi (mengikat)

Setiap permukaan yang menyentuh data atau uang wajib memakai sistem tanda:

| Kondisi | Tanda UI |
|---|---|
| Sesi/akun/kuota lokal | badge `DEMO` di Akun & ringkasan |
| Pembayaran simulasi | panel + badge `SIMULASI · tanpa uang nyata`; nomor/QR ilustrasi diberi teks "bukan instruksi transfer"; catatan simpan penanda simulasi |
| Katalog jatuh ke data contoh | label `Data contoh` pada daftar/detail |
| Backend tidak tersedia | pesan jujur "butuh server produksi" — jangan mengaku gagal jaringan |
| Fitur tidak tersedia (refund, moderasi, GPS, unggah foto, notifikasi) | tidak ditampilkan seolah ada; jika perlu disinggung, sebagai keterbatasan tertulis |

Jangan menampilkan "Live", status realtime, atau verifikasi resmi apa pun yang tidak diverifikasi kode.

## 8. Aksesibilitas

Target sentuh ≥44 (usahakan 48) dp; kontras teks ≥4,5:1 (large ≥3:1) di kedua tema — terutama `grayMedium` di krem dan `pineLight` di gelap; form dapat menggulir saat keyboard terbuka; sp mengikuti font-scale sistem (uji 1,3×); label semantik untuk dot kategori & badge (jangan hanya warna); input manual untuk QR; fokus keyboard terlihat (ring M3); dialog dapat ditutup Back.

## 9. Motion

Satu pola: reveal pertama paint saja, jarak 12px, 180ms, stagger halus; tidak ada animasi >300ms; tanpa `AnimatedEntry` raksasa. Hormati pengaturan "Remove animations" sistem (fallback fade instan). Tanpa blur/shadow/gradient di list — scroll 60fps HP low-end adalah syarat.

## 10. Checklist penerimaan (jejak ke spesifikasi)

Dari `desain.md` §4 + `FITUR_APLIKASI.md` §20:

- [x] Nol `Color(0x` inline di `screens/` (hex tersisa hanya di `core/theme.dart` sebagai definisi token error — bukan di layar), nol padding/durasi hardcoded di `screens/`; nol `dynamic` tak bertipe di UI; semua `build` per bagian <120 baris.
- [ ] Uji 360×800 (1 kolom, tanpa overflow), 375×667, 600×960 (2 kolom + rail), landscape, desktop ≥760 (max 840). — *struktur adaptif & token siap; matriks ukuran perlu spot-check browser/perangkat saat build final (klaim 3).* 
- [x] Semua state data lewat `AsyncView`; FAB hanya di Beranda; tidak ada glow/shadow/gradien/bezel ganda/`AnimatedEntry` (widget legacy sudah dihapus).
- [x] Nav: bawah <500, rail ≥500; 4 destinasi; Back sistem selalu berfungsi (rute push standar, tanpa trap); tema terang/gelap/sistem tersimpan (`ThemeController` + SharedPreferences).
- [x] Panduan selesai/dilewati/dibuka ulang (dari Akun); masuk demo + peran + keluar; akun menampilkan kuota/ID/peran.
- [x] Telusuri, filter kombinasi, muat ulang, detail + periksa keamanan + disclaimer; pesan gratis/berbayar dengan semua alur blokir ber-alasan (tercakup `detail_security_test`).
- [x] Bedakan pembayaran nyata vs simulasi di UI dan data; lanjut bayar; batal dengan konfirmasi kuota (tercakup alur bayar simulasi di tes).
- [x] Tiket + kedua QR + input manual; verifikasi toko (form, status, skor, persetujuan demo); tambah penawaran; proses pesanan (QR & manual) — tercakup `pickup_screens_test`/`pickup_flow_test`.
- [x] Dampak ber-label estimasi; bantuan/privasi/syarat/keterbatasan demo terbaca; reset kuota & reset verifikasi demo berfungsi.
- [x] Foto contoh berlisensi (`assets/images` + `ATTRIBUTION.md`), thumbnail berlabel "Foto ilustrasi", foto detail berketerangan, gambar rusak/hilang → placeholder anggun (`ListingImage`).
- [x] Font Montserrat bundling lokal (400–900) tanpa `google_fonts`; ikon web & launcher memakai merek krim/pine; manifest krim.

Status per 19 Okt 2026: seluruh jalur fitur terpasang dan lolos pengujian widget terpilih; sisa terbuka hanya pemotretan ukuran layar (butuh browser/perangkat).

## 11. Lintasan implementasi yang disarankan (disjoint)

- **Lane A — Fondasi**: tokens (warna terang/gelap, type, jarak), tema M3, `AdaptiveShell` + 4 destinasi + route map, `AsyncView`, `LabelDemo`, back/insets.
- **Lane B — Katalog**: Beranda, Jelajahi (+filter), Detail + periksa keamanan + stepper pesan (sheet).
- **Lane C — Transaksi**: Pembayaran (jalur nyata+simulasi bertanda), Pesanan (daftar, lanjut bayar, batal), Tiket + pindai QR toko.
- **Lane D — Penyedia**: verifikasi toko, penawaran saya, proses pesanan, pindai tiket, QR toko, pintu dari Akun+intro.
- **Lane E — Akun & statis**: intro/panduan, masuk demo, Akun (kuota, reset, tema), Dampak, Bantuan, Privasi, Syarat, catatan Admin.

Setiap lane berakhir dengan checklist §10 yang relevan; lane review lintas-batas (terutama badge demo/simulasi) oleh parent.
