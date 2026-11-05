# Desain Alternatif — PanganPutar "Riset Minimalis"

> Alternatif dari `FIGMA_DESIGN_SPEC.md` (Soft Structuralism) dan `desain.md` (Arus Bersih).
> Desain ini sengaja **lain**: editorial warm-minimalist, bento grid, 1 aksen warna dominan.
> Target: anti-slop, terbaca di semua device, performans tinggi di HP low-end.

## 1. Prinsip (Anti-Slop)

1. **Satu sumber warna utama.** Hanya `pine` sebagai warna aksen utama. Kategori hanya memiliki dot 8px, strip/hardcode per kategori dilarang. Semua warna via `AppTokens` atau `context.colorScheme`.
2. **Komposisi > nesting.** Maksimal nesting 3 level per build. Lebih dari itu → ekstrak ke widget kecil di file yang sama (`_NamaBagian`).
3. **No `dynamic`.** API return typed `Future<List<FoodListing>>`, bukan `Future<List<dynamic>>` + `Future.wait` campur aduk. Satu Future satu tanggung jawab.
4. **Const-default.** Semua padding, radius, durasi, ikon statis wajib `const`. `TweenAnimationBuilder` hanya untuk reveal, bukan untuk layout.
5. **Satu pola loading.** `AsyncView<T>` tunggal untuk loading / empty / error. Jangan duplikasi `if (loading) ... else if (empty)` di tiap screen.
6. **YAGNI.** Tidak ada wrapper yang cuma forward (`SectionContainer` 1 baris → ganti `Center + ConstrainedBox` inline atau extension). Tidak ada animasi >300ms untuk aksi.
7. **No ambient glow / bayangan total.** Desain ini tanpa `AmbientGlow`, tanpa `boxShadow` berat di item list. Scroll 60fps di HP low-end adalah wajib.

**Slop yang dilarang:**
- `home_screen.dart:76-475` satu `build` 400 baris → pecah.
- Warna hardcode `Color(0xFFD7EEE3)` di screen → pakai `context.colors` atau token.
- `boxShadow` + `RadialGradient` 3 lapis di scroll → jank di HP low-end.
- `AnimatedEntry` 800ms + translate 64px untuk semua item → ganti 180-220ms, 12px, hanya first paint.
- Warna kategori per-item di `build` (`switch` per kartu) → define sekali di token/widget.

## 2. Bahasa Visual (Beda dari Bezel & Arus Bersih)

| Item | Soft Structuralism (Lama) | Arus Bersih (Sudah Ada) | Baru "Riset Minimalis" |
|---|---|---|---|
| Kartu | radius 32/26 + shadow clay | Single surface, radius 20, border outlineVariant, tanpa shadow | radius **16**, border **2px solid** `outlineVariant`, **tanpa shadow**, latar putih |
| Hero | Gradien 3 warna WarmHeroCard | Header flat + angka besar, tanpa gradien | Header teks-only: `Eyebrow` + `Display Small`, tanpa gambar/hero card |
| Tombol | IslandButton pil + lingkaran panah | `FilledButton.tonal` + `FilledButton` standar M3 | `OutlinedButton` + `FilledButton` M3 standar, padding presisi |
| Aksen | 5 warna kategori penuh | 1 primer `pine`, kategori dot 8px + label, tanpa strip/pil warna | **1 aksen utama `pine`**. Kategori hanya **dot 6px** di sudut kiri atas, warna sesuai token kategori. Warna strip/harga = warna aksen utama saja (tidak per-kategori).
| Latar | Scaffold dengan `AmbientGlow` 3 blob | Scaffold flat, divider sebagai pemisah | **Scaffold warna cream/netral**, tanpa glow, divider tipis `1px` `outlineVariant` |
| Font | Montserrat semua 800 | Montserrat hanya judul (700), body 400/500 — kurangi FOUT | **Montserrat: judul 800, body 400, caption 600** — kurangi FOUT dengan warna kontras, tidak semua font weight 800 |

### Tokens (`lib/core/tokens.dart`)

```dart
abstract final class AppTokens {
  static const radiusCard = 16.0;
  static const radiusInput = 12.0;
  static const radiusBtn = 8.0;
  static const pagePadPhone = 12.0;
  static const pagePadTablet = 18.0;
  static const gapCard = 8.0;
  static const gapSection = 16.0;
  static const maxWidthPhone = 600.0;
  static const maxWidthTablet = 840.0;
  static const animFast = Duration(milliseconds: 180);
  static const minTouch = 44.0;
}
```

**Warna:** Palet warm-minimalis. Hanya 4 warna utama + neutral.

```dart
abstract final class AppColors {
  static const cream = Color(0xFFFFFBF0);    // scaffold light
  static const espresso = Color(0xFF1C2622); // teks utama, tombol primer
  static const pine = Color(0xFF047857);     // aksen utama
  static const grayMedium = Color(0xFF6B7280); // label kategori, border
  static const grayLight = Color(0xFFD1D5DB); // latar ringan
}
```

**Dot kategori:** Hanya titik kecil 6px di sudut kiri atas kartu, warna utama `pine`.

```dart
Color dotForCategory(String c) => switch (c) {
  'roti' || 'jajanan' => AppColors.pine,
  'sayur' || 'buah' => AppColors.pine,
  'minuman' => AppColors.pine,
  'paket' => AppColors.pine,
  _ => AppColors.grayMedium,
};
```

## 3. Komposisi Pas Device

### 3.1 Breakpoint (tunggal, dipakai semua screen)

```dart
enum AppSize { compact, medium, expanded }

AppSize appSizeOf(double w) =>
  w < 500 ? AppSize.compact : w < 760 ? AppSize.medium : AppSize.expanded;
```

| Lebar | Nama | Komposisi |
|---|---|---|
| <500 (HP 360×800, 375×667) | compact | List 1 kolom, `NavigationBar` 4 destinasi, AppBar compact, FAB hanya di Beranda |
| 500–760 (HP landscape, tablet kecil) | medium | List 2 kolom grid, `NavigationBar` tetap, page pad 18 |
| >760 (tablet besar / desktop) | expanded | Konten `maxWidth 840` center, 2–3 kolom grid, `NavigationRail` extended |

Helper page padding:

```dart
EdgeInsets pagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final s = appSizeOf(w);
  final side = switch (s) {
    AppSize.compact => AppTokens.pagePadPhone,
    AppSize.medium => AppTokens.pagePadTablet,
    AppSize.expanded => (w - AppTokens.maxWidthTablet) / 2,
  };
  return EdgeInsets.fromLTRB(side, 12, side, 16);
}
```

### 3.2 Aturan Komposisi Per Layar

1. **SafeArea + keyboard.** Semua form (`login`, `filter`, `tambah`) dalam `SingleChildScrollView(padding: viewInsets)` + `SafeArea`. Input min height 44.
2. **Scroll tunggal.** Pakai `CustomScrollView + SliverList/SliverGrid`, bukan `ListView` dalam `ListView`. Sticky filter = `SliverAppBar.pinned` + `SliverGrid`.
3. **Grid adaptif, bukan `Row` 2 kartu fix.** Ganti `Row(Expanded+Expanded)` dengan:

```dart
SliverGrid.builder(
  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: switch (appSizeOf(MediaQuery.sizeOf(context).width)) {
      AppSize.compact => 360, // → 1 kolom di HP sempit
      _ => 280,               // → 2 kolom tablet
    },
    mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.5,
  ),
  itemBuilder: (_, i) => ListingTile(item: items[i]),
)
```

4. **Navigasi adaptif.** Satu `AdaptiveShell`: `compact → NavigationBar`, `medium/expanded → NavigationRail`. 4 destinasi: Beranda, Jelajahi, Pesanan, Akun. FAB hanya di Beranda.
5. **Detail.** HP: push full + `DraggableScrollableSheet` untuk form order. Tablet expanded: `Row(list 280 | detail flex)` tanpa navigasi bolak-balik.
6. **Touch & type.** Judul `titleLarge 18/800`, body `13/400`, angka `tabularFigures`. Target sentuh ≥44. Jarak kartu 8, section 16 (bukan 12/28 campur).
7. **Orientation.** Landscape HP diperlakukan `medium`: paksa 2 kolom, hero disembunyikan (hanya judul + CTA), cegah overflow vertikal.

### 3.3 Kerangka File (pecah build raksama)

```
lib/core/tokens.dart        // radius, pad, durasi, breakpoint
lib/core/adaptive.dart      // appSizeOf, pagePadding, AdaptiveShell
lib/core/tokens_warna.dart // palet warm-minimalis 4 warna
lib/widgets/async_view.dart // FutureBuilder generik typed
lib/widgets/listing_tile.dart // kartu flat tunggal (tanpa bezel, tanpa shadow)
lib/screens/home/           // home_page.dart (60 baris) + _hero.txt + _stats.txt
```

Contoh `AsyncView` (ganti duplikasi di tiap screen):

```dart
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T) data;
  const AsyncView({super.key, required this.future, required this.data});

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (c, s) {
      if (s.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return ErrorView(title: 'Gagal memuat', description: '${s.error}');
      }
      if (!s.hasData) {
        return const EmptyView(title: 'Kosong', description: 'Belum ada data.');
      }
      return data(s.data as T);
    },
  );
}
```

Contoh kartu flat (ganti `BezelCard + InkWell + strip + pil`):

```dart
class ListingTile extends StatelessWidget {
  final FoodListing item;
  final VoidCallback? onTap;
  const ListingTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: onTap,
        leading: Container(
          width: 6, height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotForCategory(item.category)),
        ),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text('Sisa ${item.quantityAvailable} • ${item.city}',
          style: theme.textTheme.bodySmall),
        trailing: Text(formatRupiah(item.effectivePrice),
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
      ),
    );
  }
}
```

## 4. Checklist Penerimaan

- [ ] Nol hex / padding / durasi inline di `screens/` (grep `Color(0x` kosong).
- [ ] Nol file `screens/` >120 baris build; widget `_` per bagian.
- [ ] Nol `dynamic` / `List<dynamic>` di service & screen.
- [ ] Diuji di 360×800 (1 kolom, tanpa overflow), 375×667, 600×960 (2 kolom + rail), landscape.
- [ ] Scroll 60fps di HP low-end: tanpa blur/shadow/gradient di item list.
- [ ] Semua state (loading/empty/error/offline) lewat `AsyncView`.
- [ ] Lighthouse manual: tiap aksi <300ms feedback, target sentuh ≥44, kontras teks ≥4.5:1.
- [ ] Nol warna kategori per `switch` di dalam `build` — semua via token `dotForCategory()`.
- [ ] FAB hanya di Beranda, tidak di layar lain.
- [ ] Tidak ada `AnimatedEntry`, `AmbientGlow`, `WarmHeroCard`, `bezel double` di seluruh layar.