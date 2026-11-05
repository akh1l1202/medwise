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
