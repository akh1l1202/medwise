import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/medicine_catalog/data/models/medicine_record.dart';
import 'package:medwise/features/medicine_catalog/data/repositories/medicine_catalog_repository.dart';

final catalogSearchServiceProvider = Provider<CatalogSearchService>((ref) {
  final repository = ref.watch(medicineCatalogRepositoryProvider);
  return CatalogSearchService(repository);
});

class CatalogSearchService {
  final MedicineCatalogRepository _repository;

  CatalogSearchService(this._repository);

  Future<List<MedicineRecord>> search(String query) async {
    return await _repository.searchMedicines(query);
  }

  Future<List<MedicineRecord>> findEquivalents(String activeSalt) async {
    return await _repository.findByActiveSalt(activeSalt);
  }

  Future<List<MedicineRecord>> searchBySymptom(String symptom) async {
    return await _repository.findBySymptom(symptom);
  }
}
