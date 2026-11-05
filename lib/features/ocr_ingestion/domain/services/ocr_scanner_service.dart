import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:medwise/features/ocr_ingestion/data/models/ocr_scan_result.dart';
import 'package:medwise/features/ocr_ingestion/domain/services/fuzzy_matcher_service.dart';

final ocrScannerServiceProvider = Provider<OcrScannerService>((ref) {
  final fuzzyMatcher = ref.watch(fuzzyMatcherServiceProvider);
  return OcrScannerService(fuzzyMatcher);
});

class OcrScannerService {
  final FuzzyMatcherService _fuzzyMatcher;
  final TextRecognizer? _customRecognizer;

  OcrScannerService(this._fuzzyMatcher, {TextRecognizer? recognizer})
      : _customRecognizer = recognizer;

  TextRecognizer? _activeRecognizer;
  TextRecognizer get _recognizer =>
      _activeRecognizer ??= (_customRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin));

  Future<OcrScanResult> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _recognizer.processImage(inputImage);

    final List<String> lines = [];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }

    final detectedExpiry = extractExpiryDate(lines);
    final candidates = await _fuzzyMatcher.matchOcrLines(lines);

    return OcrScanResult(
      rawExtractedLines: lines,
      detectedExpiryDate: detectedExpiry,
      bestMatch: candidates.isNotEmpty ? candidates.first : null,
      allCandidates: candidates,
    );
  }

  /// Extracts expiry date using regex patterns common on Indian medicine foils & boxes.
  /// Handles:
  /// - Textual months: "EXP. MAY 2027", "EXP: AUG/26", "EXPIRY: MAR-2028"
  /// - Standard numeric: "EXP. 08/2026", "EXP: 08/26", "EXP.DT. 11/2025"
  /// - Full dates: "EXP. 25/08/2026", "EXP DATE 01-12-27"
  /// Returns `null` if no legitimate expiry date is identified (no static defaults).
  String? extractExpiryDate(List<String> lines) {
    const monthMap = {
      'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
      'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
      'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
    };

    // Pattern 1: Textual month e.g. "EXP. MAY 2027", "EXP: AUG/26", "EXPIRY: MAR-2028"
    final textMonthRegex = RegExp(
      r'(?:exp|expiry|exp\.?\s*dt|use\s*before|best\s*before)[:.\s]*'
      r'(?:\d{1,2}[\/\-.\s]+)?' // Optional day e.g. "25 "
      r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)'
      r'[\/\-.\s]*'
      r'(\d{2,4})',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = textMonthRegex.firstMatch(line);
      if (match != null) {
        final monthStr = match.group(1)!.toLowerCase();
        final monthNum = monthMap[monthStr] ?? '01';
        var year = match.group(2)!;
        if (year.length == 2) year = '20$year';
        return '$monthNum/$year';
      }
    }

    // Pattern 2: Explicit prefix with numeric month e.g. "EXP. 08/2026", "EXP: 08/26"
    final expNumericRegex = RegExp(
      r'(?:exp|expiry|exp\.?\s*dt|use\s*before|best\s*before)[:.\s]*'
      r'(?:\d{1,2}[\/\-.\s]+)?' // Optional day e.g. "25/"
      r'([0-1]?[0-9])[\/\-.\s]+(\d{2,4})',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = expNumericRegex.firstMatch(line);
      if (match != null) {
        final month = match.group(1)!.padLeft(2, '0');
        final mInt = int.tryParse(month) ?? 0;
        if (mInt >= 1 && mInt <= 12) {
          var year = match.group(2)!;
          if (year.length == 2) year = '20$year';
          return '$month/$year';
        }
      }
    }

    // Pattern 3: Standalone MM/YYYY or MM/YY (ignore lines indicating manufacturing/packaging dates)
    final standaloneDateRegex = RegExp(r'\b(0[1-9]|1[0-2])[\/\-.](20[2-3]\d|[2-3]\d)\b');
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('mfd') ||
          lower.contains('mfg') ||
          lower.contains('pkd') ||
          lower.contains('packed') ||
          lower.contains('manufactur')) {
        continue;
      }
      final match = standaloneDateRegex.firstMatch(line);
      if (match != null) {
        final month = match.group(1)!;
        var year = match.group(2)!;
        if (year.length == 2) year = '20$year';
        return '$month/$year';
      }
    }

    // Zero guessing: return null if not detected
    return null;
  }

  void dispose() {
    _activeRecognizer?.close();
  }
}
