// Account, the side menu and its categories fit on a phone at the text sizes testers
// use, and name and email are edited in their own rows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:controlmiles/logic/app_state.dart';
import 'package:controlmiles/routes/app_routes.dart';
import 'package:controlmiles/screens/app_menu_screen.dart';
import 'package:controlmiles/screens/profile_screen.dart';
import 'package:controlmiles/screens/settings_screen.dart';
import 'package:controlmiles/views/my_work_screen.dart';
import 'package:controlmiles/widgets/dashboard_action.dart';
import 'package:controlmiles/onboarding/product_tour.dart';

void main() {
  late AppState appState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Tours are tested on the phone; here they must not cover the screens.
    SharedPreferences.setMockInitialValues({'cm_product_tour_seen_anon': TourIds.all});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), detectSessionInUri: false),
    );
    appState = AppState();
  });

  Widget app(Widget home) => ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: home),
      );

  final screens = <String, Widget>{
    'account': const ProfileScreen(),
    'menu': const AppMenuScreen(),
    'my work': const MyWorkScreen(),
    'tracking': const SettingsScreen(section: AccountSection.tracking),
    'preferences': const SettingsScreen(section: AccountSection.preferences),
    'vehicles and reports': const SettingsScreen(section: AccountSection.vehiclesReports),
    'help': const SettingsScreen(section: AccountSection.help),
    'delete account': const SettingsScreen(section: AccountSection.deleteAccount),
  };

  for (final entry in screens.entries) {
    for (final scale in const [1.0, 1.5]) {
      testWidgets('${entry.key} fits 360x640 at text ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(app(entry.value));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the menu has the language button and no close button', (tester) async {
    await tester.pumpWidget(app(const AppMenuScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.arrow_drop_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('the menu lists every option and sign out', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const AppMenuScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    for (final key in ['dashboard', 'history', 'reports', 'account_title', 'account_tracking', 'account_vehicles_reports', 'preferences', 'account_help', 'logout']) {
      expect(find.text(appState.tr(key)), findsOneWidget, reason: key);
    }
  });

  for (final scale in const [1.0, 1.5]) {
    testWidgets('the three dashboard buttons are the same size at text ${scale}x', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      Widget action(String label) => Expanded(
            child: DashboardAction(icon: Icons.menu_rounded, label: label, background: Colors.black, foreground: Colors.white, onPressed: () {}),
          );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [action('MENU'), const SizedBox(width: 12), action('HISTORIQUE DES TRAJETS'), const SizedBox(width: 12), action('RAPPORTS')]),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final sizes = tester.widgetList(find.byType(DashboardAction)).map((w) => tester.getSize(find.byWidget(w))).toSet();
      expect(sizes.length, 1);
    });
  }

  testWidgets('going back from an option returns to the menu', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        home: const AppMenuScreen(),
        routes: {AppRoutes.profile: (_) => const Scaffold(body: Text('account page'))},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(appState.tr('account_title')));
    await tester.pumpAndSettle();
    expect(find.text('account page'), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.text(appState.tr('account_help')), findsOneWidget);
  });

  testWidgets('a row turns into its own field and there is no edit button on top', (tester) async {
    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.edit_note_rounded), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text(appState.tr('email')));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
  });
}
