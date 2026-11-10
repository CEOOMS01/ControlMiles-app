// The Regular Trip form fits on a phone at the text sizes testers use.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:controlmiles/logic/app_state.dart';
import 'package:controlmiles/views/regular_trips_screen.dart';

void main() {
  late AppState appState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), detectSessionInUri: false),
    );
    appState = AppState();
  });

  for (final scale in const [1.0, 1.5]) {
    testWidgets('editor fits 360x640 at text ${scale}x', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: RegularTripEditorScreen(
              draft: RegularTripDraft(
                startLatitude: 39.29,
                startLongitude: -76.67,
                startAddress: '219 Allendale St, Baltimore, MD',
                endLatitude: 39.30,
                endLongitude: -76.66,
                endAddress: '2430 W Lexington St, Baltimore, MD',
                purpose: 'business',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  }
}
