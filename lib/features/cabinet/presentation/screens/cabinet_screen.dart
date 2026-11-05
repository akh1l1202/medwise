import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/demo_data_seeder.dart';
import '../../data/models/cabinet_item.dart';
import '../../data/repositories/cabinet_repository.dart';
import '../controllers/cabinet_controller.dart';
import '../widgets/medicine_card.dart';
import '../widgets/medicine_detail_sheet.dart';
import '../widgets/emergency_search_dialog.dart';
import 'add_medicine_screen.dart';
import '../../../drug_interactions/presentation/controllers/interaction_alert_controller.dart';
import '../../../drug_interactions/data/models/drug_interaction_rule.dart';

class CabinetScreen extends ConsumerStatefulWidget {
  const CabinetScreen({super.key});

  @override
  ConsumerState<CabinetScreen> createState() => _CabinetScreenState();
}

class _CabinetScreenState extends ConsumerState<CabinetScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Tablets',
    'Syrups & Drops',
    'Low Stock',
  ];

  List<CabinetItem> _filterItems(List<CabinetItem> items) {
    switch (_selectedCategory) {
      case 'Tablets':
        return items.where((i) => i.form.toLowerCase().contains('tab') || i.form.toLowerCase().contains('cap')).toList();
      case 'Syrups & Drops':
        return items.where((i) => i.isLiquidOrDrop).toList();
      case 'Low Stock':
        return items.where((i) => i.isLowStock).toList();
      case 'All':
      default:
        return items;
    }
  }

  void _showDetailSheet(CabinetItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MedicineDetailSheet(
          item: item,
          onUpdate: (updated) {
            ref.read(cabinetNotifierProvider.notifier).updateItem(updated);
          },
          onDelete: () {
            ref.read(cabinetNotifierProvider.notifier).deleteItem(item.id);
          },
          onMarkOpenedToday: () {
            ref.read(cabinetNotifierProvider.notifier).markOpenedToday(item.id);
          },
        );
      },
    );
  }

  void _showEmergencyDialog(List<CabinetItem> items) {
    showDialog(
      context: context,
      builder: (context) => EmergencySearchDialog(
        cabinetItems: items,
        onSelect: _showDetailSheet,
      ),
    );
  }

  Future<void> _seedDemoData() async {
    final repo = ref.read(cabinetRepositoryProvider);
    await DemoDataSeeder.seedDemoStash(repo);
    await ref.read(cabinetNotifierProvider.notifier).refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seeded 5 realistic Indian household medicines into your cabinet!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cabinetAsync = ref.watch(cabinetNotifierProvider);
    final interactionsAsync = ref.watch(cabinetInteractionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medication, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(AppConstants.appName),
          ],
        ),
        actions: [
          // 2:00 AM Quick Finder Button
          cabinetAsync.maybeWhen(
            data: (items) => IconButton(
              icon: const Icon(Icons.flash_on, color: AppColors.warning),
              tooltip: '2:00 AM Emergency Symptom Finder',
              onPressed: () => _showEmergencyDialog(items),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          // 1-Click Demo Data Button
          TextButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('Demo Data'),
            onPressed: _seedDemoData,
          ),
        ],
      ),
      body: cabinetAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your Home Cabinet is Empty',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Digitize your home medicine drawer to prevent duplicate chemist purchases.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Preload Sample Demo Stash'),
                      onPressed: _seedDemoData,
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredItems = _filterItems(items);
          final expiredCount = items.where((i) => i.isExpired).length;
          final lowStockCount = items.where((i) => i.isLowStock).length;

          return RefreshIndicator(
            onRefresh: () => ref.read(cabinetNotifierProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                // Urgency Alerts Banner
                if (expiredCount > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.dangerBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$expiredCount medicine(s) expired or sterility breached! Dispose safely.',
                            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Clinical Drug Interactions Alert (Pairwise check across cabinet)
                interactionsAsync.maybeWhen(
                  data: (interactions) {
                    if (interactions.isEmpty) return const SizedBox.shrink();
                    final critical = interactions.where((i) => i.severity == InteractionSeverity.critical).toList();
                    final first = critical.isNotEmpty ? critical.first : interactions.first;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.danger, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.health_and_safety, color: AppColors.danger, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'CLINICAL ALERT: ${first.severity.displayName.toUpperCase()}',
                                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${first.medicineA} (${first.saltA}) + ${first.medicineB} (${first.saltB})',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            first.effect,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

                // Summary Stats Strip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatChip('Total Stash', '${items.length}', AppColors.primary),
                      const SizedBox(width: 8),
                      _buildStatChip('Low Stock', '$lowStockCount', lowStockCount > 0 ? AppColors.warning : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      _buildStatChip('Expired', '$expiredCount', expiredCount > 0 ? AppColors.danger : AppColors.textSecondary),
                    ],
                  ),
                ),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = cat);
                          },
                          selectedColor: AppColors.primarySurface,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Medicine Cards List
                if (filteredItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Text(
                      'No medicines in "$_selectedCategory" category.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  ...filteredItems.map(
                    (item) => MedicineCard(
                      item: item,
                      onTap: () => _showDetailSheet(item),
                      onDelete: () => ref.read(cabinetNotifierProvider.notifier).deleteItem(item.id),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
