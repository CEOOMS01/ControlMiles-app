// Olympus Mont Systems LLC - ControlMiles
// lib/services/cgc_governance_service.dart
//
// Connects a just-closed trip to CGC Core's governance/PoD sealing
// pipeline (see [[project_cgc_core]] and
// supabase/functions/cgc-seal-trip/index.ts, the actual server-side hop
// that talks to CGC Core -- this class is just the thin client-side
// caller). Closes ControlMiles' own flagged architectural gap: the
// antifraud engine and its hash-chain audit log run entirely
// client-side, with nothing server-side proving a trip record wasn't
// fabricated. A sealed trip gets an independent, cryptographically-signed
// decision_id from CGC Core's PoD, stored on sessions.cgc_decision_id.
//
// Deliberately fire-and-forget from the caller's point of view
// (TrackingController.stopTracking does NOT await this) -- sealing is
// evidentiary, done best-effort after the trip already closed
// successfully, and must never delay or fail the trip-close UX. The edge
// function itself is equally best-effort: it always returns 200 with
// sealed:false rather than an error for any failure mode (not
// configured, CGC Core down, timeout), so this class has nothing to
// retry or surface to the UI for v1.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CgcGovernanceService {
  static Future<void> sealTrip({
    required String sessionId,
    required int totalGpsTicks,
    required int rejectedGpsTicks,
    required double minDrivingSignatureScore,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'cgc-seal-trip',
        body: {
          'session_id': sessionId,
          'total_gps_ticks': totalGpsTicks,
          'rejected_gps_ticks': rejectedGpsTicks,
          'min_driving_signature_score': minDrivingSignatureScore,
        },
      );

      final data = response.data;
      final sealed = data is Map && data['sealed'] == true;
      debugPrint(
        sealed
            ? '[CgcGovernanceService] Trip $sessionId sealed: ${data['decision_id']}'
            : '[CgcGovernanceService] Trip $sessionId not sealed: ${data is Map ? data['reason'] : data}',
      );
    } catch (e) {
      // Best-effort by design -- never let a governance-sealing failure
      // surface anywhere near the trip-close flow.
      debugPrint('[CgcGovernanceService] sealTrip failed: $e');
    }
  }
}
