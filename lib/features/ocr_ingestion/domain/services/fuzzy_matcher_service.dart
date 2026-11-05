import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:medwise/features/ocr_ingestion/data/models/match_candidate.dart';
import 'package:medwise/features/medicine_catalog/data/models/medicine_record.dart';
import 'package:medwise/features/medicine_catalog/data/repositories/medicine_catalog_repository.dart';

final fuzzyMatcherServiceProvider = Provider<FuzzyMatcherService>((ref) {
  final repository = ref.watch(medicineCatalogRepositoryProvider);
  return FuzzyMatcherService(repository);
});

class FuzzyMatcherService {
  final MedicineCatalogRepository _catalogRepository;

  FuzzyMatcherService(this._catalogRepository);

  /// Ignore packaging boilerplate text common on Indian medicine boxes & blister packaging
  static final List<RegExp> _packagingNoisePatterns = [
    RegExp(r'\b(?:mfg|mfd|exp|expiry|b\.?no|batch\s*no|lic\s*no|m\.?r\.?p|incl|taxes)\b', caseSensitive: false),
    RegExp(r'\b(?:store\s*below|keep\s*out|reach\s*of\s*children|protect\s*from\s*light|moisture)\b', caseSensitive: false),
    RegExp(r'\b(?:marketed\s*by|manufactured\s*by|mfg\s*by|pkg\s*by|distrib|pvt\s*ltd|ltd)\b', caseSensitive: false),
    RegExp(r'\b(?:schedule\s*[hgh1]|warning\s*:|dosage\s*:|direction)\b', caseSensitive: false),
  ];

  /// Matches a collection of raw OCR text lines from blister packs/boxes against the full Indian medicines database
  /// using FTS5 querying + Dice's Coefficient bigram similarity.
  Future<List<MatchCandidate>> matchOcrLines(List<String> rawLines) async {
    if (rawLines.isEmpty) return [];

    final List<MatchCandidate> candidates = [];

    // Filter out very short lines, numbers, and packaging boilerplate
    final meaningfulLines = rawLines
        .map((line) => line.trim())
        .where((line) => line.length >= 3 && !RegExp(r'^\d+$').hasMatch(line) && !_isPackagingBoilerplate(line))
        .toList();

    for (final line in meaningfulLines) {
      final cleanedLine = _cleanPackagingLine(line);
      if (cleanedLine.length < 3) continue;

      // Query the full 246k database via FTS5 for this packaging line
      final results = await _queryFtsForLine(cleanedLine);
      final candidateNorm = _normalize(cleanedLine);

      for (final med in results) {
        final brandNorm = _normalize(med.brandName);
        final saltNorm = _normalize(med.activeSalt);

        // 1. Calculate similarity with Brand Name
        double brandScore = candidateNorm.similarityTo(brandNorm);
        if (_allTokensMatch(brandNorm, candidateNorm)) {
          brandScore = 0.95;
        } else if (candidateNorm.contains(brandNorm) || (brandNorm.length >= 4 && brandNorm.contains(candidateNorm))) {
          brandScore = (brandScore + 0.90) / 2;
        }

        // 2. Calculate similarity with Active Salt
        double saltScore = candidateNorm.similarityTo(saltNorm);
        if (_allTokensMatch(saltNorm, candidateNorm)) {
          saltScore = 0.90;
        } else if (candidateNorm.contains(saltNorm) || (saltNorm.length >= 4 && saltNorm.contains(candidateNorm))) {
          saltScore = (saltScore + 0.85) / 2;
        }

        double score = brandScore > saltScore ? brandScore : saltScore;

        // Strength bonus if strength is present on packaging
        final candStrength = _extractStrength(cleanedLine);
        final medStrength = _extractStrength(med.strength);
        if (candStrength != null && medStrength != null && candStrength == medStrength) {
          score = (score + 0.08).clamp(0.0, 1.0);
        }

        // Require at least 55% similarity to be considered a viable match candidate
        if (score >= 0.55) {
          candidates.add(MatchCandidate(
            rawText: line,
            matchedRecord: med,
            confidenceScore: score.clamp(0.0, 1.0),
          ));
        }
      }
    }

    // Sort descending by confidence score
    candidates.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

    // Deduplicate so each medicine record appears once with its highest score
    final Map<int, MatchCandidate> uniqueCandidates = {};
    for (final c in candidates) {
      if (!uniqueCandidates.containsKey(c.matchedRecord.id)) {
        uniqueCandidates[c.matchedRecord.id] = c;
      }
    }

    return uniqueCandidates.values.toList();
  }

  Future<List<MedicineRecord>> _queryFtsForLine(String cleanedLine) async {
    // 1. Try full cleaned line first
    var results = await _catalogRepository.searchMedicines(cleanedLine, limit: 10);
    if (results.isNotEmpty) return results;

    // 2. Try first significant word (e.g. "Dolo" from "Dolo 650 Tablets IP")
    final tokens = cleanedLine.split(RegExp(r'\s+')).where((t) => t.length >= 3).toList();
    if (tokens.isNotEmpty) {
      results = await _catalogRepository.searchMedicines(tokens.first, limit: 10);
      if (results.isNotEmpty) return results;
    }

    return [];
  }

  String _cleanPackagingLine(String line) {
    var cleaned = line.replaceAll(RegExp(r'[®™]'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:tablets?|capsules?|syrup|suspension|drops?|cream|gel|ointment)\s*(?:i\.?p\.?|b\.?p\.?|u\.?s\.?p\.?)?\b', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'^\s*rx\s*', caseSensitive: false), '');
    return cleaned.trim();
  }

  bool _isPackagingBoilerplate(String line) {
    final lower = line.toLowerCase();
    for (final pattern in _packagingNoisePatterns) {
      if (pattern.hasMatch(lower)) return true;
    }
    return false;
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
}
