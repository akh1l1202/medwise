import 'package:flutter/material.dart';
import 'package:medwise/core/constants/app_colors.dart';
import 'package:medwise/features/ocr_ingestion/data/models/match_candidate.dart';

class ConfidenceBadgeUtils {
  ConfidenceBadgeUtils._();

  static Color getBadgeColor(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.high:
        return AppColors.safe;
      case ConfidenceLevel.medium:
        return AppColors.warning;
      case ConfidenceLevel.low:
        return AppColors.danger;
    }
  }

  static Color getBadgeBackgroundColor(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.high:
        return AppColors.safeSurface;
      case ConfidenceLevel.medium:
        return AppColors.warningSurface;
      case ConfidenceLevel.low:
        return AppColors.dangerSurface;
    }
  }

  static Widget buildBadgeWidget(ConfidenceLevel level, int percentage) {
    final color = getBadgeColor(level);
    final bgColor = getBadgeBackgroundColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$percentage% ${level.label}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
