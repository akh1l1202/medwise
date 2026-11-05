import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/cabinet_item.dart';
import '../../domain/services/expiry_calculator_service.dart';

class MedicineCard extends StatelessWidget {
  final CabinetItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MedicineCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  IconData _getFormIcon(String form) {
    final lower = form.toLowerCase();
    if (lower.contains('drop')) return Icons.water_drop_outlined;
    if (lower.contains('syrup') || lower.contains('suspension') || lower.contains('liquid')) {
      return Icons.liquor_outlined;
    }
    if (lower.contains('capsule')) return Icons.medication_liquid_outlined;
    if (lower.contains('ointment') || lower.contains('cream') || lower.contains('gel')) {
      return Icons.clean_hands_outlined;
    }
    if (lower.contains('spray') || lower.contains('inhaler')) return Icons.air_outlined;
    return Icons.medication_outlined; // Default Tablet
  }

  @override
  Widget build(BuildContext context) {
    const expiryCalculator = ExpiryCalculatorService();
    final expiryStatus = expiryCalculator.getStatus(item);
    final isLowStock = item.isLowStock;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: item.isExpired
                ? AppColors.dangerBorder
                : isLowStock
                    ? AppColors.warningBorder
                    : AppColors.border,
            width: item.isExpired || isLowStock ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dosage form icon container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.isExpired
                            ? AppColors.dangerSurface
                            : AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getFormIcon(item.form),
                        color: item.isExpired ? AppColors.danger : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Medicine Title & Active Salt
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.brandName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.activeSalt} • ${item.strength}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Quantity Remaining Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLowStock ? AppColors.dangerSurface : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLowStock ? AppColors.dangerBorder : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${item.quantityRemaining.toStringAsFixed(item.quantityRemaining.truncateToDouble() == item.quantityRemaining ? 0 : 1)} left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isLowStock ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                // Footer Badges: Expiry & Location
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dual Expiry Badge
                    _buildExpiryBadge(expiryStatus),
                    // Physical Storage Location Tag
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          item.storageLocation,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryBadge(ExpiryStatus status) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status) {
      case ExpiryStatus.sterilityBreached:
        bg = AppColors.dangerSurface;
        text = AppColors.danger;
        icon = Icons.warning_amber_rounded;
        label = 'Sterility Breached (28d)';
        break;
      case ExpiryStatus.expired:
        bg = AppColors.dangerSurface;
        text = AppColors.danger;
        icon = Icons.cancel_outlined;
        label = 'Expired (${item.printedExpiry})';
        break;
      case ExpiryStatus.expiringSoon:
        bg = AppColors.warningSurface;
        text = AppColors.warning;
        icon = Icons.access_time_outlined;
        label = 'Expiring Soon (${item.printedExpiry})';
        break;
      case ExpiryStatus.active:
        if (item.isOpened && item.openedDaysRemaining != null) {
          bg = AppColors.primarySurface;
          text = AppColors.primaryDark;
          icon = Icons.hourglass_top_outlined;
          label = '${item.openedDaysRemaining}d safe sterility left';
        } else {
          bg = AppColors.surfaceVariant;
          text = AppColors.textSecondary;
          icon = Icons.calendar_today_outlined;
          label = 'Exp: ${item.printedExpiry}';
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
