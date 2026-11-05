import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/cabinet_db_helper.dart';
import '../models/family_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(CabinetDbHelper.instance);
});

class ProfileRepository {
  final CabinetDbHelper _dbHelper;

  ProfileRepository(this._dbHelper);

  Future<List<FamilyProfile>> getProfiles() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'family_profiles',
      orderBy: 'is_primary DESC, name ASC',
    );
    return results.map((map) => FamilyProfile.fromMap(map)).toList();
  }

  Future<FamilyProfile?> getPrimaryProfile() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'family_profiles',
      where: 'is_primary = 1',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FamilyProfile.fromMap(results.first);
  }

  Future<FamilyProfile?> getProfileById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'family_profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return FamilyProfile.fromMap(results.first);
  }

  Future<void> saveProfile(FamilyProfile profile) async {
    final db = await _dbHelper.database;
    await db.insert(
      'family_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProfile(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'family_profiles',
      where: 'id = ? AND is_primary = 0', // Safeguard primary profile
      whereArgs: [id],
    );
  }
}
