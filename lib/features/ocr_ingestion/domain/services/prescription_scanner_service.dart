import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:string_similarity/string_similarity.dart';
import '../../data/models/prescription_item_candidate.dart';
import '../../../medicine_catalog/data/models/medicine_record.dart';
import '../../../medicine_catalog/data/repositories/medicine_catalog_repository.dart';

final prescriptionScannerServiceProvider = Provider<PrescriptionScannerService>((ref) {
  final catalogRepo = ref.watch(medicineCatalogRepositoryProvider);
  return PrescriptionScannerService(catalogRepo);
});

enum DocumentType {
  medicalPrescription,
  nonPrescriptionDocument,
  utilityOrTaxBill,
  unrecognizedDocument,
}

class PrescriptionScanResult {
  final List<PrescriptionItemCandidate> candidates;
  final List<String> rawExtractedLines;
  final DocumentType documentType;
  final String? rejectionReason;
  final double overallReadabilityScore;
  final bool isHandwrittenOrLowReadability;

  const PrescriptionScanResult({
    required this.candidates,
    required this.rawExtractedLines,
    this.documentType = DocumentType.medicalPrescription,
    this.rejectionReason,
    this.overallReadabilityScore = 1.0,
    this.isHandwrittenOrLowReadability = false,
  });

  bool get isPrescription => documentType == DocumentType.medicalPrescription;
  bool get isNonPrescription =>
      documentType == DocumentType.nonPrescriptionDocument ||
      documentType == DocumentType.utilityOrTaxBill;
  bool get requiresManualInput => isHandwrittenOrLowReadability || candidates.isEmpty;
  int get readabilityPercentage => (overallReadabilityScore * 100).round().clamp(0, 100);
}

class PrescriptionScannerService {
  final MedicineCatalogRepository _catalogRepository;
  final TextRecognizer? _customRecognizer;

  PrescriptionScannerService(this._catalogRepository, {TextRecognizer? recognizer})
      : _customRecognizer = recognizer;

  TextRecognizer? _activeRecognizer;
  TextRecognizer get _recognizer =>
      _activeRecognizer ??= (_customRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin));

  /// Administrative header patterns to ignore (hospital names, vitals, clinic headers, doctor titles)
  static final List<RegExp> _adminPatterns = [
    RegExp(r'\b(?:hospital|clinic|healthcare|dispensary|nursing\s*home|medical\s*center)\b', caseSensitive: false),
    RegExp(r'^\s*dr\.?\s+[a-z]', caseSensitive: false),
    RegExp(r'\b(?:mbbs|bams|bhms|md|ms|dnb|frcs|mrco|m\.d\.|m\.b\.b\.s\.)\b', caseSensitive: false),
    RegExp(r'\b(?:patient|pt\.?)\s*(?:name|id)?[:\s]', caseSensitive: false),
    RegExp(r'\b(?:name|age|gender|sex|weight|wt|height|ht)\s*[:=]', caseSensitive: false),
    RegExp(r'\b(?:reg(?:\.|\s*no)?|uhid|opd(?:\s*no)?|ipd|bill(?:\s*no)?)\s*[:=]', caseSensitive: false),
    RegExp(r'\b(?:blood\s*pressure|b\.?p\.?|pulse|temp(?:erature)?|spo2|heart\s*rate)\s*[:=]', caseSensitive: false),
    RegExp(r'^\s*(?:diagnosis|chief\s*complaint|c\/o|h\/o|past\s*history|investigations|advice|follow[- ]up|provisional\s*diagnosis)\s*[:\-]', caseSensitive: false),
    RegExp(r'\b(?:phone|mob(?:ile)?|tel|contact|email|address|road|marg|nagar|street|pin\s*code)\s*[:=]', caseSensitive: false),
    RegExp(r'\b(?:signature|consultant|doctor\s*signature|seal)\b', caseSensitive: false),
  ];

  /// Utilities, Discoms & Municipal Tax Bills specifically
  static final List<RegExp> _utilityBillPatterns = [
    RegExp(r'\b(?:bill\s*of\s*supply|electricity|power|gas\s*bill|water\s*bill|property\s*tax)\b', caseSensitive: false),
    RegExp(r'\b(?:consumer\s*(?:no|number|id)|ca\s*no|k\s*no|meter\s*(?:no|number|reading))\b', caseSensitive: false),
    RegExp(r'\b(?:kwh|kva|connected\s*load|contract\s*demand|tariff|discom|mahadiscom|tata\s*power|adani\s*electricity|bses)\b', caseSensitive: false),
    RegExp(r'\b(?:municipal\s*corporation|ward\s*office|nagar\s*nigam|gram\s*panchayat)\b', caseSensitive: false),
    RegExp(r'\b(?:authorised\s*service\s*center|service\s*centre|appliance|product\s*query)\b', caseSensitive: false),
  ];

  /// Comprehensive patterns identifying non-prescription documents across all domains:
  /// - Utilities & Municipal Bills (electricity, gas, water, property tax)
  /// - Commercial Invoices & Receipts (retail, sales, banking, tax invoices)
  /// - Restaurants & Food Delivery (menus, kitchen tickets, table orders, cafes)
  /// - Supermarkets & Groceries (itemized grocery receipts, hypermarkets)
  /// - Shipping & Logistics (courier slips, tracking waybills, e-commerce boxes)
  /// - Identity Documents & Official Records (ID cards, licenses, passports, certificates)
  static final List<RegExp> _nonPrescriptionPatterns = [
    // 1. Utilities, Discoms & Municipal Tax Bills
    ..._utilityBillPatterns,
    // 2. Commercial Invoices, Receipts & Financial Documents
    RegExp(r'\b(?:tax\s*invoice|retail\s*invoice|commercial\s*invoice|cash\s*receipt|sales\s*receipt|invoice\s*no)\b', caseSensitive: false),
    RegExp(r'\b(?:gstin|gst\s*no|cin\s*no|service\s*tax|total\s*amount\s*payable|subtotal|sub-total|balance\s*due)\b', caseSensitive: false),
    RegExp(r'\b(?:bank\s*statement|ifsc|account\s*number|bank\s*branch|atm\s*withdrawal|upi\s*id|payment\s*mode)\b', caseSensitive: false),
    // 3. Restaurants, Cafes & Food Delivery
    RegExp(r'\b(?:restaurant|cafe|canteen|dining|kitchen|menu|table\s*no|order\s*no|waiter|swiggy|zomato|dessert|appetizer|beverage|fast\s*food)\b', caseSensitive: false),
    // 4. Retail, Supermarkets & Groceries
    RegExp(r'\b(?:supermarket|grocery|hypermarket|d-mart|dmart|reliance\s*retail|bigbasket|blinkit|zepto|item\s*qty\s*rate)\b', caseSensitive: false),
    // 5. E-commerce, Couriers & Shipping Logistics
    RegExp(r'\b(?:amazon|flipkart|tracking\s*no|courier|awb|consignee|ship\s*to|delivery\s*partner|return\s*policy|parcel)\b', caseSensitive: false),
    // 6. Identity Documents, Legal & Certificates
    RegExp(r'\b(?:aadhaar|pan\s*card|driving\s*licen[cs]e|passport|voter\s*id|birth\s*certificate|degree\s*certificate)\b', caseSensitive: false),
    // 7. Transport, Tolls & Services
    RegExp(r'\b(?:toll\s*plaza|fastag|traffic\s*police|e-challan|parking\s*receipt|boarding\s*pass|flight\s*ticket|pnr)\b', caseSensitive: false),
  ];

  /// Positive medical markers confirming legitimate clinical prescription documents
  static final List<RegExp> _prescriptionConfidencePatterns = [
    RegExp(r'^\s*dr\.?\s+[a-z]', caseSensitive: false),
    RegExp(r'\b(?:doctor|physician|surgeon|consultant|specialist|practitioner|pediatrician|cardiologist|neurologist|psychiatrist|dermatologist|gynecologist|orthopedic)\b', caseSensitive: false),
    RegExp(r'\b(?:mbbs|bams|bhms|md|ms|dnb|fcps|dorl|m\.d\.|m\.b\.b\.s\.|regd?\s*(?:no)?|mmc\s*\d+|mc\s*\d+)\b', caseSensitive: false),
    RegExp(r'\b(?:clinic|hospital|dispensary|nursing\s*home|polyclinic|health\s*centre|medical\s*center|opd|ipd)\b', caseSensitive: false),
    RegExp(r'\b(?:rx|r\/x|prescription|patient|pt\.?|diagnosis|symptoms|chief\s*complaint|c\/o|h\/o|provisional\s*diagnosis|vitals|b\.?p\.?[:\s]|spo2|uhid)\b', caseSensitive: false),
    RegExp(r'\b(?:tab\.?|cap\.?|syp\.?|inj\.?|tablets?|capsules?|syrup|drops?|suspension|ointment|cream|gel|lotion)\b', caseSensitive: false),
    RegExp(r'\b(?:1-[012]-[012]|[012]-[012]-1|[012]-[012]-[012]|od|bd|bid|tid|tds|qid|qds|sos|hs|after\s*food|before\s*food|empty\s*stomach)\b', caseSensitive: false),
    RegExp(r'\b\d+(?:\.\d+)?\s*(?:mg|mcg|gm|ml|iu)\b', caseSensitive: false),
    RegExp(r'\b(?:paracetamol|pantocid|amoxicillin|dolo|crocin|sompraz|taxim|aricep|augmentin|cetirizine|azithral|ecosprin|metformin|atorvastatin|telma)\b', caseSensitive: false),
  ];

  /// Classifies whether extracted OCR lines belong to a medical prescription or an unrelated document/image.
  /// Enforces positive medical evidence verification — non-medical images are rejected automatically.
  DocumentType classifyDocument(List<String> lines) {
    if (lines.isEmpty) return DocumentType.unrecognizedDocument;

    final fullText = lines.join(' ').toLowerCase();

    bool matchesUtility = false;
    for (final pattern in _utilityBillPatterns) {
      if (pattern.hasMatch(fullText)) {
        matchesUtility = true;
        break;
      }
    }

    int nonRxMatches = 0;
    for (final pattern in _nonPrescriptionPatterns) {
      if (pattern.hasMatch(fullText)) {
        nonRxMatches++;
      }
    }

    int prescriptionMatches = 0;
    for (final pattern in _prescriptionConfidencePatterns) {
      if (pattern.hasMatch(fullText)) {
        prescriptionMatches++;
      }
    }

    // Helper to return the specific non-prescription type
    DocumentType nonPrescriptionResult() =>
        matchesUtility ? DocumentType.utilityOrTaxBill : DocumentType.nonPrescriptionDocument;

    // 1. Explicit non-prescription indicators (bills, invoices, food menus, retail, logistics, identity)
    if (nonRxMatches >= 2 && prescriptionMatches <= 1) {
      return nonPrescriptionResult();
    }

    // 2. Positive clinical verification: A document MUST contain actual medical evidence
    // (doctor title, clinic/hospital header, clinical degrees, Rx symbol, dosage notation, or intake directions).
    // If there is zero medical evidence in the text, it is NOT a prescription!
    if (prescriptionMatches == 0) {
      return nonPrescriptionResult();
    }

    // 3. If both exist, the non-prescription tokens must not overwhelm medical evidence
    if (nonRxMatches > prescriptionMatches) {
      return nonPrescriptionResult();
    }

    return DocumentType.medicalPrescription;
  }

  /// Calculates the overall readability confidence (0.0 to 1.0) of a prescription.
  /// Detects whether doctor handwriting is legible or unreadable cursive/distorted text.
  double calculatePrescriptionReadability({
    required List<PrescriptionItemCandidate> candidates,
    required List<String> rawLines,
  }) {
    if (rawLines.isEmpty) return 0.0;

    // Filter out administrative headers to evaluate medicine lines and prescription body
    final bodyLines = rawLines.where((l) => !_isAdministrativeHeader(l.trim())).toList();
    if (bodyLines.isEmpty) return 0.20;

    // 1. If medicine candidates were extracted from the lines
    if (candidates.isNotEmpty) {
      double totalScore = 0.0;
      for (final c in candidates) {
        totalScore += c.confidenceScore;
      }
      final avgCandidateScore = totalScore / candidates.length;

      // Fraction of candidates matching known catalog medicines with high confidence (>= 0.70)
      final highConfidenceCount = candidates.where((c) => c.confidenceScore >= 0.70).length;
      final highConfidenceRatio = highConfidenceCount / candidates.length;

      // If at least half the candidates have high confidence and average >= 0.65,
      // it's a clear computerized or legible prescription
      if (avgCandidateScore >= 0.65 && highConfidenceRatio >= 0.50) {
        return avgCandidateScore.clamp(0.0, 1.0);
      } else {
        // Mixed or low-confidence uncataloged handwriting
        return (avgCandidateScore * 0.7 + highConfidenceRatio * 0.3).clamp(0.15, 0.65);
      }
    }

    // 2. If no confident candidates were found, evaluate character morphology and fragmentation:
    int totalLetters = 0;
    int noiseSymbols = 0;
    int shortWords = 0;
    int totalWords = 0;

    for (final line in bodyLines) {
      final words = line.trim().split(RegExp(r'\s+'));
      for (final w in words) {
        if (w.isEmpty) continue;
        totalWords++;
        if (w.length <= 2) shortWords++;
        for (final rune in w.runes) {
          final ch = String.fromCharCode(rune);
          if (RegExp(r'[a-zA-Z0-9]').hasMatch(ch)) {
            totalLetters++;
          } else {
            noiseSymbols++;
          }
        }
      }
    }

    if (totalWords == 0) return 0.20;

    final symbolNoiseRatio = (noiseSymbols / (totalLetters + noiseSymbols + 1)).clamp(0.0, 1.0);
    final shortWordRatio = (shortWords / totalWords).clamp(0.0, 1.0);

    // High symbol noise and high short fragment ratio indicates distorted or illegible doctor cursive
    double score = 0.50 - (symbolNoiseRatio * 0.30) - (shortWordRatio * 0.20);
    return score.clamp(0.15, 0.49);
  }

  Future<PrescriptionScanResult> processPrescriptionImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _recognizer.processImage(inputImage);

    final List<String> extractedLines = [];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          extractedLines.add(text);
        }
      }
    }

    debugPrint('[PrescriptionScanner] ML Kit extracted ${extractedLines.length} lines from image');
    for (int i = 0; i < extractedLines.length; i++) {
      debugPrint('[PrescriptionScanner] [$i]: "${extractedLines[i]}"');
    }

    final docType = classifyDocument(extractedLines);
    if (docType == DocumentType.utilityOrTaxBill || docType == DocumentType.nonPrescriptionDocument) {
      debugPrint('[PrescriptionScanner] ⚠️ Scanned image detected as non-prescription ($docType)');
      final isUtility = docType == DocumentType.utilityOrTaxBill;
      return PrescriptionScanResult(
        candidates: const [],
        rawExtractedLines: extractedLines,
        documentType: docType,
        overallReadabilityScore: 0.0,
        isHandwrittenOrLowReadability: true,
        rejectionReason: isUtility
            ? 'The scanned document appears to be a utility, electricity, or tax bill, not a doctor\'s prescription. Please scan a valid medical prescription.'
            : 'The scanned photo does not appear to be a doctor\'s prescription or hospital OPD slip. Please ensure a valid medical prescription is in frame.',
      );
    }

    if (docType == DocumentType.unrecognizedDocument || extractedLines.isEmpty) {
      debugPrint('[PrescriptionScanner] ⚠️ Scanned image has no readable text');
      return PrescriptionScanResult(
        candidates: const [],
        rawExtractedLines: extractedLines,
        documentType: DocumentType.unrecognizedDocument,
        overallReadabilityScore: 0.0,
        isHandwrittenOrLowReadability: true,
        rejectionReason: 'No readable text was found in the image. Please take a clearer photo in good lighting.',
      );
    }

    final candidates = await parsePrescriptionLines(extractedLines);
    debugPrint('[PrescriptionScanner] Successfully identified ${candidates.length} medicine candidates');

    final readabilityScore = calculatePrescriptionReadability(
      candidates: candidates,
      rawLines: extractedLines,
    );
    final isLowReadability = readabilityScore < 0.50;

    return PrescriptionScanResult(
      candidates: candidates,
      rawExtractedLines: extractedLines,
      documentType: docType,
      overallReadabilityScore: readabilityScore,
      isHandwrittenOrLowReadability: isLowReadability,
    );
  }

  /// Parses and filters extracted prescription lines, matching them against the 246k Indian catalog
  Future<List<PrescriptionItemCandidate>> parsePrescriptionLines(List<String> rawLines) async {
    // 1. Merge multi-line prescription entries (e.g. Line 1: "Tab Dolo 650", Line 2: "1-0-1 x 5 days")
    final mergedLines = _mergeMultiLinePrescriptionEntries(rawLines);

    final List<PrescriptionItemCandidate> candidates = [];
    int uncatalogedId = -1;

    for (final line in mergedLines) {
      final cleanLine = line.trim();
      if (_isAdministrativeHeader(cleanLine)) continue;

      // Extract quantity and dosage instruction if present
      final parsedDosage = _parseDosageAndQuantity(cleanLine);
      final cleanedDrugName = _cleanDrugName(cleanLine);

      if (cleanedDrugName.length < 3) continue;

      // Match against SQLite FTS5 database
      final matchResult = await _findBestCatalogMatch(cleanedDrugName);

      if (matchResult != null && matchResult.score >= 0.60) {
        candidates.add(
          PrescriptionItemCandidate(
            rawLine: cleanLine,
            matchedRecord: matchResult.record,
            confidenceScore: matchResult.score.clamp(0.0, 1.0),
            quantity: parsedDosage.quantity,
            dosageInstruction: parsedDosage.instruction,
            frequency: parsedDosage.frequency,
            whenTiming: parsedDosage.whenTiming,
            mealTiming: parsedDosage.mealTiming,
            days: parsedDosage.days,
            isSelected: true,
          ),
        );
      } else if (_looksLikeMedicineEntry(cleanLine, cleanedDrugName)) {
        // Calculate true readability confidence (never hardcode 0.65)
        final calculatedConfidence = _calculateReadabilityConfidence(cleanLine, cleanedDrugName);
        candidates.add(
          PrescriptionItemCandidate(
            rawLine: cleanLine,
            matchedRecord: MedicineRecord(
              id: uncatalogedId--,
              brandName: _formatTitleCase(cleanedDrugName),
              activeSalt: 'Prescribed Formulation',
              strength: parsedDosage.strength ?? '',
              manufacturer: 'Prescription Item',
              dosageForm: parsedDosage.form ?? 'Tablet',
              commonSymptoms: const [],
            ),
            confidenceScore: calculatedConfidence,
            quantity: parsedDosage.quantity,
            dosageInstruction: parsedDosage.instruction,
            frequency: parsedDosage.frequency,
            whenTiming: parsedDosage.whenTiming,
            mealTiming: parsedDosage.mealTiming,
            days: parsedDosage.days,
            // If confidence is low (<50%), do not auto-select; require user review
            isSelected: calculatedConfidence >= 0.50,
          ),
        );
      }
    }

    // Deduplicate candidates by matched medicine record or brand name
    final Map<String, PrescriptionItemCandidate> uniqueMap = {};
    for (final c in candidates) {
      final key = c.matchedRecord.brandName.toLowerCase();
      final existing = uniqueMap[key];
      if (existing == null || c.confidenceScore > existing.confidenceScore) {
        uniqueMap[key] = c;
      }
    }

    return uniqueMap.values.toList();
  }

  /// Helper to turn any raw text line directly into a candidate (e.g. from user manual tap)
  Future<PrescriptionItemCandidate> createCandidateFromRawLine(String rawLine) async {
    final parsedDosage = _parseDosageAndQuantity(rawLine);
    final cleanedDrugName = _cleanDrugName(rawLine);
    final effectiveName = cleanedDrugName.length >= 2 ? cleanedDrugName : rawLine.trim();

    final matchResult = await _findBestCatalogMatch(effectiveName);
    if (matchResult != null && matchResult.score >= 0.60) {
      return PrescriptionItemCandidate(
        rawLine: rawLine,
        matchedRecord: matchResult.record,
        confidenceScore: matchResult.score.clamp(0.0, 1.0),
        quantity: parsedDosage.quantity,
        dosageInstruction: parsedDosage.instruction,
        frequency: parsedDosage.frequency,
        whenTiming: parsedDosage.whenTiming,
        mealTiming: parsedDosage.mealTiming,
        days: parsedDosage.days,
        isSelected: true,
      );
    }

    final calculatedConfidence = _calculateReadabilityConfidence(rawLine, effectiveName);

    return PrescriptionItemCandidate(
      rawLine: rawLine,
      matchedRecord: MedicineRecord(
        id: -DateTime.now().millisecondsSinceEpoch,
        brandName: _formatTitleCase(effectiveName),
        activeSalt: 'Prescribed Formulation',
        strength: parsedDosage.strength ?? '',
        manufacturer: 'Prescription Item',
        dosageForm: parsedDosage.form ?? 'Tablet',
        commonSymptoms: const [],
      ),
      confidenceScore: calculatedConfidence,
      quantity: parsedDosage.quantity,
      dosageInstruction: parsedDosage.instruction,
      frequency: parsedDosage.frequency,
      whenTiming: parsedDosage.whenTiming,
      mealTiming: parsedDosage.mealTiming,
      days: parsedDosage.days,
      isSelected: true,
    );
  }

  /// Merges adjacent lines where Line 1 is a drug name and Line 2 is its dosage frequency
  List<String> _mergeMultiLinePrescriptionEntries(List<String> rawLines) {
    final List<String> merged = [];
    String? pendingDrugLine;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;
      if (_isAdministrativeHeader(line)) continue;

      final isDosageOnly = _isDosageOnlyLine(line);

      if (pendingDrugLine != null) {
        if (isDosageOnly) {
          merged.add('$pendingDrugLine $line');
          pendingDrugLine = null;
          continue;
        } else {
          merged.add(pendingDrugLine);
          pendingDrugLine = null;
        }
      }

      if (_hasMedicineIndicators(line) && !isDosageOnly) {
        final parsed = _parseDosageAndQuantity(line);
        if (parsed.instruction == null) {
          pendingDrugLine = line;
        } else {
          merged.add(line);
        }
      } else {
        merged.add(line);
      }
    }

    if (pendingDrugLine != null) {
      merged.add(pendingDrugLine);
    }

    return merged;
  }

  bool _isDosageOnlyLine(String line) {
    final lower = line.toLowerCase();
    if (RegExp(r'^(?:[012]\s*[-/+\s]\s*[012]\s*[-/+\s]\s*[012]|[012]{3}|\b(?:od|bd|bid|tid|tds|qid|qds|sos|hs|stat)\b)').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^\d+\s*(?:tabs?|tablets?|caps?|days?|d)\b').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^(?:after|before|with|post|pre)\s*(?:food|meals?|breakfast|lunch|dinner)\b').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^(?:empty\s*stomach|at\s*bedtime)\b').hasMatch(lower)) {
      return true;
    }
    return false;
  }

  bool _hasMedicineIndicators(String line) {
    final lower = line.toLowerCase();
    if (RegExp(r'^(?:\d+[\.)]|rx[:.\s]|•|\*)\s*(?:tab|cap|syp|inj|drop|cream|gel|oint)\b', caseSensitive: false).hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'\b(?:tab\.?|cap\.?|syp\.?|inj\.?|tablet|capsule|syrup)\b', caseSensitive: false).hasMatch(lower)) {
      return true;
    }
    return false;
  }

  bool _looksLikeMedicineEntry(String rawLine, String cleanedName) {
    if (cleanedName.length < 3) return false;
    final lower = rawLine.toLowerCase();

    // Contains dosage form or numbering
    if (RegExp(r'\b(?:tab|tablets?|cap|capsules?|syp|syrup|inj|drops?|cream|gel|oint)\b').hasMatch(lower)) {
      return true;
    }
    // Contains strength notation
    if (RegExp(r'\b\d+(?:\.\d+)?\s*(?:mg|gm|g|mcg|ml|iu|%)\b').hasMatch(lower)) {
      return true;
    }
    // Contains dosage frequency or compact 3-digit notation
    if (RegExp(r'(?:[012]\s*[-/+\s]\s*[012]\s*[-/+\s]\s*[012]|\b[012]{3}\b|\b(?:od|bd|tid|tds|qid|sos|hs|stat)\b|days?)').hasMatch(lower)) {
      return true;
    }
    return false;
  }

  Future<({MedicineRecord record, double score})?> _findBestCatalogMatch(String cleanedName) async {
    // 1. Query FTS5 catalog
    var candidates = await _catalogRepository.searchMedicines(cleanedName, limit: 15);

    // If FTS returned empty, try querying the first word (e.g. "Dolo" from "Dolo 650")
    if (candidates.isEmpty) {
      final firstWord = cleanedName.split(RegExp(r'\s+')).first;
      if (firstWord.length >= 3) {
        candidates = await _catalogRepository.searchMedicines(firstWord, limit: 15);
      }
    }

    // Zero guessing: If FTS finds no candidates, do NOT pull random medicines from DB!
    if (candidates.isEmpty) {
      return null;
    }

    MedicineRecord? bestMatch;
    double bestScore = 0.0;
    final candidateNorm = _normalize(cleanedName);

    for (final med in candidates) {
      final brandNorm = _normalize(med.brandName);
      final saltNorm = _normalize(med.activeSalt);

      // Score against brand name
      double brandScore = candidateNorm.similarityTo(brandNorm);
      if (_allTokensMatch(brandNorm, candidateNorm)) {
        brandScore = 0.95;
      } else if (candidateNorm.contains(brandNorm) || brandNorm.contains(candidateNorm)) {
        brandScore = (brandScore + 0.90) / 2;
      }

      // Score against active salt
      double saltScore = candidateNorm.similarityTo(saltNorm);
      if (_allTokensMatch(saltNorm, candidateNorm)) {
        saltScore = 0.90;
      } else if (candidateNorm.contains(saltNorm) || saltNorm.contains(candidateNorm)) {
        saltScore = (saltScore + 0.85) / 2;
      }

      double score = brandScore > saltScore ? brandScore : saltScore;

      // Strength bonus
      final candStrength = _extractStrength(cleanedName);
      final medStrength = _extractStrength(med.strength);
      if (candStrength != null && medStrength != null && candStrength == medStrength) {
        score = (score + 0.08).clamp(0.0, 1.0);
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = med;
      }
    }

    // Require at least 60% similarity to claim a catalog match
    if (bestMatch != null && bestScore >= 0.60) {
      return (record: bestMatch, score: bestScore);
    }
    return null;
  }

  /// Calculates mathematical readability confidence for uncataloged handwritten / OCR strings.
  /// Discerns between legitimate readable medicine entries vs illegible cursive scribbles.
  double _calculateReadabilityConfidence(String rawLine, String cleanedName) {
    if (cleanedName.length < 3) return 0.20;

    // Check vowel ratio: legitimate medicine names have vowels (a, e, i, o, u, y)
    final lettersOnly = cleanedName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (lettersOnly.isEmpty) return 0.20;

    final vowelCount = lettersOnly.replaceAll(RegExp(r'[^aeiouy]'), '').length;
    final vowelRatio = vowelCount / lettersOnly.length;

    // Unreadable cursive OCR noise usually has either zero vowels ("xptqz", "lkwr") or odd repetitive letters
    if (vowelRatio < 0.15 || vowelRatio > 0.80) {
      return 0.35; // 🔴 Low Confidence - Cursive scribble / OCR noise
    }

    double confidence = 0.50; // Base score for readable uncataloged brand

    // Boost confidence if standard medical indicators exist on the line
    final lower = rawLine.toLowerCase();
    if (RegExp(r'\b(?:tab|tablets?|cap|capsules?|syp|syrup|inj|drops?)\b').hasMatch(lower)) {
      confidence += 0.10;
    }
    if (RegExp(r'\b\d+(?:\.\d+)?\s*(?:mg|gm|g|mcg|ml|iu|%)\b').hasMatch(lower)) {
      confidence += 0.10;
    }
    if (RegExp(r'(?:[012]-[012]-[012]|\b(?:od|bd|tid|tds|qid|sos)\b)').hasMatch(lower)) {
      confidence += 0.08;
    }

    return confidence.clamp(0.20, 0.75);
  }

  bool _allTokensMatch(String target, String source) {
    final targetTokens = target.split(' ').where((t) => t.length >= 3).toList();
    if (targetTokens.isEmpty) return false;
    for (final t in targetTokens) {
      if (!source.contains(t)) return false;
    }
    return true;
  }

  String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractStrength(String s) {
    final m = RegExp(r'\b(\d+(?:\.\d+)?\s*(?:mg|gm|mcg|ml|iu|%))\b', caseSensitive: false).firstMatch(s);
    return m?.group(1)?.toLowerCase().replaceAll(' ', '');
  }

  bool _isAdministrativeHeader(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.length < 3) return true;
    for (final pattern in _adminPatterns) {
      if (pattern.hasMatch(lower)) return true;
    }
    if (RegExp(r'^\d+[\/\-.]\d+[\/\-.]\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^\d+$').hasMatch(lower)) return true;
    return false;
  }

  String _cleanDrugName(String line) {
    // 1. Strip leading numbering and bullets (e.g. "1.", "2)", "•")
    var cleaned = line.replaceAll(RegExp(r'^\s*(?:\d+[\.)\s-]*|•\s*|\*\s*)+', caseSensitive: false), '');

    // 2. Strip prescription symbols ("Rx:", "Rx -", "Rx", "R/x:")
    cleaned = cleaned.replaceAll(RegExp(r'^\s*(?:rx|r\/x)[:.\s-]*', caseSensitive: false), '');

    // 3. Strip dosage forms from the beginning (e.g. "Tab.", "Cap.", "Syp.", "Inj.")
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*(?:tab\.?|tablets?|cap\.?|capsules?|syp\.?|syrups?|inj\.?|injections?|drops?|eye\s*drops?|ointment|oint|cream|gel|suspension|susp)\s*', caseSensitive: false),
      '',
    );

    // 4. Strip trailing instructions, dosage frequencies, and meal relations
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?:\b[012]\s*[-/+\s]\s*[012]\s*[-/+\s]\s*[012]\b|\b[012]{3}\b|\b(?:od|bd|bid|tid|tds|qid|qds|sos|hs|stat)\b|after\s*(?:food|meals?|breakfast|lunch|dinner)|before\s*(?:food|meals?|breakfast|lunch|dinner)|post\s*(?:food|meals?)|pre\s*(?:food|meals?)|with\s*(?:food|meals?)|empty\s*stomach|at\s*bedtime|daily|twice\s*daily|thrice\s*daily|(?:for|x)?\s*\d+\s*(?:days?|d|weeks?|wks?|months?)).*$',
        caseSensitive: false,
      ),
      '',
    );

    // 5. Strip standalone quantity notations
    cleaned = cleaned.replaceAll(RegExp(r'\b\d+\s*(?:tabs?|tablets?|caps?|capsules?|pills?|days?|d)\b', caseSensitive: false), '');

    return cleaned.trim();
  }

  ({
    int quantity,
    String? instruction,
    String? strength,
    String? form,
    String? frequency,
    String? whenTiming,
    String? mealTiming,
    int? days,
  }) _parseDosageAndQuantity(String line) {
    final lower = line.toLowerCase();
    final strength = _extractStrength(line);

    // Form detection
    String form = 'Tablet';
    if (lower.contains('cap')) form = 'Capsule';
    if (lower.contains('syp') || lower.contains('syrup')) form = 'Syrup';
    if (lower.contains('inj')) form = 'Injection';
    if (lower.contains('drop')) form = 'Drops';
    if (lower.contains('cream') || lower.contains('gel') || lower.contains('oint')) form = 'Ointment';
    if (lower.contains('inhal')) form = 'Inhaler';
    if (lower.contains('susp')) form = 'Suspension';

    final isLiquid = form != 'Tablet' && form != 'Capsule';

    // 1. Duration / Days parsing (e.g. "x 5 days", "for 14 days", "5 days", "x 7d", "for 1 week")
    int? parsedDays;
    final daysMatch = RegExp(r'\b(?:for|x)?\s*(\d+)\s*(?:days?|d)\b', caseSensitive: false).firstMatch(lower);
    if (daysMatch != null) {
      parsedDays = int.tryParse(daysMatch.group(1) ?? '');
    } else {
      final weeksMatch = RegExp(r'\b(?:for|x)?\s*(\d+)\s*(?:weeks?|wks?|wk)\b', caseSensitive: false).firstMatch(lower);
      if (weeksMatch != null) {
        final w = int.tryParse(weeksMatch.group(1) ?? '');
        if (w != null) parsedDays = w * 7;
      } else {
        final monthsMatch = RegExp(r'\b(?:for|x)?\s*(\d+)\s*(?:months?|mths?|mo)\b', caseSensitive: false).firstMatch(lower);
        if (monthsMatch != null) {
          final m = int.tryParse(monthsMatch.group(1) ?? '');
          if (m != null) parsedDays = m * 30;
        }
      }
    }

    // 2. Meal Timing parsing
    String? mealTiming;
    if (RegExp(r'\b(?:after\s*(?:food|meals?|breakfast|lunch|dinner)|post\s*(?:food|meals?|lunch|dinner)|p\.?c\.?)\b', caseSensitive: false).hasMatch(lower)) {
      mealTiming = 'After Food';
    } else if (RegExp(r'\b(?:before\s*(?:food|meals?|breakfast|lunch|dinner)|pre\s*(?:food|meals?|lunch|dinner)|empty\s*stomach|a\.?c\.?)\b', caseSensitive: false).hasMatch(lower)) {
      mealTiming = 'Before Food';
    } else if (RegExp(r'\b(?:with\s*(?:food|meals?))\b', caseSensitive: false).hasMatch(lower)) {
      mealTiming = 'With Food';
    } else if (RegExp(r'\b(?:at\s*bedtime|before\s*sleep|night\s*only|h\.?s\.?)\b', caseSensitive: false).hasMatch(lower)) {
      mealTiming = 'At Bedtime';
    }

    // 3. Explicit Quantity Check
    final explicitMatch = RegExp(r'\b(\d+)\s*(?:tabs?|tablets?|caps?|capsules?|pills?)\b', caseSensitive: false).firstMatch(lower);
    final bottleMatch = RegExp(r'\b(\d+)\s*(?:bottles?|tubes?|units?|vials?|syp)\b', caseSensitive: false).firstMatch(lower);

    // 4. Frequency Parsing (Breakfast, Lunch, Dinner)
    String? frequency;
    int morning = 0;
    int noon = 0;
    int night = 0;
    bool freqFound = false;

    // 4a. Separated 3-digit frequency: e.g. "1-0-1", "1/0/1", "1+0+1", "1 0 1"
    final sepMatch = RegExp(r'\b([012])\s*[-/+\s]\s*([012])\s*[-/+\s]\s*([012])\b').firstMatch(lower);
    if (sepMatch != null) {
      morning = int.tryParse(sepMatch.group(1)!) ?? 0;
      noon = int.tryParse(sepMatch.group(2)!) ?? 0;
      night = int.tryParse(sepMatch.group(3)!) ?? 0;
      frequency = '$morning-$noon-$night';
      freqFound = true;
    }

    // 4b. Compact 3-digit frequency: e.g. "101", "111", "001", "100", "010", "110", "011"
    if (!freqFound) {
      final compactMatch = RegExp(r'\b([012])([012])([012])\b').firstMatch(lower);
      if (compactMatch != null) {
        final m = int.tryParse(compactMatch.group(1)!) ?? 0;
        final a = int.tryParse(compactMatch.group(2)!) ?? 0;
        final n = int.tryParse(compactMatch.group(3)!) ?? 0;
        if (m + a + n > 0) {
          morning = m;
          noon = a;
          night = n;
          frequency = '$morning-$noon-$night';
          freqFound = true;
        }
      }
    }

    // 4c. Standard Latin Frequency Codes (OD, BD, TID, TDS, QID, HS, SOS, STAT)
    if (!freqFound) {
      if (RegExp(r'\b(?:od|o\.d\.|once\s*daily|once\s*a\s*day)\b', caseSensitive: false).hasMatch(lower)) {
        frequency = 'OD';
        morning = 1;
        freqFound = true;
      } else if (RegExp(r'\b(?:bd|b\.d\.|bid|b\.i\.d\.|twice\s*daily|twice\s*a\s*day)\b', caseSensitive: false).hasMatch(lower)) {
        frequency = 'BD';
        morning = 1;
        night = 1;
        freqFound = true;
      } else if (RegExp(r'\b(?:tds|t\.d\.s\.|tid|t\.i\.d\.|thrice\s*daily|thrice\s*a\s*day)\b', caseSensitive: false).hasMatch(lower)) {
        frequency = 'TDS';
        morning = 1;
        noon = 1;
        night = 1;
        freqFound = true;
      } else if (RegExp(r'\b(?:qid|q\.i\.d\.|4\s*times\s*(?:a\s*day|daily))\b', caseSensitive: false).hasMatch(lower)) {
        frequency = 'QID';
        morning = 1;
        noon = 2;
        night = 1;
        freqFound = true;
      } else if (RegExp(r'\b(?:hs|h\.s\.|night\s*only)\b', caseSensitive: false).hasMatch(lower)) {
        frequency = 'HS';
        night = 1;
        freqFound = true;
      } else if (RegExp(r'\b(?:sos|s\.o\.s\.|prn|p\.r\.n\.|as\s*needed)\b', caseSensitive: false).hasMatch(lower)) {
        frequency = 'SOS';
        freqFound = true;
      } else if (RegExp(r'\bstat\b', caseSensitive: false).hasMatch(lower)) {
        frequency = 'STAT';
        morning = 1;
        freqFound = true;
      }
    }

    // 5. When Timing Description (Breakfast, Lunch, Dinner breakdown)
    String? whenTiming;
    if (freqFound) {
      if (frequency == 'SOS') {
        whenTiming = 'As Needed';
      } else if (frequency == 'STAT') {
        whenTiming = 'Single Immediate Dose';
      } else if (morning > 0 && noon > 0 && night > 0) {
        whenTiming = 'Morning, Noon & Night';
      } else if (morning > 0 && noon == 0 && night > 0) {
        whenTiming = 'Morning & Night';
      } else if (morning > 0 && noon == 0 && night == 0) {
        whenTiming = 'Morning only';
      } else if (morning == 0 && noon > 0 && night == 0) {
        whenTiming = 'Afternoon only';
      } else if (morning == 0 && noon == 0 && night > 0) {
        whenTiming = 'Night only';
      } else if (morning > 0 && noon > 0 && night == 0) {
        whenTiming = 'Morning & Afternoon';
      } else if (morning == 0 && noon > 0 && night > 0) {
        whenTiming = 'Afternoon & Night';
      }
    }

    // 6. Quantity Calculation
    int calculatedQty = 10;
    if (explicitMatch != null) {
      calculatedQty = int.tryParse(explicitMatch.group(1) ?? '10') ?? 10;
    } else if (bottleMatch != null) {
      calculatedQty = int.tryParse(bottleMatch.group(1) ?? '1') ?? 1;
    } else if (isLiquid) {
      calculatedQty = 1; // Default to 1 bottle/tube for liquid syrups/drops/ointments
    } else {
      final dailyDoses = morning + noon + night;
      final effectiveDays = parsedDays ?? 5;
      calculatedQty = dailyDoses > 0 ? dailyDoses * effectiveDays : 10;
    }

    // 7. Human-friendly instruction formatting
    String? instruction;
    if (explicitMatch != null) {
      instruction = 'Prescribed $calculatedQty tablets';
      if (mealTiming != null) instruction = '$instruction • $mealTiming';
      if (parsedDays != null) instruction = '$instruction • $parsedDays days';
    } else if (freqFound) {
      final daysPart = parsedDays != null ? ' for $parsedDays days' : '';
      final whenPart = whenTiming != null ? ' ($whenTiming)' : '';
      final mealPart = mealTiming != null ? ' • $mealTiming' : '';
      instruction = '$frequency$daysPart$whenPart$mealPart';
    } else if (mealTiming != null || parsedDays != null) {
      instruction = [
        if (parsedDays != null) '$parsedDays days',
        ?mealTiming,
      ].join(' • ');
    }

    return (
      quantity: calculatedQty,
      instruction: instruction,
      strength: strength,
      form: form,
      frequency: frequency,
      whenTiming: whenTiming,
      mealTiming: mealTiming,
      days: parsedDays,
    );
  }

  String _formatTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  void dispose() {
    _activeRecognizer?.close();
  }
}
