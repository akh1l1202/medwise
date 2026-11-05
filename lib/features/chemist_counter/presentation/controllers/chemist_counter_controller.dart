import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/chemist_counter/data/models/chemist_cart_item.dart';
import 'package:medwise/features/chemist_counter/data/models/smart_buy_result.dart';
import 'package:medwise/features/chemist_counter/domain/services/salt_equivalence_service.dart';
import 'package:medwise/features/cabinet/presentation/controllers/cabinet_controller.dart';

final chemistCartProvider = StateNotifierProvider<ChemistCartNotifier, List<ChemistCartItem>>((ref) {
  return ChemistCartNotifier();
});

class ChemistCartNotifier extends StateNotifier<List<ChemistCartItem>> {
  ChemistCartNotifier() : super([]);

  void addItem(ChemistCartItem item) {
    state = [...state, item];
  }

  void removeItem(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void updateQuantity(String id, int newQuantity) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(quantityPrescribed: newQuantity) else item
    ];
  }

  void clearCart() {
    state = [];
  }
}

final smartBuyEvaluationProvider = Provider<List<SmartBuyResult>>((ref) {
  final cart = ref.watch(chemistCartProvider);
  final cabinetAsync = ref.watch(cabinetNotifierProvider);
  final equivalenceService = ref.watch(saltEquivalenceServiceProvider);

  final cabinetItems = cabinetAsync.valueOrNull ?? [];
  return equivalenceService.evaluateCart(
    cartItems: cart,
    cabinetItems: cabinetItems,
  );
});

final totalEstimatedSavingsProvider = Provider<double>((ref) {
  final results = ref.watch(smartBuyEvaluationProvider);
  return results.fold<double>(0.0, (sum, result) => sum + result.estimatedSavings);
});
