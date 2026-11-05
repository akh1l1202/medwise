import '../../../../core/constants/app_constants.dart';
import '../../../medicine_catalog/data/models/medicine_record.dart';

enum ConfidenceLevel {
  high,   // >= 0.90 (Green)
  medium, // 0.70 - 0.89 (Amber)
  low;    // < 0.70 (Red)

  static ConfidenceLevel fromScore(double score) {
    if (score >= AppConstants.confidenceHighThreshold) return ConfidenceLevel.high;
    if (score >= AppConstants.confidenceMediumThreshold) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  String get label {
    switch (this) {
      case ConfidenceLevel.high:
        return 'Direct Match';
      case ConfidenceLevel.medium:
        return 'Suggested Match';
      case ConfidenceLevel.low:
        return 'Low Confidence / Manual Review';
    }
  }
}

class MatchCandidate {
  final String rawText;
  final MedicineRecord matchedRecord;
  final double confidenceScore;

  const MatchCandidate({
    required this.rawText,
    required this.matchedRecord,
    required this.confidenceScore,
  });

  ConfidenceLevel get level => ConfidenceLevel.fromScore(confidenceScore);

  int get confidencePercentage => (confidenceScore * 100).round();
}
