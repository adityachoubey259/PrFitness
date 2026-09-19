import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/app/prfitness_app.dart';
import 'package:prfitness/core/database/app_database.dart';
import 'package:prfitness/features/profile/data/profile_repository.dart';

void main() {
  testWidgets('saved profile opens premium command center', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

    await ProfileRepository(database).save(
      name: 'Test User',
      birthDate: DateTime(1996, 1, 1),
      sex: 'male',
      heightCm: 180,
      weightKg: 80,
      activityLevel: 'moderate',
      goal: 'maintain',
      dailyStudyTargetMinutes: 120,
    );

    await tester.pumpWidget(PrFitnessApp(database: database));

    await tester.pumpAndSettle();

    expect(find.text('Command Center'), findsOneWidget);

    expect(find.textContaining('Test User'), findsWidgets);

    await database.close();
  });
}
