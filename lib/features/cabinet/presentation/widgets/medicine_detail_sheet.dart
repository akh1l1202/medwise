import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/cabinet_item.dart';

class MedicineDetailSheet extends StatefulWidget {
  final CabinetItem item;
  final Function(CabinetItem) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onMarkOpenedToday;

  const MedicineDetailSheet({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onDelete,
    required this.onMarkOpenedToday,
  });

  @override
  State<MedicineDetailSheet> createState() => _MedicineDetailSheetState();
}

class _MedicineDetailSheetState extends State<MedicineDetailSheet> {
  late double _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantityRemaining;
  }

  void _adjustQuantity(double delta) {
    setState(() {
      _quantity = (_quantity + delta).clamp(0.0, 999.0);
    });
    widget.onUpdate(widget.item.copyWith(quantityRemaining: _quantity));
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Brand Title & Form
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.brandName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.item.activeSalt} (${widget.item.strength})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Quantity Stepper Tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remaining Quantity',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${_quantity.toStringAsFixed(_quantity.truncateToDouble() == _quantity ? 0 : 1)} ${widget.item.form.toLowerCase()}s',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove),
                      onPressed: _quantity > 0 ? () => _adjustQuantity(-1.0) : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      onPressed: () => _adjustQuantity(1.0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Storage location & Printed Expiry
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  title: 'Storage Location',
                  content: widget.item.storageLocation,
                  icon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  title: 'Printed Expiry',
                  content: widget.item.printedExpiry,
                  icon: Icons.calendar_month_outlined,
                  isWarning: widget.item.isPrintedExpired,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // "Opened-On" 28-day Sterility Clock (For liquids / drops)
          if (widget.item.isLiquidOrDrop)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.item.isSterilityExpired
                    ? AppColors.dangerSurface
                    : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.item.isSterilityExpired
                      ? AppColors.dangerBorder
                      : AppColors.primaryLight.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        color: widget.item.isSterilityExpired ? AppColors.danger : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '28-Day Open Sterility Period',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.item.isSterilityExpired
                              ? AppColors.danger
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (widget.item.isOpened && widget.item.openedDaysRemaining != null) ...[
                    Text(
                      widget.item.isSterilityExpired
                          ? 'Sterility period has ended! Safely discard this eye drop/syrup.'
                          : '${widget.item.openedDaysRemaining} days remaining of safe sterility.',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.item.isSterilityExpired
                            ? AppColors.danger
                            : AppColors.primaryDark,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Unopened seal. Once opened, ophthalmic drops and syrups must be used within 28 days.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.alarm_add, size: 18),
                      label: const Text('Mark Opened Today'),
                      onPressed: () {
                        widget.onMarkOpenedToday();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
          // Symptoms Tags
          if (widget.item.symptomTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Associated Symptoms',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.item.symptomTags.map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.surfaceVariant,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.dangerSurface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? AppColors.dangerBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isWarning ? AppColors.danger : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isWarning ? AppColors.danger : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isWarning ? AppColors.danger : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
