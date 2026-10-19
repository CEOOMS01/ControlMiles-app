// Product tour (2026-10-18): the tour never showed on any phone since 1.3.0
// -- ProductTour.run looked for targets with `key.currentContext`, which
// showcaseview 5.x never sets. This starts a one-step tour the way the
// History "?" does and checks its card is really on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:controlmiles/logic/app_state.dart';
import 'package:controlmiles/onboarding/product_tour.dart';

class _TourHost extends StatefulWidget {
  const _TourHost();
  @override
  State<_TourHost> createState() => _TourHostState();
}

class _TourHostState extends State<_TourHost> {
  final _scope = TourScope('test');
  final _target = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scope.register();
  }

  @override
  void dispose() {
    _scope.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [
        TourHelpButton(
          onPressed: () => ProductTour.run(
            context,
            id: TourIds.history,
            scope: _scope.name,
            keys: [_target],
            force: true,
          ),
        ),
      ]),
      body: Center(
        child: TourTarget(
          showcaseKey: _target,
          scope: _scope.name,
          step: 1,
          total: 1,
          titleKey: 'ptour_trip_title',
          bodyKey: 'ptour_trip_body',
          child: const SizedBox(width: 200, height: 80, child: Text('Trip 1')),
        ),
      ),
    );
  }
}

void main() {
  late AppState appState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
    appState = AppState();
  });

  testWidgets('the "?" replay shows the tour card over its target', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: _TourHost()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final title = appState.tr('ptour_trip_title');
    expect(find.text(title), findsNothing);

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text(title), findsOneWidget);
    expect(find.text(appState.tr('tour_got_it')), findsOneWidget);
  });
}
