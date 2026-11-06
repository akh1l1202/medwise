import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/confidence_badge_utils.dart';
import '../../../cabinet/data/models/cabinet_item.dart';
import '../../../cabinet/presentation/controllers/cabinet_controller.dart';
import '../../data/models/match_candidate.dart';
import '../../data/models/ocr_scan_result.dart';
import '../controllers/ocr_review_controller.dart';
import '../../../chemist_counter/presentation/widgets/prescription_scan_modal.dart';

class OcrScannerScreen extends ConsumerStatefulWidget {
  const OcrScannerScreen({super.key});

  @override
  ConsumerState<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends ConsumerState<OcrScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;

  // Review Form Controllers
  final _brandController = TextEditingController();
  final _saltController = TextEditingController();
  final _strengthController = TextEditingController();
  final _expiryController = TextEditingController();
  final _batchController = TextEditingController();
  final _quantityController = TextEditingController(text: '10');
  String _selectedForm = 'Tablet';
  String _selectedLocation = 'Living Room Drawer';

  MatchCandidate? _selectedCandidate;

  @override
  void dispose() {
    _brandController.dispose();
    _saltController.dispose();
    _strengthController.dispose();
    _expiryController.dispose();
    _batchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) return;

      setState(() {
        _imagePath = file.path;
      });

      await ref.read(ocrReviewStateProvider.notifier).scanImage(file.path);

      final state = ref.read(ocrReviewStateProvider);
      final result = state.valueOrNull;
      if (result != null) {
        _populateFieldsFromScan(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    }
  }

  void _populateFieldsFromScan(OcrScanResult result) {
    if (result.bestMatch != null) {
      _applyCandidate(result.bestMatch!);
    } else if (result.rawExtractedLines.isNotEmpty) {
      _brandController.text = result.rawExtractedLines.first;
    }

    if (result.detectedExpiryDate != null) {
      _expiryController.text = result.detectedExpiryDate!;
    } else {
      _expiryController.clear(); // Never insert fake dates
    }

    if (result.detectedBatchNumber != null) {
      _batchController.text = result.detectedBatchNumber!;
    } else {
      _batchController.clear();
    }
  }

  void _applyCandidate(MatchCandidate candidate) {
    setState(() {
      _selectedCandidate = candidate;
      _brandController.text = candidate.matchedRecord.brandName;
      _saltController.text = candidate.matchedRecord.activeSalt;
      _strengthController.text = candidate.matchedRecord.strength;
      _selectedForm = candidate.matchedRecord.dosageForm;
    });
  }

  Future<void> _commitToCabinet() async {
    if (_brandController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand name is required')),
      );
      return;
    }

    const uuid = Uuid();
    final item = CabinetItem(
      id: uuid.v4(),
      brandName: _brandController.text.trim(),
      activeSalt: _saltController.text.trim().isEmpty ? 'General Formulation' : _saltController.text.trim(),
      strength: _strengthController.text.trim(),
      form: _selectedForm,
      quantityRemaining: double.tryParse(_quantityController.text) ?? 10.0,
      printedExpiry: _expiryController.text.trim().isEmpty ? 'Unspecified' : _expiryController.text.trim(),
      storageLocation: _selectedLocation,
      profileId: 'profile-primary-self',
      createdAt: DateTime.now(),
    );

    await ref.read(cabinetNotifierProvider.notifier).addItem(item);

    ref.read(ocrReviewStateProvider.notifier).reset();
    setState(() {
      _imagePath = null;
      _selectedCandidate = null;
      _brandController.clear();
      _saltController.clear();
      _strengthController.clear();
      _expiryController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verified and saved ${item.brandName} to your cabinet!'),
          backgroundColor: AppColors.safe,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrReviewStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strip & Box OCR Scanner'),
      ),
      body: ocrState.when(
        data: (result) {
          if (_imagePath == null || result == null) {
            return _buildScannerPrompt();
          }
          return _buildReviewForm(result);
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Running ML Kit on-device text recognition...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Calculating Dice\'s coefficient fuzzy similarity against Indian database',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Text('Error: $err'),
        ),
      ),
    );
  }

  Widget _buildScannerPrompt() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primarySurfaceBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.document_scanner_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Capture Medicine Blister or Box',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Google ML Kit OCR processes packaging on-device. Fuzzy string matching resolves brand names with mathematical confidence scoring.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Privacy & Architecture Trust Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTrustChip(Icons.lock_outline_rounded, '100% Offline'),
                const SizedBox(width: 8),
                _buildTrustChip(Icons.bolt_rounded, 'Fuzzy Dice Match'),
                const SizedBox(width: 8),
                _buildTrustChip(Icons.verified_user_outlined, 'Zero Cloud Leak'),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => _captureImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => _captureImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const PrescriptionScanModal(),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.subtleShadow,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 26),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan Doctor Prescription Slip',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Parse printed hospital & clinic slips for chemist buying',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewForm(OcrScanResult result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo & Confidence Badge Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OCR Detection Result',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    if (_selectedCandidate != null)
                      ConfidenceBadgeUtils.buildBadgeWidget(
                        _selectedCandidate!.level,
                        _selectedCandidate!.confidencePercentage,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Low Confidence (<70%)', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 8),
                    if (result.detectedExpiryDate != null)
                      Text(
                        'Detected Expiry: ${result.detectedExpiryDate}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.safe),
                      )
                    else
                      const Text(
                        '⚠️ Expiry not detected (enter manually below)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger),
                      ),
                    if (result.detectedBatchNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Detected Batch: ${result.detectedBatchNumber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Informative banner if front plastic side of blister pack was photographed
          if (result.hasNoExtractedText) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.flip_to_back_rounded, color: AppColors.warning, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Printed Text Found (Front of Strip)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Most medicine blister strips print brand names, batch numbers, and expiry dates on the silver foil on the back. Flip the strip and tap "Scan Another Medicine" or enter details below.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // "Did you mean?" suggestions chips
          if (result.allCandidates.length > 1) ...[
            const Text(
              'Matched Suggestions (Tap to apply):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: result.allCandidates.take(3).map((candidate) {
                  final isSelected = _selectedCandidate?.matchedRecord.id == candidate.matchedRecord.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text('${candidate.matchedRecord.brandName} (${candidate.confidencePercentage}%)'),
                      backgroundColor: isSelected ? AppColors.primarySurface : AppColors.surfaceVariant,
                      onPressed: () => _applyCandidate(candidate),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(),
          const SizedBox(height: 12),

          // Human-in-the-Loop Editable Fields
          const Text(
            'Human-in-the-Loop Review (Edit before saving)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brandController,
            decoration: const InputDecoration(labelText: 'Brand Name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _saltController,
            decoration: const InputDecoration(labelText: 'Active Salt *'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _strengthController,
                  decoration: const InputDecoration(labelText: 'Strength'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  decoration: const InputDecoration(labelText: 'Expiry (MM/YYYY)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _batchController,
            decoration: const InputDecoration(labelText: 'Batch Number (Optional)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity Remaining'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedLocation,
                  decoration: const InputDecoration(labelText: 'Location'),
                  items: ['Living Room Drawer', 'Kitchen Stash', 'Fridge Door', 'First Aid Box']
                      .map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedLocation = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm & Save to Cabinet', style: TextStyle(fontSize: 16)),
              onPressed: _commitToCabinet,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Another Medicine'),
              onPressed: () {
                setState(() {
                  _imagePath = null;
                });
                ref.read(ocrReviewStateProvider.notifier).reset();
              },
            ),
          ),
        ],
      ),
    );
  }
}
