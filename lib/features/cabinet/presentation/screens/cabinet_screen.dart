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
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.medication_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.safe,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '100% Offline Safe',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.safe,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 2:00 AM Quick Finder Button
          cabinetAsync.maybeWhen(
            data: (items) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showEmergencyDialog(items),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warningBorder, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: AppColors.warning, size: 16),
                        SizedBox(width: 3),
                        Text(
                          '2AM Quick',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          // 1-Click Demo Data Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _seedDemoData,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_fix_high, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        'Demo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

                // Modern Integrated Micro-Dashboard
                _buildMicroDashboard(
                  total: items.length,
                  lowStock: lowStockCount,
                  expired: expiredCount,
                ),

                // Modern Category Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),

                // Medicine Cards List
                if (filteredItems.isEmpty)
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        Text(
                          'No medicines found in "$_selectedCategory"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
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
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Medicine',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
          );
        },
      ),
    );
  }

  Widget _buildMicroDashboard({required int total, required int lowStock, required int expired}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Cabinet Overview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Live Drawer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricTile(
                title: 'Total Items',
                count: '$total',
                color: AppColors.primary,
                icon: Icons.medication_rounded,
                bgColor: AppColors.primarySurface,
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              _buildMetricTile(
                title: 'Low Stock',
                count: '$lowStock',
                color: lowStock > 0 ? AppColors.warning : AppColors.textMuted,
                icon: Icons.warning_amber_rounded,
                bgColor: lowStock > 0 ? AppColors.warningSurface : AppColors.surfaceVariant,
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              _buildMetricTile(
                title: 'Expired / Alert',
                count: '$expired',
                color: expired > 0 ? AppColors.danger : AppColors.textMuted,
                icon: Icons.event_busy_rounded,
                bgColor: expired > 0 ? AppColors.dangerSurface : AppColors.surfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
    required Color bgColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
