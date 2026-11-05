import 'dart:convert';
import 'package:medwise/core/constants/app_constants.dart';

class CabinetItem {
  final String id;
  final String brandName;
  final String activeSalt;
  final String strength;
  final String form; // 'Tablet', 'Capsule', 'Syrup', 'Ophthalmic Drop', etc.
  final double quantityRemaining;
  final String printedExpiry; // 'MM/YYYY'
  final DateTime? openedOnDate;
  final bool isOpened;
  final String storageLocation;
  final List<String> symptomTags;
  final String profileId;
  final DateTime createdAt;

  const CabinetItem({
    required this.id,
    required this.brandName,
    required this.activeSalt,
    required this.strength,
    required this.form,
    required this.quantityRemaining,
    required this.printedExpiry,
    this.openedOnDate,
    this.isOpened = false,
    this.storageLocation = 'Medicine Drawer',
    this.symptomTags = const [],
    required this.profileId,
    required this.createdAt,
  });

  bool get isLiquidOrDrop =>
      form.toLowerCase().contains('drop') ||
      form.toLowerCase().contains('syrup') ||
      form.toLowerCase().contains('suspension') ||
      form.toLowerCase().contains('liquid');

  /// Safe 28-day countdown for opened drops & syrups
  int? get openedDaysRemaining {
    if (!isOpened || openedOnDate == null) return null;
    final daysElapsed = DateTime.now().difference(openedOnDate!).inDays;
    final remaining = AppConstants.openSterilityDaysLimit - daysElapsed;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isSterilityExpired {
    final daysLeft = openedDaysRemaining;
    return daysLeft != null && daysLeft <= 0;
  }

  /// Check whether printed expiry has passed
  bool get isPrintedExpired {
    try {
      final parts = printedExpiry.split('/');
      if (parts.length == 2) {
        final month = int.parse(parts[0]);
        var year = int.parse(parts[1]);
        if (year < 100) year += 2000;
        final expiryDate = DateTime(year, month + 1, 0, 23, 59, 59);
        return DateTime.now().isAfter(expiryDate);
      }
    } catch (_) {}
    return false;
  }

  bool get isExpired => isPrintedExpired || isSterilityExpired;

  bool get isLowStock => quantityRemaining <= 2.0;

  factory CabinetItem.fromMap(Map<String, dynamic> map) {
    List<String> tags = [];
    final rawTags = map['symptom_tags'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          tags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        tags = rawTags.split(',').map((e) => e.trim()).toList();
      }
    }

    return CabinetItem(
      id: map['id'] as String,
      brandName: map['brand_name'] as String,
      activeSalt: map['active_salt'] as String,
      strength: map['strength'] as String? ?? '',
      form: map['form'] as String? ?? 'Tablet',
      quantityRemaining: (map['quantity_remaining'] as num).toDouble(),
      printedExpiry: map['printed_expiry'] as String,
      openedOnDate: map['opened_on_date'] != null
          ? DateTime.tryParse(map['opened_on_date'] as String)
          : null,
      isOpened: (map['is_opened'] as int? ?? 0) == 1,
      storageLocation: map['storage_location'] as String? ?? 'Medicine Drawer',
      symptomTags: tags,
      profileId: map['profile_id'] as String,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand_name': brandName,
      'active_salt': activeSalt,
      'strength': strength,
      'form': form,
      'quantity_remaining': quantityRemaining,
      'printed_expiry': printedExpiry,
      'opened_on_date': openedOnDate?.toIso8601String(),
      'is_opened': isOpened ? 1 : 0,
      'storage_location': storageLocation,
      'symptom_tags': jsonEncode(symptomTags),
      'profile_id': profileId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CabinetItem copyWith({
    String? id,
    String? brandName,
    String? activeSalt,
    String? strength,
    String? form,
    double? quantityRemaining,
    String? printedExpiry,
    DateTime? openedOnDate,
    bool? isOpened,
    String? storageLocation,
    List<String>? symptomTags,
    String? profileId,
    DateTime? createdAt,
  }) {
    return CabinetItem(
      id: id ?? this.id,
      brandName: brandName ?? this.brandName,
      activeSalt: activeSalt ?? this.activeSalt,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      quantityRemaining: quantityRemaining ?? this.quantityRemaining,
      printedExpiry: printedExpiry ?? this.printedExpiry,
      openedOnDate: openedOnDate ?? this.openedOnDate,
      isOpened: isOpened ?? this.isOpened,
      storageLocation: storageLocation ?? this.storageLocation,
      symptomTags: symptomTags ?? this.symptomTags,
      profileId: profileId ?? this.profileId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
