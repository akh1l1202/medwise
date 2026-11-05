import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/cabinet/data/models/cabinet_item.dart';
import 'package:medwise/features/chemist_counter/data/models/chemist_cart_item.dart';
import 'package:medwise/features/chemist_counter/data/models/smart_buy_result.dart';

final saltEquivalenceServiceProvider = Provider<SaltEquivalenceService>((ref) {
  return const SaltEquivalenceService();
});

class SaltEquivalenceService {
  const SaltEquivalenceService();

  /// Evaluates a single prescribed item against the user's active home cabinet stock.
  SmartBuyResult evaluateItem({
    required ChemistCartItem cartItem,
    required List<CabinetItem> cabinetItems,
  }) {
    final prescribedSalt = _normalize(cartItem.activeSalt);
    final prescribedStrength = _normalize(cartItem.prescribedStrength);

    // Filter valid, non-expired items sharing the same active salt
    final matchingItems = cabinetItems.where((item) {
      if (item.isExpired) return false;
      return _normalize(item.activeSalt) == prescribedSalt;
    }).toList();

    if (matchingItems.isEmpty) {
      // No active salt match at home -> user must purchase full prescribed amount
      return SmartBuyResult(
        cartItem: cartItem,
        matchingCabinetItem: null,
        quantityAlreadyOwned: 0.0,
        recommendedBuyQuantity: cartItem.quantityPrescribed,
        estimatedSavings: 0.0,
        strengthMismatch: false,
      );
    }

    // Sort to prioritize exact strength matches first
    matchingItems.sort((a, b) {
      final aMatchesStrength = _normalize(a.strength) == prescribedStrength;
      final bMatchesStrength = _normalize(b.strength) == prescribedStrength;
      if (aMatchesStrength && !bMatchesStrength) return -1;
      if (!aMatchesStrength && bMatchesStrength) return 1;
      return b.quantityRemaining.compareTo(a.quantityRemaining);
    });

    final bestMatch = matchingItems.first;
    final bestMatchStrength = _normalize(bestMatch.strength);

    final isStrengthMismatch = prescribedStrength.isNotEmpty &&
        bestMatchStrength.isNotEmpty &&
        prescribedStrength != bestMatchStrength;

    if (isStrengthMismatch) {
      return SmartBuyResult(
        cartItem: cartItem,
        matchingCabinetItem: bestMatch,
        quantityAlreadyOwned: bestMatch.quantityRemaining,
        recommendedBuyQuantity: cartItem.quantityPrescribed,
        estimatedSavings: 0.0,
        strengthMismatch: true,
        strengthWarningMessage:
            'Same active salt found (${bestMatch.activeSalt}), but different strength (${bestMatch.strength} at home vs ${cartItem.prescribedStrength} prescribed). Consult your doctor or chemist before substituting.',
        storageLocation: bestMatch.storageLocation,
      );
    }

    // Exact salt and strength match! Calculate Smart Buy recommendations
    final owned = bestMatch.quantityRemaining;
    final needed = cartItem.quantityPrescribed;
    final recommendedBuy = (needed - owned).clamp(0.0, needed.toDouble()).ceil();
    final quantitySaved = needed - recommendedBuy;
    final savings = quantitySaved * cartItem.estimatedPricePerUnit;

    return SmartBuyResult(
      cartItem: cartItem,
      matchingCabinetItem: bestMatch,
      quantityAlreadyOwned: owned,
      recommendedBuyQuantity: recommendedBuy,
      estimatedSavings: savings,
      strengthMismatch: false,
      storageLocation: bestMatch.storageLocation,
    );
  }

  /// Evaluates an entire cart against the user's active home cabinet stock.
  List<SmartBuyResult> evaluateCart({
    required List<ChemistCartItem> cartItems,
    required List<CabinetItem> cabinetItems,
  }) {
    return cartItems
        .map((item) => evaluateItem(cartItem: item, cabinetItems: cabinetItems))
        .toList();
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
  }
}
