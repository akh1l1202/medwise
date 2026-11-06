import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/confidence_badge_utils.dart';
import '../../../ocr_ingestion/data/models/prescription_item_candidate.dart';
import '../../../ocr_ingestion/domain/services/prescription_scanner_service.dart';
import '../../../medicine_catalog/data/models/medicine_record.dart';
import '../../../medicine_catalog/data/repositories/medicine_catalog_repository.dart';
import '../../data/models/chemist_cart_item.dart';
import '../controllers/chemist_counter_controller.dart';

class PrescriptionScanModal extends ConsumerStatefulWidget {
  const PrescriptionScanModal({super.key});

  @override
  ConsumerState<PrescriptionScanModal> createState() => _PrescriptionScanModalState();
}

class _PrescriptionScanModalState extends ConsumerState<PrescriptionScanModal> {
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;
  bool _isProcessing = false;
  List<PrescriptionItemCandidate> _candidates = [];
  List<String> _rawLines = [];
  DocumentType _documentType = DocumentType.medicalPrescription;
  String? _rejectionReason;
  double _overallReadabilityScore = 1.0;
  bool _isHandwrittenOrLowReadability = false;

  final TextEditingController _manualSearchController = TextEditingController();
  List<MedicineRecord> _manualSearchResults = [];
  bool _isSearchingCatalog = false;

  @override
  void dispose() {
    _manualSearchController.dispose();
    super.dispose();
  }

  Future<void> _onManualSearchChanged(String query) async {
    final clean = query.trim();
    if (clean.length < 2) {
      setState(() => _manualSearchResults = []);
      return;
    }
    setState(() => _isSearchingCatalog = true);
    final repo = ref.read(medicineCatalogRepositoryProvider);
    final results = await repo.searchMedicines(clean, limit: 5);
    if (mounted) {
      setState(() {
        _manualSearchResults = results;
        _isSearchingCatalog = false;
      });
    }
  }

  void _addMedicineFromCatalog(MedicineRecord med) {
    setState(() {
      _candidates.add(
        PrescriptionItemCandidate(
          rawLine: 'Manually Added: ${med.brandName}',
          matchedRecord: med,
          confidenceScore: 1.0,
          quantity: 10,
          dosageInstruction: '1-0-1 after food',
          isSelected: true,
        ),
      );
      _manualSearchController.clear();
      _manualSearchResults = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${med.brandName}" to prescribed list!'),
          backgroundColor: AppColors.safe,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) return;

      setState(() {
        _imagePath = file.path;
        _isProcessing = true;
        _candidates = [];
        _rawLines = [];
        _documentType = DocumentType.medicalPrescription;
        _rejectionReason = null;
        _overallReadabilityScore = 1.0;
        _isHandwrittenOrLowReadability = false;
        _manualSearchResults = [];
      });

      final scanner = ref.read(prescriptionScannerServiceProvider);
      final result = await scanner.processPrescriptionImage(file.path);

      setState(() {
        _candidates = result.candidates;
        _rawLines = result.rawExtractedLines;
        _documentType = result.documentType;
        _rejectionReason = result.rejectionReason;
        _overallReadabilityScore = result.overallReadabilityScore;
        _isHandwrittenOrLowReadability = result.isHandwrittenOrLowReadability;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read prescription: $e')),
        );
      }
    }
  }

  Future<void> _addRawLineAsCandidate(String line) async {
    final scanner = ref.read(prescriptionScannerServiceProvider);
    final candidate = await scanner.createCandidateFromRawLine(line);
    setState(() {
      _candidates.add(candidate);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${candidate.matchedRecord.brandName}"'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  bool _showManualSearchField = false;

  void _editCandidateDialog(PrescriptionItemCandidate candidate, int index) {
    final nameCtrl = TextEditingController(text: candidate.matchedRecord.brandName);
    final qtyCtrl = TextEditingController(text: candidate.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Prescribed Medicine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Medicine / Brand Name', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity to Buy', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newQty = int.tryParse(qtyCtrl.text.trim()) ?? candidate.quantity;
              if (newName.isNotEmpty) {
                setState(() {
                  _candidates[index] = candidate.copyWith(
                    matchedRecord: candidate.matchedRecord.copyWith(brandName: newName),
                    quantity: newQty,
                    confidenceScore: 1.0, // Human verified
                    isSelected: true,
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadabilityBannerAndSearchBar() {
    final isLow = _isHandwrittenOrLowReadability || _candidates.isEmpty;
    final percentage = (_overallReadabilityScore * 100).toInt().clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLow ? AppColors.warningSurface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLow ? AppColors.warningBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLow) ...[
            Row(
              children: [
                const Icon(Icons.draw_outlined, color: AppColors.warning, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Low Handwriting Readability ($percentage% Confidence)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Doctor\'s cursive handwriting is difficult to decipher with full certainty. Please search and add prescribed medicines manually to ensure safety.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _manualSearchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search 246,000 medicines (e.g. Dolo, Rebegen, Sompraz)...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
              suffixIcon: _isSearchingCatalog
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _manualSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _manualSearchController.clear();
                            setState(() => _manualSearchResults = []);
                          },
                        )
                      : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: _onManualSearchChanged,
          ),
          if (_manualSearchResults.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _manualSearchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final med = _manualSearchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(med.brandName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${med.activeSalt}${med.strength.isNotEmpty ? " • ${med.strength}" : ""}', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.add_circle, color: AppColors.primary, size: 22),
                    onTap: () => _addMedicineFromCatalog(med),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _importSelectedToCart() {
    final selected = _candidates.where((c) => c.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one medicine to import.')),
      );
      return;
    }

    const uuid = Uuid();
    final cartNotifier = ref.read(chemistCartProvider.notifier);

    for (final item in selected) {
      cartNotifier.addItem(
        ChemistCartItem(
          id: uuid.v4(),
          brandName: item.matchedRecord.brandName,
          activeSalt: item.matchedRecord.activeSalt,
          prescribedStrength: item.matchedRecord.strength,
          quantityPrescribed: item.quantity,
          dosageForm: item.matchedRecord.dosageForm,
        ),
      );
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported ${selected.length} prescribed medicines into Chemist Cart!'),
        backgroundColor: AppColors.safe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _candidates.where((c) => c.isSelected).length;

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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
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
          // Modal Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Prescription Slip',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Parses computerized clinic & hospital slips on-device',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Capture / Pick Image Buttons if no image yet
          if (_imagePath == null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.document_scanner_outlined, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Snap a photo of the printed prescription',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Best results on printed/computerized doctor slips (Apollo, Practo, Max, OPD slips).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_isProcessing) ...[
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Extracting medicines & dosage lines...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Matching against Indian Pharmacopoeia Database',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_documentType == DocumentType.utilityOrTaxBill) ...[
            // Explicit rejection of non-prescription utility / tax / service bills
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.dangerBorder, width: 2),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Non-Prescription Document Detected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _rejectionReason ??
                            'The scanned image appears to be a utility, electricity, or tax bill rather than a doctor\'s prescription.\n\nPlease scan a medical prescription or OPD slip.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Doctor\'s Prescription', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => setState(() {
                          _imagePath = null;
                          _documentType = DocumentType.medicalPrescription;
                          _rejectionReason = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_candidates.isEmpty) ...[
            // Empty auto-matches, provide manual search bar directly and raw lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadabilityBannerAndSearchBar(),
                  const SizedBox(height: 8),
                  if (_rawLines.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Extracted Raw Lines (${_rawLines.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _imagePath = null),
                          child: const Text('Retake Photo', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _rawLines.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final line = _rawLines[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Text(line, style: const TextStyle(fontSize: 13)),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add', style: TextStyle(fontSize: 12)),
                              onPressed: () => _addRawLineAsCandidate(line),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No readable text detected',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Please use the search box above to manually enter your prescribed drugs.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Candidate Medicines List
            if (_isHandwrittenOrLowReadability || _showManualSearchField)
              _buildReadabilityBannerAndSearchBar(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detected Medicines (${_candidates.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                  icon: Icon(_showManualSearchField ? Icons.close : Icons.add, size: 15),
                  label: Text(_showManualSearchField ? 'Close' : 'Add', style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _showManualSearchField = !_showManualSearchField),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  onPressed: () => setState(() => _imagePath = null),
                  child: const Text('Retake', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.separated(
                itemCount: _candidates.length + (_rawLines.isNotEmpty ? 1 : 0),
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == _candidates.length) {
                    // Expandable drawer for raw extracted lines at bottom
                    return Card(
                      color: AppColors.surfaceVariant,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          'Missing a medicine? View all ${_rawLines.length} raw text lines',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                        children: _rawLines.map((line) {
                          return ListTile(
                            dense: true,
                            title: Text(line, style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                              tooltip: 'Add line as medicine',
                              onPressed: () => _addRawLineAsCandidate(line),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }

                  final candidate = _candidates[index];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: candidate.isSelected ? AppColors.primary : AppColors.border,
                        width: candidate.isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: candidate.isSelected,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                candidate.isSelected = val ?? false;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        candidate.matchedRecord.brandName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        softWrap: true,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                      tooltip: 'Edit name or quantity',
                                      onPressed: () => _editCandidateDialog(candidate, index),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                      tooltip: 'Remove',
                                      onPressed: () => setState(() => _candidates.removeAt(index)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${candidate.matchedRecord.activeSalt}${candidate.matchedRecord.strength.isNotEmpty ? " • ${candidate.matchedRecord.strength}" : ""}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    ConfidenceBadgeUtils.buildBadgeWidget(
                                      candidate.level,
                                      candidate.confidencePercentage,
                                      compact: true,
                                    ),
                                    if (candidate.dosageInstruction != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySurface,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          candidate.dosageInstruction!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Quantity Stepper
                                Row(
                                  children: [
                                    const Text('Quantity to buy:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.remove, size: 16),
                                      onPressed: candidate.quantity > 1
                                          ? () => setState(() => candidate.quantity -= 1)
                                          : null,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '${candidate.quantity}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add, size: 16),
                                      onPressed: () => setState(() => candidate.quantity += 1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Import Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  'Import $selectedCount Medicine(s) to Chemist Cart',
                  style: const TextStyle(fontSize: 15),
                ),
                onPressed: selectedCount > 0 ? _importSelectedToCart : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
