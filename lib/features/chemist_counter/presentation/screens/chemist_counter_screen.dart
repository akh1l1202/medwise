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
  int _prescribedQuantity = 10;
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
    final cartItem = ChemistCartItem(
      id: uuid.v4(),
      brandName: record.brandName,
      activeSalt: record.activeSalt,
      prescribedStrength: record.strength,
      quantityPrescribed: _prescribedQuantity,
      dosageForm: record.dosageForm,
    );

    ref.read(chemistCartProvider.notifier).addItem(cartItem);

    setState(() {
      _suggestions = [];
      _searchController.clear();
      _prescribedQuantity = 10;
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

    return Scaffold(
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enter Prescribed Medicine',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
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
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search prescribed (e.g. Dolo 650)...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                        ),
                        onChanged: _onSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quantity dropdown selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButton<int>(
                        value: _prescribedQuantity,
                        underline: const SizedBox.shrink(),
                        items: [5, 10, 15, 20, 30].map((qty) {
                          return DropdownMenuItem(value: qty, child: Text('$qty tabs'));
                        }).toList(),
                        onChanged: (val) => setState(() => _prescribedQuantity = val ?? 10),
                      ),
                    ),
                  ],
                ),
                // Autocomplete Suggestions Dropdown
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _suggestions.length.clamp(0, 4),
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final med = _suggestions[index];
                        return ListTile(
                          title: Text(med.brandName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${med.activeSalt} • ${med.strength}'),
                          trailing: const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 20),
                          onTap: () => _addPrescribedMedicine(med),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Prescription & Equivalence Evaluation List
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 56, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'Your Prescription Cart is Empty',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Search prescribed medicines above (e.g. Dolo 650) to instantly detect active salt matches in your home cabinet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: eval.strengthMismatch
                                ? AppColors.warningBorder
                                : eval.hasCabinetEquivalence
                                    ? AppColors.safeBorder
                                    : AppColors.border,
                            width: 1.5,
                          ),
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
                                          'Prescribed: ${eval.cartItem.brandName}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: isCheckedOff ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        Text(
                                          '${eval.cartItem.activeSalt} (${eval.cartItem.prescribedStrength})',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                                    onPressed: () => ref.read(chemistCartProvider.notifier).removeItem(eval.cartItem.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Active Salt Equivalence Callout Card
                              if (eval.hasCabinetEquivalence && !eval.strengthMismatch) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.safeSurface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle, size: 16, color: AppColors.safe),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Equivalence Found: ${eval.matchingCabinetItem!.brandName}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.safe,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'You already have ${eval.quantityAlreadyOwned.toStringAsFixed(0)} tablets of ${eval.matchingCabinetItem!.brandName} (${eval.matchingCabinetItem!.activeSalt} ${eval.matchingCabinetItem!.strength}) in your ${eval.storageLocation ?? 'cabinet'}.',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        eval.canSkipPurchase
                                            ? '💡 Skip purchase entirely! Home stock covers full prescription.'
                                            : '💡 Recommendation: Buy only ${eval.recommendedBuyQuantity} tablets.',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          eval.strengthWarningMessage ?? 'Strength concentration mismatch.',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'No active salt stock found in cabinet. Buy full ${eval.recommendedBuyQuantity} tablets.',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

          // Bottom Action: Sync to Cabinet Button
          if (cart.isNotEmpty)
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
    );
  }
}
