import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/cabinet/data/models/cabinet_item.dart';
import 'package:medwise/features/cabinet/data/models/intake_schedule.dart';
import 'package:medwise/features/cabinet/data/repositories/cabinet_repository.dart';
import 'package:medwise/features/cabinet/domain/services/dose_depletion_service.dart';
import 'package:medwise/features/profiles/presentation/controllers/profile_controller.dart';

final cabinetNotifierProvider = AsyncNotifierProvider<CabinetNotifier, List<CabinetItem>>(() {
  return CabinetNotifier();
});

final cabinetSchedulesProvider = FutureProvider<List<IntakeSchedule>>((ref) async {
  final repository = ref.watch(cabinetRepositoryProvider);
  final activeProfile = ref.watch(selectedProfileIdProvider);
  return await repository.getSchedules(profileId: activeProfile);
});

class CabinetNotifier extends AsyncNotifier<List<CabinetItem>> {
  @override
  Future<List<CabinetItem>> build() async {
    final repository = ref.watch(cabinetRepositoryProvider);
    final activeProfile = ref.watch(selectedProfileIdProvider);
    return await repository.getCabinetItems(profileId: activeProfile);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(cabinetRepositoryProvider);
      final activeProfile = ref.read(selectedProfileIdProvider);
      return await repository.getCabinetItems(profileId: activeProfile);
    });
  }

  Future<void> addItem(CabinetItem item) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(cabinetRepositoryProvider);
      await repository.addCabinetItem(item);
      final activeProfile = ref.read(selectedProfileIdProvider);
      return await repository.getCabinetItems(profileId: activeProfile);
    });
  }

  Future<void> updateItem(CabinetItem item) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(cabinetRepositoryProvider);
      await repository.updateCabinetItem(item);
      final activeProfile = ref.read(selectedProfileIdProvider);
      return await repository.getCabinetItems(profileId: activeProfile);
    });
  }

  Future<void> deleteItem(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(cabinetRepositoryProvider);
      await repository.deleteCabinetItem(id);
      final activeProfile = ref.read(selectedProfileIdProvider);
      return await repository.getCabinetItems(profileId: activeProfile);
    });
  }

  Future<void> markOpenedToday(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(cabinetRepositoryProvider);
      await repository.markOpenedToday(id);
      final activeProfile = ref.read(selectedProfileIdProvider);
      return await repository.getCabinetItems(profileId: activeProfile);
    });
  }

  Future<DoseDepletionResult?> recordDoseTaken({
    required IntakeSchedule schedule,
    required CabinetItem item,
  }) async {
    final depletionService = ref.read(doseDepletionServiceProvider);
    final result = await depletionService.markDoseTaken(
      schedule: schedule,
      item: item,
    );
    await refresh();
    ref.invalidate(cabinetSchedulesProvider);
    return result;
  }
}
