class MedicineRecord {
  final int id;
  final String brandName;
  final String activeSalt;
  final String strength;
  final String manufacturer;
  final String dosageForm;
  final List<String> commonSymptoms;

  const MedicineRecord({
    required this.id,
    required this.brandName,
    required this.activeSalt,
    required this.strength,
    required this.manufacturer,
    required this.dosageForm,
    required this.commonSymptoms,
  });

  factory MedicineRecord.fromMap(Map<String, dynamic> map) {
    final symptomsRaw = map['common_symptoms'] as String? ?? '';
    final symptoms = symptomsRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return MedicineRecord(
      id: map['id'] as int? ?? 0,
      brandName: map['brand_name'] as String? ?? '',
      activeSalt: map['active_salt'] as String? ?? '',
      strength: map['strength'] as String? ?? '',
      manufacturer: map['manufacturer'] as String? ?? '',
      dosageForm: map['dosage_form'] as String? ?? 'Tablet',
      commonSymptoms: symptoms,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand_name': brandName,
      'active_salt': activeSalt,
      'strength': strength,
      'manufacturer': manufacturer,
      'dosage_form': dosageForm,
      'common_symptoms': commonSymptoms.join(', '),
    };
  }

  MedicineRecord copyWith({
    int? id,
    String? brandName,
    String? activeSalt,
    String? strength,
    String? manufacturer,
    String? dosageForm,
    List<String>? commonSymptoms,
  }) {
    return MedicineRecord(
      id: id ?? this.id,
      brandName: brandName ?? this.brandName,
      activeSalt: activeSalt ?? this.activeSalt,
      strength: strength ?? this.strength,
      manufacturer: manufacturer ?? this.manufacturer,
      dosageForm: dosageForm ?? this.dosageForm,
      commonSymptoms: commonSymptoms ?? this.commonSymptoms,
    );
  }

  @override
  String toString() => '$brandName ($activeSalt - $strength)';
}
