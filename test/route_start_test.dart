import 'dart:io';

import 'package:controlmiles/tracking/route_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-11-11: an automatic trip's address said "219 Allendale" while its drawn route
// began at the first GPS point, 250 m away. The parking spot goes first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_route');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  test('the parking spot becomes the first point of the route', () async {
    await RouteRecorder.add('s1', 39.288700, -76.677220); // first GPS point
    await RouteRecorder.add('s1', 39.287000, -76.674000);
    await RouteRecorder.startAt('s1', 39.290825, -76.677932); // 219 Allendale
    final lines = await File('${tmp.path}/routes/s1.txt').readAsLines();
    expect(lines, ['39.290825,-76.677932', '39.288700,-76.677220', '39.287000,-76.674000']);
  });
}
