import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/family_profile.dart';
import '../../data/repositories/profile_repository.dart';

final profilesProvider = AsyncNotifierProvider<ProfileNotifier, List<FamilyProfile>>(() {
  return ProfileNotifier();
});

final selectedProfileIdProvider = StateProvider<String?>((ref) => null);

class ProfileNotifier extends AsyncNotifier<List<FamilyProfile>> {
  @override
  Future<List<FamilyProfile>> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    return await repository.getProfiles();
  }

  Future<void> addProfile(FamilyProfile profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(profileRepositoryProvider);
      await repository.saveProfile(profile);
      return await repository.getProfiles();
    });
  }

  Future<void> updateProfile(FamilyProfile profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(profileRepositoryProvider);
      await repository.saveProfile(profile);
      return await repository.getProfiles();
    });
  }

  Future<void> deleteProfile(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(profileRepositoryProvider);
      await repository.deleteProfile(id);
      return await repository.getProfiles();
    });
  }
}
