import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/pr_theme.dart';
import '../../../core/widgets/premium_panel.dart';
import '../data/offline_food_repository.dart';

class FoodIntelligenceScreen extends StatefulWidget {
  const FoodIntelligenceScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<FoodIntelligenceScreen> createState() => _FoodIntelligenceScreenState();
}

class _FoodIntelligenceScreenState extends State<FoodIntelligenceScreen> {
  late final OfflineFoodRepository _repo = OfflineFoodRepository(
    widget.database,
  );
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repo.ensureSeeded();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = PrTheme.accent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Food Intelligence'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create custom food',
            onPressed: _createCustomFood,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: <Widget>[
          PremiumPanel(
            borderRadius: 34,
            child: Row(
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.restaurant_menu_rounded, color: accent),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Offline food intelligence',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Local search, serving-size nutrition, favourites, recent foods and custom foods — no cloud required.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              labelText: 'Search foods',
              hintText: 'Banana, roti, dal, paneer...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Food library',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<FoodFavoriteRow>>(
            stream: _repo.watchFavorites(),
            builder: (context, favSnapshot) {
              final favourites = (favSnapshot.data ?? const <FoodFavoriteRow>[])
                  .map((e) => e.foodId)
                  .toSet();

              return StreamBuilder<List<FoodCatalogItemRow>>(
                stream: _repo.watchSearch(_query),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final foods = snapshot.data!;
                  if (foods.isEmpty) {
                    return const PremiumPanel(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No local food matched. Create a custom food if needed.',
                        ),
                      ),
                    );
                  }

                  return PremiumPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < foods.length; i++)
                          _FoodRow(
                            food: foods[i],
                            favourite: favourites.contains(foods[i].id),
                            last: i == foods.length - 1,
                            onFavourite: () async {
                              await _repo.toggleFavorite(foods[i].id);
                              HapticFeedback.selectionClick();
                            },
                            onTap: () => _logFood(foods[i]),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Recent entries',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<FoodEntry>>(
            future: _repo.recentFoods(),
            builder: (context, snapshot) {
              final recent = snapshot.data ?? const <FoodEntry>[];
              if (recent.isEmpty) {
                return const PremiumPanel(
                  child: Text(
                    'Recent foods will appear here after you log them.',
                  ),
                );
              }
              return PremiumPanel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recent
                      .map(
                        (entry) => ActionChip(
                          avatar: const Icon(Icons.history_rounded, size: 17),
                          label: Text(entry.name),
                          onPressed: () async {
                            final catalog =
                                await (widget.database.select(
                                        widget.database.foodCatalogItems,
                                      )
                                      ..where((t) => t.name.equals(entry.name))
                                      ..limit(1))
                                    .getSingleOrNull();
                            if (catalog != null && mounted) {
                              await _logFood(catalog);
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logFood(FoodCatalogItemRow food) async {
    final grams = TextEditingController(
      text: food.defaultServingGrams.toStringAsFixed(0),
    );
    String meal = 'snack';

    final result = await showModalBottomSheet<({double grams, String meal})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  food.name,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '${food.caloriesPer100g.toStringAsFixed(0)} kcal / 100 g • P ${food.proteinPer100g.toStringAsFixed(1)} • C ${food.carbsPer100g.toStringAsFixed(1)} • F ${food.fatPer100g.toStringAsFixed(1)}',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: grams,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Serving size',
                    suffixText: 'g / ml equivalent',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: meal,
                  decoration: const InputDecoration(labelText: 'Meal'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'breakfast',
                      child: Text('Breakfast'),
                    ),
                    DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                    DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                    DropdownMenuItem(value: 'snack', child: Text('Snack')),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => meal = value ?? 'snack'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () {
                      final value = double.tryParse(grams.text.trim());
                      if (value == null || value <= 0 || value > 5000) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a valid serving between 0 and 5000 g.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop((grams: value, meal: meal));
                    },
                    child: const Text('Log food'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    grams.dispose();
    if (result == null) return;
    await _repo.logFood(food: food, grams: result.grams, mealType: result.meal);
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${food.name} added to ${result.meal}.')),
      );
      setState(() {});
    }
  }

  Future<void> _createCustomFood() async {
    final name = TextEditingController();
    final kcal = TextEditingController();
    final protein = TextEditingController(text: '0');
    final carbs = TextEditingController(text: '0');
    final fat = TextEditingController(text: '0');
    final serving = TextEditingController(text: '100');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Create custom food',
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Food name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kcal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories / 100 g'),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: protein,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Protein'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbs,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbs'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fat,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fat'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: serving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Default serving grams'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await _repo.createCustomFood(
                        name: name.text,
                        caloriesPer100g: double.parse(kcal.text),
                        proteinPer100g: double.parse(protein.text),
                        carbsPer100g: double.parse(carbs.text),
                        fatPer100g: double.parse(fat.text),
                        defaultServingGrams: double.parse(serving.text),
                      );

                      if (!sheetContext.mounted) {
                        return;
                      }

                      Navigator.of(sheetContext).pop(true);
                    } catch (error) {
                      if (!sheetContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text('Could not save: $error'),
                        ),
                      );
                    }
                  },
                  child: const Text('Save custom food'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    name.dispose();
    kcal.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    serving.dispose();

    if (saved == true && mounted) {
      setState(() {});
    }
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.food,
    required this.favourite,
    required this.last,
    required this.onFavourite,
    required this.onTap,
  });

  final FoodCatalogItemRow food;
  final bool favourite;
  final bool last;
  final VoidCallback onFavourite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = PrTheme.accent(context);
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.local_dining_rounded, color: accent),
          ),
          title: Text(
            food.name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${food.caloriesPer100g.toStringAsFixed(0)} kcal / 100 g • serving ${food.defaultServingGrams.toStringAsFixed(0)} ${food.defaultUnit}',
          ),
          trailing: IconButton(
            tooltip: favourite ? 'Remove favourite' : 'Favourite',
            onPressed: onFavourite,
            icon: Icon(
              favourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: accent,
            ),
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}
