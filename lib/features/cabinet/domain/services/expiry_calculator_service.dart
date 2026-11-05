import '../../data/models/cabinet_item.dart';

enum ExpiryStatus {
  active,
  expiringSoon, // <= 30 days
  expired,
  sterilityBreached, // 28-day open limit reached for liquids/drops
}

class ExpiryCalculatorService {
  const ExpiryCalculatorService();

  ExpiryStatus getStatus(CabinetItem item) {
    if (item.isSterilityExpired) {
      return ExpiryStatus.sterilityBreached;
    }

    if (item.isPrintedExpired) {
      return ExpiryStatus.expired;
    }

    // Check if within 30 days of printed expiry
    try {
      final parts = item.printedExpiry.split('/');
      if (parts.length == 2) {
        final month = int.parse(parts[0]);
        var year = int.parse(parts[1]);
        if (year < 100) year += 2000;
        final expiryDate = DateTime(year, month + 1, 0, 23, 59, 59);
        final differenceDays = expiryDate.difference(DateTime.now()).inDays;
        if (differenceDays <= 30 && differenceDays >= 0) {
          return ExpiryStatus.expiringSoon;
        }
      }
    } catch (_) {}

    return ExpiryStatus.active;
  }

  String getExpiryBadgeLabel(CabinetItem item) {
    final status = getStatus(item);
    switch (status) {
      case ExpiryStatus.sterilityBreached:
        return 'Sterility Expired (28d)';
      case ExpiryStatus.expired:
        return 'Expired (${item.printedExpiry})';
      case ExpiryStatus.expiringSoon:
        return 'Expiring Soon (${item.printedExpiry})';
      case ExpiryStatus.active:
        return 'Exp: ${item.printedExpiry}';
    }
  }
}
