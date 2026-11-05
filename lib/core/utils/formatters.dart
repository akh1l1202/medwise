import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _rupeeFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String formatRupees(double amount) {
    return _rupeeFormat.format(amount);
  }

  static String formatExpiryDate(DateTime date) {
    final formatter = DateFormat('MM/yyyy');
    return formatter.format(date);
  }
}
