import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medwise/core/database/bundled_db_helper.dart';
import 'package:medwise/features/medicine_catalog/data/models/medicine_record.dart';

final medicineCatalogRepositoryProvider = Provider<MedicineCatalogRepository>((ref) {
  return MedicineCatalogRepository(BundledDbHelper.instance);
});

class MedicineCatalogRepository {
  final BundledDbHelper _dbHelper;

  MedicineCatalogRepository(this._dbHelper);

  /// Sub-millisecond autocomplete using SQLite FTS5 Full-Text Search.
  /// Supports prefix search (e.g., 'Dol*' or 'Paracet*').
  Future<List<MedicineRecord>> searchMedicines(String query, {int limit = 20}) async {
    final cleanQuery = query.trim().replaceAll("'", "''");
    if (cleanQuery.isEmpty) return [];

    final db = await _dbHelper.database;

    try {
      // Extract alphanumeric tokens for robust FTS5 prefix query (e.g. "Pan-D" -> "Pan* D*")
      final tokens = query
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 2)
          .toList();

      if (tokens.isNotEmpty) {
        final ftsQuery = tokens.map((t) => '$t*').join(' ');
        final results = await db.rawQuery('''
          SELECT m.* 
          FROM medicines m
          JOIN medicines_fts fts ON m.id = fts.rowid
          WHERE medicines_fts MATCH ?
          LIMIT ?
        ''', [ftsQuery, limit]);

        if (results.isNotEmpty) {
          return results.map((map) => MedicineRecord.fromMap(map)).toList();
        }
      }
    } catch (_) {
      // Fallback to standard LIKE if FTS fails
    }

    final likePattern = '%$cleanQuery%';
    final results = await db.rawQuery('''
      SELECT * FROM medicines
      WHERE brand_name LIKE ? OR active_salt LIKE ?
      ORDER BY brand_name ASC
      LIMIT ?
    ''', [likePattern, likePattern, limit]);

    return results.map((map) => MedicineRecord.fromMap(map)).toList();
  }

  /// Retrieve all brand equivalents sharing the specified active salt.
  Future<List<MedicineRecord>> findByActiveSalt(String activeSalt) async {
    final cleanSalt = activeSalt.trim();
    if (cleanSalt.isEmpty) return [];

    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT * FROM medicines
      WHERE LOWER(active_salt) = LOWER(?)
      ORDER BY brand_name ASC
    ''', [cleanSalt]);

    return results.map((map) => MedicineRecord.fromMap(map)).toList();
  }

  /// Search medicines for emergency 2:00 AM symptom lookup (e.g. 'Acidity', 'Fever')
  Future<List<MedicineRecord>> findBySymptom(String symptom) async {
    final cleanSymptom = symptom.trim();
    if (cleanSymptom.isEmpty) return [];

    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT * FROM medicines
      WHERE common_symptoms LIKE ?
      ORDER BY brand_name ASC
    ''', ['%$cleanSymptom%']);

    return results.map((map) => MedicineRecord.fromMap(map)).toList();
  }

  /// Retrieve all medicines in catalog
  Future<List<MedicineRecord>> getAllMedicines({int limit = 100}) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'medicines',
      orderBy: 'brand_name ASC',
      limit: limit,
    );
    return results.map((map) => MedicineRecord.fromMap(map)).toList();
  }
}
