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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flash_on, color: AppColors.danger, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2:00 AM Quick Finder',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Find medicines by immediate symptom',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search symptom (e.g. Acidity, Fever)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filter('');
                        },
                      )
                    : null,
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 12),
            // Quick symptom chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickSymptoms.map((symptom) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(symptom, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _searchController.text = symptom;
                        _filter(symptom);
                      },
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Results List
            Flexible(
              child: _filtered.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: const Text(
                        'No matching medicines in your cabinet.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.brandName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Found in: ${item.storageLocation} • ${item.quantityRemaining} left'),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
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
    );
  }
}
