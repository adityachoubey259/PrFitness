import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/core/database/app_database.dart';
import 'package:prfitness/features/productivity/data/productivity_repository.dart';

void main() {
  test('study, goals and routines persist locally', () async {
    final AppDatabase database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

    final ProductivityRepository repository = ProductivityRepository(database);

    await repository.addManualStudy(subject: 'Algorithms', minutes: 45);

    await repository.addGoal(title: 'Complete practice set', category: 'Study');

    await repository.addRoutine(title: 'Morning mobility', type: 'Workout');

    final List<StudySession> study = await database
        .watchStudyForDay(DateTime.now())
        .first;

    final List<Goal> goals = await database.watchGoals().first;

    final List<RoutineItem> routines = await database.watchRoutines().first;

    expect(study, hasLength(1));
    expect(goals, hasLength(1));
    expect(routines, hasLength(1));

    await repository.setGoalCompletedToday(
      goalId: goals.first.id,
      completed: true,
    );

    await repository.setRoutineCompletedToday(
      routineId: routines.first.id,
      completed: true,
    );

    final List<GoalCompletion> goalCompletions = await database
        .watchGoalCompletionsForDay(DateTime.now())
        .first;

    final List<RoutineCompletion> routineCompletions = await database
        .watchRoutineCompletionsForDay(DateTime.now())
        .first;

    expect(goalCompletions, hasLength(1));

    expect(routineCompletions, hasLength(1));

    await database.close();
  });
}
