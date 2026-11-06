import 'package:medwise/features/cabinet/data/models/cabinet_item.dart';
import 'chemist_cart_item.dart';

class SmartBuyResult {
  final ChemistCartItem cartItem;
  final CabinetItem? matchingCabinetItem;
  final double quantityAlreadyOwned;
  final int recommendedBuyQuantity;
  final double estimatedSavings; // In Indian Rupees (₹)
  final bool strengthMismatch;
  final String? strengthWarningMessage;
  final String? storageLocation;

  const SmartBuyResult({
    required this.cartItem,
    this.matchingCabinetItem,
    this.quantityAlreadyOwned = 0.0,
    required this.recommendedBuyQuantity,
    this.estimatedSavings = 0.0,
    this.strengthMismatch = false,
    this.strengthWarningMessage,
    this.storageLocation,
  });

  bool get hasCabinetEquivalence => matchingCabinetItem != null && quantityAlreadyOwned > 0;

  bool get canSkipPurchase => hasCabinetEquivalence && recommendedBuyQuantity == 0 && !strengthMismatch;

  String formatOwnedQuantity() {
    final count = quantityAlreadyOwned.toStringAsFixed(quantityAlreadyOwned.truncateToDouble() == quantityAlreadyOwned ? 0 : 1);
    final lower = cartItem.dosageForm.toLowerCase();
    if (lower.contains('syrup') || lower.contains('suspension') || lower.contains('liquid') || lower.contains('drop')) {
      return '$count ${quantityAlreadyOwned == 1 ? 'bottle' : 'bottles'}';
    }
    if (lower.contains('ointment') || lower.contains('cream') || lower.contains('gel')) {
      return '$count ${quantityAlreadyOwned == 1 ? 'tube' : 'tubes'}';
    }
    if (lower.contains('spray') || lower.contains('inhaler')) {
      return '$count ${quantityAlreadyOwned == 1 ? 'unit' : 'units'}';
    }
    return '$count ${quantityAlreadyOwned == 1 ? 'tablet' : 'tablets'}';
  }

  String formatRecommendedBuy() {
    final count = recommendedBuyQuantity;
    final lower = cartItem.dosageForm.toLowerCase();
    if (lower.contains('syrup') || lower.contains('suspension') || lower.contains('liquid') || lower.contains('drop')) {
      return '$count ${count == 1 ? 'bottle' : 'bottles'}';
    }
    if (lower.contains('ointment') || lower.contains('cream') || lower.contains('gel')) {
      return '$count ${count == 1 ? 'tube' : 'tubes'}';
    }
    if (lower.contains('spray') || lower.contains('inhaler')) {
      return '$count ${count == 1 ? 'unit' : 'units'}';
    }
    return '$count ${count == 1 ? 'tablet' : 'tablets'}';
  }
}
