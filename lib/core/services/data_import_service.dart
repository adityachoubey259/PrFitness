import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

class ImportSummary {
  const ImportSummary({required this.records});

  final int records;
}

class DataImportService {
  DataImportService(this.database);

  final AppDatabase database;

  Future<ImportSummary> restoreJson(String source) async {
    final dynamic decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be a JSON object.');
    }
    if (decoded['format'] != 'prfitness-export') {
      throw const FormatException('This is not a PrFitness backup.');
    }

    final int version = (decoded['formatVersion'] as num?)?.toInt() ?? -1;
    if (version != 1) {
      throw FormatException('Unsupported PrFitness backup version: $version.');
    }

    DateTime dt(dynamic value) {
      if (value is! String) {
        throw const FormatException('Invalid date value in backup.');
      }
      return DateTime.parse(value).toLocal();
    }

    List<Map<String, dynamic>> list(String key) {
      final dynamic value = decoded[key];
      if (value == null) return <Map<String, dynamic>>[];
      if (value is! List) throw FormatException('$key must be an array.');
      return value
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    int count = 0;

    await database.transaction(() async {
      await database.customStatement(
        "INSERT INTO app_settings(key, value) VALUES('sync.suppress','1') "
        "ON CONFLICT(key) DO UPDATE SET value='1'",
      );

      try {
        await database.delete(database.routineCompletions).go();
        await database.delete(database.goalCompletions).go();
        await database.delete(database.reminders).go();
        await database.delete(database.routineItems).go();
        await database.delete(database.goals).go();
        await database.delete(database.studySessions).go();
        await database.delete(database.waterEntries).go();
        await database.delete(database.activityEntries).go();
        await database.delete(database.foodEntries).go();
        await database.delete(database.weightEntries).go();
        await database.delete(database.profiles).go();
        await database.customStatement(
          "DELETE FROM app_settings WHERE key NOT LIKE 'sync.%'",
        );

        final dynamic profileRaw = decoded['profile'];
        if (profileRaw is Map) {
          final Map<String, dynamic> profile = Map<String, dynamic>.from(
            profileRaw,
          );
          await database.upsertProfile(
            ProfilesCompanion(
              id: Value(profile['id'] as String),
              name: Value(profile['name'] as String),
              birthDate: Value(dt(profile['birthDate'])),
              sex: Value(profile['sex'] as String),
              heightCm: Value((profile['heightCm'] as num).toDouble()),
              weightKg: Value((profile['weightKg'] as num).toDouble()),
              targetWeightKg: Value(
                (profile['targetWeightKg'] as num?)?.toDouble(),
              ),
              activityLevel: Value(profile['activityLevel'] as String),
              goal: Value(profile['goal'] as String),
              dailyStudyTargetMinutes: Value(
                (profile['dailyStudyTargetMinutes'] as num).toInt(),
              ),
              createdAt: Value(dt(profile['createdAt'])),
              updatedAt: Value(dt(profile['updatedAt'])),
            ),
          );
          count++;
        }

        for (final Map<String, dynamic> item in list('foodEntries')) {
          await database
              .into(database.foodEntries)
              .insert(
                FoodEntriesCompanion(
                  id: Value(item['id'] as String),
                  name: Value(item['name'] as String),
                  calories: Value((item['calories'] as num).toDouble()),
                  proteinG: Value((item['proteinG'] as num?)?.toDouble()),
                  carbsG: Value((item['carbsG'] as num?)?.toDouble()),
                  fatG: Value((item['fatG'] as num?)?.toDouble()),
                  mealType: Value((item['mealType'] as String?) ?? 'snack'),
                  servingQuantity: Value(
                    (item['servingQuantity'] as num?)?.toDouble() ?? 1,
                  ),
                  servingUnit: Value(
                    (item['servingUnit'] as String?) ?? 'serving',
                  ),
                  servingGrams: Value(
                    (item['servingGrams'] as num?)?.toDouble(),
                  ),
                  occurredAt: Value(dt(item['occurredAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('activityEntries')) {
          await database
              .into(database.activityEntries)
              .insert(
                ActivityEntriesCompanion(
                  id: Value(item['id'] as String),
                  activityType: Value(item['activityType'] as String),
                  intensity: Value(item['intensity'] as String),
                  durationMinutes: Value(
                    (item['durationMinutes'] as num).toInt(),
                  ),
                  distanceKm: Value((item['distanceKm'] as num?)?.toDouble()),
                  caloriesBurned: Value(
                    (item['caloriesBurned'] as num).toDouble(),
                  ),
                  occurredAt: Value(dt(item['occurredAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('waterEntries')) {
          await database
              .into(database.waterEntries)
              .insert(
                WaterEntriesCompanion(
                  id: Value(item['id'] as String),
                  amountMl: Value((item['amountMl'] as num).toInt()),
                  occurredAt: Value(dt(item['occurredAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('studySessions')) {
          await database
              .into(database.studySessions)
              .insert(
                StudySessionsCompanion(
                  id: Value(item['id'] as String),
                  subject: Value(item['subject'] as String),
                  startedAt: Value(dt(item['startedAt'])),
                  endedAt: Value(dt(item['endedAt'])),
                  durationSeconds: Value(
                    (item['durationSeconds'] as num).toInt(),
                  ),
                  notes: Value(item['notes'] as String?),
                  createdAt: Value(dt(item['createdAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('goals')) {
          await database
              .into(database.goals)
              .insert(
                GoalsCompanion(
                  id: Value(item['id'] as String),
                  title: Value(item['title'] as String),
                  category: Value(item['category'] as String),
                  frequency: Value(item['frequency'] as String),
                  active: Value(item['active'] as bool),
                  createdAt: Value(dt(item['createdAt'])),
                  updatedAt: Value(dt(item['updatedAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('goalCompletions')) {
          await database
              .into(database.goalCompletions)
              .insert(
                GoalCompletionsCompanion(
                  id: Value(item['id'] as String),
                  goalId: Value(item['goalId'] as String),
                  completedAt: Value(dt(item['completedAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('routines')) {
          await database
              .into(database.routineItems)
              .insert(
                RoutineItemsCompanion(
                  id: Value(item['id'] as String),
                  title: Value(item['title'] as String),
                  routineType: Value(item['routineType'] as String),
                  sortOrder: Value((item['sortOrder'] as num).toInt()),
                  active: Value(item['active'] as bool),
                  createdAt: Value(dt(item['createdAt'])),
                  updatedAt: Value(dt(item['updatedAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('routineCompletions')) {
          await database
              .into(database.routineCompletions)
              .insert(
                RoutineCompletionsCompanion(
                  id: Value(item['id'] as String),
                  routineId: Value(item['routineId'] as String),
                  completedAt: Value(dt(item['completedAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('reminders')) {
          await database
              .into(database.reminders)
              .insert(
                RemindersCompanion(
                  id: Value(item['id'] as String),
                  title: Value(item['title'] as String),
                  body: Value(item['body'] as String),
                  category: Value(item['category'] as String),
                  scheduleType: Value(item['scheduleType'] as String),
                  hour: Value((item['hour'] as num).toInt()),
                  minute: Value((item['minute'] as num).toInt()),
                  weekdaysMask: Value((item['weekdaysMask'] as num).toInt()),
                  scheduledAt: Value(
                    item['scheduledAt'] == null
                        ? null
                        : dt(item['scheduledAt']),
                  ),
                  notificationBaseId: Value(
                    (item['notificationBaseId'] as num).toInt(),
                  ),
                  enabled: Value(item['enabled'] as bool),
                  createdAt: Value(dt(item['createdAt'])),
                  updatedAt: Value(dt(item['updatedAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('weightEntries')) {
          await database
              .into(database.weightEntries)
              .insert(
                WeightEntriesCompanion(
                  id: Value(item['id'] as String),
                  weightKg: Value((item['weightKg'] as num).toDouble()),
                  note: Value(item['note'] as String?),
                  occurredAt: Value(dt(item['occurredAt'])),
                  createdAt: Value(dt(item['createdAt'])),
                ),
              );
          count++;
        }

        for (final Map<String, dynamic> item in list('settings')) {
          final String key = item['key'] as String;
          if (key.startsWith('sync.')) continue;
          await database.writeSetting(key, item['value'] as String);
        }
      } finally {
        await database.customStatement(
          "INSERT INTO app_settings(key, value) VALUES('sync.suppress','0') "
          "ON CONFLICT(key) DO UPDATE SET value='0'",
        );
      }
    });

    return ImportSummary(records: count);
  }
}
