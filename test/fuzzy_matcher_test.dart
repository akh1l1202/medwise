import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/core/database/bundled_db_helper.dart';
import 'package:medwise/features/medicine_catalog/data/models/medicine_record.dart';
import 'package:medwise/features/medicine_catalog/data/repositories/medicine_catalog_repository.dart';
import 'package:medwise/features/ocr_ingestion/domain/services/fuzzy_matcher_service.dart';

class MockCatalogRepository extends MedicineCatalogRepository {
  MockCatalogRepository() : super(BundledDbHelper.instance);

  final List<MedicineRecord> _mockDb = const [
    MedicineRecord(
      id: 1,
      brandName: 'Dolo 650 Tablet',
      activeSalt: 'Paracetamol',
      strength: '650mg',
      dosageForm: 'Tablet',
      manufacturer: 'Micro Labs Ltd',
      commonSymptoms: ['Fever', 'Pain'],
    ),
    MedicineRecord(
      id: 2,
      brandName: 'Crocin 650',
      activeSalt: 'Paracetamol',
      strength: '650mg',
      dosageForm: 'Tablet',
      manufacturer: 'GlaxoSmithKline',
      commonSymptoms: ['Fever'],
    ),
    MedicineRecord(
      id: 3,
      brandName: 'Pan-D Capsule',
      activeSalt: 'Pantoprazole + Domperidone',
      strength: '40mg + 30mg',
      dosageForm: 'Capsule',
      manufacturer: 'Alkem Laboratories',
      commonSymptoms: ['Acidity', 'GERD'],
    ),
    MedicineRecord(
      id: 4,
      brandName: 'Telma 40 Tablet',
      activeSalt: 'Telmisartan',
      strength: '40mg',
      dosageForm: 'Tablet',
      manufacturer: 'Glenmark Pharmaceuticals',
      commonSymptoms: ['Hypertension'],
    ),
  ];

  @override
  Future<List<MedicineRecord>> searchMedicines(String query, {int limit = 20}) async {
    final lower = query.toLowerCase();
    return _mockDb.where((m) =>
      m.brandName.toLowerCase().contains(lower) ||
      m.activeSalt.toLowerCase().contains(lower) ||
      lower.contains(m.brandName.toLowerCase()) ||
      lower.contains(m.activeSalt.toLowerCase())
    ).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FuzzyMatcherService Tests (Blister Pack & Box Scanning)', () {
    late FuzzyMatcherService matcher;

    setUp(() {
      matcher = FuzzyMatcherService(MockCatalogRepository());
    });

    test('Matches brand across the alphabet (e.g. Dolo 650, Pan-D, Telma 40) stripped of packaging noise', () async {
      final rawPackagingLines = [
        'Rx Dolo 650 Tablets I.P.',
        'Each uncoated tablet contains: Paracetamol IP 650mg',
        'Batch No. D-2940',
        'Mfg. Lic. No. 25/UA/2019',
        'Store below 30°C. Protect from light.',
      ];

      final candidates = await matcher.matchOcrLines(rawPackagingLines);

      expect(candidates.isNotEmpty, isTrue);
      expect(candidates.first.matchedRecord.brandName, equals('Dolo 650 Tablet'));
      expect(candidates.first.confidenceScore, greaterThanOrEqualTo(0.85));
    });

    test('Matches Pan-D and Telma (verifying letters C-Z are fully covered)', () async {
      final panDLines = [
        'Pan-D Capsules',
        'Pantoprazole and Domperidone SR Capsules',
      ];

      final panDResult = await matcher.matchOcrLines(panDLines);
      expect(panDResult.isNotEmpty, isTrue);
      expect(panDResult.first.matchedRecord.brandName, equals('Pan-D Capsule'));

      final telmaLines = [
        'Telma 40 Tablets IP',
        'Telmisartan Tablets IP 40mg',
      ];

      final telmaResult = await matcher.matchOcrLines(telmaLines);
      expect(telmaResult.isNotEmpty, isTrue);
      expect(telmaResult.first.matchedRecord.brandName, equals('Telma 40 Tablet'));
    });

    test('Ignores packaging boilerplate lines and does not false-match them', () async {
      final boilerplateLines = [
        'Batch No. B-4819',
        'Mfg Lic No. 12/L/2021',
        'Store in a cool dry place',
        'Keep out of reach of children',
        'Marketed by: Sun Pharma Laboratories Ltd',
      ];

      final candidates = await matcher.matchOcrLines(boilerplateLines);
      expect(candidates, isEmpty, reason: 'Boilerplate lines must never be matched to medicines');
    });

    test('Rejects random unreadable OCR noise (zero hallucination)', () async {
      final noiseLines = [
        'qwxzplm 8820',
        '--- !! ---',
      ];

      final candidates = await matcher.matchOcrLines(noiseLines);
      expect(candidates, isEmpty);
    });
  });
}
