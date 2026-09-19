import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_factory.dart';
import '../../reminders/data/reminder_repository.dart';
import 'account_service.dart';
import 'sync_database.dart';

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.conflicts,
  });

  final int pushed;
  final int pulled;
  final int conflicts;
}

class SyncService {
  SyncService(this.database, {AccountService? accountService})
    : accountService = accountService ?? AccountService();

  final AppDatabase database;
  final AccountService accountService;

  static const String _boundAccountKey = 'sync.bound_account';
  static const String _seededAccountKey = 'sync.seeded_account';
  static const String _cursorKey = 'sync.cursor';
  static const String _deviceKey = 'sync.device_id';
  static const String _lastSyncKey = 'sync.last_success_utc';

  Future<SyncResult> syncNow() async {
    await database.ensureSyncInfrastructure();

    final AccountSnapshot? account = await accountService.currentAccount();
    if (account == null) {
      throw const ApiException('Sign in before syncing.', statusCode: 401);
    }

    await _prepareAccount(account.id);

    final List<SyncOutboxRow> outbox =
        await (database.select(database.syncOutbox)
              ..orderBy(<OrderClauseGenerator<SyncOutbox>>[
                (SyncOutbox table) => OrderingTerm.asc(table.queuedAtEpochMs),
              ])
              ..limit(250))
            .get();

    final List<Map<String, Object?>> changes = <Map<String, Object?>>[];
    final Map<String, SyncOutboxRow> sentByKey = <String, SyncOutboxRow>{};

    for (final SyncOutboxRow row in outbox) {
      final SyncEntityStateRow? state = await database.syncEntityState(
        entityType: row.entityType,
        entityId: row.entityId,
      );

      final Map<String, Object?>? payload = row.operation == 'delete'
          ? null
          : await _serialize(row.entityType, row.entityId);

      changes.add(<String, Object?>{
        'entityType': row.entityType,
        'entityId': row.entityId,
        'operation': payload == null ? 'delete' : row.operation,
        'baseVersion': state?.serverVersion ?? 0,
        'payload': payload,
      });

      sentByKey['${row.entityType}|${row.entityId}'] = row;
    }

    int cursor =
        int.tryParse(await database.readSetting(_cursorKey) ?? '0') ?? 0;
    final String deviceId = await _deviceId();

    int pushed = 0;
    int pulled = 0;
    int conflicts = 0;
    bool firstPage = true;
    bool hasMore = true;
    int page = 0;

    while (hasMore && page < 20) {
      page++;
      final response = await accountService.authorizedPost(
        path: '/v1/sync',
        body: <String, Object?>{
          'cursor': cursor,
          'deviceId': deviceId,
          'changes': firstPage ? changes : <Object?>[],
        },
      );

      final Map<String, dynamic> body = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String message =
            body['error'] as String? ?? 'Sync request failed.';
        for (final SyncOutboxRow row in outbox) {
          await database.markOutboxFailure(row, message);
        }
        throw ApiException(message, statusCode: response.statusCode);
      }

      final List<dynamic> accepted =
          body['accepted'] as List<dynamic>? ?? <dynamic>[];
      final List<dynamic> conflictRows =
          body['conflicts'] as List<dynamic>? ?? <dynamic>[];
      final List<dynamic> records =
          body['records'] as List<dynamic>? ?? <dynamic>[];
      final Set<String> conflictKeys = <String>{};

      if (firstPage) {
        for (final dynamic raw in conflictRows) {
          final Map<String, dynamic> conflict = Map<String, dynamic>.from(
            raw as Map,
          );
          final String type = conflict['entityType'] as String;
          final String id = conflict['entityId'] as String;
          final int version = (conflict['serverVersion'] as num).toInt();
          final bool deleted = conflict['deleted'] as bool? ?? false;
          final dynamic remotePayload = conflict['payload'];
          final Map<String, Object?>? localPayload = await _serialize(type, id);

          await database.addSyncConflict(
            SyncConflictsCompanion(
              id: Value(IdFactory.uuidV4()),
              entityType: Value(type),
              entityId: Value(id),
              localJson: Value(
                localPayload == null ? null : jsonEncode(localPayload),
              ),
              remoteJson: Value(
                remotePayload == null ? null : jsonEncode(remotePayload),
              ),
              remoteDeleted: Value(deleted),
              remoteVersion: Value(version),
              createdAtEpochMs: Value(DateTime.now().millisecondsSinceEpoch),
              resolved: const Value(false),
            ),
          );

          conflictKeys.add('$type|$id');
          final SyncOutboxRow? sent = sentByKey['$type|$id'];
          if (sent != null) await database.removeOutboxIfUnchanged(sent);
          conflicts++;
        }

        for (final dynamic raw in accepted) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(
            raw as Map,
          );
          final String type = item['entityType'] as String;
          final String id = item['entityId'] as String;
          final int version = (item['serverVersion'] as num).toInt();

          await database.saveSyncEntityState(
            entityType: type,
            entityId: id,
            serverVersion: version,
          );

          final SyncOutboxRow? sent = sentByKey['$type|$id'];
          if (sent != null) await database.removeOutboxIfUnchanged(sent);
          pushed++;
        }
      }

      await database.setSyncSuppressed(true);
      try {
        for (final dynamic raw in records) {
          final Map<String, dynamic> record = Map<String, dynamic>.from(
            raw as Map,
          );
          final String type = record['entityType'] as String;
          final String id = record['entityId'] as String;
          final String key = '$type|$id';

          if (conflictKeys.contains(key)) continue;
          if (await database.hasPendingSync(entityType: type, entityId: id)) {
            continue;
          }

          await _applyRemote(record);
          await database.saveSyncEntityState(
            entityType: type,
            entityId: id,
            serverVersion: (record['serverVersion'] as num).toInt(),
          );
          pulled++;
        }
      } finally {
        await database.setSyncSuppressed(false);
      }

      cursor = (body['cursor'] as num?)?.toInt() ?? cursor;
      await database.writeSetting(_cursorKey, cursor.toString());
      hasMore = body['hasMore'] as bool? ?? false;
      firstPage = false;
    }

    await ReminderRepository(database).rescheduleEnabledReminders();
    await database.writeSetting(
      _lastSyncKey,
      DateTime.now().toUtc().toIso8601String(),
    );

    return SyncResult(pushed: pushed, pulled: pulled, conflicts: conflicts);
  }

  Future<void> useRemote(SyncConflictRow conflict) async {
    await database.setSyncSuppressed(true);
    try {
      await _applyRemote(<String, dynamic>{
        'entityType': conflict.entityType,
        'entityId': conflict.entityId,
        'deleted': conflict.remoteDeleted,
        'serverVersion': conflict.remoteVersion,
        'payload': conflict.remoteJson == null
            ? null
            : jsonDecode(conflict.remoteJson!),
      });
    } finally {
      await database.setSyncSuppressed(false);
    }

    await (database.delete(database.syncOutbox)..where(
          (SyncOutbox table) =>
              table.entityType.equals(conflict.entityType) &
              table.entityId.equals(conflict.entityId),
        ))
        .go();

    await database.saveSyncEntityState(
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      serverVersion: conflict.remoteVersion,
    );
    await database.resolveConflict(conflict.id);
  }

  Future<void> keepLocal(SyncConflictRow conflict) async {
    await database.saveSyncEntityState(
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      serverVersion: conflict.remoteVersion,
    );

    final Map<String, Object?>? local = await _serialize(
      conflict.entityType,
      conflict.entityId,
    );

    await database.queueSync(
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      operation: local == null ? 'delete' : 'upsert',
    );
    await database.resolveConflict(conflict.id);
  }

  Future<void> _prepareAccount(String accountId) async {
    final String? bound = await database.readSetting(_boundAccountKey);
    if (bound != null && bound != accountId) {
      throw const ApiException(
        'This local dataset is already linked to another cloud account. Export your data before changing account ownership.',
      );
    }

    if (bound == null) {
      await database.writeSetting(_boundAccountKey, accountId);
      await database.writeSetting(_cursorKey, '0');
    }

    final String? seeded = await database.readSetting(_seededAccountKey);
    if (seeded != accountId) {
      await _seedLocalSnapshot();
      await database.writeSetting(_seededAccountKey, accountId);
    }
  }

  Future<void> _seedLocalSnapshot() async {
    final List<(String, String)> rows = <(String, String)>[];
    final ProfileRow? profile = await database.getProfile();
    if (profile != null) rows.add(('profile', profile.id));

    for (final FoodEntry row
        in await database.select(database.foodEntries).get()) {
      rows.add(('food', row.id));
    }
    for (final ActivityEntry row
        in await database.select(database.activityEntries).get()) {
      rows.add(('activity', row.id));
    }
    for (final WaterEntry row
        in await database.select(database.waterEntries).get()) {
      rows.add(('water', row.id));
    }
    for (final StudySession row
        in await database.select(database.studySessions).get()) {
      rows.add(('study', row.id));
    }
    for (final Goal row in await database.select(database.goals).get()) {
      rows.add(('goal', row.id));
    }
    for (final GoalCompletion row
        in await database.select(database.goalCompletions).get()) {
      rows.add(('goal_completion', row.id));
    }
    for (final RoutineItem row
        in await database.select(database.routineItems).get()) {
      rows.add(('routine', row.id));
    }
    for (final RoutineCompletion row
        in await database.select(database.routineCompletions).get()) {
      rows.add(('routine_completion', row.id));
    }
    for (final Reminder row
        in await database.select(database.reminders).get()) {
      rows.add(('reminder', row.id));
    }
    for (final WeightEntry row
        in await database.select(database.weightEntries).get()) {
      rows.add(('weight', row.id));
    }

    for (final (String type, String id) in rows) {
      await database.queueSync(
        entityType: type,
        entityId: id,
        operation: 'upsert',
      );
    }
  }

  Future<String> _deviceId() async {
    String? value = await database.readSetting(_deviceKey);
    if (value != null && value.isNotEmpty) return value;
    value = IdFactory.uuidV4();
    await database.writeSetting(_deviceKey, value);
    return value;
  }

  Future<Map<String, Object?>?> _serialize(String type, String id) async {
    String utc(DateTime value) => value.toUtc().toIso8601String();

    switch (type) {
      case 'profile':
        final ProfileRow? row =
            await (database.select(database.profiles)
                  ..where((Profiles table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'name': row.name,
          'birthDate': utc(row.birthDate),
          'sex': row.sex,
          'heightCm': row.heightCm,
          'weightKg': row.weightKg,
          'targetWeightKg': row.targetWeightKg,
          'activityLevel': row.activityLevel,
          'goal': row.goal,
          'dailyStudyTargetMinutes': row.dailyStudyTargetMinutes,
          'createdAt': utc(row.createdAt),
          'updatedAt': utc(row.updatedAt),
        };
      case 'food':
        final FoodEntry? row =
            await (database.select(database.foodEntries)
                  ..where((FoodEntries table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'name': row.name,
          'calories': row.calories,
          'proteinG': row.proteinG,
          'carbsG': row.carbsG,
          'fatG': row.fatG,
          'mealType': row.mealType,
          'servingQuantity': row.servingQuantity,
          'servingUnit': row.servingUnit,
          'servingGrams': row.servingGrams,
          'occurredAt': utc(row.occurredAt),
        };
      case 'activity':
        final ActivityEntry? row =
            await (database.select(database.activityEntries)
                  ..where((ActivityEntries table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'activityType': row.activityType,
          'intensity': row.intensity,
          'durationMinutes': row.durationMinutes,
          'distanceKm': row.distanceKm,
          'caloriesBurned': row.caloriesBurned,
          'occurredAt': utc(row.occurredAt),
        };
      case 'water':
        final WaterEntry? row =
            await (database.select(database.waterEntries)
                  ..where((WaterEntries table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'amountMl': row.amountMl,
          'occurredAt': utc(row.occurredAt),
        };
      case 'study':
        final StudySession? row =
            await (database.select(database.studySessions)
                  ..where((StudySessions table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'subject': row.subject,
          'startedAt': utc(row.startedAt),
          'endedAt': utc(row.endedAt),
          'durationSeconds': row.durationSeconds,
          'notes': row.notes,
          'createdAt': utc(row.createdAt),
        };
      case 'goal':
        final Goal? row =
            await (database.select(database.goals)
                  ..where((Goals table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'title': row.title,
          'category': row.category,
          'frequency': row.frequency,
          'active': row.active,
          'createdAt': utc(row.createdAt),
          'updatedAt': utc(row.updatedAt),
        };
      case 'goal_completion':
        final GoalCompletion? row =
            await (database.select(database.goalCompletions)
                  ..where((GoalCompletions table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'goalId': row.goalId,
          'completedAt': utc(row.completedAt),
        };
      case 'routine':
        final RoutineItem? row =
            await (database.select(database.routineItems)
                  ..where((RoutineItems table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'title': row.title,
          'routineType': row.routineType,
          'sortOrder': row.sortOrder,
          'active': row.active,
          'createdAt': utc(row.createdAt),
          'updatedAt': utc(row.updatedAt),
        };
      case 'routine_completion':
        final RoutineCompletion? row =
            await (database.select(database.routineCompletions)
                  ..where((RoutineCompletions table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'routineId': row.routineId,
          'completedAt': utc(row.completedAt),
        };
      case 'reminder':
        final Reminder? row =
            await (database.select(database.reminders)
                  ..where((Reminders table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'title': row.title,
          'body': row.body,
          'category': row.category,
          'scheduleType': row.scheduleType,
          'hour': row.hour,
          'minute': row.minute,
          'weekdaysMask': row.weekdaysMask,
          'scheduledAt': row.scheduledAt == null ? null : utc(row.scheduledAt!),
          'notificationBaseId': row.notificationBaseId,
          'enabled': row.enabled,
          'createdAt': utc(row.createdAt),
          'updatedAt': utc(row.updatedAt),
        };
      case 'weight':
        final WeightEntry? row =
            await (database.select(database.weightEntries)
                  ..where((WeightEntries table) => table.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'weightKg': row.weightKg,
          'note': row.note,
          'occurredAt': utc(row.occurredAt),
          'createdAt': utc(row.createdAt),
        };
    }
    return null;
  }

  Future<void> _applyRemote(Map<String, dynamic> record) async {
    final String type = record['entityType'] as String;
    final String id = record['entityId'] as String;
    final bool deleted = record['deleted'] as bool? ?? false;

    if (deleted) {
      await _deleteLocal(type, id);
      return;
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      record['payload'] as Map,
    );
    DateTime dt(dynamic value) => DateTime.parse(value as String).toLocal();

    switch (type) {
      case 'profile':
        await database.upsertProfile(
          ProfilesCompanion(
            id: Value(payload['id'] as String),
            name: Value(payload['name'] as String),
            birthDate: Value(dt(payload['birthDate'])),
            sex: Value(payload['sex'] as String),
            heightCm: Value((payload['heightCm'] as num).toDouble()),
            weightKg: Value((payload['weightKg'] as num).toDouble()),
            targetWeightKg: Value(
              (payload['targetWeightKg'] as num?)?.toDouble(),
            ),
            activityLevel: Value(payload['activityLevel'] as String),
            goal: Value(payload['goal'] as String),
            dailyStudyTargetMinutes: Value(
              (payload['dailyStudyTargetMinutes'] as num).toInt(),
            ),
            createdAt: Value(dt(payload['createdAt'])),
            updatedAt: Value(dt(payload['updatedAt'])),
          ),
        );
      case 'food':
        await database
            .into(database.foodEntries)
            .insertOnConflictUpdate(
              FoodEntriesCompanion(
                id: Value(payload['id'] as String),
                name: Value(payload['name'] as String),
                calories: Value((payload['calories'] as num).toDouble()),
                proteinG: Value((payload['proteinG'] as num?)?.toDouble()),
                carbsG: Value((payload['carbsG'] as num?)?.toDouble()),
                fatG: Value((payload['fatG'] as num?)?.toDouble()),

                mealType: Value((payload['mealType'] as String?) ?? 'snack'),

                servingQuantity: Value(
                  (payload['servingQuantity'] as num?)?.toDouble() ?? 1,
                ),

                servingUnit: Value(
                  (payload['servingUnit'] as String?) ?? 'serving',
                ),

                servingGrams: Value(
                  (payload['servingGrams'] as num?)?.toDouble(),
                ),
                occurredAt: Value(dt(payload['occurredAt'])),
              ),
            );
      case 'activity':
        await database
            .into(database.activityEntries)
            .insertOnConflictUpdate(
              ActivityEntriesCompanion(
                id: Value(payload['id'] as String),
                activityType: Value(payload['activityType'] as String),
                intensity: Value(payload['intensity'] as String),
                durationMinutes: Value(
                  (payload['durationMinutes'] as num).toInt(),
                ),
                distanceKm: Value((payload['distanceKm'] as num?)?.toDouble()),
                caloriesBurned: Value(
                  (payload['caloriesBurned'] as num).toDouble(),
                ),
                occurredAt: Value(dt(payload['occurredAt'])),
              ),
            );
      case 'water':
        await database
            .into(database.waterEntries)
            .insertOnConflictUpdate(
              WaterEntriesCompanion(
                id: Value(payload['id'] as String),
                amountMl: Value((payload['amountMl'] as num).toInt()),
                occurredAt: Value(dt(payload['occurredAt'])),
              ),
            );
      case 'study':
        await database
            .into(database.studySessions)
            .insertOnConflictUpdate(
              StudySessionsCompanion(
                id: Value(payload['id'] as String),
                subject: Value(payload['subject'] as String),
                startedAt: Value(dt(payload['startedAt'])),
                endedAt: Value(dt(payload['endedAt'])),
                durationSeconds: Value(
                  (payload['durationSeconds'] as num).toInt(),
                ),
                notes: Value(payload['notes'] as String?),
                createdAt: Value(dt(payload['createdAt'])),
              ),
            );
      case 'goal':
        await database
            .into(database.goals)
            .insertOnConflictUpdate(
              GoalsCompanion(
                id: Value(payload['id'] as String),
                title: Value(payload['title'] as String),
                category: Value(payload['category'] as String),
                frequency: Value(payload['frequency'] as String),
                active: Value(payload['active'] as bool),
                createdAt: Value(dt(payload['createdAt'])),
                updatedAt: Value(dt(payload['updatedAt'])),
              ),
            );
      case 'goal_completion':
        await database
            .into(database.goalCompletions)
            .insertOnConflictUpdate(
              GoalCompletionsCompanion(
                id: Value(payload['id'] as String),
                goalId: Value(payload['goalId'] as String),
                completedAt: Value(dt(payload['completedAt'])),
              ),
            );
      case 'routine':
        await database
            .into(database.routineItems)
            .insertOnConflictUpdate(
              RoutineItemsCompanion(
                id: Value(payload['id'] as String),
                title: Value(payload['title'] as String),
                routineType: Value(payload['routineType'] as String),
                sortOrder: Value((payload['sortOrder'] as num).toInt()),
                active: Value(payload['active'] as bool),
                createdAt: Value(dt(payload['createdAt'])),
                updatedAt: Value(dt(payload['updatedAt'])),
              ),
            );
      case 'routine_completion':
        await database
            .into(database.routineCompletions)
            .insertOnConflictUpdate(
              RoutineCompletionsCompanion(
                id: Value(payload['id'] as String),
                routineId: Value(payload['routineId'] as String),
                completedAt: Value(dt(payload['completedAt'])),
              ),
            );
      case 'reminder':
        await database
            .into(database.reminders)
            .insertOnConflictUpdate(
              RemindersCompanion(
                id: Value(payload['id'] as String),
                title: Value(payload['title'] as String),
                body: Value(payload['body'] as String),
                category: Value(payload['category'] as String),
                scheduleType: Value(payload['scheduleType'] as String),
                hour: Value((payload['hour'] as num).toInt()),
                minute: Value((payload['minute'] as num).toInt()),
                weekdaysMask: Value((payload['weekdaysMask'] as num).toInt()),
                scheduledAt: Value(
                  payload['scheduledAt'] == null
                      ? null
                      : dt(payload['scheduledAt']),
                ),
                notificationBaseId: Value(
                  (payload['notificationBaseId'] as num).toInt(),
                ),
                enabled: Value(payload['enabled'] as bool),
                createdAt: Value(dt(payload['createdAt'])),
                updatedAt: Value(dt(payload['updatedAt'])),
              ),
            );
      case 'weight':
        await database
            .into(database.weightEntries)
            .insertOnConflictUpdate(
              WeightEntriesCompanion(
                id: Value(payload['id'] as String),
                weightKg: Value((payload['weightKg'] as num).toDouble()),
                note: Value(payload['note'] as String?),
                occurredAt: Value(dt(payload['occurredAt'])),
                createdAt: Value(dt(payload['createdAt'])),
              ),
            );
    }
  }

  Future<void> _deleteLocal(String type, String id) async {
    switch (type) {
      case 'profile':
        await (database.delete(
          database.profiles,
        )..where((Profiles t) => t.id.equals(id))).go();
      case 'food':
        await (database.delete(
          database.foodEntries,
        )..where((FoodEntries t) => t.id.equals(id))).go();
      case 'activity':
        await (database.delete(
          database.activityEntries,
        )..where((ActivityEntries t) => t.id.equals(id))).go();
      case 'water':
        await (database.delete(
          database.waterEntries,
        )..where((WaterEntries t) => t.id.equals(id))).go();
      case 'study':
        await (database.delete(
          database.studySessions,
        )..where((StudySessions t) => t.id.equals(id))).go();
      case 'goal':
        await (database.delete(
          database.goals,
        )..where((Goals t) => t.id.equals(id))).go();
      case 'goal_completion':
        await (database.delete(
          database.goalCompletions,
        )..where((GoalCompletions t) => t.id.equals(id))).go();
      case 'routine':
        await (database.delete(
          database.routineItems,
        )..where((RoutineItems t) => t.id.equals(id))).go();
      case 'routine_completion':
        await (database.delete(
          database.routineCompletions,
        )..where((RoutineCompletions t) => t.id.equals(id))).go();
      case 'reminder':
        await (database.delete(
          database.reminders,
        )..where((Reminders t) => t.id.equals(id))).go();
      case 'weight':
        await (database.delete(
          database.weightEntries,
        )..where((WeightEntries t) => t.id.equals(id))).go();
    }
  }

  Map<String, dynamic> _decode(String source) {
    try {
      final dynamic value = jsonDecode(source);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {
      // handled below
    }
    return <String, dynamic>{'error': 'Unexpected sync response.'};
  }
}
