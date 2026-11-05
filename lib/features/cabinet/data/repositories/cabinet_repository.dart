import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:medwise/core/database/cabinet_db_helper.dart';
import 'package:medwise/features/cabinet/data/models/cabinet_item.dart';
import 'package:medwise/features/cabinet/data/models/intake_schedule.dart';

final cabinetRepositoryProvider = Provider<CabinetRepository>((ref) {
  return CabinetRepository(CabinetDbHelper.instance);
});

class CabinetRepository {
  final CabinetDbHelper _dbHelper;

  CabinetRepository(this._dbHelper);

  // --- Cabinet Items CRUD ---

  Future<List<CabinetItem>> getCabinetItems({String? profileId}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results;
    if (profileId != null && profileId.isNotEmpty) {
      results = await db.query(
        'cabinet_items',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'created_at DESC',
      );
    } else {
      results = await db.query('cabinet_items', orderBy: 'created_at DESC');
    }
    return results.map((map) => CabinetItem.fromMap(map)).toList();
  }

  Future<CabinetItem?> getCabinetItemById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'cabinet_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return CabinetItem.fromMap(results.first);
  }

  Future<List<CabinetItem>> findByActiveSalt(String activeSalt) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'cabinet_items',
      where: 'LOWER(active_salt) = LOWER(?)',
      whereArgs: [activeSalt.trim()],
    );
    return results.map((map) => CabinetItem.fromMap(map)).toList();
  }

  Future<List<CabinetItem>> searchCabinet(String query) async {
    final db = await _dbHelper.database;
    final pattern = '%${query.trim().toLowerCase()}%';
    final results = await db.rawQuery('''
      SELECT * FROM cabinet_items
      WHERE LOWER(brand_name) LIKE ? 
         OR LOWER(active_salt) LIKE ? 
         OR LOWER(symptom_tags) LIKE ?
         OR LOWER(storage_location) LIKE ?
      ORDER BY created_at DESC
    ''', [pattern, pattern, pattern, pattern]);
    return results.map((map) => CabinetItem.fromMap(map)).toList();
  }

  Future<void> addCabinetItem(CabinetItem item) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cabinet_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCabinetItem(CabinetItem item) async {
    final db = await _dbHelper.database;
    await db.update(
      'cabinet_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteCabinetItem(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'cabinet_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark liquid/drop opened on today's date (starts 28-day countdown)
  Future<void> markOpenedToday(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'cabinet_items',
      {
        'is_opened': 1,
        'opened_on_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Decrement stock upon user marking dose as taken
  Future<double> decrementStock(String id, double amount) async {
    final item = await getCabinetItemById(id);
    if (item == null) return 0.0;

    final newQuantity = (item.quantityRemaining - amount).clamp(0.0, double.infinity);
    final updated = item.copyWith(quantityRemaining: newQuantity);
    await updateCabinetItem(updated);
    return newQuantity;
  }

  // --- Intake Schedules CRUD ---

  Future<List<IntakeSchedule>> getSchedules({String? profileId}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results;
    if (profileId != null && profileId.isNotEmpty) {
      results = await db.query(
        'intake_schedules',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'time_of_day ASC',
      );
    } else {
      results = await db.query('intake_schedules', orderBy: 'time_of_day ASC');
    }
    return results.map((map) => IntakeSchedule.fromMap(map)).toList();
  }

  Future<void> addSchedule(IntakeSchedule schedule) async {
    final db = await _dbHelper.database;
    await db.insert(
      'intake_schedules',
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSchedule(IntakeSchedule schedule) async {
    final db = await _dbHelper.database;
    await db.update(
      'intake_schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<void> deleteSchedule(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'intake_schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increment antibiotic current day (e.g. Day 2 of 5 -> Day 3 of 5)
  Future<void> advanceAntibioticDay(String scheduleId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'intake_schedules',
      where: 'id = ? AND is_antibiotic = 1',
      whereArgs: [scheduleId],
      limit: 1,
    );
    if (results.isEmpty) return;

    final schedule = IntakeSchedule.fromMap(results.first);
    final currentDay = schedule.courseCurrentDay ?? 1;
    final totalDays = schedule.courseTotalDays ?? currentDay;

    if (currentDay < totalDays) {
      await updateSchedule(schedule.copyWith(courseCurrentDay: currentDay + 1));
    }
  }
}
