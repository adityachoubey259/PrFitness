import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

class DataExportService {
  DataExportService(this.database);

  final AppDatabase database;

  Future<File> exportJson() async {
    final ProfileRow? profile = await database.getProfile();

    final List<FoodEntry> foods = await database
        .select(database.foodEntries)
        .get();

    final List<ActivityEntry> activities = await database
        .select(database.activityEntries)
        .get();

    final List<WaterEntry> waters = await database
        .select(database.waterEntries)
        .get();

    final List<StudySession> study = await database
        .select(database.studySessions)
        .get();

    final List<Goal> goals = await database.select(database.goals).get();

    final List<GoalCompletion> goalCompletions = await database
        .select(database.goalCompletions)
        .get();

    final List<RoutineItem> routines = await database
        .select(database.routineItems)
        .get();

    final List<RoutineCompletion> routineCompletions = await database
        .select(database.routineCompletions)
        .get();

    final List<Reminder> reminders = await database
        .select(database.reminders)
        .get();

    final List<WeightEntry> weights = await database
        .select(database.weightEntries)
        .get();

    final List<AppSetting> settings = await database
        .select(database.appSettings)
        .get();

    String utc(DateTime value) => value.toUtc().toIso8601String();

    final Map<String, Object?> export = <String, Object?>{
      'format': 'prfitness-export',
      'formatVersion': 1,
      'databaseSchemaVersion': database.schemaVersion,
      'exportedAtUtc': utc(DateTime.now()),
      'profile': profile == null
          ? null
          : <String, Object?>{
              'id': profile.id,
              'name': profile.name,
              'birthDate': utc(profile.birthDate),
              'sex': profile.sex,
              'heightCm': profile.heightCm,
              'weightKg': profile.weightKg,
              'targetWeightKg': profile.targetWeightKg,
              'activityLevel': profile.activityLevel,
              'goal': profile.goal,
              'dailyStudyTargetMinutes': profile.dailyStudyTargetMinutes,
              'createdAt': utc(profile.createdAt),
              'updatedAt': utc(profile.updatedAt),
            },
      'foodEntries': foods
          .map(
            (FoodEntry item) => <String, Object?>{
              'id': item.id,
              'name': item.name,
              'calories': item.calories,
              'proteinG': item.proteinG,
              'carbsG': item.carbsG,
              'fatG': item.fatG,
              'mealType': item.mealType,
              'servingQuantity': item.servingQuantity,
              'servingUnit': item.servingUnit,
              'servingGrams': item.servingGrams,
              'occurredAt': utc(item.occurredAt),
            },
          )
          .toList(),
      'activityEntries': activities
          .map(
            (ActivityEntry item) => <String, Object?>{
              'id': item.id,
              'activityType': item.activityType,
              'intensity': item.intensity,
              'durationMinutes': item.durationMinutes,
              'distanceKm': item.distanceKm,
              'caloriesBurned': item.caloriesBurned,
              'occurredAt': utc(item.occurredAt),
            },
          )
          .toList(),
      'waterEntries': waters
          .map(
            (WaterEntry item) => <String, Object?>{
              'id': item.id,
              'amountMl': item.amountMl,
              'occurredAt': utc(item.occurredAt),
            },
          )
          .toList(),
      'studySessions': study
          .map(
            (StudySession item) => <String, Object?>{
              'id': item.id,
              'subject': item.subject,
              'startedAt': utc(item.startedAt),
              'endedAt': utc(item.endedAt),
              'durationSeconds': item.durationSeconds,
              'notes': item.notes,
              'createdAt': utc(item.createdAt),
            },
          )
          .toList(),
      'goals': goals
          .map(
            (Goal item) => <String, Object?>{
              'id': item.id,
              'title': item.title,
              'category': item.category,
              'frequency': item.frequency,
              'active': item.active,
              'createdAt': utc(item.createdAt),
              'updatedAt': utc(item.updatedAt),
            },
          )
          .toList(),
      'goalCompletions': goalCompletions
          .map(
            (GoalCompletion item) => <String, Object?>{
              'id': item.id,
              'goalId': item.goalId,
              'completedAt': utc(item.completedAt),
            },
          )
          .toList(),
      'routines': routines
          .map(
            (RoutineItem item) => <String, Object?>{
              'id': item.id,
              'title': item.title,
              'routineType': item.routineType,
              'sortOrder': item.sortOrder,
              'active': item.active,
              'createdAt': utc(item.createdAt),
              'updatedAt': utc(item.updatedAt),
            },
          )
          .toList(),
      'routineCompletions': routineCompletions
          .map(
            (RoutineCompletion item) => <String, Object?>{
              'id': item.id,
              'routineId': item.routineId,
              'completedAt': utc(item.completedAt),
            },
          )
          .toList(),
      'reminders': reminders
          .map(
            (Reminder item) => <String, Object?>{
              'id': item.id,
              'title': item.title,
              'body': item.body,
              'category': item.category,
              'scheduleType': item.scheduleType,
              'hour': item.hour,
              'minute': item.minute,
              'weekdaysMask': item.weekdaysMask,
              'scheduledAt': item.scheduledAt == null
                  ? null
                  : utc(item.scheduledAt!),
              'notificationBaseId': item.notificationBaseId,
              'enabled': item.enabled,
              'createdAt': utc(item.createdAt),
              'updatedAt': utc(item.updatedAt),
            },
          )
          .toList(),
      'weightEntries': weights
          .map(
            (WeightEntry item) => <String, Object?>{
              'id': item.id,
              'weightKg': item.weightKg,
              'note': item.note,
              'occurredAt': utc(item.occurredAt),
              'createdAt': utc(item.createdAt),
            },
          )
          .toList(),
      'settings': settings
          .map(
            (AppSetting item) => <String, Object?>{
              'key': item.key,
              'value': item.value,
            },
          )
          .toList(),
    };

    final Directory root = await getApplicationDocumentsDirectory();

    final Directory exports = Directory(
      '${root.path}'
      '${Platform.pathSeparator}'
      'PrFitness'
      '${Platform.pathSeparator}'
      'exports',
    );

    await exports.create(recursive: true);

    final DateTime now = DateTime.now();

    String two(int value) => value.toString().padLeft(2, '0');

    final String filename =
        'prfitness_${now.year}'
        '${two(now.month)}'
        '${two(now.day)}_'
        '${two(now.hour)}'
        '${two(now.minute)}'
        '${two(now.second)}.json';

    final File file = File(
      '${exports.path}'
      '${Platform.pathSeparator}'
      '$filename',
    );

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');

    await file.writeAsString(encoder.convert(export), flush: true);

    return file;
  }
}
