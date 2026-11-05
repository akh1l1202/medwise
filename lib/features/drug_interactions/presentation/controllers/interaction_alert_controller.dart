import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/drug_interactions/domain/services/interaction_checker_service.dart';
import 'package:medwise/features/cabinet/presentation/controllers/cabinet_controller.dart';

final cabinetInteractionsProvider = FutureProvider<List<DetectedInteraction>>((ref) async {
  final cabinetItems = await ref.watch(cabinetNotifierProvider.future);
  final checker = ref.watch(interactionCheckerServiceProvider);

  final medicines = cabinetItems
      .where((item) => !item.isExpired)
      .map((item) => (brandName: item.brandName, activeSalt: item.activeSalt))
      .toList();

  return await checker.checkPairwiseInteractions(medicines);
});
