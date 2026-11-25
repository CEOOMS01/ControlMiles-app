import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:controlmiles/i18n/app_texts.dart';
import 'package:controlmiles/logic/app_state.dart';
import 'package:controlmiles/services/app_update_service.dart';
import 'package:controlmiles/services/update_guard.dart';
import 'package:controlmiles/widgets/update_gate.dart';

class _FakeAppState extends ChangeNotifier implements AppState {
  @override
  String tr(String key) => AppTexts.getText(key, AppLanguage.en);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _app() => ChangeNotifierProvider<AppState>(
  create: (_) => _FakeAppState(),
  child: MaterialApp(
    home: UpdateGate(
      checkOnStart: false,
      child: Scaffold(
        body: Center(
          child: TextButton(onPressed: () {}, child: const Text('the app')),
        ),
      ),
    ),
  ),
);

void main() {
  tearDown(() => AppUpdateService.requirement.value = null);

  group('which build a phone must reach', () {
    test('it is the higher of min_build and latest_build', () {
      expect(AppUpdateService.requiredBuild(0, 78), 78);
      expect(AppUpdateService.requiredBuild(80, 78), 80);
      expect(AppUpdateService.requiredBuild(0, 0), 0);
    });

    test(
      'an older build is blocked; the same or a newer one is not; no row means nothing is required',
      () {
        expect(AppUpdateService.isBlocked(77, 78), isTrue);
        expect(AppUpdateService.isBlocked(78, 78), isFalse);
        expect(AppUpdateService.isBlocked(79, 78), isFalse);
        expect(AppUpdateService.isBlocked(5, 0), isFalse);
      },
    );
  });

  group('the first start after an update', () {
    test(
      'a newer build than the last one that ran is an update; a first install is not',
      () {
        expect(UpdateGuard.isUpdate(78, 79), isTrue);
        expect(UpdateGuard.isUpdate(79, 79), isFalse);
        expect(UpdateGuard.isUpdate(80, 79), isFalse);
        expect(UpdateGuard.isUpdate(null, 79), isFalse);
      },
    );
  });

  group('the update screen', () {
    testWidgets(
      'with nothing required, the app is shown and there is no notice',
      (tester) async {
        await tester.pumpWidget(_app());
        expect(find.text('the app'), findsOneWidget);
        expect(find.text('Update'), findsNothing);
      },
    );

    testWidgets(
      'when a build is required the app is hidden and only the update screen is usable',
      (tester) async {
        await tester.pumpWidget(_app());
        AppUpdateService.requirement.value = const UpdateRequirement(
          installed: 77,
          required: 78,
          storeUrl: 'https://example.invalid/store',
        );
        await tester.pump();

        expect(find.text('New version available'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);
        // The app underneath is kept but not shown or reachable.
        expect(find.text('the app'), findsNothing);
        expect(find.text('Later'), findsNothing);
      },
    );

    testWidgets(
      'when the requirement clears the same app comes back with its state',
      (tester) async {
        await tester.pumpWidget(_app());
        AppUpdateService.requirement.value = const UpdateRequirement(
          installed: 77,
          required: 78,
          storeUrl: 'https://example.invalid/store',
        );
        await tester.pump();
        AppUpdateService.requirement.value = null;
        await tester.pump();
        expect(find.text('the app'), findsOneWidget);
        expect(find.text('Update'), findsNothing);
      },
    );
  });
}
