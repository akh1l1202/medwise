import 'dart:convert';

class FamilyProfile {
  final String id;
  final String name;
  final String relation; // 'Self', 'Parent', 'Child', 'Spouse', 'Other'
  final List<String> allergies;
  final bool isPrimary;

  const FamilyProfile({
    required this.id,
    required this.name,
    required this.relation,
    required this.allergies,
    this.isPrimary = false,
  });

  factory FamilyProfile.fromMap(Map<String, dynamic> map) {
    List<String> parsedAllergies = [];
    final rawAllergies = map['allergies'];
    if (rawAllergies is String && rawAllergies.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAllergies);
        if (decoded is List) {
          parsedAllergies = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedAllergies = rawAllergies.split(',').map((e) => e.trim()).toList();
      }
    }

    return FamilyProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      relation: map['relation'] as String,
      allergies: parsedAllergies,
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'allergies': jsonEncode(allergies),
      'is_primary': isPrimary ? 1 : 0,
    };
  }

  FamilyProfile copyWith({
    String? id,
    String? name,
    String? relation,
    List<String>? allergies,
    bool? isPrimary,
  }) {
    return FamilyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      allergies: allergies ?? this.allergies,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
