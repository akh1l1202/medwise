import 'package:flutter_test/flutter_test.dart';
import 'package:medwise/core/database/bundled_db_helper.dart';
import 'package:medwise/features/medicine_catalog/data/models/medicine_record.dart';
import 'package:medwise/features/medicine_catalog/data/repositories/medicine_catalog_repository.dart';
import 'package:medwise/features/ocr_ingestion/domain/services/prescription_scanner_service.dart';

class MockMedicineCatalogRepository extends MedicineCatalogRepository {
  MockMedicineCatalogRepository() : super(BundledDbHelper.instance);

  final List<MedicineRecord> _mockCatalog = const [
    MedicineRecord(
      id: 1,
      brandName: 'Dolo 650',
      activeSalt: 'Paracetamol',
      strength: '650mg',
      dosageForm: 'Tablet',
      manufacturer: 'Micro Labs Ltd',
      commonSymptoms: ['Fever', 'Body Ache', 'Headache'],
    ),
    MedicineRecord(
      id: 2,
      brandName: 'Crocin 650',
      activeSalt: 'Paracetamol',
      strength: '650mg',
      dosageForm: 'Tablet',
      manufacturer: 'GlaxoSmithKline',
      commonSymptoms: ['Fever', 'Headache'],
    ),
    MedicineRecord(
      id: 3,
      brandName: 'Augmentin 625 Duo',
      activeSalt: 'Amoxicillin and Clavulanic Acid',
      strength: '625mg',
      dosageForm: 'Tablet',
      manufacturer: 'GlaxoSmithKline',
      commonSymptoms: ['Bacterial Infection', 'Throat Infection'],
    ),
    MedicineRecord(
      id: 4,
      brandName: 'Pantocid 40',
      activeSalt: 'Pantoprazole',
      strength: '40mg',
      dosageForm: 'Tablet',
      manufacturer: 'Sun Pharmaceutical',
      commonSymptoms: ['Acidity', 'GERD', 'Heartburn'],
    ),
    MedicineRecord(
      id: 5,
      brandName: 'Azithral 500',
      activeSalt: 'Azithromycin',
      strength: '500mg',
      dosageForm: 'Tablet',
      manufacturer: 'Alembic Pharmaceuticals',
      commonSymptoms: ['Bacterial Infection', 'Throat Infection', 'Chest Congestion'],
    ),
  ];

  @override
  Future<List<MedicineRecord>> searchMedicines(String query, {int limit = 20}) async {
    final lower = query.toLowerCase();
    return _mockCatalog.where((m) =>
      m.brandName.toLowerCase().contains(lower) ||
      m.activeSalt.toLowerCase().contains(lower) ||
      lower.contains(m.brandName.toLowerCase()) ||
      lower.contains(m.activeSalt.toLowerCase())
    ).toList();
  }

  @override
  Future<List<MedicineRecord>> getAllMedicines({int limit = 100}) async {
    return _mockCatalog;
  }
}

void main() {
  group('PrescriptionScannerService Tests', () {
    late PrescriptionScannerService service;
    late MockMedicineCatalogRepository mockRepo;

    setUp(() {
      mockRepo = MockMedicineCatalogRepository();
      service = PrescriptionScannerService(mockRepo);
    });

    tearDown(() {
      service.dispose();
    });

    test('Filters clinic headers, doctor credentials, and patient vitals', () async {
      final slipLines = [
        'Apollo Hospitals Healthcare Ltd',
        'Dr. Rajesh Verma MBBS, MD (Medicine)',
        'Patient Name: Rohit Sharma',
        'Age: 34 / Male Date: 04/10/2026',
        'BP: 120/80 mmHg Pulse: 74 Temp: 98.4 F',
        'Diagnosis: Acute Viral Pharyngitis',
        'Rx',
        'Tab Dolo 650 1-0-1 x 5 days',
        'Doctor Signature',
      ];

      final candidates = await service.parsePrescriptionLines(slipLines);

      expect(candidates.length, equals(1));
      expect(candidates.first.matchedRecord.brandName, equals('Dolo 650'));
      expect(candidates.first.matchedRecord.activeSalt, equals('Paracetamol'));
      expect(candidates.first.quantity, equals(10));
    });

    test('Parses multi-medicine prescription slip with different dosage notations', () async {
      final slipLines = [
        '1. Tab Dolo 650 1-0-1 x 5 days',
        '2. Cap Augmentin 625 Duo BD x 5 days',
        '3. Pantocid 40 10 tabs',
        '4. Azithral 500 OD x 3 days',
      ];

      final candidates = await service.parsePrescriptionLines(slipLines);

      expect(candidates.length, equals(4));

      // Dolo 650: 1-0-1 x 5 days -> (1 + 0 + 1) * 5 = 10 tabs
      final dolo = candidates.firstWhere((c) => c.matchedRecord.brandName == 'Dolo 650');
      expect(dolo.quantity, equals(10));
      expect(dolo.dosageInstruction, contains('1-0-1 for 5 days'));

      // Augmentin 625 Duo: BD x 5 days -> 2 * 5 = 10 tabs
      final augmentin = candidates.firstWhere((c) => c.matchedRecord.brandName == 'Augmentin 625 Duo');
      expect(augmentin.quantity, equals(10));
      expect(augmentin.dosageInstruction, contains('BD for 5 days'));

      // Pantocid 40: 10 tabs explicit
      final pantocid = candidates.firstWhere((c) => c.matchedRecord.brandName == 'Pantocid 40');
      expect(pantocid.quantity, equals(10));
      expect(pantocid.dosageInstruction, contains('10 tablets'));

      // Azithral 500: OD x 3 days -> 1 * 3 = 3 tabs
      final azithral = candidates.firstWhere((c) => c.matchedRecord.brandName == 'Azithral 500');
      expect(azithral.quantity, equals(3));
      expect(azithral.dosageInstruction, contains('OD for 3 days'));
    });

    test('Merges multi-line split entries (e.g. Line 1: Drug Name, Line 2: Dosage)', () async {
      final splitSlipLines = [
        'Rx',
        '1. Tab Dolo 650',
        '1-0-1 x 5 days',
        '2. Pantocid 40',
        '1 tab OD before food x 10 days',
      ];

      final candidates = await service.parsePrescriptionLines(splitSlipLines);

      expect(candidates.length, equals(2));
      expect(candidates[0].matchedRecord.brandName, equals('Dolo 650'));
      expect(candidates[0].quantity, equals(10));
      expect(candidates[1].matchedRecord.brandName, equals('Pantocid 40'));
      expect(candidates[1].quantity, equals(10));
    });

    test('Identifies generic active salt prescription (Paracetamol 650mg)', () async {
      final genericSlipLines = [
        '1. Paracetamol 650mg Tablet 1-0-1 x 5 days',
      ];

      final candidates = await service.parsePrescriptionLines(genericSlipLines);

      expect(candidates.isNotEmpty, isTrue);
      // Matches Paracetamol formulations in catalog
      expect(candidates.first.matchedRecord.activeSalt, equals('Paracetamol'));
      expect(candidates.first.quantity, equals(10));
    });

    test('Fallbacks to uncataloged prescribed item when drug not in database', () async {
      final uncatalogedLines = [
        '1. Tab Telma 40 1-0-0 x 30 days',
      ];

      final candidates = await service.parsePrescriptionLines(uncatalogedLines);

      expect(candidates.length, equals(1));
      expect(candidates.first.matchedRecord.brandName, contains('Telma 40'));
      expect(candidates.first.quantity, equals(30)); // 1 per day x 30 days = 30 tablets!
    });

    test('Deduplicates repeat lines in scan results', () async {
      final slipLines = [
        'Tab Dolo 650 1-0-1 x 5 days',
        'Dolo 650 (Paracetamol 650mg)',
      ];

      final candidates = await service.parsePrescriptionLines(slipLines);

      expect(candidates.length, equals(1));
      expect(candidates.first.matchedRecord.brandName, equals('Dolo 650'));
    });

    test('Does not match random medicine for unreadable cursive scribble (zero hallucination)', () async {
      // Unreadable scribble from handwritten prescription
      final scribbleLines = [
        '1. Tab xzptq 1-0-1',
      ];

      final candidates = await service.parsePrescriptionLines(scribbleLines);

      expect(candidates.length, equals(1));
      // Must NOT match a random database drug like "Augmentin" or "Azithral"
      expect(candidates.first.matchedRecord.brandName, equals('Xzptq'));
      expect(candidates.first.matchedRecord.activeSalt, equals('Prescribed Formulation'));
      // Must be evaluated as low confidence (< 50%, Red tier)
      expect(candidates.first.confidenceScore, lessThan(0.50));
      // Must not be auto-selected for import
      expect(candidates.first.isSelected, isFalse);
    });

    test('Discards pure non-medicine noise lines', () async {
      final noiseLines = [
        '--- ~~~~ ----',
        'xyz qwrty ppp',
      ];

      final candidates = await service.parsePrescriptionLines(noiseLines);
      expect(candidates, isEmpty, reason: 'Pure noise lines without dosage or medicine indicators must be dropped');
    });

    test('Rejects electricity and utility bills as non-prescription documents', () {
      final utilityBillLines = [
        'Navi Mumbai Municipal Corporation',
        'G Ward Office Airoli Corporation',
        'BILL OF SUPPLY FOR THE MONTH OF - SEPTEMBER-2026',
        'BILL NO(GGN): 000003520314445',
        'CONSUMER NO: 000091959003',
        'GSTIN: 27AAECM2933K1ZB',
        'METER NO: 12419 Phase: 3 CONNECTED LOAD: 2.00 KW TARIFF: LT-I',
        'CURRENT CHARGES: 6740.00 DUE DATE: 04-10-2026',
        'TOTAL AMOUNT PAYABLE: 6820.00',
        'Scan this QR Code with BHIM App for UPI Payment',
      ];

      final docType = service.classifyDocument(utilityBillLines);
      expect(docType, equals(DocumentType.utilityOrTaxBill));
    });

    test('Rejects service/appliance invoices as non-prescription documents', () {
      final applianceInvoiceLines = [
        'GOLDEN SERVICE 9324632837',
        'Authorised Service Center Faber',
        'Shop No. 15, Purnashanti Height, Thane West - 400 601',
        'GST No.: 27FMFPK6465M1ZC',
        'Tax Invoice No. 2028',
        'Product: HICRICHICT Chimney Status: OW',
        'Total Amount: 1200.00',
      ];

      final docType = service.classifyDocument(applianceInvoiceLines);
      expect(docType, equals(DocumentType.utilityOrTaxBill));
    });

    test('Classifies genuine clinic and hospital prescriptions correctly', () {
      final realPrescriptionLines = [
        'Criti-Care ICCU, MULTISPECIALITY HOSPITAL & TRAUMA CENTRE',
        'Dr. Sundeep G. Mestri MBBS, M.D (Bom.)',
        'Dr. Sameer R. Dumir MBBS, M.D. Consulting Cardiologist',
        'Patient: MR. AKHIL TYAGI (20y, Male)',
        'Diagnosis: STOMACH DISCOMFORT, Fever 99.7',
        'Rx',
        '1) SOMPRAZ D 40 CAPSULE 1-0-0 Daily - 10 Days',
        'Composition : Domperidone 30 MG + Esomeprazole 40 MG',
        'Timing : 1 Before breakfast',
        '2) UNIENZYME TAB 0-1-0 Daily - 10 Days',
      ];

      final docType = service.classifyDocument(realPrescriptionLines);
      expect(docType, equals(DocumentType.medicalPrescription));
    });

    test('Scores illegible handwritten cursive as low readability (< 50%) and prompts manual input', () async {
      // Real handwritten ENT prescription lines from Dr. Sachin Nemane photo (IMG20261105194901.jpg & 194645.jpg)
      final cursiveLines = [
        'Dr. Sachin T. Nemane MS DORL',
        'Date: 20/06/2026',
        'ov @ 4',
        'Cary',
        '@ 7 Ow Cse2?',
        'lara',
        'Gr eX 7',
        'Go Kare ok Oe',
        '@ Lise pee ae ge',
      ];

      final candidates = await service.parsePrescriptionLines(cursiveLines);
      final score = service.calculatePrescriptionReadability(
        candidates: candidates,
        rawLines: cursiveLines,
      );

      // Must be evaluated as low readability (< 50% confidence)
      expect(score, lessThan(0.50));
      expect(score, greaterThanOrEqualTo(0.15));

      final result = PrescriptionScanResult(
        candidates: candidates,
        rawExtractedLines: cursiveLines,
        overallReadabilityScore: score,
        isHandwrittenOrLowReadability: score < 0.50,
      );

      expect(result.isHandwrittenOrLowReadability, isTrue);
      expect(result.requiresManualInput, isTrue);
      expect(result.readabilityPercentage, lessThan(50));
    });

    test('Scores clean printed prescriptions with high readability (>= 85%)', () async {
      final printedLines = [
        'Apollo Clinic Healthcare',
        'Dr. Rajesh Verma MD',
        'Rx',
        '1. Tab Dolo 650 1-0-1 x 5 days',
        '2. Tab Pantocid 40 1-0-0 before food',
        '3. Tab Augmentin 625 Duo 1-0-1 x 3 days',
      ];

      final candidates = await service.parsePrescriptionLines(printedLines);
      expect(candidates.length, equals(3));

      final score = service.calculatePrescriptionReadability(
        candidates: candidates,
        rawLines: printedLines,
      );

      expect(score, greaterThanOrEqualTo(0.85));

      final result = PrescriptionScanResult(
        candidates: candidates,
        rawExtractedLines: printedLines,
        overallReadabilityScore: score,
        isHandwrittenOrLowReadability: score < 0.50,
      );

      expect(result.isHandwrittenOrLowReadability, isFalse);
      expect(result.requiresManualInput, isFalse);
      expect(result.readabilityPercentage, greaterThanOrEqualTo(85));
    });
  });
}
