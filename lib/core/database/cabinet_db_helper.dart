import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';

class CabinetDbHelper {
  CabinetDbHelper._();
  static final CabinetDbHelper instance = CabinetDbHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbDirectory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbDirectory.path, AppConstants.userCabinetDbFileName);

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE family_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        relation TEXT NOT NULL,
        allergies TEXT,
        is_primary INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE cabinet_items (
        id TEXT PRIMARY KEY,
        brand_name TEXT NOT NULL,
        active_salt TEXT NOT NULL,
        strength TEXT NOT NULL,
        form TEXT NOT NULL,
        quantity_remaining REAL NOT NULL,
        printed_expiry TEXT NOT NULL,
        opened_on_date TEXT,
        is_opened INTEGER DEFAULT 0,
        storage_location TEXT,
        symptom_tags TEXT,
        profile_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(profile_id) REFERENCES family_profiles(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE intake_schedules (
        id TEXT PRIMARY KEY,
        cabinet_item_id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        time_of_day TEXT NOT NULL,
        meal_relation TEXT NOT NULL,
        dose_amount REAL NOT NULL,
        is_antibiotic INTEGER DEFAULT 0,
        course_total_days INTEGER,
        course_current_day INTEGER,
        FOREIGN KEY(cabinet_item_id) REFERENCES cabinet_items(id) ON DELETE CASCADE
      );
    ''');

    // Create default Primary Profile: "Self"
    await db.insert('family_profiles', {
      'id': 'profile-primary-self',
      'name': 'Primary User',
      'relation': 'Self',
      'allergies': '[]',
      'is_primary': 1,
    });
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
