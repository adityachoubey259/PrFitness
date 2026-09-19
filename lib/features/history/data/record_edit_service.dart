import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class UndoRecord {
  const UndoRecord({required this.type, required this.json});
  final String type;
  final String json;
}

class RecordEditService {
  RecordEditService(this.database);
  final AppDatabase database;

  Future<void> updateFood(
    FoodEntry row, {
    required String name,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) async {
    if (name.trim().isEmpty ||
        calories < 0 ||
        proteinG < 0 ||
        carbsG < 0 ||
        fatG < 0) {
      throw ArgumentError('Food values must be valid and non-negative.');
    }
    await (database.update(
      database.foodEntries,
    )..where((t) => t.id.equals(row.id))).write(
      FoodEntriesCompanion(
        name: Value(name.trim()),
        calories: Value(calories),
        proteinG: Value(proteinG),
        carbsG: Value(carbsG),
        fatG: Value(fatG),
      ),
    );
  }

  Future<void> updateActivity(
    ActivityEntry row, {
    required String type,
    required String intensity,
    required int minutes,
    double? distanceKm,
    required double calories,
  }) async {
    if (type.trim().isEmpty ||
        intensity.trim().isEmpty ||
        minutes <= 0 ||
        calories < 0 ||
        (distanceKm != null && distanceKm < 0)) {
      throw ArgumentError('Activity values are invalid.');
    }
    await (database.update(
      database.activityEntries,
    )..where((t) => t.id.equals(row.id))).write(
      ActivityEntriesCompanion(
        activityType: Value(type.trim()),
        intensity: Value(intensity.trim()),
        durationMinutes: Value(minutes),
        distanceKm: Value(distanceKm),
        caloriesBurned: Value(calories),
      ),
    );
  }

  Future<void> updateWater(WaterEntry row, int ml) async {
    if (ml <= 0 || ml > 10000) throw ArgumentError('Water must be 1–10000 ml.');
    await (database.update(database.waterEntries)
          ..where((t) => t.id.equals(row.id)))
        .write(WaterEntriesCompanion(amountMl: Value(ml)));
  }

  Future<void> updateStudy(
    StudySession row, {
    required String subject,
    required int durationMinutes,
    String? notes,
  }) async {
    if (subject.trim().isEmpty ||
        durationMinutes <= 0 ||
        durationMinutes > 1440) {
      throw ArgumentError('Study values are invalid.');
    }
    final seconds = durationMinutes * 60;
    await (database.update(
      database.studySessions,
    )..where((t) => t.id.equals(row.id))).write(
      StudySessionsCompanion(
        subject: Value(subject.trim()),
        durationSeconds: Value(seconds),
        endedAt: Value(row.startedAt.add(Duration(seconds: seconds))),
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
      ),
    );
  }

  Future<void> updateWeight(WeightEntry row, double kg, String? note) async {
    if (kg < 25 || kg > 400) throw ArgumentError('Weight must be 25–400 kg.');
    await database.transaction(() async {
      await (database.update(
        database.weightEntries,
      )..where((t) => t.id.equals(row.id))).write(
        WeightEntriesCompanion(
          weightKg: Value(kg),
          note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
        ),
      );
      final latest =
          await (database.select(database.weightEntries)
                ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                ..limit(1))
              .getSingleOrNull();
      final profile = await database.getProfile();
      if (latest != null && profile != null && latest.id == row.id) {
        await (database.update(
          database.profiles,
        )..where((t) => t.id.equals(profile.id))).write(
          ProfilesCompanion(
            weightKg: Value(kg),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  Future<void> updateGoal(
    Goal row, {
    required String title,
    required String category,
    required String frequency,
    required bool active,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Goal title is required.');
    await (database.update(
      database.goals,
    )..where((t) => t.id.equals(row.id))).write(
      GoalsCompanion(
        title: Value(title.trim()),
        category: Value(category.trim()),
        frequency: Value(frequency.trim()),
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateRoutine(
    RoutineItem row, {
    required String title,
    required String routineType,
    required int sortOrder,
    required bool active,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Routine title is required.');
    await (database.update(
      database.routineItems,
    )..where((t) => t.id.equals(row.id))).write(
      RoutineItemsCompanion(
        title: Value(title.trim()),
        routineType: Value(routineType.trim()),
        sortOrder: Value(sortOrder),
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateReminder(
    Reminder row, {
    required String title,
    required String body,
    required int hour,
    required int minute,
    required bool enabled,
  }) async {
    if (title.trim().isEmpty ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw ArgumentError('Reminder values are invalid.');
    }
    await database.upsertReminder(
      RemindersCompanion(
        id: Value(row.id),
        title: Value(title.trim()),
        body: Value(body.trim()),
        category: Value(row.category),
        scheduleType: Value(row.scheduleType),
        hour: Value(hour),
        minute: Value(minute),
        weekdaysMask: Value(row.weekdaysMask),
        scheduledAt: Value(row.scheduledAt),
        notificationBaseId: Value(row.notificationBaseId),
        enabled: Value(enabled),
        createdAt: Value(row.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<UndoRecord> deleteFood(FoodEntry row) async {
    final token = UndoRecord(type: 'food', json: jsonEncode(_foodJson(row)));
    await (database.delete(
      database.foodEntries,
    )..where((t) => t.id.equals(row.id))).go();
    return token;
  }

  Future<UndoRecord> deleteActivity(ActivityEntry row) async {
    final token = UndoRecord(
      type: 'activity',
      json: jsonEncode(_activityJson(row)),
    );
    await (database.delete(
      database.activityEntries,
    )..where((t) => t.id.equals(row.id))).go();
    return token;
  }

  Future<UndoRecord> deleteWater(WaterEntry row) async {
    final token = UndoRecord(type: 'water', json: jsonEncode(_waterJson(row)));
    await (database.delete(
      database.waterEntries,
    )..where((t) => t.id.equals(row.id))).go();
    return token;
  }

  Future<UndoRecord> deleteStudy(StudySession row) async {
    final token = UndoRecord(type: 'study', json: jsonEncode(_studyJson(row)));
    await (database.delete(
      database.studySessions,
    )..where((t) => t.id.equals(row.id))).go();
    return token;
  }

  Future<UndoRecord> deleteWeight(WeightEntry row) async {
    final token = UndoRecord(
      type: 'weight',
      json: jsonEncode(_weightJson(row)),
    );
    await (database.delete(
      database.weightEntries,
    )..where((t) => t.id.equals(row.id))).go();
    await _refreshProfileWeightFromHistory();
    return token;
  }

  Future<UndoRecord> deleteGoal(Goal row) async {
    final token = UndoRecord(type: 'goal', json: jsonEncode(_goalJson(row)));
    await (database.delete(
      database.goals,
    )..where((t) => t.id.equals(row.id))).go();
    return token;
  }

  Future<UndoRecord> deleteRoutine(RoutineItem row) async {
    final token = UndoRecord(
      type: 'routine',
      json: jsonEncode(_routineJson(row)),
    );
    await (database.delete(
      database.routineItems,
    )..where((t) => t.id.equals(row.id))).go();
    return token;
  }

  Future<UndoRecord> deleteReminder(Reminder row) async {
    final token = UndoRecord(
      type: 'reminder',
      json: jsonEncode(_reminderJson(row)),
    );
    await database.deleteReminder(row.id);
    return token;
  }

  Future<void> undo(UndoRecord token) async {
    final m = Map<String, dynamic>.from(jsonDecode(token.json) as Map);
    DateTime dt(String key) => DateTime.parse(m[key] as String).toLocal();

    switch (token.type) {
      case 'food':
        await database
            .into(database.foodEntries)
            .insertOnConflictUpdate(
              FoodEntriesCompanion(
                id: Value(m['id'] as String),
                name: Value(m['name'] as String),
                calories: Value((m['calories'] as num).toDouble()),
                proteinG: Value((m['proteinG'] as num?)?.toDouble()),
                carbsG: Value((m['carbsG'] as num?)?.toDouble()),
                fatG: Value((m['fatG'] as num?)?.toDouble()),
                mealType: Value((m['mealType'] as String?) ?? 'snack'),
                servingQuantity: Value(
                  (m['servingQuantity'] as num?)?.toDouble() ?? 1,
                ),
                servingUnit: Value((m['servingUnit'] as String?) ?? 'serving'),
                servingGrams: Value((m['servingGrams'] as num?)?.toDouble()),
                occurredAt: Value(dt('occurredAt')),
              ),
            );
      case 'activity':
        await database
            .into(database.activityEntries)
            .insertOnConflictUpdate(
              ActivityEntriesCompanion(
                id: Value(m['id'] as String),
                activityType: Value(m['activityType'] as String),
                intensity: Value(m['intensity'] as String),
                durationMinutes: Value((m['durationMinutes'] as num).toInt()),
                distanceKm: Value((m['distanceKm'] as num?)?.toDouble()),
                caloriesBurned: Value((m['caloriesBurned'] as num).toDouble()),
                occurredAt: Value(dt('occurredAt')),
              ),
            );
      case 'water':
        await database
            .into(database.waterEntries)
            .insertOnConflictUpdate(
              WaterEntriesCompanion(
                id: Value(m['id'] as String),
                amountMl: Value((m['amountMl'] as num).toInt()),
                occurredAt: Value(dt('occurredAt')),
              ),
            );
      case 'study':
        await database
            .into(database.studySessions)
            .insertOnConflictUpdate(
              StudySessionsCompanion(
                id: Value(m['id'] as String),
                subject: Value(m['subject'] as String),
                startedAt: Value(dt('startedAt')),
                endedAt: Value(dt('endedAt')),
                durationSeconds: Value((m['durationSeconds'] as num).toInt()),
                notes: Value(m['notes'] as String?),
                createdAt: Value(dt('createdAt')),
              ),
            );
      case 'weight':
        await database
            .into(database.weightEntries)
            .insertOnConflictUpdate(
              WeightEntriesCompanion(
                id: Value(m['id'] as String),
                weightKg: Value((m['weightKg'] as num).toDouble()),
                note: Value(m['note'] as String?),
                occurredAt: Value(dt('occurredAt')),
                createdAt: Value(dt('createdAt')),
              ),
            );
      case 'goal':
        await database
            .into(database.goals)
            .insertOnConflictUpdate(
              GoalsCompanion(
                id: Value(m['id'] as String),
                title: Value(m['title'] as String),
                category: Value(m['category'] as String),
                frequency: Value(m['frequency'] as String),
                active: Value(m['active'] as bool),
                createdAt: Value(dt('createdAt')),
                updatedAt: Value(dt('updatedAt')),
              ),
            );
      case 'routine':
        await database
            .into(database.routineItems)
            .insertOnConflictUpdate(
              RoutineItemsCompanion(
                id: Value(m['id'] as String),
                title: Value(m['title'] as String),
                routineType: Value(m['routineType'] as String),
                sortOrder: Value((m['sortOrder'] as num).toInt()),
                active: Value(m['active'] as bool),
                createdAt: Value(dt('createdAt')),
                updatedAt: Value(dt('updatedAt')),
              ),
            );
      case 'reminder':
        await database.upsertReminder(
          RemindersCompanion(
            id: Value(m['id'] as String),
            title: Value(m['title'] as String),
            body: Value(m['body'] as String),
            category: Value(m['category'] as String),
            scheduleType: Value(m['scheduleType'] as String),
            hour: Value((m['hour'] as num).toInt()),
            minute: Value((m['minute'] as num).toInt()),
            weekdaysMask: Value((m['weekdaysMask'] as num).toInt()),
            scheduledAt: Value(
              m['scheduledAt'] == null
                  ? null
                  : DateTime.parse(m['scheduledAt'] as String).toLocal(),
            ),
            notificationBaseId: Value((m['notificationBaseId'] as num).toInt()),
            enabled: Value(m['enabled'] as bool),
            createdAt: Value(dt('createdAt')),
            updatedAt: Value(dt('updatedAt')),
          ),
        );
    }

    if (token.type == 'weight') {
      await _refreshProfileWeightFromHistory();
    }
  }

  Future<void> _refreshProfileWeightFromHistory() async {
    final profile = await database.getProfile();
    if (profile == null) return;
    final latest =
        await (database.select(database.weightEntries)
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
              ..limit(1))
            .getSingleOrNull();
    if (latest == null) return;
    await (database.update(
      database.profiles,
    )..where((t) => t.id.equals(profile.id))).write(
      ProfilesCompanion(
        weightKg: Value(latest.weightKg),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Map<String, Object?> _foodJson(FoodEntry r) => <String, Object?>{
    'id': r.id,
    'name': r.name,
    'calories': r.calories,
    'proteinG': r.proteinG,
    'carbsG': r.carbsG,
    'fatG': r.fatG,
    'mealType': r.mealType,
    'servingQuantity': r.servingQuantity,
    'servingUnit': r.servingUnit,
    'servingGrams': r.servingGrams,
    'occurredAt': r.occurredAt.toUtc().toIso8601String(),
  };
  Map<String, Object?> _activityJson(ActivityEntry r) => <String, Object?>{
    'id': r.id,
    'activityType': r.activityType,
    'intensity': r.intensity,
    'durationMinutes': r.durationMinutes,
    'distanceKm': r.distanceKm,
    'caloriesBurned': r.caloriesBurned,
    'occurredAt': r.occurredAt.toUtc().toIso8601String(),
  };
  Map<String, Object?> _waterJson(WaterEntry r) => <String, Object?>{
    'id': r.id,
    'amountMl': r.amountMl,
    'occurredAt': r.occurredAt.toUtc().toIso8601String(),
  };
  Map<String, Object?> _studyJson(StudySession r) => <String, Object?>{
    'id': r.id,
    'subject': r.subject,
    'startedAt': r.startedAt.toUtc().toIso8601String(),
    'endedAt': r.endedAt.toUtc().toIso8601String(),
    'durationSeconds': r.durationSeconds,
    'notes': r.notes,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
  };
  Map<String, Object?> _weightJson(WeightEntry r) => <String, Object?>{
    'id': r.id,
    'weightKg': r.weightKg,
    'note': r.note,
    'occurredAt': r.occurredAt.toUtc().toIso8601String(),
    'createdAt': r.createdAt.toUtc().toIso8601String(),
  };
  Map<String, Object?> _goalJson(Goal r) => <String, Object?>{
    'id': r.id,
    'title': r.title,
    'category': r.category,
    'frequency': r.frequency,
    'active': r.active,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };
  Map<String, Object?> _routineJson(RoutineItem r) => <String, Object?>{
    'id': r.id,
    'title': r.title,
    'routineType': r.routineType,
    'sortOrder': r.sortOrder,
    'active': r.active,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };
  Map<String, Object?> _reminderJson(Reminder r) => <String, Object?>{
    'id': r.id,
    'title': r.title,
    'body': r.body,
    'category': r.category,
    'scheduleType': r.scheduleType,
    'hour': r.hour,
    'minute': r.minute,
    'weekdaysMask': r.weekdaysMask,
    'scheduledAt': r.scheduledAt?.toUtc().toIso8601String(),
    'notificationBaseId': r.notificationBaseId,
    'enabled': r.enabled,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };
}
