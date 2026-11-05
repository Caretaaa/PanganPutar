# PanganPutar

<!-- impeccable:product-schema 1 -->

## Platform

android

Flutter Android dan Web, sesuai pilihan pengguna. Versi web menyediakan akses melalui browser; navigasi mengikuti ukuran layar.

## Stack

Flutter dan Dart. Fungsi proyek sumber digunakan kembali bila sesuai, tanpa mengubah direktori sumber.

Pengguna memilih Supabase (PostgreSQL, Auth, Storage) untuk integrasi berikutnya. Metode masuk yang dipilih: email/kata sandi, Google, dan nomor HP dengan OTP SMS. Konfigurasi proyek, OAuth Google, serta penyedia SMS belum diberikan; pilihan ini belum berarti integrasi produksi tersedia.

## Users

- Pengunjung menjelajahi makanan berlebih dan membaca panduan.
- Penerima memesan makanan gratis atau berbayar, lalu mengambilnya di toko.
- Penyedia memverifikasi toko, menawarkan makanan, dan memproses pengambilan.
- Admin dikenali oleh sesi; moderasi produksi tidak termasuk aplikasi mobile.

## Product Purpose

Mempertemukan penyedia makanan berlebih dengan penerima melalui penawaran, pemesanan, dan pengambilan langsung di toko.

## Operating Context

Bahasa Indonesia, mata uang rupiah, tanggal lokal. Pengguna dapat mencoba peran penerima dan penyedia pada satu perangkat melalui sesi demo lokal.

## Capabilities and Constraints

Acuan lengkap: `FITUR_APLIKASI.md` dari proyek sumber. Pertahankan panduan awal, sesi demo, pencarian dan filter, detail keamanan pangan, kuota perangkat, pembayaran, pesanan, QR dua arah dengan cadangan manual, verifikasi toko, operasional penyedia, dampak, bantuan, privasi, syarat, dan preferensi tema.

Kuota bawaan 4 porsi dan 2 pesanan per perangkat per hari; keluar akun dan pembatalan tidak mengembalikan kuota. Pesanan dan penawaran baru adalah data demo dalam memori. Identitas instalasi, kuota, sesi, tema, panduan, dan verifikasi toko disimpan lokal.

Katalog dan pembayaran memiliki jalur backend. Pembayaran simulasi wajib jelas bertanda tanpa uang nyata. Autentikasi produksi, sinkronisasi transaksi, refund, moderasi, verifikasi usaha resmi, dan validasi QR oleh server tidak boleh diklaim tersedia.

## Brand Commitments

Nama PanganPutar. Bahasa Indonesia yang lugas. Desain mengikuti dokumen pengguna `desain.md`, bukan desain lama proyek sumber.

Tambahan dari pengguna: foto makanan untuk data contoh. Foto merupakan ilustrasi, bukan bukti kondisi makanan atau foto toko nyata.

## Evidence on Hand

- `/home/caramela/Downloads/panganputar_flutter/FITUR_APLIKASI.md`
- `/home/caramela/Downloads/panganputar_flutter/desain.md`
- Proyek Flutter sumber di `/home/caramela/Downloads/panganputar_flutter/`; direktori `tiket/` tidak termasuk.

## Product Principles

- Pertahankan aturan bisnis saat mengganti tampilan.
- Bedakan data contoh, simulasi, dan integrasi produksi secara jujur.
- Keberadaan informasi dan verifikasi demo bukan jaminan keamanan pangan.
- Seluruh tindakan utama harus dapat digunakan pada layar kecil.

## Accessibility & Inclusion

Target sentuh minimal 44 piksel logis; kontras teks minimal 4,5:1. Form dapat digulir saat keyboard terbuka, tema terang/gelap/sistem, dan input manual ketika kamera tidak tersedia.
