import 'package:intl/intl.dart';

final _currencyFmt = NumberFormat('#,###', 'ja_JP');
final _dateFmt = DateFormat('yyyy/MM/dd', 'ja_JP');
final _dateTimeFmt = DateFormat('yyyy/MM/dd HH:mm', 'ja_JP');

String formatCurrency(int? amount) {
  if (amount == null) return '未設定';
  return '¥${_currencyFmt.format(amount)}';
}

String formatDate(DateTime? date) {
  if (date == null) return '-';
  return _dateFmt.format(date);
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  return _dateTimeFmt.format(dt);
}

String formatProfit(int? profit) {
  if (profit == null) return '-';
  final sign = profit >= 0 ? '+' : '';
  return '$sign${formatCurrency(profit)}';
}

String formatProfitRate(double? rate) {
  if (rate == null) return '-';
  final sign = rate >= 0 ? '+' : '';
  return '$sign${rate.toStringAsFixed(1)}%';
}
