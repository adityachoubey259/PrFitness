import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/core/database/app_database.dart';
import 'package:prfitness/features/history/data/history_repository.dart';

void main() {
  test('weight record updates profile atomically', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

    final DateTime now = DateTime.now();

    await database.upsertProfile(
      ProfilesCompanion(
        id: const Value('profile-1'),
        name: const Value('Test User'),
        birthDate: Value(DateTime(1995, 1, 1)),
        sex: const Value('male'),
        heightCm: const Value(180),
        weightKg: const Value(80),
        activityLevel: const Value('moderate'),
        goal: const Value('maintain'),
        dailyStudyTargetMinutes: const Value(120),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final ProfileRow profile = (await database.getProfile())!;

    final ProfileRow updated = await HistoryRepository(database)
        .recordWeight(profile: profile, weightKg: 78.5);

    expect(updated.weightKg, 78.5);

    final List<WeightEntry> weights = await database
        .select(database.weightEntries)
        .get();

    expect(weights, hasLength(1));

    expect(weights.first.weightKg, 78.5);

    await database.close();
  });
}
