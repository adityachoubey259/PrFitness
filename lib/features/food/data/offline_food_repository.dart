import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_factory.dart';
import '../domain/food_math.dart';

class OfflineFoodRepository {
  OfflineFoodRepository(this.database);

  final AppDatabase database;

  Future<void> ensureSeeded() async {
    final countExpression = database.foodCatalogItems.id.count();
    final countQuery = database.selectOnly(database.foodCatalogItems)
      ..addColumns([countExpression]);
    final count = await countQuery
        .map((row) => row.read(countExpression) ?? 0)
        .getSingle();
    if (count > 0) return;

    final now = DateTime.now();
    const foods = <List<Object>>[
      ['banana', 'Banana', 'kela', 89.0, 1.1, 22.8, 0.3, 118.0, 'g'],
      ['apple', 'Apple', 'seb', 52.0, 0.3, 13.8, 0.2, 182.0, 'g'],
      ['orange', 'Orange', 'santra', 47.0, 0.9, 11.8, 0.1, 131.0, 'g'],
      ['guava', 'Guava', 'amrood', 68.0, 2.6, 14.3, 1.0, 100.0, 'g'],
      ['papaya', 'Papaya', 'papita', 43.0, 0.5, 10.8, 0.3, 145.0, 'g'],
      ['mango', 'Mango', 'aam', 60.0, 0.8, 15.0, 0.4, 165.0, 'g'],
      ['watermelon', 'Watermelon', 'tarbooj', 30.0, 0.6, 7.6, 0.2, 150.0, 'g'],
      [
        'white_rice_cooked',
        'White rice, cooked',
        'chawal rice',
        130.0,
        2.7,
        28.2,
        0.3,
        150.0,
        'g',
      ],
      [
        'brown_rice_cooked',
        'Brown rice, cooked',
        'brown chawal',
        123.0,
        2.7,
        25.6,
        1.0,
        150.0,
        'g',
      ],
      [
        'roti_wheat',
        'Whole-wheat roti',
        'chapati roti',
        297.0,
        10.0,
        55.0,
        4.0,
        40.0,
        'g',
      ],
      ['oats_dry', 'Oats, dry', 'oatmeal', 389.0, 16.9, 66.3, 6.9, 40.0, 'g'],
      [
        'poha',
        'Poha, prepared',
        'flattened rice',
        130.0,
        2.5,
        25.0,
        2.5,
        150.0,
        'g',
      ],
      ['idli', 'Idli', 'idly', 146.0, 4.5, 30.0, 0.7, 50.0, 'g'],
      ['dosa_plain', 'Plain dosa', 'dosa', 184.0, 4.5, 30.0, 5.0, 100.0, 'g'],
      [
        'upma',
        'Upma, prepared',
        'suji upma',
        120.0,
        3.5,
        20.0,
        3.0,
        150.0,
        'g',
      ],
      [
        'dal_cooked',
        'Dal, cooked',
        'lentil dal',
        116.0,
        9.0,
        20.0,
        0.4,
        150.0,
        'g',
      ],
      [
        'rajma_cooked',
        'Rajma, cooked',
        'kidney beans',
        127.0,
        8.7,
        22.8,
        0.5,
        150.0,
        'g',
      ],
      [
        'chickpeas_cooked',
        'Chickpeas, cooked',
        'chana',
        164.0,
        8.9,
        27.4,
        2.6,
        150.0,
        'g',
      ],
      [
        'paneer',
        'Paneer',
        'cottage cheese',
        265.0,
        18.3,
        1.2,
        20.8,
        100.0,
        'g',
      ],
      ['tofu', 'Tofu', 'soy paneer', 76.0, 8.1, 1.9, 4.8, 100.0, 'g'],
      [
        'milk_toned',
        'Toned milk',
        'milk doodh',
        60.0,
        3.2,
        4.8,
        3.0,
        250.0,
        'ml',
      ],
      [
        'curd_plain',
        'Plain curd',
        'dahi yogurt',
        61.0,
        3.5,
        4.7,
        3.3,
        150.0,
        'g',
      ],
      ['egg_whole', 'Whole egg', 'anda egg', 143.0, 12.6, 0.7, 9.5, 50.0, 'g'],
      [
        'chicken_breast_cooked',
        'Chicken breast, cooked',
        'chicken',
        165.0,
        31.0,
        0.0,
        3.6,
        100.0,
        'g',
      ],
      [
        'fish_rohu_cooked',
        'Rohu fish, cooked',
        'fish machhli',
        130.0,
        22.0,
        0.0,
        4.5,
        100.0,
        'g',
      ],
      ['peanut', 'Peanuts', 'moongfali', 567.0, 25.8, 16.1, 49.2, 28.0, 'g'],
      ['almond', 'Almonds', 'badam', 579.0, 21.2, 21.6, 49.9, 28.0, 'g'],
      ['walnut', 'Walnuts', 'akhrot', 654.0, 15.2, 13.7, 65.2, 28.0, 'g'],
      [
        'potato_boiled',
        'Potato, boiled',
        'aloo',
        87.0,
        1.9,
        20.1,
        0.1,
        150.0,
        'g',
      ],
      [
        'sweet_potato',
        'Sweet potato, cooked',
        'shakarkand',
        90.0,
        2.0,
        20.7,
        0.2,
        150.0,
        'g',
      ],
      ['broccoli', 'Broccoli', 'broccoli', 34.0, 2.8, 6.6, 0.4, 100.0, 'g'],
      ['spinach', 'Spinach', 'palak', 23.0, 2.9, 3.6, 0.4, 100.0, 'g'],
      ['cucumber', 'Cucumber', 'kheera', 15.0, 0.7, 3.6, 0.1, 100.0, 'g'],
      ['tomato', 'Tomato', 'tamatar', 18.0, 0.9, 3.9, 0.2, 100.0, 'g'],
      ['carrot', 'Carrot', 'gajar', 41.0, 0.9, 9.6, 0.2, 100.0, 'g'],
      [
        'bread_wholewheat',
        'Whole-wheat bread',
        'bread',
        247.0,
        13.0,
        41.0,
        4.2,
        30.0,
        'g',
      ],
      ['butter', 'Butter', 'makhan', 717.0, 0.9, 0.1, 81.1, 10.0, 'g'],
      ['ghee', 'Ghee', 'clarified butter', 900.0, 0.0, 0.0, 100.0, 10.0, 'g'],
      ['sugar', 'Sugar', 'chini', 387.0, 0.0, 100.0, 0.0, 5.0, 'g'],
      [
        'tea_milk_sugar',
        'Milk tea with sugar',
        'chai',
        45.0,
        1.0,
        7.0,
        1.5,
        200.0,
        'ml',
      ],
      [
        'coffee_milk_sugar',
        'Coffee with milk and sugar',
        'coffee',
        50.0,
        1.2,
        8.0,
        1.5,
        200.0,
        'ml',
      ],
      [
        'whey_protein',
        'Whey protein powder',
        'protein whey',
        400.0,
        80.0,
        8.0,
        6.0,
        30.0,
        'g',
      ],
    ];

    await database.batch((batch) {
      batch.insertAll(
        database.foodCatalogItems,
        foods
            .map(
              (row) => FoodCatalogItemsCompanion.insert(
                id: row[0] as String,
                name: row[1] as String,
                aliases: Value(row[2] as String),
                caloriesPer100g: row[3] as double,
                proteinPer100g: Value(row[4] as double),
                carbsPer100g: Value(row[5] as double),
                fatPer100g: Value(row[6] as double),
                defaultServingGrams: Value(row[7] as double),
                defaultUnit: Value(row[8] as String),
                userDefined: const Value(false),
                createdAt: now,
              ),
            )
            .toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Stream<List<FoodCatalogItemRow>> watchSearch(String query) {
    final normalized = query.trim().toLowerCase();
    final q = database.select(database.foodCatalogItems)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (normalized.isNotEmpty) {
      q.where(
        (t) => t.name.like('%$normalized%') | t.aliases.like('%$normalized%'),
      );
    }
    return q.watch();
  }

  Stream<List<FoodFavoriteRow>> watchFavorites() =>
      database.select(database.foodFavorites).watch();

  Future<void> toggleFavorite(String foodId) async {
    final existing = await (database.select(
      database.foodFavorites,
    )..where((t) => t.foodId.equals(foodId))).getSingleOrNull();
    if (existing == null) {
      await database
          .into(database.foodFavorites)
          .insert(
            FoodFavoritesCompanion.insert(
              foodId: foodId,
              createdAt: DateTime.now(),
            ),
          );
    } else {
      await (database.delete(
        database.foodFavorites,
      )..where((t) => t.foodId.equals(foodId))).go();
    }
  }

  Future<void> createCustomFood({
    required String name,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
    required double defaultServingGrams,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Food name is required.');
    FoodMath.fromPer100g(
      grams: defaultServingGrams,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
    );
    await database
        .into(database.foodCatalogItems)
        .insert(
          FoodCatalogItemsCompanion.insert(
            id: IdFactory.uuidV4(),
            name: clean,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: Value(proteinPer100g),
            carbsPer100g: Value(carbsPer100g),
            fatPer100g: Value(fatPer100g),
            defaultServingGrams: Value(defaultServingGrams),
            defaultUnit: const Value('g'),
            userDefined: const Value(true),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> logFood({
    required FoodCatalogItemRow food,
    required double grams,
    required String mealType,
  }) async {
    const meals = <String>{'breakfast', 'lunch', 'dinner', 'snack'};
    if (!meals.contains(mealType)) throw ArgumentError('Invalid meal type.');

    final p = FoodMath.fromPer100g(
      grams: grams,
      caloriesPer100g: food.caloriesPer100g,
      proteinPer100g: food.proteinPer100g,
      carbsPer100g: food.carbsPer100g,
      fatPer100g: food.fatPer100g,
    );

    await database.addFood(
      FoodEntriesCompanion(
        id: Value(IdFactory.uuidV4()),
        name: Value(food.name),
        calories: Value(p.calories),
        proteinG: Value(p.proteinG),
        carbsG: Value(p.carbsG),
        fatG: Value(p.fatG),
        mealType: Value(mealType),
        servingQuantity: Value(grams),
        servingUnit: const Value('g'),
        servingGrams: Value(grams),
        occurredAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<FoodEntry>> recentFoods({int limit = 12}) =>
      (database.select(database.foodEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(limit))
          .get();
}
