import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../cabinet/data/models/cabinet_item.dart';
import '../../../cabinet/presentation/controllers/cabinet_controller.dart';
import '../../../medicine_catalog/data/models/medicine_record.dart';
import '../../../medicine_catalog/data/repositories/medicine_catalog_repository.dart';
import '../../data/models/chemist_cart_item.dart';
import '../../data/models/smart_buy_result.dart';
import '../controllers/chemist_counter_controller.dart';
import '../widgets/prescription_scan_modal.dart';

class ChemistCounterScreen extends ConsumerStatefulWidget {
  const ChemistCounterScreen({super.key});

  @override
  ConsumerState<ChemistCounterScreen> createState() => _ChemistCounterScreenState();
}

class _ChemistCounterScreenState extends ConsumerState<ChemistCounterScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MedicineRecord> _suggestions = [];
  bool _isSearching = false;
  final Set<String> _checkedOffItemIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPrescriptionScanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrescriptionScanModal(),
    );
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    final repo = ref.read(medicineCatalogRepositoryProvider);
    final results = await repo.searchMedicines(query.trim());
    setState(() {
      _suggestions = results;
      _isSearching = false;
    });
  }

  void _addPrescribedMedicine(MedicineRecord record) {
    const uuid = Uuid();
    final lowerForm = record.dosageForm.toLowerCase();
    final isUnitForm = lowerForm.contains('syrup') ||
        lowerForm.contains('drop') ||
        lowerForm.contains('suspension') ||
        lowerForm.contains('liquid') ||
        lowerForm.contains('ointment') ||
        lowerForm.contains('cream') ||
        lowerForm.contains('gel') ||
        lowerForm.contains('spray') ||
        lowerForm.contains('inhaler');

    // Default to 1 bottle/tube for syrups & liquids, 10 for tablets/capsules
    final initialQuantity = isUnitForm ? 1 : 10;

    final cartItem = ChemistCartItem(
      id: uuid.v4(),
      brandName: record.brandName,
      activeSalt: record.activeSalt,
      prescribedStrength: record.strength,
      quantityPrescribed: initialQuantity,
      dosageForm: record.dosageForm,
    );

    ref.read(chemistCartProvider.notifier).addItem(cartItem);

    setState(() {
      _suggestions = [];
      _searchController.clear();
    });
  }

  Future<void> _syncPurchasedToCabinet(List<SmartBuyResult> evaluations) async {
    final cabinetNotifier = ref.read(cabinetNotifierProvider.notifier);
    const uuid = Uuid();

    for (final eval in evaluations) {
      final buyAmount = eval.recommendedBuyQuantity.toDouble();
      if (buyAmount <= 0) continue;

      if (eval.hasCabinetEquivalence && eval.matchingCabinetItem != null && !eval.strengthMismatch) {
        // Increment existing matching item
        final existing = eval.matchingCabinetItem!;
        final updated = existing.copyWith(
          quantityRemaining: existing.quantityRemaining + buyAmount,
        );
        await cabinetNotifier.updateItem(updated);
      } else {
        // Add as a new cabinet item
        final newItem = CabinetItem(
          id: uuid.v4(),
          brandName: eval.cartItem.brandName,
          activeSalt: eval.cartItem.activeSalt,
          strength: eval.cartItem.prescribedStrength,
          form: eval.cartItem.dosageForm,
          quantityRemaining: buyAmount,
          printedExpiry: '12/2027',
          storageLocation: 'Living Room Drawer',
          profileId: 'profile-primary-self',
          createdAt: DateTime.now(),
        );
        await cabinetNotifier.addItem(newItem);
      }
    }

    ref.read(chemistCartProvider.notifier).clearCart();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchased medicines synced to your home cabinet!'),
          backgroundColor: AppColors.safe,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(chemistCartProvider);
    final evaluations = ref.watch(smartBuyEvaluationProvider);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chemist Counter "Smart Buy"'),
          actions: [
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'Scan Prescription Slip',
              onPressed: _showPrescriptionScanModal,
            ),
            if (cart.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Clear Cart',
                onPressed: () => ref.read(chemistCartProvider.notifier).clearCart(),
              ),
          ],
        ),
        body: Column(
          children: [
            // Prescription Search Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Enter Prescribed Medicine',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _showPrescriptionScanModal,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.document_scanner_outlined, size: 16, color: AppColors.primaryDark),
                              SizedBox(width: 4),
                              Text(
                                'Scan Slip',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search prescribed (e.g. Dolo 650, Benadryl)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _suggestions = [];
                                });
                              },
                            )
                          : (_isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null),
                    ),
                    onChanged: _onSearch,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Autocomplete Suggestions Mode (smoothly occupies Expanded area when user is actively searching)
            if (_suggestions.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Matching Medicines (${_suggestions.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _suggestions = [];
                                _searchController.clear();
                              });
                              FocusScope.of(context).unfocus();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Text(
                                'Dismiss',
                                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final med = _suggestions[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 20),
                            ),
                            title: Text(med.brandName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('${med.activeSalt} • ${med.strength} (${med.dosageForm})', style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 20),
                            onTap: () {
                              _addPrescribedMedicine(med);
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              // Prescription & Equivalence Evaluation List
              Expanded(
                child: cart.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: const BoxDecoration(
                                  color: AppColors.primarySurface,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, size: 36, color: AppColors.primary),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your Prescription Cart is Empty',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Search prescribed medicines above (e.g. Dolo 650) to instantly detect active salt matches in your home cabinet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: evaluations.length,
                        itemBuilder: (context, index) {
                          final eval = evaluations[index];
                          final isCheckedOff = _checkedOffItemIds.contains(eval.cartItem.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: eval.strengthMismatch
                                    ? AppColors.warningBorder
                                    : eval.hasCabinetEquivalence
                                        ? AppColors.safeBorder
                                        : AppColors.border,
                                width: eval.strengthMismatch || eval.hasCabinetEquivalence ? 1.5 : 1,
                              ),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: isCheckedOff,
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _checkedOffItemIds.add(eval.cartItem.id);
                                            } else {
                                              _checkedOffItemIds.remove(eval.cartItem.id);
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              eval.cartItem.brandName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                                decoration: isCheckedOff ? TextDecoration.lineThrough : null,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${eval.cartItem.activeSalt} • ${eval.cartItem.prescribedStrength}',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                                        onPressed: () => ref.read(chemistCartProvider.notifier).removeItem(eval.cartItem.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Form-Aware Quantity Stepper Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Prescribed needed:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: eval.cartItem.quantityPrescribed > 1
                                                  ? () {
                                                      final step = eval.cartItem.isLiquidOrUnitItem ? 1 : 5;
                                                      final newQty = (eval.cartItem.quantityPrescribed - step).clamp(1, 999);
                                                      ref.read(chemistCartProvider.notifier).updateQuantity(eval.cartItem.id, newQty);
                                                    }
                                                  : null,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Icon(Icons.remove_rounded, size: 14),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text(
                                                '${eval.cartItem.quantityPrescribed} ${eval.cartItem.unitLabel}',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                              ),
                                            ),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () {
                                                final step = eval.cartItem.isLiquidOrUnitItem ? 1 : 5;
                                                ref.read(chemistCartProvider.notifier).updateQuantity(
                                                  eval.cartItem.id,
                                                  eval.cartItem.quantityPrescribed + step,
                                                );
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Icon(Icons.add_rounded, size: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Active Salt Equivalence Callout Card
                                  if (eval.hasCabinetEquivalence && !eval.strengthMismatch) ...[
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.safeSurface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.safeBorder, width: 1),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.safe),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Equivalence Found: ${eval.matchingCabinetItem!.brandName}',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.safe,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'You already have ${eval.formatOwnedQuantity()} of ${eval.matchingCabinetItem!.brandName} (${eval.matchingCabinetItem!.activeSalt} ${eval.matchingCabinetItem!.strength}) in your ${eval.storageLocation ?? 'cabinet'}.',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppColors.safeBorder),
                                            ),
                                            child: Text(
                                              eval.canSkipPurchase
                                                  ? '💡 Skip purchase entirely! Home stock covers full prescription.'
                                                  : '💡 Recommendation: Buy only ${eval.formatRecommendedBuy()}.',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (eval.strengthMismatch) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.warningSurface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.warningBorder, width: 1),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              eval.strengthWarningMessage ?? 'Strength concentration mismatch.',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add_shopping_cart_rounded, size: 16, color: AppColors.textSecondary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'No active salt stock in cabinet. Buy full ${eval.formatRecommendedBuy()}.',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

            // Bottom Action: Sync to Cabinet Button (hidden when soft keyboard is up to preserve viewport)
            if (cart.isNotEmpty && !isKeyboardOpen)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: const Text('Add Purchased to Cabinet', style: TextStyle(fontSize: 16)),
                    onPressed: () => _syncPurchasedToCabinet(evaluations),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
