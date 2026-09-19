import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/core/database/app_database.dart';
import 'package:prfitness/core/services/data_import_service.dart';

void main() {
  test('validated backup restores profile and food', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    final String now = DateTime(2026, 9, 19, 8).toUtc().toIso8601String();

    final String backup = jsonEncode(<String, Object?>{
      'format': 'prfitness-export',
      'formatVersion': 1,
      'profile': <String, Object?>{
        'id': 'profile-1',
        'name': 'Tester',
        'birthDate': DateTime(1995, 1, 1).toUtc().toIso8601String(),
        'sex': 'male',
        'heightCm': 180,
        'weightKg': 80,
        'targetWeightKg': null,
        'activityLevel': 'moderate',
        'goal': 'maintain',
        'dailyStudyTargetMinutes': 120,
        'createdAt': now,
        'updatedAt': now,
      },
      'foodEntries': <Object?>[
        <String, Object?>{
          'id': 'food-1',
          'name': 'Banana',
          'calories': 105,
          'proteinG': 1.3,
          'carbsG': 27,
          'fatG': 0.4,
          'occurredAt': now,
        },
      ],
      'activityEntries': <Object?>[],
      'waterEntries': <Object?>[],
      'studySessions': <Object?>[],
      'goals': <Object?>[],
      'goalCompletions': <Object?>[],
      'routines': <Object?>[],
      'routineCompletions': <Object?>[],
      'reminders': <Object?>[],
      'weightEntries': <Object?>[],
      'settings': <Object?>[],
    });

    final ImportSummary summary = await DataImportService(database)
        .restoreJson(backup);

    expect(summary.records, 2);
    expect((await database.getProfile())?.name, 'Tester');
    expect(await database.select(database.foodEntries).get(), hasLength(1));

    await database.close();
  });

  test('foreign backup format is rejected', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

    await expectLater(
      DataImportService(database).restoreJson(
        const JsonEncoder().convert(<String, Object?>{
          'format': 'something-else',
          'formatVersion': 1,
        }),
      ),
      throwsA(isA<FormatException>()),
    );

    await database.close();
  });
}
