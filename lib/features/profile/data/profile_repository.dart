import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_factory.dart';

class ProfileRepository {
  ProfileRepository(this.database);

  final AppDatabase database;

  Future<ProfileRow?> load() {
    return database.getProfile();
  }

  Future<ProfileRow> save({
    ProfileRow? existing,
    required String name,
    required DateTime birthDate,
    required String sex,
    required double heightCm,
    required double weightKg,
    double? targetWeightKg,
    required String activityLevel,
    required String goal,
    required int dailyStudyTargetMinutes,
  }) async {
    final DateTime now = DateTime.now();

    final String id = existing?.id ?? IdFactory.uuidV4();

    await database.upsertProfile(
      ProfilesCompanion(
        id: Value(id),
        name: Value(name.trim()),
        birthDate: Value(birthDate),
        sex: Value(sex),
        heightCm: Value(heightCm),
        weightKg: Value(weightKg),
        targetWeightKg: Value(targetWeightKg),
        activityLevel: Value(activityLevel),
        goal: Value(goal),
        dailyStudyTargetMinutes: Value(dailyStudyTargetMinutes),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
      ),
    );

    final ProfileRow? saved = await database.getProfile();

    if (saved == null) {
      throw StateError('Profile could not be reloaded after save.');
    }

    return saved;
  }
}
