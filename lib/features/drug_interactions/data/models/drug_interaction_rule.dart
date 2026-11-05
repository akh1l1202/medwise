enum InteractionSeverity {
  critical,
  moderate,
  mild;

  static InteractionSeverity fromString(String val) {
    switch (val.toUpperCase()) {
      case 'CRITICAL':
        return InteractionSeverity.critical;
      case 'MODERATE':
        return InteractionSeverity.moderate;
      case 'MILD':
      default:
        return InteractionSeverity.mild;
    }
  }

  String get displayName {
    switch (this) {
      case InteractionSeverity.critical:
        return 'Critical Hazard';
      case InteractionSeverity.moderate:
        return 'Moderate Warning';
      case InteractionSeverity.mild:
        return 'Mild Advisory';
    }
  }
}

class DrugInteractionRule {
  final String saltA;
  final String saltB;
  final InteractionSeverity severity;
  final String effect;
  final String recommendation;

  const DrugInteractionRule({
    required this.saltA,
    required this.saltB,
    required this.severity,
    required this.effect,
    required this.recommendation,
  });

  factory DrugInteractionRule.fromJson(Map<String, dynamic> json) {
    return DrugInteractionRule(
      saltA: (json['salt_a'] as String? ?? '').trim().toLowerCase(),
      saltB: (json['salt_b'] as String? ?? '').trim().toLowerCase(),
      severity: InteractionSeverity.fromString(json['severity'] as String? ?? 'MILD'),
      effect: json['effect'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'salt_a': saltA,
      'salt_b': saltB,
      'severity': severity.name.toUpperCase(),
      'effect': effect,
      'recommendation': recommendation,
    };
  }

  /// Checks if this rule applies to the given pair of active salts.
  bool matches(String firstSalt, String secondSalt) {
    final s1 = firstSalt.toLowerCase();
    final s2 = secondSalt.toLowerCase();

    // Direct match or partial token match (e.g. "Paracetamol" in "Paracetamol 650mg")
    final matchDirect = (s1.contains(saltA) && s2.contains(saltB)) ||
        (s1.contains(saltB) && s2.contains(saltA));

    return matchDirect;
  }
}
