import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/features/cabinet/data/models/cabinet_item.dart';
import 'package:medwise/features/cabinet/domain/services/expiry_calculator_service.dart';
import 'package:medwise/features/chemist_counter/data/models/chemist_cart_item.dart';
import 'package:medwise/features/chemist_counter/domain/services/salt_equivalence_service.dart';
import 'package:medwise/features/drug_interactions/data/models/drug_interaction_rule.dart';
import 'package:medwise/features/drug_interactions/data/repositories/drug_interaction_repository.dart';
import 'package:medwise/features/drug_interactions/domain/services/interaction_checker_service.dart';
import 'package:medwise/features/ocr_ingestion/data/models/match_candidate.dart';

// Mock repository for offline interactions
class MockDrugInteractionRepository implements DrugInteractionRepository {
  @override
  Future<List<DrugInteractionRule>> getRules() async {
    return [
      const DrugInteractionRule(
        saltA: 'aspirin',
        saltB: 'warfarin',
        severity: InteractionSeverity.critical,
        effect: 'Severe hemorrhage risk',
        recommendation: 'Avoid concurrent use',
      ),
      const DrugInteractionRule(
        saltA: 'metformin',
        saltB: 'alcohol',
        severity: InteractionSeverity.critical,
        effect: 'Potentiates risk of severe lactic acidosis',
        recommendation: 'Avoid alcohol consumption',
      ),
      const DrugInteractionRule(
        saltA: 'ibuprofen',
        saltB: 'paracetamol',
        severity: InteractionSeverity.moderate,
        effect: 'Renal strain and gastric discomfort',
        recommendation: 'Stagger doses',
      ),
    ];
  }
}

void main() {
  group('SaltEquivalenceService Tests', () {
    const service = SaltEquivalenceService();

    test('Identifies active salt equivalence between Dolo 650 and Crocin 650', () {
      final cartItem = const ChemistCartItem(
        id: 'cart-1',
        brandName: 'Dolo 650',
        activeSalt: 'Paracetamol',
        prescribedStrength: '650mg',
        quantityPrescribed: 10,
        estimatedPricePerUnit: 3.50,
      );

      final cabinetItem = CabinetItem(
        id: 'cab-1',
        brandName: 'Crocin 650',
        activeSalt: 'Paracetamol',
        strength: '650mg',
        form: 'Tablet',
        quantityRemaining: 8.0,
        printedExpiry: '12/2027',
        profileId: 'profile-1',
        createdAt: DateTime.now(),
      );

      final result = service.evaluateItem(
        cartItem: cartItem,
        cabinetItems: [cabinetItem],
      );

      expect(result.hasCabinetEquivalence, isTrue);
      expect(result.quantityAlreadyOwned, equals(8.0));
      expect(result.recommendedBuyQuantity, equals(2));
      expect(result.estimatedSavings, equals(8.0 * 3.50));
      expect(result.strengthMismatch, isFalse);
    });

    test('Strength Guard flags concentration mismatch (500mg vs 650mg)', () {
      final cartItem = const ChemistCartItem(
        id: 'cart-2',
        brandName: 'Dolo 650',
        activeSalt: 'Paracetamol',
        prescribedStrength: '650mg',
        quantityPrescribed: 10,
      );

      final cabinetItem = CabinetItem(
        id: 'cab-2',
        brandName: 'Calpol 500',
        activeSalt: 'Paracetamol',
        strength: '500mg',
        form: 'Tablet',
        quantityRemaining: 15.0,
        printedExpiry: '12/2027',
        profileId: 'profile-1',
        createdAt: DateTime.now(),
      );

      final result = service.evaluateItem(
        cartItem: cartItem,
        cabinetItems: [cabinetItem],
      );

      expect(result.hasCabinetEquivalence, isTrue);
      expect(result.strengthMismatch, isTrue);
      expect(result.strengthWarningMessage, contains('different strength'));
      expect(result.recommendedBuyQuantity, equals(10)); // Cannot substitute blindly
    });
  });

  group('DrugInteractionCheckerService Tests', () {
    test('Flags critical interaction between Aspirin and Warfarin', () async {
      final checker = InteractionCheckerService(MockDrugInteractionRepository());

      final interactions = await checker.checkInteractions(
        targetBrand: 'Ecosprin 75',
        targetSalt: 'Aspirin',
        existingMedicines: [
          (brandName: 'Coumadin', activeSalt: 'Warfarin'),
        ],
      );

      expect(interactions.isNotEmpty, isTrue);
      expect(interactions.first.severity, equals(InteractionSeverity.critical));
      expect(interactions.first.effect, contains('hemorrhage'));
    });
  });

  group('ExpiryCalculatorService Tests', () {
    const service = ExpiryCalculatorService();

    test('Detects opened liquid/drop sterility breach (>28 days)', () {
      final openedItem = CabinetItem(
        id: 'cab-3',
        brandName: 'Refresh Tears Eye Drops',
        activeSalt: 'Carboxymethylcellulose',
        strength: '0.5%',
        form: 'Ophthalmic Drop',
        quantityRemaining: 1.0,
        printedExpiry: '12/2028',
        isOpened: true,
        openedOnDate: DateTime.now().subtract(const Duration(days: 30)),
        profileId: 'profile-1',
        createdAt: DateTime.now(),
      );

      expect(openedItem.isSterilityExpired, isTrue);
      expect(service.getStatus(openedItem), equals(ExpiryStatus.sterilityBreached));
    });

    test('Calculates active sterility when opened within 28 days', () {
      final openedItem = CabinetItem(
        id: 'cab-4',
        brandName: 'Refresh Tears Eye Drops',
        activeSalt: 'Carboxymethylcellulose',
        strength: '0.5%',
        form: 'Ophthalmic Drop',
        quantityRemaining: 1.0,
        printedExpiry: '12/2028',
        isOpened: true,
        openedOnDate: DateTime.now().subtract(const Duration(days: 10)),
        profileId: 'profile-1',
        createdAt: DateTime.now(),
      );

      expect(openedItem.isSterilityExpired, isFalse);
      expect(openedItem.openedDaysRemaining, equals(18));
      expect(service.getStatus(openedItem), equals(ExpiryStatus.active));
    });
  });

  group('ConfidenceLevel Tests', () {
    test('Scores map correctly to High, Medium, and Low tiers', () {
      expect(ConfidenceLevel.fromScore(0.95), equals(ConfidenceLevel.high));
      expect(ConfidenceLevel.fromScore(0.90), equals(ConfidenceLevel.high));
      expect(ConfidenceLevel.fromScore(0.85), equals(ConfidenceLevel.medium));
      expect(ConfidenceLevel.fromScore(0.70), equals(ConfidenceLevel.medium));
      expect(ConfidenceLevel.fromScore(0.69), equals(ConfidenceLevel.low));
      expect(ConfidenceLevel.fromScore(0.30), equals(ConfidenceLevel.low));
    });
  });
}
