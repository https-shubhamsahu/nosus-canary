import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:no_sus/features/groups/screens/groups_screen.dart';
import 'package:no_sus/features/groups/domain/models/study_group.dart';
import 'package:no_sus/features/groups/providers/groups_provider.dart';

class MockGroupsNotifier extends GroupsNotifier with Mock {
  @override
  Future<List<StudyGroup>> build() async {
    return [
      StudyGroup(
        id: 'g1',
        name: 'Math 101',
        description: 'Calculus study group',
        inviteCode: 'MATH101',
        members: const [],
        fileCount: 0,
        lastActivity: DateTime.now(),
      ),
      StudyGroup(
        id: 'g2',
        name: 'Physics',
        description: 'Physics group',
        inviteCode: 'PHYS200',
        members: const [],
        fileCount: 0,
        lastActivity: DateTime.now(),
      ),
    ];
  }
}

void main() {
  group('GroupsScreen Widget Tests', () {
    testWidgets('renders groups and search bar correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupsProvider.overrideWith(() => MockGroupsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GroupsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify essential UI elements are present
      expect(find.text('STUDY GROUPS'), findsOneWidget); // Assuming header says this
      expect(find.byType(TextField), findsOneWidget); // Search bar
      
      // Verify groups are displayed
      expect(find.text('Math 101'), findsOneWidget);
      expect(find.text('Physics'), findsOneWidget);
    });

    testWidgets('group cards and create-group FAB are announced as labeled buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupsProvider.overrideWith(() => MockGroupsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GroupsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Regression guard for the accessibility fixes in GroupCard and the
      // create-group FAB — checks the Semantics widgets' own configuration.
      final groupCardFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Open group Math 101',
      );
      expect(groupCardFinder, findsOneWidget);
      expect(tester.widget<Semantics>(groupCardFinder).properties.button, isTrue);

      final createFabFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Create group',
      );
      expect(createFabFinder, findsOneWidget);
      expect(tester.widget<Semantics>(createFabFinder).properties.button, isTrue);
    });
  });
}
