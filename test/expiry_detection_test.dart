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

    test('Correctly resolves expiry date in multi-line Indian blister pack layouts (e.g. Ketorolac photo)', () {
      // Lines taken directly from desktop photo IMG20261105201125.jpg (Dr. Reddy's Ketorolac 10mg)
      final photoLines = [
        'Each uncoated dispersible tablet contains: Ketorolac Tromethamine IP 10 mg',
        'Dr. Reddy\'s Laboratories Ltd.',
        'B.No., MFG.Dt., EXP.Dt., MRP Rs. PER 15 TABS',
        'INCL. OF ALL TAXES #',
        '2501750 JUL.2025',
        'JUN.2028 177.25',
      ];

      final expiry = service.extractExpiryDate(photoLines);
      // Manufacturing is JUL.2025, Expiry is JUN.2028 -> Must pick JUN.2028!
      expect(expiry, equals('06/2028'));
    });

    test('Extracts medicine batch number from real blister strip text', () {
      // Direct packaging line from IMG20261105200615.jpg
      expect(
        service.extractBatchNumber(['B.NO.SBO0150A', 'M FG. 03/2026', 'EXP. 02/2030']),
        equals('SBO0150A'),
      );

      // Direct packaging line from IMG20261105201136.jpg (Myoril)
      expect(
        service.extractBatchNumber(['myoril', 'CORONA Remedies Limited', 'B.No.0225', 'P:OCT.']),
        equals('0225'),
      );

      // Multi-line header from IMG20261105201125.jpg
      expect(
        service.extractBatchNumber([
          'B.No., MFG.Dt., EXP.Dt., MRP Rs.',
          '2501750 JUL.2025',
        ]),
        equals('2501750'),
      );
    });
  });
}
