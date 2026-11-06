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

  static Widget buildBadgeWidget(ConfidenceLevel level, int percentage, {bool compact = false}) {
    final color = getBadgeColor(level);
    final bgColor = getBadgeBackgroundColor(level);

    String labelText;
    if (compact) {
      switch (level) {
        case ConfidenceLevel.high:
          labelText = '$percentage% Verified';
          break;
        case ConfidenceLevel.medium:
          labelText = '$percentage% Match';
          break;
        case ConfidenceLevel.low:
          labelText = '$percentage% Unclear';
          break;
      }
    } else {
      labelText = '$percentage% ${level.label}';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            labelText,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
