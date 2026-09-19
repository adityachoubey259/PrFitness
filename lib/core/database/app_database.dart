import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

String _prFitnessDatabaseName = 'prfitness';

void configurePrFitnessDatabaseName(String name) {
  if (!RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(name)) {
    throw ArgumentError.value(name, 'name', 'Invalid PrFitness database name.');
  }
  _prFitnessDatabaseName = name;
}

@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 80)();

  DateTimeColumn get birthDate => dateTime()();

  TextColumn get sex => text()();

  RealColumn get heightCm => real()();

  RealColumn get weightKg => real()();

  RealColumn get targetWeightKg => real().nullable()();

  TextColumn get activityLevel => text()();

  TextColumn get goal => text()();

  IntColumn get dailyStudyTargetMinutes =>
      integer().withDefault(const Constant(120))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class FoodEntries extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  RealColumn get calories => real()();

  RealColumn get proteinG => real().nullable()();

  RealColumn get carbsG => real().nullable()();

  RealColumn get fatG => real().nullable()();

  TextColumn get mealType => text().withDefault(const Constant('snack'))();
  RealColumn get servingQuantity => real().withDefault(const Constant(1))();
  TextColumn get servingUnit => text().withDefault(const Constant('serving'))();
  RealColumn get servingGrams => real().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class ActivityEntries extends Table {
  TextColumn get id => text()();

  TextColumn get activityType => text()();

  TextColumn get intensity => text()();

  IntColumn get durationMinutes => integer()();

  RealColumn get distanceKm => real().nullable()();

  RealColumn get caloriesBurned => real()();

  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class WaterEntries extends Table {
  TextColumn get id => text()();

  IntColumn get amountMl => integer()();

  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

class StudySessions extends Table {
  TextColumn get id => text()();

  TextColumn get subject => text().withLength(min: 1, max: 100)();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get endedAt => dateTime()();

  IntColumn get durationSeconds => integer()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class Goals extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 140)();

  TextColumn get category => text().withDefault(const Constant('Personal'))();

  TextColumn get frequency => text().withDefault(const Constant('daily'))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class GoalCompletions extends Table {
  TextColumn get id => text()();

  TextColumn get goalId =>
      text().references(Goals, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class RoutineItems extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 140)();

  TextColumn get routineType =>
      text().withDefault(const Constant('Personal'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class RoutineCompletions extends Table {
  TextColumn get id => text()();

  TextColumn get routineId =>
      text().references(RoutineItems, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class Reminders extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 140)();

  TextColumn get body =>
      text().withDefault(const Constant('Time to make progress.'))();

  TextColumn get category => text().withDefault(const Constant('Personal'))();

  TextColumn get scheduleType => text().withDefault(const Constant('daily'))();

  IntColumn get hour => integer()();

  IntColumn get minute => integer()();

  IntColumn get weekdaysMask => integer().withDefault(const Constant(127))();

  DateTimeColumn get scheduledAt => dateTime().nullable()();

  IntColumn get notificationBaseId => integer()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class WeightEntries extends Table {
  TextColumn get id => text()();

  RealColumn get weightKg => real()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get occurredAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get operation => text()();

  IntColumn get queuedAtEpochMs => integer()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entityType, entityId};
}

@DataClassName('SyncEntityStateRow')
class SyncEntityStates extends Table {
  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  IntColumn get syncedAtEpochMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entityType, entityId};
}

@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  TextColumn get id => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get localJson => text().nullable()();

  TextColumn get remoteJson => text().nullable()();

  BoolColumn get remoteDeleted =>
      boolean().withDefault(const Constant(false))();

  IntColumn get remoteVersion => integer()();

  IntColumn get createdAtEpochMs => integer()();

  BoolColumn get resolved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('FoodCatalogItemRow')
class FoodCatalogItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get aliases => text().withDefault(const Constant(''))();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real().withDefault(const Constant(0))();
  RealColumn get carbsPer100g => real().withDefault(const Constant(0))();
  RealColumn get fatPer100g => real().withDefault(const Constant(0))();
  RealColumn get defaultServingGrams =>
      real().withDefault(const Constant(100))();
  TextColumn get defaultUnit => text().withDefault(const Constant('g'))();
  BoolColumn get userDefined => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('FoodFavoriteRow')
class FoodFavorites extends Table {
  TextColumn get foodId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{foodId};
}

@DriftDatabase(
  tables: <Type>[
    Profiles,
    FoodEntries,
    ActivityEntries,
    WaterEntries,
    AppSettings,
    StudySessions,
    Goals,
    GoalCompletions,
    RoutineItems,
    RoutineCompletions,
    Reminders,
    WeightEntries,

    SyncOutbox,
    SyncEntityStates,
    SyncConflicts,

    FoodCatalogItems,
    FoodFavorites,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: _prFitnessDatabaseName));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (Migrator migrator, int from, int to) async {
        if (from < 2) {
          await migrator.createTable(studySessions);

          await migrator.createTable(goals);

          await migrator.createTable(goalCompletions);

          await migrator.createTable(routineItems);

          await migrator.createTable(routineCompletions);
        }

        if (from < 3) {
          await migrator.createTable(reminders);
        }

        if (from < 4) {
          await migrator.createTable(weightEntries);
        }

        if (from < 5) {
          await migrator.createTable(syncOutbox);

          await migrator.createTable(syncEntityStates);

          await migrator.createTable(syncConflicts);
        }
        if (from < 6) {
          await migrator.addColumn(foodEntries, foodEntries.mealType);
          await migrator.addColumn(foodEntries, foodEntries.servingQuantity);
          await migrator.addColumn(foodEntries, foodEntries.servingUnit);
          await migrator.addColumn(foodEntries, foodEntries.servingGrams);
          await migrator.createTable(foodCatalogItems);
          await migrator.createTable(foodFavorites);
        }
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');

        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_local_food_time '
          'ON food_entries(occurred_at)',
        );

        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_local_activity_time '
          'ON activity_entries(occurred_at)',
        );

        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_local_water_time '
          'ON water_entries(occurred_at)',
        );

        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_local_study_time '
          'ON study_sessions(started_at)',
        );

        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_local_goal_completion_time '
          'ON goal_completions(completed_at)',
        );

        await customStatement(
          'CREATE INDEX IF NOT EXISTS '
          'idx_local_routine_completion_time '
          'ON routine_completions(completed_at)',
        );
      },
    );
  }

  Future<ProfileRow?> getProfile() {
    return (select(profiles)..limit(1)).getSingleOrNull();
  }

  Stream<ProfileRow?> watchProfile() {
    return (select(profiles)..limit(1)).watchSingleOrNull();
  }

  Future<void> upsertProfile(ProfilesCompanion profile) async {
    await into(profiles).insertOnConflictUpdate(profile);
  }

  Future<String?> readSetting(String settingKey) async {
    final AppSetting? setting =
        await (select(appSettings)
              ..where((AppSettings table) => table.key.equals(settingKey)))
            .getSingleOrNull();

    return setting?.value;
  }

  Future<void> writeSetting(String settingKey, String settingValue) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: settingKey, value: settingValue),
    );
  }

  Future<void> deleteSetting(String settingKey) async {
    await (delete(
      appSettings,
    )..where((AppSettings table) => table.key.equals(settingKey))).go();
  }

  Stream<List<FoodEntry>> watchFoodForDay(DateTime day) {
    final (DateTime, DateTime) bounds = _dayBounds(day);

    return (select(foodEntries)
          ..where(
            (FoodEntries table) =>
                table.occurredAt.isBiggerOrEqualValue(bounds.$1) &
                table.occurredAt.isSmallerThanValue(bounds.$2),
          )
          ..orderBy(<OrderClauseGenerator<FoodEntries>>[
            (FoodEntries table) => OrderingTerm.desc(table.occurredAt),
          ]))
        .watch();
  }

  Stream<List<ActivityEntry>> watchActivityForDay(DateTime day) {
    final (DateTime, DateTime) bounds = _dayBounds(day);

    return (select(activityEntries)
          ..where(
            (ActivityEntries table) =>
                table.occurredAt.isBiggerOrEqualValue(bounds.$1) &
                table.occurredAt.isSmallerThanValue(bounds.$2),
          )
          ..orderBy(<OrderClauseGenerator<ActivityEntries>>[
            (ActivityEntries table) => OrderingTerm.desc(table.occurredAt),
          ]))
        .watch();
  }

  Stream<List<WaterEntry>> watchWaterForDay(DateTime day) {
    final (DateTime, DateTime) bounds = _dayBounds(day);

    return (select(waterEntries)
          ..where(
            (WaterEntries table) =>
                table.occurredAt.isBiggerOrEqualValue(bounds.$1) &
                table.occurredAt.isSmallerThanValue(bounds.$2),
          )
          ..orderBy(<OrderClauseGenerator<WaterEntries>>[
            (WaterEntries table) => OrderingTerm.desc(table.occurredAt),
          ]))
        .watch();
  }

  Stream<List<StudySession>> watchStudyForDay(DateTime day) {
    final (DateTime, DateTime) bounds = _dayBounds(day);

    return (select(studySessions)
          ..where(
            (StudySessions table) =>
                table.startedAt.isBiggerOrEqualValue(bounds.$1) &
                table.startedAt.isSmallerThanValue(bounds.$2),
          )
          ..orderBy(<OrderClauseGenerator<StudySessions>>[
            (StudySessions table) => OrderingTerm.desc(table.startedAt),
          ]))
        .watch();
  }

  Stream<List<Goal>> watchGoals() {
    return (select(goals)
          ..where((Goals table) => table.active.equals(true))
          ..orderBy(<OrderClauseGenerator<Goals>>[
            (Goals table) => OrderingTerm.asc(table.createdAt),
          ]))
        .watch();
  }

  Stream<List<GoalCompletion>> watchGoalCompletionsForDay(DateTime day) {
    final (DateTime, DateTime) bounds = _dayBounds(day);

    return (select(goalCompletions)..where(
          (GoalCompletions table) =>
              table.completedAt.isBiggerOrEqualValue(bounds.$1) &
              table.completedAt.isSmallerThanValue(bounds.$2),
        ))
        .watch();
  }

  Stream<List<RoutineItem>> watchRoutines() {
    return (select(routineItems)
          ..where((RoutineItems table) => table.active.equals(true))
          ..orderBy(<OrderClauseGenerator<RoutineItems>>[
            (RoutineItems table) => OrderingTerm.asc(table.sortOrder),
          ]))
        .watch();
  }

  Stream<List<RoutineCompletion>> watchRoutineCompletionsForDay(DateTime day) {
    final (DateTime, DateTime) bounds = _dayBounds(day);

    return (select(routineCompletions)..where(
          (RoutineCompletions table) =>
              table.completedAt.isBiggerOrEqualValue(bounds.$1) &
              table.completedAt.isSmallerThanValue(bounds.$2),
        ))
        .watch();
  }

  Future<void> addFood(FoodEntriesCompanion entry) async {
    await into(foodEntries).insert(entry);
  }

  Future<void> addActivity(ActivityEntriesCompanion entry) async {
    await into(activityEntries).insert(entry);
  }

  Future<void> addWater(WaterEntriesCompanion entry) async {
    await into(waterEntries).insert(entry);
  }

  Future<void> addStudySession(StudySessionsCompanion entry) async {
    await into(studySessions).insert(entry);
  }

  Future<void> addGoal(GoalsCompanion entry) async {
    await into(goals).insert(entry);
  }

  Future<void> addRoutine(RoutineItemsCompanion entry) async {
    await into(routineItems).insert(entry);
  }

  Stream<List<Reminder>> watchReminders() {
    return (select(reminders)..orderBy(<OrderClauseGenerator<Reminders>>[
          (Reminders table) => OrderingTerm.asc(table.hour),
          (Reminders table) => OrderingTerm.asc(table.minute),
        ]))
        .watch();
  }

  Future<List<Reminder>> getReminders() {
    return select(reminders).get();
  }

  Future<Reminder?> getReminder(String reminderId) {
    return (select(reminders)
          ..where((Reminders table) => table.id.equals(reminderId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertReminder(RemindersCompanion reminder) async {
    await into(reminders).insertOnConflictUpdate(reminder);
  }

  Future<void> deleteReminder(String reminderId) async {
    await (delete(
      reminders,
    )..where((Reminders table) => table.id.equals(reminderId))).go();
  }

  (DateTime, DateTime) _dayBounds(DateTime day) {
    final DateTime start = DateTime(day.year, day.month, day.day);

    return (start, start.add(const Duration(days: 1)));
  }
}
