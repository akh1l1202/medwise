import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';

class BundledDbHelper {
  BundledDbHelper._();
  static final BundledDbHelper instance = BundledDbHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // If running on desktop (Windows/Linux/macOS) initialize ffi
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbDirectory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbDirectory.path, AppConstants.bundledDbFileName);
    final dbFile = File(dbPath);

    // Copy bundled database from assets if not present or if asset has been updated
    bool shouldCopy = !await dbFile.exists();
    if (!shouldCopy) {
      try {
        final ByteData data = await rootBundle.load(AppConstants.bundledDbAssetPath);
        if (await dbFile.length() != data.lengthInBytes) {
          shouldCopy = true;
          debugPrint('Bundled DB asset updated, refreshing local database copy.');
        }
      } catch (_) {}
    }

    if (shouldCopy) {
      try {
        final ByteData data = await rootBundle.load(AppConstants.bundledDbAssetPath);
        final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(dbPath).writeAsBytes(bytes, flush: true);
        debugPrint('Copied bundled Indian Medicines DB to: $dbPath (${bytes.length} bytes)');
      } catch (e) {
        debugPrint('Error loading bundled DB from asset: $e');
        // If asset loading fails (e.g. CLI runner), try reading directly from relative path
        final localAsset = File(AppConstants.bundledDbAssetPath);
        if (await localAsset.exists()) {
          await localAsset.copy(dbPath);
          debugPrint('Copied bundled DB from local file path: $dbPath');
        }
      }
    }

    return await openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: true,
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
