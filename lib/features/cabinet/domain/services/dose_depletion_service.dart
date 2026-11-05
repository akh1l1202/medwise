import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/cabinet/data/models/cabinet_item.dart';
import 'package:medwise/features/cabinet/data/models/intake_schedule.dart';
import 'package:medwise/features/cabinet/data/repositories/cabinet_repository.dart';

final doseDepletionServiceProvider = Provider<DoseDepletionService>((ref) {
  final repository = ref.watch(cabinetRepositoryProvider);
  return DoseDepletionService(repository);
});

class DoseDepletionService {
  final CabinetRepository _repository;

  DoseDepletionService(this._repository);

  /// Decrement the medicine quantity in the cabinet when a dose is taken.
  /// Also advances antibiotic course day if applicable.
  Future<DoseDepletionResult> markDoseTaken({
    required IntakeSchedule schedule,
    required CabinetItem item,
  }) async {
    final updatedQuantity = await _repository.decrementStock(
      item.id,
      schedule.doseAmount,
    );

    if (schedule.isAntibiotic) {
      await _repository.advanceAntibioticDay(schedule.id);
    }

    final isLowStock = updatedQuantity <= 2.0;
    return DoseDepletionResult(
      cabinetItemId: item.id,
      brandName: item.brandName,
      previousQuantity: item.quantityRemaining,
      remainingQuantity: updatedQuantity,
      isLowStock: isLowStock,
      wasAntibioticAdvanced: schedule.isAntibiotic,
    );
  }
}

class DoseDepletionResult {
  final String cabinetItemId;
  final String brandName;
  final double previousQuantity;
  final double remainingQuantity;
  final bool isLowStock;
  final bool wasAntibioticAdvanced;

  const DoseDepletionResult({
    required this.cabinetItemId,
    required this.brandName,
    required this.previousQuantity,
    required this.remainingQuantity,
    required this.isLowStock,
    required this.wasAntibioticAdvanced,
  });
}
