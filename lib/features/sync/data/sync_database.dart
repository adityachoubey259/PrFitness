import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

extension SyncDatabaseExtension on AppDatabase {
  Future<void> ensureSyncInfrastructure() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_queue '
      'ON sync_outbox(queued_at_epoch_ms)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_conflict_open '
      'ON sync_conflicts(resolved, created_at_epoch_ms)',
    );

    const List<(String, String)> tracked = <(String, String)>[
      ('profiles', 'profile'),
      ('food_entries', 'food'),
      ('activity_entries', 'activity'),
      ('water_entries', 'water'),
      ('study_sessions', 'study'),
      ('goals', 'goal'),
      ('goal_completions', 'goal_completion'),
      ('routine_items', 'routine'),
      ('routine_completions', 'routine_completion'),
      ('reminders', 'reminder'),
      ('weight_entries', 'weight'),
    ];

    for (final (String table, String entity) in tracked) {
      await customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_${table}_insert
AFTER INSERT ON $table
WHEN COALESCE((SELECT CAST(value AS INTEGER) FROM app_settings WHERE key = 'sync.suppress'), 0) = 0
BEGIN
  INSERT INTO sync_outbox(entity_type, entity_id, operation, queued_at_epoch_ms, attempt_count, last_error)
  VALUES('$entity', NEW.id, 'upsert', CAST(strftime('%s','now') AS INTEGER) * 1000, 0, NULL)
  ON CONFLICT(entity_type, entity_id)
  DO UPDATE SET operation = 'upsert', queued_at_epoch_ms = excluded.queued_at_epoch_ms, attempt_count = 0, last_error = NULL;
END;
''');

      await customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_${table}_update
AFTER UPDATE ON $table
WHEN COALESCE((SELECT CAST(value AS INTEGER) FROM app_settings WHERE key = 'sync.suppress'), 0) = 0
BEGIN
  INSERT INTO sync_outbox(entity_type, entity_id, operation, queued_at_epoch_ms, attempt_count, last_error)
  VALUES('$entity', NEW.id, 'upsert', CAST(strftime('%s','now') AS INTEGER) * 1000, 0, NULL)
  ON CONFLICT(entity_type, entity_id)
  DO UPDATE SET operation = 'upsert', queued_at_epoch_ms = excluded.queued_at_epoch_ms, attempt_count = 0, last_error = NULL;
END;
''');

      await customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_${table}_delete
AFTER DELETE ON $table
WHEN COALESCE((SELECT CAST(value AS INTEGER) FROM app_settings WHERE key = 'sync.suppress'), 0) = 0
BEGIN
  INSERT INTO sync_outbox(entity_type, entity_id, operation, queued_at_epoch_ms, attempt_count, last_error)
  VALUES('$entity', OLD.id, 'delete', CAST(strftime('%s','now') AS INTEGER) * 1000, 0, NULL)
  ON CONFLICT(entity_type, entity_id)
  DO UPDATE SET operation = 'delete', queued_at_epoch_ms = excluded.queued_at_epoch_ms, attempt_count = 0, last_error = NULL;
END;
''');
    }
  }

  Stream<List<SyncOutboxRow>> watchSyncOutboxRows() {
    return (select(syncOutbox)..orderBy(<OrderClauseGenerator<SyncOutbox>>[
          (SyncOutbox table) => OrderingTerm.asc(table.queuedAtEpochMs),
        ]))
        .watch();
  }

  Stream<List<SyncConflictRow>> watchOpenSyncConflicts() {
    return (select(syncConflicts)
          ..where((SyncConflicts table) => table.resolved.equals(false))
          ..orderBy(<OrderClauseGenerator<SyncConflicts>>[
            (SyncConflicts table) => OrderingTerm.desc(table.createdAtEpochMs),
          ]))
        .watch();
  }

  Future<void> setSyncSuppressed(bool value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: 'sync.suppress',
        value: value ? '1' : '0',
      ),
    );
  }

  Future<void> queueSync({
    required String entityType,
    required String entityId,
    required String operation,
  }) async {
    await into(syncOutbox).insertOnConflictUpdate(
      SyncOutboxCompanion(
        entityType: Value(entityType),
        entityId: Value(entityId),
        operation: Value(operation),
        queuedAtEpochMs: Value(DateTime.now().millisecondsSinceEpoch),
        attemptCount: const Value(0),
        lastError: const Value(null),
      ),
    );
  }

  Future<bool> hasPendingSync({
    required String entityType,
    required String entityId,
  }) async {
    final SyncOutboxRow? row =
        await (select(syncOutbox)
              ..where(
                (SyncOutbox table) =>
                    table.entityType.equals(entityType) &
                    table.entityId.equals(entityId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> removeOutboxIfUnchanged(SyncOutboxRow sent) async {
    await (delete(syncOutbox)..where(
          (SyncOutbox table) =>
              table.entityType.equals(sent.entityType) &
              table.entityId.equals(sent.entityId) &
              table.queuedAtEpochMs.equals(sent.queuedAtEpochMs),
        ))
        .go();
  }

  Future<void> markOutboxFailure(SyncOutboxRow row, String message) async {
    final String safe = message.length <= 500
        ? message
        : message.substring(0, 500);
    await (update(syncOutbox)..where(
          (SyncOutbox table) =>
              table.entityType.equals(row.entityType) &
              table.entityId.equals(row.entityId),
        ))
        .write(
          SyncOutboxCompanion(
            attemptCount: Value(row.attemptCount + 1),
            lastError: Value(safe),
          ),
        );
  }

  Future<SyncEntityStateRow?> syncEntityState({
    required String entityType,
    required String entityId,
  }) {
    return (select(syncEntityStates)
          ..where(
            (SyncEntityStates table) =>
                table.entityType.equals(entityType) &
                table.entityId.equals(entityId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> saveSyncEntityState({
    required String entityType,
    required String entityId,
    required int serverVersion,
  }) async {
    await into(syncEntityStates).insertOnConflictUpdate(
      SyncEntityStatesCompanion(
        entityType: Value(entityType),
        entityId: Value(entityId),
        serverVersion: Value(serverVersion),
        syncedAtEpochMs: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> addSyncConflict(SyncConflictsCompanion conflict) async {
    await into(syncConflicts).insertOnConflictUpdate(conflict);
  }

  Future<void> resolveConflict(String id) async {
    await (update(syncConflicts)
          ..where((SyncConflicts table) => table.id.equals(id)))
        .write(const SyncConflictsCompanion(resolved: Value(true)));
  }

  Future<void> clearSyncMetadata() async {
    await transaction(() async {
      await delete(syncOutbox).go();
      await delete(syncEntityStates).go();
      await delete(syncConflicts).go();
    });
  }
}
