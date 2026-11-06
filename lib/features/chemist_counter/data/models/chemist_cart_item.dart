class ChemistCartItem {
  final String id;
  final String brandName;
  final String activeSalt;
  final String prescribedStrength;
  final int quantityPrescribed;
  final String dosageForm;
  final double estimatedPricePerUnit;

  const ChemistCartItem({
    required this.id,
    required this.brandName,
    required this.activeSalt,
    required this.prescribedStrength,
    required this.quantityPrescribed,
    this.dosageForm = 'Tablet',
    this.estimatedPricePerUnit = 3.50, // Average Indian OTC/Rx tablet price in ₹
  });

  bool get isLiquidOrUnitItem {
    final lower = dosageForm.toLowerCase();
    return lower.contains('syrup') ||
        lower.contains('drop') ||
        lower.contains('suspension') ||
        lower.contains('liquid') ||
        lower.contains('ointment') ||
        lower.contains('cream') ||
        lower.contains('gel') ||
        lower.contains('spray') ||
        lower.contains('inhaler');
  }

  String get unitLabel {
    final lower = dosageForm.toLowerCase();
    if (lower.contains('syrup') || lower.contains('suspension') || lower.contains('liquid')) {
      return quantityPrescribed == 1 ? 'bottle' : 'bottles';
    }
    if (lower.contains('drop')) {
      return quantityPrescribed == 1 ? 'bottle' : 'bottles';
    }
    if (lower.contains('ointment') || lower.contains('cream') || lower.contains('gel')) {
      return quantityPrescribed == 1 ? 'tube' : 'tubes';
    }
    if (lower.contains('spray') || lower.contains('inhaler')) {
      return quantityPrescribed == 1 ? 'unit' : 'units';
    }
    return quantityPrescribed == 1 ? 'tablet' : 'tablets';
  }

  ChemistCartItem copyWith({
    String? id,
    String? brandName,
    String? activeSalt,
    String? prescribedStrength,
    int? quantityPrescribed,
    String? dosageForm,
    double? estimatedPricePerUnit,
  }) {
    return ChemistCartItem(
      id: id ?? this.id,
      brandName: brandName ?? this.brandName,
      activeSalt: activeSalt ?? this.activeSalt,
      prescribedStrength: prescribedStrength ?? this.prescribedStrength,
      quantityPrescribed: quantityPrescribed ?? this.quantityPrescribed,
      dosageForm: dosageForm ?? this.dosageForm,
      estimatedPricePerUnit: estimatedPricePerUnit ?? this.estimatedPricePerUnit,
    );
  }
}
