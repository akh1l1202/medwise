import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/features/ocr_ingestion/data/models/ocr_scan_result.dart';
import 'package:medwise/features/ocr_ingestion/domain/services/ocr_scanner_service.dart';

final ocrReviewStateProvider = StateNotifierProvider<OcrReviewController, AsyncValue<OcrScanResult?>>((ref) {
  final scanner = ref.watch(ocrScannerServiceProvider);
  return OcrReviewController(scanner);
});

class OcrReviewController extends StateNotifier<AsyncValue<OcrScanResult?>> {
  final OcrScannerService _scannerService;

  OcrReviewController(this._scannerService) : super(const AsyncValue.data(null));

  Future<void> scanImage(String imagePath) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _scannerService.processImage(imagePath);
    });
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
