import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../cabinet/data/models/cabinet_item.dart';
import '../../../cabinet/data/models/intake_schedule.dart';
import '../../../cabinet/presentation/controllers/cabinet_controller.dart';
import '../../../cabinet/data/repositories/cabinet_repository.dart';

class AdherenceScreen extends ConsumerStatefulWidget {
  const AdherenceScreen({super.key});

  @override
  ConsumerState<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends ConsumerState<AdherenceScreen> {
  Future<void> _recordDose(IntakeSchedule schedule, CabinetItem item) async {
    final result = await ref.read(cabinetNotifierProvider.notifier).recordDoseTaken(
      schedule: schedule,
      item: item,
    );

    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Marked taken! Remaining: ${result.remainingQuantity.toStringAsFixed(0)} tabs.${result.isLowStock ? ' ⚠️ Low stock refill alert!' : ''}',
          ),
          backgroundColor: result.isLowStock ? AppColors.warning : AppColors.safe,
        ),
      );
    }
  }

  void _showAddScheduleDialog(List<CabinetItem> cabinetItems) {
    if (cabinetItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add medicines to your cabinet first!')),
      );
      return;
    }

    String selectedCabinetId = cabinetItems.first.id;
    String timeOfDay = '08:00';
    String mealRelation = 'AFTER_FOOD';
    double doseAmount = 1.0;
    bool isAntibiotic = false;
    int courseTotalDays = 5;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Dose Reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCabinetId,
                      decoration: const InputDecoration(labelText: 'Medicine'),
                      items: cabinetItems.map((item) {
                        return DropdownMenuItem(
                          value: item.id,
                          child: Text(item.brandName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedCabinetId = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: timeOfDay,
                      decoration: const InputDecoration(labelText: 'Time of Day'),
                      items: ['08:00', '13:00', '16:00', '20:30', '22:00'].map((time) {
                        return DropdownMenuItem(value: time, child: Text(time));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => timeOfDay = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mealRelation,
                      decoration: const InputDecoration(labelText: 'Meal Relation'),
                      items: ['BEFORE_FOOD', 'AFTER_FOOD', 'WITH_FOOD'].map((rel) {
                        return DropdownMenuItem(value: rel, child: Text(rel.replaceAll('_', ' ')));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => mealRelation = val!),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Is Antibiotic Course?'),
                      subtitle: const Text('Enables adherence day counter'),
                      value: isAntibiotic,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setDialogState(() => isAntibiotic = val ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text('Save Schedule'),
                  onPressed: () async {
                    const uuid = Uuid();
                    final newSched = IntakeSchedule(
                      id: uuid.v4(),
                      cabinetItemId: selectedCabinetId,
                      profileId: 'profile-primary-self',
                      timeOfDay: timeOfDay,
                      mealRelation: mealRelation,
                      doseAmount: doseAmount,
                      isAntibiotic: isAntibiotic,
                      courseTotalDays: isAntibiotic ? courseTotalDays : null,
                      courseCurrentDay: isAntibiotic ? 1 : null,
                    );
                    await ref.read(cabinetRepositoryProvider).addSchedule(newSched);
                    ref.invalidate(cabinetSchedulesProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(cabinetSchedulesProvider);
    final cabinetAsync = ref.watch(cabinetNotifierProvider);
    final cabinetItems = cabinetAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dose Adherence & Reminders'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showAddScheduleDialog(cabinetItems),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primarySurfaceBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_add_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Add Dose',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
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
      body: schedulesAsync.when(
        data: (schedules) {
          final antibioticSchedules = schedules.where((s) => s.isAntibiotic).toList();

          if (schedules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm, size: 44, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Active Dose Schedules',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Schedule intake reminders to track daily compliance and automatically decrement cabinet stock when marking doses taken.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.alarm_add_rounded),
                      label: const Text('Add Dose Schedule'),
                      onPressed: () => _showAddScheduleDialog(cabinetItems),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Antibiotic Adherence Master Banner
              if (antibioticSchedules.isNotEmpty) ...[
                ...antibioticSchedules.map((sched) {
                  final linkedItem = cabinetItems.firstWhere(
                    (i) => i.id == sched.cabinetItemId,
                    orElse: () => CabinetItem(
                      id: '',
                      brandName: 'Antibiotic',
                      activeSalt: '',
                      strength: '',
                      form: '',
                      quantityRemaining: 0,
                      printedExpiry: '',
                      profileId: '',
                      createdAt: DateTime.now(),
                    ),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4), width: 1.5),
                      boxShadow: AppColors.subtleShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'ANTIBIOTIC REGIMEN: ${sched.antibioticProgressLabel.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          linkedItem.brandName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '⚠️ Do not stop early even if feeling better! Finish all prescribed days to prevent antibiotic resistance.',
                          style: TextStyle(fontSize: 12, color: AppColors.primaryDark, height: 1.35),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Today\'s Scheduled Doses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
              ),
              const SizedBox(height: 8),

              ...schedules.map((schedule) {
                final item = cabinetItems.firstWhere(
                  (i) => i.id == schedule.cabinetItemId,
                  orElse: () => CabinetItem(
                    id: '',
                    brandName: 'Medicine',
                    activeSalt: '',
                    strength: '',
                    form: 'Tablet',
                    quantityRemaining: 0,
                    printedExpiry: '',
                    profileId: '',
                    createdAt: DateTime.now(),
                  ),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alarm_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(height: 3),
                              Text(
                                schedule.timeOfDay,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.brandName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${schedule.doseAmount.toStringAsFixed(0)} tab • ${schedule.mealRelation.replaceAll('_', ' ')}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: item.isLowStock ? AppColors.danger : AppColors.safe,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.quantityRemaining.toStringAsFixed(0)} left in cabinet',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: item.isLowStock ? AppColors.danger : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _recordDose(schedule, item),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Taken', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
