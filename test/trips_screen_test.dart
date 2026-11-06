// The trips page renders from preview rows (no connection) at stock phone sizes
// and at the system text sizes testers use, without a layout overflow. Also writes a
// picture of it when TRIPS_SHOT is set (used to look at the design).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:controlmiles/logic/app_state.dart';
import 'package:controlmiles/screens/trips_screen.dart';
import 'package:controlmiles/widgets/trip_card.dart';
import 'package:controlmiles/widgets/trip_card.dart';
import 'package:controlmiles/theme/screen_fit.dart';

Future<void> _loadRealFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final files = Directory(dir).listSync().whereType<File>()
      .where((f) => RegExp(r'roboto-[a-z]+\.ttf$').hasMatch(f.path) && !f.path.contains('italic'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
  for (final family in ['Inter', 'Roboto']) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

Map<String, dynamic> _section(String id, String sid, String app, String start, String end, double miles,
        {String? purpose, String? from, String? to, String? notes}) =>
    {
      'id': id,
      'session_id': sid,
      'user_id': 'u',
      'gig_app': app,
      'section_status': 'closed',
      'start_time': start,
      'end_time': end,
      'total_miles': miles,
      'total_duration_seconds': DateTime.parse(end).difference(DateTime.parse(start)).inSeconds,
      'irs_purpose': purpose,
      'start_address': from,
      'end_address': to,
      'notes': notes,
    };

Map<String, dynamic> _trip(String sid, String start, String end, double miles, List<Map<String, dynamic>> sections) => {
      'id': sid,
      'user_id': 'u',
      'start_time': start,
      'end_time': end,
      'total_miles': miles,
      'total_duration_seconds': DateTime.parse(end).difference(DateTime.parse(start)).inSeconds,
      'is_closed': true,
      'session_status': 'closed',
      'session_sections': sections,
    };

final _rows = <Map<String, dynamic>>[
  _trip('s1', '2026-11-06T16:43:00Z', '2026-11-06T16:46:30Z', 1.6, [
    _section('a1', 's1', 'custom', '2026-11-06T16:43:00Z', '2026-11-06T16:46:30Z', 1.6,
        from: '4607 Coleherne Rd, Baltimore, MD', to: '328 Allendale St, Baltimore, MD'),
  ]),
  _trip('s2', '2026-11-06T16:06:00Z', '2026-11-06T16:16:30Z', 2.2, [
    _section('b1', 's2', 'custom', '2026-11-06T16:06:00Z', '2026-11-06T16:16:30Z', 2.2,
        purpose: 'business', from: '4134 Edmondson Avenue, Baltimore', to: '4711 Edmondson Avenue, Baltimore', notes: 'Pickup at the warehouse'),
  ]),
  _trip('s3', '2026-11-05T15:00:00Z', '2026-11-05T15:40:00Z', 12.4, [
    _section('c1', 's3', 'roadie', '2026-11-05T15:00:00Z', '2026-11-05T15:20:00Z', 6.0, from: 'Home', to: 'Depot'),
    _section('c2', 's3', 'doordash', '2026-11-05T15:20:00Z', '2026-11-05T15:40:00Z', 6.4, to: '1200 Light St, Baltimore'),
  ]),
  _trip('s4', '2026-10-30T13:00:00Z', '2026-10-30T13:25:00Z', 7.1, [
    _section('d1', 's4', 'custom', '2026-10-30T13:00:00Z', '2026-10-30T13:25:00Z', 7.1, purpose: 'medical'),
  ]),
];

void main() {
  late AppState appState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
    await initializeDateFormatting('en');
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), detectSessionInUri: false),
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

  _popupTests();

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    for (final scale in const [1.0, 1.5]) {
      testWidgets('trips page fits: ${size.width.toInt()}x${size.height.toInt()} @ text ${scale}x', (tester) async {
        final tall = Platform.environment['TRIPS_SHOT_DIR'] != null && size.width == 412 && scale == 1.0;
        tester.view.physicalSize = (tall ? const Size(412, 1500) : size) * 3;
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final key = GlobalKey();
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              builder: (context, c) => ScreenFitScope(child: c!),
              home: RepaintBoundary(key: key, child: TripsScreen(previewRows: _rows)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);

        final dir = Platform.environment['TRIPS_SHOT_DIR'];
        if (dir != null && scale == 1.0 && size.width == 412) {
          Future<void> shoot(String name) => tester.runAsync(() async {
                final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 2);
                final data = await image.toByteData(format: ui.ImageByteFormat.png);
                File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
              });
          await shoot('trips_all');
          await tester.tap(find.textContaining('No category'));
          await tester.pump(const Duration(milliseconds: 400));
          await shoot('trips_unclassified');
          await tester.tap(find.text('Summary'));
          await tester.pump(const Duration(milliseconds: 400));
          await shoot('trips_summary');
        }
      });
    }
  }
}

void _popupTests() {
  testWidgets('trip pop-up card fits and draws', (tester) async {
    final appState = AppState();
    tester.view.physicalSize = const Size(412, 915) * 3;
    tester.view.devicePixelRatio = 3;
    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Inter'),
          builder: (context, c) => ScreenFitScope(child: c!),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: Colors.black54,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      TripCard(
                        trip: TripData.fromRow(_rows.first),
                        framed: false,
                        onPurpose: (_) {},
                        onMore: () {},
                        onEditAddress: () {},
                        onNote: () {},
                      ),
                      TextButton(onPressed: () {}, child: const Text('Categorize later')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    final shot = Platform.environment['TRIPS_SHOT_POPUP'];
    if (shot != null) {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(shot).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
