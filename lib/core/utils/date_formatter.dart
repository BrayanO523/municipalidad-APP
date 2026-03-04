import 'package:intl/intl.dart';

abstract class DateFormatter {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _currencyFormat = NumberFormat.currency(
    symbol: 'L',
    decimalDigits: 2,
  );

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date);
  }

  static String formatCurrency(num? amount) {
    if (amount == null) return 'L 0.00';
    return _currencyFormat.format(amount);
  }
}
