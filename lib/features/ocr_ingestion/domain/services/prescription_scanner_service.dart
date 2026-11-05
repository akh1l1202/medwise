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

  /// Patterns indicating non-prescription documents (e.g. electricity, gas, water, or appliance bills)
  static final List<RegExp> _billPatterns = [
    RegExp(r'\b(?:bill\s*of\s*supply|tax\s*invoice|retail\s*invoice|receipt)\b', caseSensitive: false),
    RegExp(r'\b(?:electricity|power|gas\s*bill|water\s*bill|property\s*tax)\b', caseSensitive: false),
    RegExp(r'\b(?:consumer\s*(?:no|number|id)|ca\s*no|k\s*no|meter\s*(?:no|number|reading))\b', caseSensitive: false),
    RegExp(r'\b(?:kwh|kva|connected\s*load|contract\s*demand|tariff)\b', caseSensitive: false),
    RegExp(r'\b(?:discom|mngl|igcl|mahadiscom|tata\s*power|adani\s*electricity|bses)\b', caseSensitive: false),
    RegExp(r'\b(?:municipal\s*corporation|ward\s*office|nagar\s*nigam|gram\s*panchayat)\b', caseSensitive: false),
    RegExp(r'\b(?:gstin|gst\s*no|service\s*tax|cin\s*no)\b', caseSensitive: false),
    RegExp(r'\b(?:total\s*amount\s*payable|due\s*date|billing\s*unit|prompt\s*payment)\b', caseSensitive: false),
    RegExp(r'\b(?:authorised\s*service\s*center|service\s*centre|appliance|product\s*query)\b', caseSensitive: false),
  ];

  /// Positive medical markers confirming legitimate clinical prescription documents
  static final List<RegExp> _prescriptionConfidencePatterns = [
    RegExp(r'^\s*dr\.?\s+[a-z]', caseSensitive: false),
    RegExp(r'\b(?:doctor|physician|surgeon|consultant|clinic|hospital|dispensary|nursing\s*home)\b', caseSensitive: false),
    RegExp(r'\b(?:mbbs|bams|bhms|md|ms|dnb|fcps|dorl|m\.d\.|m\.b\.b\.s\.)\b', caseSensitive: false),
    RegExp(r'\b(?:rx|r\/x|patient|pt\.?|diagnosis|symptoms|chief\s*complaint)\b', caseSensitive: false),
    RegExp(r'\b(?:tab\.?|cap\.?|syp\.?|tablets?|capsules?|syrup|dosage|after\s*food|before\s*food)\b', caseSensitive: false),
    RegExp(r'\b(?:1-[012]-[012]|[012]-[012]-1|od|bd|bid|tid|tds|qid|sos|hs)\b', caseSensitive: false),
  ];

  /// Classifies whether extracted OCR lines belong to a medical prescription or an unrelated bill/invoice
  DocumentType classifyDocument(List<String> lines) {
    if (lines.isEmpty) return DocumentType.unrecognizedDocument;

    final fullText = lines.join(' ').toLowerCase();

    int billMatches = 0;
    for (final pattern in _billPatterns) {
      if (pattern.hasMatch(fullText)) {
        billMatches++;
      }
    }

    int prescriptionMatches = 0;
    for (final pattern in _prescriptionConfidencePatterns) {
      if (pattern.hasMatch(fullText)) {
        prescriptionMatches++;
      }
    }

    // If 2 or more strong bill indicators are present and medical indicators are sparse (<= 1),
    // classify as a non-prescription utility/tax bill
    if (billMatches >= 2 && prescriptionMatches <= 1) {
      return DocumentType.utilityOrTaxBill;
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
    if (docType == DocumentType.utilityOrTaxBill) {
      debugPrint('[PrescriptionScanner] ⚠️ Scanned image detected as non-prescription (utility/tax bill)');
      return PrescriptionScanResult(
        candidates: const [],
        rawExtractedLines: extractedLines,
        documentType: DocumentType.utilityOrTaxBill,
        overallReadabilityScore: 0.0,
        isHandwrittenOrLowReadability: true,
        rejectionReason: 'The scanned document appears to be a utility, electricity, or tax bill, not a doctor\'s prescription. Please scan a valid medical prescription.',
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
    if (RegExp(r'^(?:1-[012]-[012]|[012]-[012]-1|[012]-[012]-[012]|\b(?:od|bd|bid|tid|tds|qid|qds|sos|hs)\b)').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^\d+\s*(?:tabs?|tablets?|caps?|days?)\b').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^(?:after\s*food|before\s*food|with\s*food|empty\s*stomach)\b').hasMatch(lower)) {
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
    // Contains dosage frequency
    if (RegExp(r'(?:[012]-[012]-[012]|\b(?:od|bd|tid|tds|qid|sos|hs)\b|days?)').hasMatch(lower)) {
      return true;
    }
    // Starts with list numbering (e.g. "1.", "2)")
    if (RegExp(r'^\s*\d+[\.)]').hasMatch(rawLine)) {
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

    // 4. Strip trailing instructions and dosage frequencies
    cleaned = cleaned.replaceAll(
      RegExp(r'(?:1-[012]-[012]|[012]-[012]-1|[012]-[012]-[012]|\b(?:od|bd|bid|tid|tds|qid|qds|sos|hs)\b|after\s*food|before\s*food|with\s*food|empty\s*stomach|daily|thrice\s*daily|twice\s*daily|for\s*\d+\s*days?|x\s*\d+\s*days?).*$', caseSensitive: false),
      '',
    );

    // 5. Strip standalone quantity notations
    cleaned = cleaned.replaceAll(RegExp(r'\b\d+\s*(?:tabs?|tablets?|caps?|capsules?|pills?|days?)\b', caseSensitive: false), '');

    return cleaned.trim();
  }

  ({int quantity, String? instruction, String? strength, String? form}) _parseDosageAndQuantity(String line) {
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

    // 1. Explicit quantity: "10 tabs", "15 tablets", "10 caps"
    final explicitMatch = RegExp(r'(\d+)\s*(?:tabs?|tablets?|caps?|capsules?|pills?)', caseSensitive: false).firstMatch(lower);
    if (explicitMatch != null) {
      final qty = int.tryParse(explicitMatch.group(1) ?? '10') ?? 10;
      return (quantity: qty, instruction: 'Prescribed $qty tablets', strength: strength, form: form);
    }

    // 2. Frequency with days: "1-0-1 x 5 days", "1-0-1 for 5 days"
    final freqDaysMatch = RegExp(r'([012])-([012])-([012])\s*(?:x|for)?\s*(\d+)\s*days?', caseSensitive: false).firstMatch(lower);
    if (freqDaysMatch != null) {
      final morning = int.tryParse(freqDaysMatch.group(1) ?? '0') ?? 0;
      final noon = int.tryParse(freqDaysMatch.group(2) ?? '0') ?? 0;
      final night = int.tryParse(freqDaysMatch.group(3) ?? '0') ?? 0;
      final days = int.tryParse(freqDaysMatch.group(4) ?? '5') ?? 5;
      final dailyTotal = morning + noon + night;
      final calculatedQty = dailyTotal > 0 ? dailyTotal * days : 10;
      return (
        quantity: calculatedQty,
        instruction: '${freqDaysMatch.group(1)}-${freqDaysMatch.group(2)}-${freqDaysMatch.group(3)} for $days days ($calculatedQty total)',
        strength: strength,
        form: form,
      );
    }

    // 3. Standalone frequency: "1-0-1" (default 5 days)
    final standaloneFreq = RegExp(r'([012])-([012])-([012])').firstMatch(lower);
    if (standaloneFreq != null) {
      final morning = int.tryParse(standaloneFreq.group(1) ?? '0') ?? 0;
      final noon = int.tryParse(standaloneFreq.group(2) ?? '0') ?? 0;
      final night = int.tryParse(standaloneFreq.group(3) ?? '0') ?? 0;
      final dailyTotal = morning + noon + night;
      final defaultDays = 5;
      final calculatedQty = dailyTotal > 0 ? dailyTotal * defaultDays : 10;
      return (
        quantity: calculatedQty,
        instruction: '${standaloneFreq.group(0)} (5 days standard)',
        strength: strength,
        form: form,
      );
    }

    // 4. BD/OD/TDS/TID/QID notation: e.g. "TDS x 5 days" or "BD x 5 days"
    final codeDaysMatch = RegExp(r'\b(od|bd|bid|tid|tds|qid)\b\s*(?:x|for)?\s*(\d+)\s*days?', caseSensitive: false).firstMatch(lower);
    if (codeDaysMatch != null) {
      final code = codeDaysMatch.group(1)!.toLowerCase();
      final days = int.tryParse(codeDaysMatch.group(2) ?? '5') ?? 5;
      int perDay = 1;
      if (code == 'bd' || code == 'bid') perDay = 2;
      if (code == 'tid' || code == 'tds') perDay = 3;
      if (code == 'qid') perDay = 4;
      return (
        quantity: perDay * days,
        instruction: '${code.toUpperCase()} for $days days (${perDay * days} total)',
        strength: strength,
        form: form,
      );
    }

    return (quantity: 10, instruction: null, strength: strength, form: form);
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
