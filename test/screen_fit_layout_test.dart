// Screen fit (2026-10-18): testers on stock phones saw every screen too big.
// Renders the sign-in screen and the dashboard's gig-app carousel and trip
// row through ScreenFitScope (text clamp) on small, stock and roomy phones,
// plus the 480 dp canvas ScreenFitBinding draws stock phones on, at the
// system text sizes testers use, and fails on any layout overflow.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:controlmiles/logic/app_state.dart';
import 'package:controlmiles/screens/login_screen.dart';
import 'package:controlmiles/theme/screen_fit.dart';
import 'package:controlmiles/widgets/gig_app_selector.dart';
import 'package:controlmiles/widgets/tracking_action_button.dart';

const _phones = <String, Size>{
  'small 360x640': Size(360, 640),
  'Galaxy S23+ 384x832': Size(384, 832),
  'stock 412x915': Size(412, 915),
  'scaled canvas 480x1040': Size(480, 1040),
};
const _textScales = [1.0, 1.3, 1.5, 2.0];

/// The app sets 'Inter' but bundles no font file, so Android draws Roboto.
/// Load the real Roboto from the Flutter SDK under both names; the test
/// font's square glyphs are far wider than real text and would report
/// overflows no phone shows.
Future<void> _loadRealFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final files = Directory(dir).listSync().whereType<File>()
      .where((f) => RegExp(r'roboto-[a-z]+\.ttf$').hasMatch(f.path) && !f.path.contains('italic'));
  for (final family in ['Inter', 'Roboto']) {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = f.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

Future<void> _pumpOn(WidgetTester tester, AppState appState, Size size, double textScale, Widget child) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        builder: (context, c) => ScreenFitScope(child: c!),
        home: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  late AppState appState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
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

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('text scale is clamped to 0.85x-1.3x', (tester) async {
    double? seen;
    await _pumpOn(tester, appState, const Size(384, 832), 2.0, Builder(builder: (context) {
      seen = MediaQuery.textScalerOf(context).scale(10) / 10;
      return const SizedBox();
    }));
    expect(seen, ScreenFitScope.maxTextScale);
  });

  test('stock phones are drawn at 0.80x, never below 0.75x, tablets at 1x', () {
    expect(uiScaleForShortestSide(384), closeTo(0.8, 0.001));
    expect(uiScaleForShortestSide(412), closeTo(0.858, 0.001));
    expect(uiScaleForShortestSide(300), kMinUiScale);
    expect(uiScaleForShortestSide(600), 1.0);
  });

  for (final phone in _phones.entries) {
    for (final scale in _textScales) {
      final label = '${phone.key} @ text ${scale}x';

      testWidgets('sign-in fits: $label', (tester) async {
        await _pumpOn(tester, appState, phone.value, scale, const LoginScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('dashboard carousel + trip row fit: $label', (tester) async {
        await _pumpOn(
          tester,
          appState,
          phone.value,
          scale,
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: TrackingActionButton(selectedGigApp: null, compact: true),
                  ),
                  GigAppSelector(selectedGigApp: null, activeGigApp: null, onAppSelected: (_) {}),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
