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
}
