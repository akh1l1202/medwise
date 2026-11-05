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
    final detectedBatch = extractBatchNumber(lines);
    final candidates = await _fuzzyMatcher.matchOcrLines(lines);

    return OcrScanResult(
      rawExtractedLines: lines,
      detectedExpiryDate: detectedExpiry,
      detectedBatchNumber: detectedBatch,
      bestMatch: candidates.isNotEmpty ? candidates.first : null,
      allCandidates: candidates,
    );
  }

  /// Extracts expiry date using regex patterns common on Indian medicine foils & boxes.
  /// Handles:
  /// - Textual months: "EXP. MAY 2027", "EXP: AUG/26", "EXPIRY: MAR-2028"
  /// - Standard numeric: "EXP. 08/2026", "EXP: 08/26", "EXP.DT. 11/2025"
  /// - Multi-line packaging: Chronological resolution picking latest date when MFG & EXP co-occur
  /// Returns `null` if no legitimate expiry date is identified (no static defaults).
  String? extractExpiryDate(List<String> lines) {
    const monthMap = {
      'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
      'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
      'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
    };

    // Pattern 1: Explicit textual month with EXP prefix e.g. "EXP. MAY 2027", "EXP: AUG/26", "EXPIRY: MAR-2028"
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

    // Pattern 2: Explicit numeric month with EXP prefix e.g. "EXP. 08/2026", "EXP: 08/26"
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

    // Pattern 3: Chronological multi-date detection for header-separated layouts
    // Collect all candidate dates across all lines, parsing both textual and numeric formats
    final List<({int year, int month, String formatted})> collectedDates = [];

    final generalTextMonth = RegExp(
      r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[\/\-.\s]+(20[2-3]\d|[2-3]\d)\b',
      caseSensitive: false,
    );
    final generalNumeric = RegExp(r'\b(0[1-9]|1[0-2])[\/\-.](20[2-3]\d|[2-3]\d)\b');

    for (final line in lines) {
      final lower = line.toLowerCase();
      final isMfgLine = lower.contains('mfd') ||
          lower.contains('mfg') ||
          lower.contains('pkd') ||
          lower.contains('packed') ||
          lower.contains('manufactur');

      if (isMfgLine) continue;

      for (final m in generalTextMonth.allMatches(line)) {
        final mStr = m.group(1)!.toLowerCase();
        final mNum = int.tryParse(monthMap[mStr] ?? '01') ?? 1;
        var yStr = m.group(2)!;
        if (yStr.length == 2) yStr = '20$yStr';
        final yInt = int.tryParse(yStr) ?? 2026;
        collectedDates.add((year: yInt, month: mNum, formatted: '${monthMap[mStr]}/$yStr'));
      }

      for (final m in generalNumeric.allMatches(line)) {
        final mNum = int.tryParse(m.group(1)!) ?? 1;
        var yStr = m.group(2)!;
        if (yStr.length == 2) yStr = '20$yStr';
        final yInt = int.tryParse(yStr) ?? 2026;
        collectedDates.add((year: yInt, month: mNum, formatted: '${m.group(1)!}/$yStr'));
      }
    }

    if (collectedDates.isNotEmpty) {
      // Sort chronologically ascending; the latest date is the Expiry Date (MFG date is earlier)
      collectedDates.sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        return a.month.compareTo(b.month);
      });
      return collectedDates.last.formatted;
    }

    // Zero guessing: return null if not detected
    return null;
  }

  /// Extracts the medicine batch number from blister packaging lines (e.g. "B.NO.SBO0150A", "B.No. 0225", "Batch No: TN-9874A")
  String? extractBatchNumber(List<String> lines) {
    final batchRegex = RegExp(
      r'\b(?:b\.?\s*no\.?|batch\s*(?:no\.?)?|lot\s*(?:no\.?)?)[:.\s]*([a-zA-Z0-9\/\-]{3,})',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final match = batchRegex.firstMatch(line);
      if (match != null) {
        final val = match.group(1)!.trim();
        if (!RegExp(r'^(?:mfg|exp|mrp|rs|date|per)\b', caseSensitive: false).hasMatch(val)) {
          return val;
        }
      }

      // Check multi-line header (e.g. Line i: "B.No., MFG.Dt.", Line i+1: "2501750 JUL.2025")
      if (RegExp(r'\b(?:b\.?\s*no\.?|batch\s*(?:no\.?)?)\b', caseSensitive: false).hasMatch(line) &&
          i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        final matchNext = RegExp(r'^([a-zA-Z0-9\/\-]{4,})').firstMatch(nextLine);
        if (matchNext != null) {
          final candidate = matchNext.group(1)!;
          if (!RegExp(r'\b(?:mfg|exp|date|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b', caseSensitive: false)
              .hasMatch(candidate)) {
            return candidate;
          }
        }
      }
    }
    return null;
  }

  void dispose() {
    _activeRecognizer?.close();
  }
}
