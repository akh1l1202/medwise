import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/drug_interaction_rule.dart';

final drugInteractionRepositoryProvider = Provider<DrugInteractionRepository>((ref) {
  return DrugInteractionRepository();
});

class DrugInteractionRepository {
  List<DrugInteractionRule>? _cachedRules;

  Future<List<DrugInteractionRule>> getRules() async {
    if (_cachedRules != null) return _cachedRules!;

    try {
      final jsonString = await rootBundle.loadString(AppConstants.drugInteractionsAssetPath);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _cachedRules = jsonList.map((e) => DrugInteractionRule.fromJson(e)).toList();
      return _cachedRules!;
    } catch (_) {
      return [];
    }
  }
}
