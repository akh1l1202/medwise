import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/confidence_badge_utils.dart';
import '../../../ocr_ingestion/data/models/prescription_item_candidate.dart';
import '../../../ocr_ingestion/domain/services/prescription_scanner_service.dart';
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) return;

      setState(() {
        _imagePath = file.path;
        _isProcessing = true;
        _candidates = [];
        _rawLines = [];
      });

      final scanner = ref.read(prescriptionScannerServiceProvider);
      final result = await scanner.processPrescriptionImage(file.path);

      setState(() {
        _candidates = result.candidates;
        _rawLines = result.rawExtractedLines;
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
          ] else if (_candidates.isEmpty) ...[
            // Empty auto-matches, but show raw extracted lines if available
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_rawLines.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warningBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app, color: AppColors.warning, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Tap any line below to add it directly as a medicine:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Extracted Lines (${_rawLines.length})',
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No text could be extracted',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Ensure the slip is well-lit and clearly photographed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Candidate Medicines List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detected Medicines (${_candidates.length})',
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
                                  children: [
                                    Expanded(
                                      child: Text(
                                        candidate.matchedRecord.brandName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    ConfidenceBadgeUtils.buildBadgeWidget(
                                      candidate.level,
                                      candidate.confidencePercentage,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${candidate.matchedRecord.activeSalt}${candidate.matchedRecord.strength.isNotEmpty ? " • ${candidate.matchedRecord.strength}" : ""}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                if (candidate.dosageInstruction != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dosage: ${candidate.dosageInstruction}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
