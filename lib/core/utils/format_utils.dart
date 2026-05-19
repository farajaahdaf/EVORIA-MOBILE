import 'package:intl/intl.dart';

String formatRupiah(num amount) {
  if (amount == 0) return 'Gratis';
  return NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);
}

String formatDate(DateTime? dt) {
  if (dt == null) return '-';
  return DateFormat('d MMM yyyy', 'id_ID').format(dt);
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
}

String formatDateShort(DateTime? dt) {
  if (dt == null) return '-';
  return DateFormat('d MMM', 'id_ID').format(dt);
}

String formatTime(DateTime? dt) {
  if (dt == null) return '-';
  return DateFormat('HH:mm', 'id_ID').format(dt);
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) return '${diff.inDays} hari lalu';
  if (diff.inHours > 0) return '${diff.inHours} jam lalu';
  if (diff.inMinutes > 0) return '${diff.inMinutes} menit lalu';
  return 'Baru saja';
}

String buildImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  final cleaned = path.replaceFirst(RegExp(r'^/?storage/'), '');
  return 'https://evoria.life/storage/$cleaned';
}
