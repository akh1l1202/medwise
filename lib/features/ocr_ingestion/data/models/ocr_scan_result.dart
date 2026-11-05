import 'match_candidate.dart';

class OcrScanResult {
  final List<String> rawExtractedLines;
  final String? detectedExpiryDate;
  final MatchCandidate? bestMatch;
  final List<MatchCandidate> allCandidates;

  const OcrScanResult({
    required this.rawExtractedLines,
    this.detectedExpiryDate,
    this.bestMatch,
    this.allCandidates = const [],
  });

  bool get hasMatch => bestMatch != null;
}
