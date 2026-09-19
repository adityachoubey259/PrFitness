import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/core/database/app_database.dart';
import 'package:prfitness/features/sync/data/sync_database.dart';

void main() {
  test('tracked insert enters persistent sync outbox', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    await database.ensureSyncInfrastructure();

    await database.addFood(
      FoodEntriesCompanion(
        id: const Value('food-1'),
        name: const Value('Banana'),
        calories: const Value(105),
        occurredAt: Value(DateTime.now()),
      ),
    );

    final List<SyncOutboxRow> rows = await database
        .select(database.syncOutbox)
        .get();

    expect(rows, hasLength(1));
    expect(rows.first.entityType, 'food');
    expect(rows.first.entityId, 'food-1');
    expect(rows.first.operation, 'upsert');

    await database.close();
  });

  test('remote suppression prevents echo', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    await database.ensureSyncInfrastructure();
    await database.setSyncSuppressed(true);

    await database.addWater(
      WaterEntriesCompanion(
        id: const Value('water-1'),
        amountMl: const Value(500),
        occurredAt: Value(DateTime.now()),
      ),
    );

    await database.setSyncSuppressed(false);
    final List<SyncOutboxRow> rows = await database
        .select(database.syncOutbox)
        .get();
    expect(rows, isEmpty);
    await database.close();
  });

  test('delete replaces pending upsert with tombstone', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    await database.ensureSyncInfrastructure();

    await database.addWater(
      WaterEntriesCompanion(
        id: const Value('water-delete'),
        amountMl: const Value(250),
        occurredAt: Value(DateTime.now()),
      ),
    );

    await (database.delete(
      database.waterEntries,
    )..where((WaterEntries table) => table.id.equals('water-delete'))).go();

    final SyncOutboxRow row = await database
        .select(database.syncOutbox)
        .getSingle();
    expect(row.operation, 'delete');
    await database.close();
  });
}
