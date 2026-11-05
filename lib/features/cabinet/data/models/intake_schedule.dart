class IntakeSchedule {
  final String id;
  final String cabinetItemId;
  final String profileId;
  final String timeOfDay; // '08:00', '13:00', '20:30'
  final String mealRelation; // 'BEFORE_FOOD', 'AFTER_FOOD', 'WITH_FOOD'
  final double doseAmount; // 1.0, 0.5, etc.
  final bool isAntibiotic;
  final int? courseTotalDays;
  final int? courseCurrentDay;

  const IntakeSchedule({
    required this.id,
    required this.cabinetItemId,
    required this.profileId,
    required this.timeOfDay,
    this.mealRelation = 'AFTER_FOOD',
    this.doseAmount = 1.0,
    this.isAntibiotic = false,
    this.courseTotalDays,
    this.courseCurrentDay,
  });

  String get antibioticProgressLabel {
    if (!isAntibiotic || courseTotalDays == null || courseCurrentDay == null) {
      return '';
    }
    return 'Day $courseCurrentDay of $courseTotalDays';
  }

  factory IntakeSchedule.fromMap(Map<String, dynamic> map) {
    return IntakeSchedule(
      id: map['id'] as String,
      cabinetItemId: map['cabinet_item_id'] as String,
      profileId: map['profile_id'] as String,
      timeOfDay: map['time_of_day'] as String,
      mealRelation: map['meal_relation'] as String? ?? 'AFTER_FOOD',
      doseAmount: (map['dose_amount'] as num?)?.toDouble() ?? 1.0,
      isAntibiotic: (map['is_antibiotic'] as int? ?? 0) == 1,
      courseTotalDays: map['course_total_days'] as int?,
      courseCurrentDay: map['course_current_day'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cabinet_item_id': cabinetItemId,
      'profile_id': profileId,
      'time_of_day': timeOfDay,
      'meal_relation': mealRelation,
      'dose_amount': doseAmount,
      'is_antibiotic': isAntibiotic ? 1 : 0,
      'course_total_days': courseTotalDays,
      'course_current_day': courseCurrentDay,
    };
  }

  IntakeSchedule copyWith({
    String? id,
    String? cabinetItemId,
    String? profileId,
    String? timeOfDay,
    String? mealRelation,
    double? doseAmount,
    bool? isAntibiotic,
    int? courseTotalDays,
    int? courseCurrentDay,
  }) {
    return IntakeSchedule(
      id: id ?? this.id,
      cabinetItemId: cabinetItemId ?? this.cabinetItemId,
      profileId: profileId ?? this.profileId,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      mealRelation: mealRelation ?? this.mealRelation,
      doseAmount: doseAmount ?? this.doseAmount,
      isAntibiotic: isAntibiotic ?? this.isAntibiotic,
      courseTotalDays: courseTotalDays ?? this.courseTotalDays,
      courseCurrentDay: courseCurrentDay ?? this.courseCurrentDay,
    );
  }
}
