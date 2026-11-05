import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/core/database/bundled_db_helper.dart';
import 'package:medwise/features/medicine_catalog/data/repositories/medicine_catalog_repository.dart';
import 'package:medwise/features/ocr_ingestion/domain/services/fuzzy_matcher_service.dart';
import 'package:medwise/features/ocr_ingestion/domain/services/ocr_scanner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expiry Date Extraction Tests (Real-World Indian Packaging)', () {
    late OcrScannerService service;

    setUp(() {
      final mockRepo = MedicineCatalogRepository(BundledDbHelper.instance);
      final fuzzyMatcher = FuzzyMatcherService(mockRepo);
      service = OcrScannerService(fuzzyMatcher);
    });

    tearDown(() {
      service.dispose();
    });

    test('Extracts textual month expiry formats (e.g. MAY 2027, AUG/26)', () {
      expect(
        service.extractExpiryDate(['Crocin 650', 'B.No. T4012', 'EXP. MAY 2027']),
        equals('05/2027'),
      );

      expect(
        service.extractExpiryDate(['Dolo 650', 'EXP: AUG/26']),
        equals('08/2026'),
      );

      expect(
        service.extractExpiryDate(['Augmentin 625 Duo', 'EXPIRY: MAR-2028', 'M.R.P. 223.42']),
        equals('03/2028'),
      );

      expect(
        service.extractExpiryDate(['Pantocid 40', 'USE BEFORE: DEC 29']),
        equals('12/2029'),
      );
    });

    test('Extracts numeric expiry formats (e.g. 08/2026, 08/26, 25/08/2026)', () {
      expect(
        service.extractExpiryDate(['Ciplox 500', 'EXP. 08/2026']),
        equals('08/2026'),
      );

      expect(
        service.extractExpiryDate(['Telma 40', 'EXP: 08/26']),
        equals('08/2026'),
      );

      expect(
        service.extractExpiryDate(['Azithral 500', 'EXP.DT. 11/2025']),
        equals('11/2025'),
      );

      expect(
        service.extractExpiryDate(['Ecosprin 75', 'EXP DATE 25/08/2026']),
        equals('08/2026'),
      );
    });

    test('Strictly returns null when no expiry date is found (zero fake defaults)', () {
      // Packaging where date was blurred, unreadable, or missing
      final linesWithoutExpiry = [
        'Micro Labs Limited',
        'Batch No. 9812A',
        'Mfg Lic No: 28/UA/2018',
        'Store in a cool dry place',
      ];

      final result = service.extractExpiryDate(linesWithoutExpiry);
      expect(result, isNull, reason: 'Must be null so user is prompted to enter manually');
    });

    test('Does not confuse manufacturing date (MFD) with expiry date', () {
      final linesWithOnlyMfd = [
        'MFD. 01/2024',
        'MFD DATE: 12/2023',
        'B.No. 4410',
      ];

      final result = service.extractExpiryDate(linesWithOnlyMfd);
      expect(result, isNull);
    });
  });
}
