import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/drug_interactions/data/models/drug_interaction_rule.dart';
import 'package:medwise/features/drug_interactions/data/repositories/drug_interaction_repository.dart';

final interactionCheckerServiceProvider = Provider<InteractionCheckerService>((ref) {
  final repository = ref.watch(drugInteractionRepositoryProvider);
  return InteractionCheckerService(repository);
});

class DetectedInteraction {
  final String medicineA;
  final String saltA;
  final String medicineB;
  final String saltB;
  final DrugInteractionRule rule;

  const DetectedInteraction({
    required this.medicineA,
    required this.saltA,
    required this.medicineB,
    required this.saltB,
    required this.rule,
  });

  InteractionSeverity get severity => rule.severity;
  String get effect => rule.effect;
  String get recommendation => rule.recommendation;
}

class InteractionCheckerService {
  final DrugInteractionRepository _repository;

  InteractionCheckerService(this._repository);

  /// Check a target medicine against an existing list of medicines.
  Future<List<DetectedInteraction>> checkInteractions({
    required String targetBrand,
    required String targetSalt,
    required List<({String brandName, String activeSalt})> existingMedicines,
  }) async {
    final rules = await _repository.getRules();
    final List<DetectedInteraction> detected = [];

    for (final existing in existingMedicines) {
      for (final rule in rules) {
        if (rule.matches(targetSalt, existing.activeSalt)) {
          detected.add(DetectedInteraction(
            medicineA: targetBrand,
            saltA: targetSalt,
            medicineB: existing.brandName,
            saltB: existing.activeSalt,
            rule: rule,
          ));
        }
      }
    }

    // Sort by severity (critical first)
    detected.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return detected;
  }

  /// Check all pairwise interactions within a given list of medicines.
  Future<List<DetectedInteraction>> checkPairwiseInteractions(
    List<({String brandName, String activeSalt})> medicines,
  ) async {
    final rules = await _repository.getRules();
    final List<DetectedInteraction> detected = [];

    for (int i = 0; i < medicines.length; i++) {
      for (int j = i + 1; j < medicines.length; j++) {
        final med1 = medicines[i];
        final med2 = medicines[j];
        for (final rule in rules) {
          if (rule.matches(med1.activeSalt, med2.activeSalt)) {
            detected.add(DetectedInteraction(
              medicineA: med1.brandName,
              saltA: med1.activeSalt,
              medicineB: med2.brandName,
              saltB: med2.activeSalt,
              rule: rule,
            ));
          }
        }
      }
    }

    detected.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return detected;
  }
}
