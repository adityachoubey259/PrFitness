import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_factory.dart';

enum HistoryType { food, activity, water, study, weight }

class HistorySnapshot {
  const HistorySnapshot({
    required this.foods,
    required this.activities,
    required this.waters,
    required this.study,
    required this.weights,
  });

  final List<FoodEntry> foods;
  final List<ActivityEntry> activities;
  final List<WaterEntry> waters;
  final List<StudySession> study;
  final List<WeightEntry> weights;
}

class HistoryRepository {
  HistoryRepository(this.database);

  final AppDatabase database;

  Future<HistorySnapshot> load({int days = 90}) async {
    final DateTime now = DateTime.now();

    final DateTime start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final List<FoodEntry> foods =
        await (database.select(database.foodEntries)
              ..where(
                (FoodEntries table) =>
                    table.occurredAt.isBiggerOrEqualValue(start),
              )
              ..orderBy(<OrderClauseGenerator<FoodEntries>>[
                (FoodEntries table) => OrderingTerm.desc(table.occurredAt),
              ]))
            .get();

    final List<ActivityEntry> activities =
        await (database.select(database.activityEntries)
              ..where(
                (ActivityEntries table) =>
                    table.occurredAt.isBiggerOrEqualValue(start),
              )
              ..orderBy(<OrderClauseGenerator<ActivityEntries>>[
                (ActivityEntries table) => OrderingTerm.desc(table.occurredAt),
              ]))
            .get();

    final List<WaterEntry> waters =
        await (database.select(database.waterEntries)
              ..where(
                (WaterEntries table) =>
                    table.occurredAt.isBiggerOrEqualValue(start),
              )
              ..orderBy(<OrderClauseGenerator<WaterEntries>>[
                (WaterEntries table) => OrderingTerm.desc(table.occurredAt),
              ]))
            .get();

    final List<StudySession> study =
        await (database.select(database.studySessions)
              ..where(
                (StudySessions table) =>
                    table.startedAt.isBiggerOrEqualValue(start),
              )
              ..orderBy(<OrderClauseGenerator<StudySessions>>[
                (StudySessions table) => OrderingTerm.desc(table.startedAt),
              ]))
            .get();

    final List<WeightEntry> weights =
        await (database.select(database.weightEntries)
              ..where(
                (WeightEntries table) =>
                    table.occurredAt.isBiggerOrEqualValue(start),
              )
              ..orderBy(<OrderClauseGenerator<WeightEntries>>[
                (WeightEntries table) => OrderingTerm.desc(table.occurredAt),
              ]))
            .get();

    return HistorySnapshot(
      foods: foods,
      activities: activities,
      waters: waters,
      study: study,
      weights: weights,
    );
  }

  Future<ProfileRow> recordWeight({
    required ProfileRow profile,
    required double weightKg,
    String? note,
  }) async {
    if (weightKg < 25 || weightKg > 400) {
      throw ArgumentError('Weight must be between 25 and 400 kg.');
    }

    final DateTime now = DateTime.now();

    await database.transaction(() async {
      await database
          .into(database.weightEntries)
          .insert(
            WeightEntriesCompanion.insert(
              id: IdFactory.uuidV4(),
              weightKg: weightKg,
              note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
              occurredAt: now,
              createdAt: now,
            ),
          );

      await (database.update(
        database.profiles,
      )..where((Profiles table) => table.id.equals(profile.id))).write(
        ProfilesCompanion(weightKg: Value(weightKg), updatedAt: Value(now)),
      );
    });

    final ProfileRow? updated = await database.getProfile();

    if (updated == null) {
      throw StateError('Profile could not be reloaded.');
    }

    return updated;
  }

  Future<void> delete({
    required HistoryType type,
    required String id,
    ProfileRow? profile,
  }) async {
    switch (type) {
      case HistoryType.food:
        await (database.delete(
          database.foodEntries,
        )..where((FoodEntries table) => table.id.equals(id))).go();

      case HistoryType.activity:
        await (database.delete(
          database.activityEntries,
        )..where((ActivityEntries table) => table.id.equals(id))).go();

      case HistoryType.water:
        await (database.delete(
          database.waterEntries,
        )..where((WaterEntries table) => table.id.equals(id))).go();

      case HistoryType.study:
        await (database.delete(
          database.studySessions,
        )..where((StudySessions table) => table.id.equals(id))).go();

      case HistoryType.weight:
        await _deleteWeight(id: id, profile: profile);
    }
  }

  Future<void> _deleteWeight({required String id, ProfileRow? profile}) async {
    await database.transaction(() async {
      await (database.delete(
        database.weightEntries,
      )..where((WeightEntries table) => table.id.equals(id))).go();

      if (profile == null) {
        return;
      }

      final WeightEntry? latest =
          await (database.select(database.weightEntries)
                ..orderBy(<OrderClauseGenerator<WeightEntries>>[
                  (WeightEntries table) => OrderingTerm.desc(table.occurredAt),
                ])
                ..limit(1))
              .getSingleOrNull();

      if (latest != null) {
        await (database.update(
          database.profiles,
        )..where((Profiles table) => table.id.equals(profile.id))).write(
          ProfilesCompanion(
            weightKg: Value(latest.weightKg),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}
