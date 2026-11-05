import 'package:intl/intl.dart';

String formatRupiah(int n) {
  if (n <= 0) return 'Gratis';
  final f = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  return f.format(n);
}

String formatTanggal(DateTime d) {
  final local = d.toLocal();
  try {
    final f = DateFormat('EEE, d MMM y • HH:mm', 'id_ID');
    return f.format(local);
  } catch (_) {
    // Jaring pengaman: data locale belum siap (mis. lupa initializeDateFormatting)
    // — jangan sampai melempar ke UI, pakai format manual Indonesia.
    return _formatTanggalManual(local);
  }
}

String _formatTanggalManual(DateTime d) {
  const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  const bulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.year} • $hh:$mm';
}

String timeLeft(DateTime end, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = end.difference(current);
  if (diff.isNegative || diff.inSeconds <= 0) return 'Sudah berakhir';
  if (diff.inHours < 1) {
    final m = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return 'Sisa $m menit';
  }
  if (diff.inHours < 24) return 'Sisa ${diff.inHours} jam';
  return 'Sisa ${diff.inDays} hari';
}

const kategoriLabel = {
  'nasi': 'Nasi',
  'roti': 'Roti',
  'lauk': 'Lauk',
  'sayur': 'Sayur',
  'buah': 'Buah',
  'minuman': 'Minuman',
  'paket': 'Paket',
  'jajanan': 'Jajanan',
  'lainnya': 'Lainnya',
};

const statusPesananLabel = {
  'menunggu': 'Menunggu',
  'dikonfirmasi': 'Dikonfirmasi',
  'siap_diambil': 'Siap diambil',
  'selesai': 'Selesai',
  'dibatalkan': 'Dibatalkan',
};
