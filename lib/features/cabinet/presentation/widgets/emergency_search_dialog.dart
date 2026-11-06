import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/cabinet_item.dart';

class EmergencySearchDialog extends StatefulWidget {
  final List<CabinetItem> cabinetItems;
  final Function(CabinetItem) onSelect;

  const EmergencySearchDialog({
    super.key,
    required this.cabinetItems,
    required this.onSelect,
  });

  @override
  State<EmergencySearchDialog> createState() => _EmergencySearchDialogState();
}

class _EmergencySearchDialogState extends State<EmergencySearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<CabinetItem> _filtered = [];

  final List<String> _quickSymptoms = [
    'Acidity',
    'Fever',
    'Headache',
    'Body Pain',
    'Cough',
    'Dry Eyes',
  ];

  @override
  void initState() {
    super.initState();
    _filtered = widget.cabinetItems;
  }

  void _filter(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _filtered = widget.cabinetItems;
      });
      return;
    }

    setState(() {
      _filtered = widget.cabinetItems.where((item) {
        final matchesSymptom = item.symptomTags.any((tag) => tag.toLowerCase().contains(clean));
        final matchesBrand = item.brandName.toLowerCase().contains(clean);
        final matchesSalt = item.activeSalt.toLowerCase().contains(clean);
        return matchesSymptom || matchesBrand || matchesSalt;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = availableHeight * 0.75;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with safe Expanded text and Close button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.dangerBorder),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2:00 AM Quick Finder',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Find medicines by immediate symptom',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Search input
              TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search symptom (e.g. Acidity, Fever)...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filter('');
                          },
                        )
                      : null,
                ),
                onChanged: _filter,
              ),
              const SizedBox(height: 10),
              // Quick symptom chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickSymptoms.map((symptom) {
                    final isSelected = _searchController.text.toLowerCase() == symptom.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          symptom,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                          ),
                        ),
                        onPressed: () {
                          _searchController.text = symptom;
                          _filter(symptom);
                        },
                        backgroundColor: isSelected ? AppColors.primarySurface : AppColors.surfaceVariant,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              // Results List: safely constrained and scrollable in available dialog space
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 36, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              const Text(
                                'No matching medicines in cabinet',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Text(
                              item.brandName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${item.storageLocation} • ${item.quantityRemaining.toStringAsFixed(0)} left',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelect(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
