import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/core/database/app_database.dart';
import 'package:prfitness/features/history/data/record_edit_service.dart';
import 'package:prfitness/features/sync/data/sync_database.dart';

void main() {
  test('edit persists and is captured by sync outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureSyncInfrastructure();
    await db.addFood(
      FoodEntriesCompanion(
        id: const Value('food-edit'),
        name: const Value('Old'),
        calories: const Value(100),
        occurredAt: Value(DateTime.now()),
      ),
    );
    await db.delete(db.syncOutbox).go();
    final row = await db.select(db.foodEntries).getSingle();
    await RecordEditService(db).updateFood(
      row,
      name: 'New',
      calories: 120,
      proteinG: 5,
      carbsG: 10,
      fatG: 2,
    );
    final updated = await db.select(db.foodEntries).getSingle();
    expect(updated.name, 'New');
    expect(updated.calories, 120);
    final outbox = await db.select(db.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.operation, 'upsert');
    await db.close();
  });

  test('delete then undo restores record and replaces tombstone', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureSyncInfrastructure();
    await db.addWater(
      WaterEntriesCompanion(
        id: const Value('water-undo'),
        amountMl: const Value(500),
        occurredAt: Value(DateTime.now()),
      ),
    );
    await db.delete(db.syncOutbox).go();
    final row = await db.select(db.waterEntries).getSingle();
    final service = RecordEditService(db);
    final token = await service.deleteWater(row);
    var queued = await db.select(db.syncOutbox).getSingle();
    expect(queued.operation, 'delete');
    await service.undo(token);
    expect(await db.select(db.waterEntries).get(), hasLength(1));
    queued = await db.select(db.syncOutbox).getSingle();
    expect(queued.operation, 'upsert');
    await db.close();
  });
}
