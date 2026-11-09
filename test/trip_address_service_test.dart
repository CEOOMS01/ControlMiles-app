import 'dart:convert';

import 'package:controlmiles/services/trip_address_service.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart' as pi;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uid = '4594289a-9b7e-4b2b-a177-b9eab3c3525c';
const _sectionId = '681c5213-d3aa-4635-9aa3-114e25c25de2';

/// The phone's geocoder: answers from [_answers], in order of the lookups made.
class _FakeGeocoding extends pi.Geocoding {
  _FakeGeocoding(super.params) : super.implementation();

  @override
  Future<List<pi.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async {
    _lookups.add('$latitude,$longitude');
    if (_geocoderFails) throw Exception('no network');
    return _answers;
  }
}

class _FakeFactory extends pi.GeocodingPlatformFactory {
  @override
  pi.Geocoding createGeocoding(pi.GeocodingCreationParams params) => _FakeGeocoding(params);
}

final _lookups = <String>[];
var _answers = <pi.Placemark>[];
var _geocoderFails = false;

final _requests = <http.Request>[];
Map<String, dynamic>? _row;
List<Map<String, dynamic>> _backfillRows = const [];

http.Response _json(http.Request request, Object body) =>
    http.Response(jsonEncode(body), 200, request: request, headers: {'content-type': 'application/json'});

List<http.Request> get _patches => _requests.where((r) => r.method == 'PATCH').toList();

String _jwt() {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': _uid, 'exp': exp, 'role': 'authenticated'})}.sig';
}

Map<String, dynamic> _switchedRow() => {
      'start_latitude': 39.3404572,
      'start_longitude': -76.6719746,
      'end_latitude': 39.3320505,
      'end_longitude': -76.6694564,
      'start_address': null,
      'end_address': null,
      'address_edited': false,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    pi.GeocodingPlatformFactory.instance = _FakeFactory();
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'test-key',
      httpClient: MockClient((request) async {
        _requests.add(request);
        if (request.method == 'PATCH') return _json(request, []);
        if (request.url.queryParameters['select'] == 'id') return _json(request, _backfillRows);
        return _json(request, _row == null ? [] : [_row]);
      }),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
    await Supabase.instance.client.auth.recoverSession(jsonEncode({
      'access_token': _jwt(),
      'refresh_token': 'r',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      'user': {
        'id': _uid,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }));
  });

  setUp(() {
    _lookups.clear();
    _requests.clear();
    _geocoderFails = false;
    _row = _switchedRow();
    _backfillRows = const [];
    _answers = const [
      pi.Placemark(
        subThoroughfare: '4616',
        thoroughfare: 'Reisterstown Road',
        locality: 'Baltimore',
        administrativeArea: 'Maryland',
      ),
    ];
  });

  group('lookup', () {
    test('builds a street-level address', () async {
      expect(await TripAddressService.lookup(39.34, -76.67), '4616 Reisterstown Road, Baltimore, Maryland');
    });

    test('uses the place name when there is no street', () async {
      _answers = const [pi.Placemark(name: 'Exit 22', locality: 'Laurel', administrativeArea: 'Maryland')];
      expect(await TripAddressService.lookup(39.1, -76.8), 'Exit 22, Laurel, Maryland');
    });

    test('no answer or no network gives null', () async {
      _answers = const [];
      expect(await TripAddressService.lookup(39.1, -76.8), isNull);
      _geocoderFails = true;
      expect(await TripAddressService.lookup(39.1, -76.8), isNull);
    });
  });

  group('fillSection', () {
    test('a segment closed by an app switch gets its start and end, only if still empty', () async {
      await TripAddressService.fillSection(_sectionId);

      expect(_lookups, ['39.3404572,-76.6719746', '39.3320505,-76.6694564']);
      expect(_patches, hasLength(2));
      expect(jsonDecode(_patches[0].body), {'start_address': '4616 Reisterstown Road, Baltimore, Maryland'});
      expect(_patches[0].url.queryParameters['start_address'], 'is.null');
      expect(jsonDecode(_patches[1].body), {'end_address': '4616 Reisterstown Road, Baltimore, Maryland'});
      expect(_patches[1].url.queryParameters['end_address'], 'is.null');
      expect(_patches[0].url.queryParameters['id'], 'eq.$_sectionId');
    });

    test('never writes miles, times or coordinates', () async {
      await TripAddressService.fillSection(_sectionId);
      for (final p in _patches) {
        expect((jsonDecode(p.body) as Map).keys.single, endsWith('_address'));
      }
    });

    test('an address already there is left alone', () async {
      _row = {..._switchedRow(), 'start_address': 'Already here'};
      await TripAddressService.fillSection(_sectionId);
      expect(_lookups, ['39.3320505,-76.6694564']);
      expect(_patches.single.url.queryParameters.containsKey('end_address'), isTrue);
    });

    test('an address the driver edited is never replaced', () async {
      _row = {..._switchedRow(), 'address_edited': true};
      await TripAddressService.fillSection(_sectionId);
      expect(_lookups, isEmpty);
      expect(_patches, isEmpty);
    });

    test('a segment with no end coordinates only fills its start', () async {
      _row = {..._switchedRow(), 'end_latitude': null, 'end_longitude': null};
      await TripAddressService.fillSection(_sectionId);
      expect(_lookups, ['39.3404572,-76.6719746']);
      expect(_patches.single.url.queryParameters.containsKey('start_address'), isTrue);
    });

    test('offline stores nothing, so it can be retried', () async {
      _geocoderFails = true;
      await TripAddressService.fillSection(_sectionId);
      expect(_patches, isEmpty);
    });

    test('a very short segment the database already removed does nothing', () async {
      _row = null;
      await TripAddressService.fillSection(_sectionId);
      expect(_lookups, isEmpty);
      expect(_patches, isEmpty);
    });
  });

  test('backfill includes segments closed by an app switch', () async {
    _backfillRows = [
      {'id': _sectionId},
    ];
    await TripAddressService.backfillRecent();

    final list = _requests.firstWhere((r) => r.method == 'GET' && r.url.queryParameters['select'] == 'id');
    expect(list.url.queryParameters['section_status'], 'in.("closed","switched")');
    expect(list.url.queryParameters['user_id'], 'eq.$_uid');
    expect(list.url.queryParameters['organization_id'], 'is.null');
    expect(_patches, hasLength(2));
  });
}
