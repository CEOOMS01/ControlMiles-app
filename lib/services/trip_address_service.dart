// Olympus Mont Systems LLC - ControlMiles
// lib/services/trip_address_service.dart
//
// Where a trip started and ended, as a street address (2026-11-04). The phone
// itself turns the saved coordinates into an address (Android's geocoder: no
// key, no cost, nothing extra to run); this file only asks for it, once per
// end of a trip, and stores the text next to the coordinates.
//
//   * Looked up when a trip section closes, never per GPS fix.
//   * Offline or no result: nothing is stored, and backfillRecent() tries
//     again the next time the app opens, so old trips fill in too.
//   * Never overwrites an address the driver edited by hand.
//   * Street level only ("219 Allendale St, Baltimore, MD"): the recorded
//     coordinates are not changed, and they stay frozen once a trip closes.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripAddressService {
  TripAddressService._();

  static bool _busy = false;

  /// "219 Allendale St, Baltimore, MD", or null when the phone has no answer.
  static Future<String?> lookup(double lat, double lng) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 8));
      if (marks.isEmpty) return null;
      final p = marks.first;
      String clean(String? v) => (v ?? '').trim();
      final street = [clean(p.subThoroughfare), clean(p.thoroughfare)].where((e) => e.isNotEmpty).join(' ');
      final parts = <String>[
        if (street.isNotEmpty) street else if (clean(p.name).isNotEmpty) clean(p.name),
        if (clean(p.locality).isNotEmpty) clean(p.locality),
        if (clean(p.administrativeArea).isNotEmpty) clean(p.administrativeArea),
      ];
      final text = parts.join(', ');
      return text.isEmpty ? null : (text.length > 300 ? text.substring(0, 300) : text);
    } catch (e) {
      debugPrint('[TripAddress] lookup failed: $e');
      return null;
    }
  }

  /// Fills the start and end address of one section that has none yet.
  static Future<void> fillSection(String sectionId) async {
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('session_sections')
          .select('start_latitude, start_longitude, end_latitude, end_longitude, start_address, end_address, address_edited')
          .eq('id', sectionId)
          .maybeSingle();
      if (row == null || row['address_edited'] == true) return;

      double? n(String k) => (row[k] as num?)?.toDouble();

      if (row['start_address'] == null && n('start_latitude') != null && n('start_longitude') != null) {
        final a = await lookup(n('start_latitude')!, n('start_longitude')!);
        if (a != null) {
          await client
              .from('session_sections')
              .update({'start_address': a})
              .eq('id', sectionId)
              .isFilter('start_address', null);
        }
      }
      if (row['end_address'] == null && n('end_latitude') != null && n('end_longitude') != null) {
        final a = await lookup(n('end_latitude')!, n('end_longitude')!);
        if (a != null) {
          await client
              .from('session_sections')
              .update({'end_address': a})
              .eq('id', sectionId)
              .isFilter('end_address', null);
        }
      }
    } catch (e) {
      debugPrint('[TripAddress] fillSection failed: $e');
    }
  }

  /// The driver's latest closed trips that still have no address (offline at
  /// the time, or older than this feature). A few at a time, once per start.
  static Future<void> backfillRecent({int limit = 12}) async {
    if (_busy) return;
    _busy = true;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await Supabase.instance.client
          .from('session_sections')
          .select('id')
          .eq('user_id', uid)
          .eq('section_status', 'closed')
          .isFilter('organization_id', null)
          .eq('address_edited', false)
          .or('and(start_address.is.null,start_latitude.not.is.null),and(end_address.is.null,end_latitude.not.is.null)')
          .order('start_time', ascending: false)
          .limit(limit);
      for (final r in rows as List) {
        await fillSection(r['id'] as String);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      debugPrint('[TripAddress] backfill failed: $e');
    } finally {
      _busy = false;
    }
  }
}
