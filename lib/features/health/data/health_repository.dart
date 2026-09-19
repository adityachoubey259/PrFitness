import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_factory.dart';
import '../domain/health_engine.dart';

class HealthRepository {
  HealthRepository(this.database);

  final AppDatabase database;

  Future<void> addFood({
    required String name,
    required double calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Food name is required.');
    }

    if (calories <= 0) {
      throw ArgumentError('Calories must be greater than zero.');
    }

    await database.addFood(
      FoodEntriesCompanion(
        id: Value(IdFactory.uuidV4()),
        name: Value(name.trim()),
        calories: Value(calories),
        proteinG: Value(proteinG),
        carbsG: Value(carbsG),
        fatG: Value(fatG),
        occurredAt: Value(DateTime.now()),
      ),
    );
  }

  Future<ActivityEstimate> addActivity({
    required String activityType,
    required String intensity,
    required double weightKg,
    required int durationMinutes,
    double? distanceKm,
  }) async {
    final ActivityEstimate estimate = HealthEngine.estimateActivity(
      activityType: activityType,
      intensity: intensity,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
      distanceKm: distanceKm,
    );

    await database.addActivity(
      ActivityEntriesCompanion(
        id: Value(IdFactory.uuidV4()),
        activityType: Value(activityType),
        intensity: Value(intensity),
        durationMinutes: Value(durationMinutes),
        distanceKm: Value(distanceKm),
        caloriesBurned: Value(estimate.calories),
        occurredAt: Value(DateTime.now()),
      ),
    );

    return estimate;
  }

  Future<void> addWater(int amountMl) async {
    if (amountMl <= 0) {
      throw ArgumentError('Water amount must be greater than zero.');
    }

    await database.addWater(
      WaterEntriesCompanion(
        id: Value(IdFactory.uuidV4()),
        amountMl: Value(amountMl),
        occurredAt: Value(DateTime.now()),
      ),
    );
  }
}
