import 'match_candidate.dart';
import '../../../medicine_catalog/data/models/medicine_record.dart';

class PrescriptionItemCandidate {
  final String rawLine;
  final MedicineRecord matchedRecord;
  final double confidenceScore;
  int quantity;
  final String? dosageInstruction;
  bool isSelected;

  PrescriptionItemCandidate({
    required this.rawLine,
    required this.matchedRecord,
    required this.confidenceScore,
    this.quantity = 10,
    this.dosageInstruction,
    this.isSelected = true,
  });

  ConfidenceLevel get level => ConfidenceLevel.fromScore(confidenceScore);
  int get confidencePercentage => (confidenceScore * 100).round();

  PrescriptionItemCandidate copyWith({
    String? rawLine,
    MedicineRecord? matchedRecord,
    double? confidenceScore,
    int? quantity,
    String? dosageInstruction,
    bool? isSelected,
  }) {
    return PrescriptionItemCandidate(
      rawLine: rawLine ?? this.rawLine,
      matchedRecord: matchedRecord ?? this.matchedRecord,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      quantity: quantity ?? this.quantity,
      dosageInstruction: dosageInstruction ?? this.dosageInstruction,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
