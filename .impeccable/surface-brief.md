# Surface brief — PanganPutar (aplikasi utama)

Scope & mode: Operate, code-led, Flutter Android + Web. Estetika dikunci pengguna: **Riset Minimalis** (`desain.md` otoritas visual; `PRODUCT.md` otoritas produk; `FITUR_APLIKASI.md` otoritas fungsi). Jangan ajukan estetika lain.

## Direction contract

- THESIS: satu aksen pine + kartu flat ber-border di krem hangat; menolak hero bergradien, kategori berwarna penuh, dan shadow/glow. Kejujuran demo (badge DEMO/SIMULASI/Data contoh) adalah bagian dari bahasa visual, bukan catatan kaki.
- OWN-WORLD: cream #FFFBF0 / espresso #1C2622 / pine #047857 (+ pineLight #10B981 di gelap), Montserrat 800 judul–400 body–600 caption, radius 16 border 2px tanpa shadow, spacing 8/12/16/18, M3 NavigationBar (<500) / NavigationRail (≥500), maxWidth 840.
- STORY: pengunjung paham mekanisme makanan berlebih → pesan (gratis/berbayar bertanda) → ambil dengan tiket QR; penyedia diverifikasi → tawar → proses pengambilan; keterbatasan backend terbaca jujur.
- FIRST VIEWPORT (Beranda): header teks-only eyebrow + Display Small di atas cream, daftar ListingTile flat 1 kolom (compact), muat ulang; FAB hanya untuk penyedia terverifikasi. Tidak ada gambar hero, tidak ada glow.
- FORM: kelanjutan langsung dari spesifikasi pengguna (posisi 1 dari 1; seed tidak berlaku — arah dipin). Signature: reveal 180ms/12px sekali; steppers & sheet pesan presisi.
- FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

Resolved sejak brief ditulis: palet gelap terpasang penuh (kontras `pineLight` di gelap dipakai di seluruh status/CTA sekunder; spot-check perangkat tetap disarankan); Montserrat kini bundling lokal (400–900, tanpa `google_fonts`); foto contoh berlisensi dengan `ATTRIBUTION.md`; ikon web/launcher diganti merek krim–pine.

Keputusan pengguna tercatat: autentikasi **Supabase (email/password + Google + phone OTP)** — integrasi **belum** dibangun, scaffold layanan distaging tanpa kabel UI, sesi demo dipertahankan (DESIGN.md §4a).

Unresolved: FAB Beranda dikunci hanya-untuk-penyedia-terverifikasi (batal bila parent memutuskan lain); matriks ukuran layar (360/375/600/landscape/desktop) menunggu spot-check browser/perangkat; satu tes `supabase_auth_service_test` gagal di lane parent (layanan distaging, di luar scope UI).
