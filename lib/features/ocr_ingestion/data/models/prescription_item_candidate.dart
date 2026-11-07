import 'match_candidate.dart';
import '../../../medicine_catalog/data/models/medicine_record.dart';

class PrescriptionItemCandidate {
  final String rawLine;
  final MedicineRecord matchedRecord;
  final double confidenceScore;
  int quantity;
  final String? dosageInstruction;
  final String? frequency; // e.g. "1-0-1", "1-1-1", "0-0-1", "OD", "BD", "TDS"
  final String? whenTiming; // e.g. "Morning & Night", "Breakfast & Dinner"
  final String? mealTiming; // e.g. "After Food", "Before Food", "At Bedtime"
  final int? days; // e.g. 5, 7, 10, 14, 30
  bool isSelected;

  PrescriptionItemCandidate({
    required this.rawLine,
    required this.matchedRecord,
    required this.confidenceScore,
    this.quantity = 10,
    this.dosageInstruction,
    this.frequency,
    this.whenTiming,
    this.mealTiming,
    this.days,
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
    String? frequency,
    String? whenTiming,
    String? mealTiming,
    int? days,
    bool? isSelected,
  }) {
    return PrescriptionItemCandidate(
      rawLine: rawLine ?? this.rawLine,
      matchedRecord: matchedRecord ?? this.matchedRecord,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      quantity: quantity ?? this.quantity,
      dosageInstruction: dosageInstruction ?? this.dosageInstruction,
      frequency: frequency ?? this.frequency,
      whenTiming: whenTiming ?? this.whenTiming,
      mealTiming: mealTiming ?? this.mealTiming,
      days: days ?? this.days,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
