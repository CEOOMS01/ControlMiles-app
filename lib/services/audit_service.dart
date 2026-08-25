// Olympus Mont Systems LLC - ControlMiles
// lib/services/audit_service.dart - PRODUCTION READY (Hardened)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_event.dart';
import '../models/odometer_evidence.dart';
import '../utils/hash_utils.dart';

class AuditService {
  static final SupabaseClient db = Supabase.instance.client;

  // ============================================================
  // WRITE: CRYPTOGRAPHIC LOGGING (Blockchain-lite)
  // ============================================================

  static Future<void> logAuditEvent({
    required String sessionId,
    required String eventType,
    required Map<String, dynamic> payload,
    String? sectionId, // FIX 1: columna real en audit_events
  }) async {
    try {
      // FIX 2: guard null — user_id es NOT NULL en el schema
      final userId = db.auth.currentUser?.id;
      if (userId == null) {
        _logDebug("AUDIT_SKIP", eventType, {"reason": "user not authenticated"});
        return;
      }

      final now = DateTime.now().toIso8601String();
      final prevHash = await _getLastHash(sessionId);

      final safePayload = Map<String, dynamic>.from(payload);

      final newHash = hashJson({
        "sessionId": sessionId,
        "eventType": eventType,
        "payload": safePayload,
        "timestamp": now,
        "prevHash": prevHash,
      });

      // FIX 1: section_id va como columna, no dentro del payload
      await db.from("audit_events").insert({
        "session_id": sessionId,
        "section_id": sectionId,         // FIX 1: columna real
        "user_id": userId,               // FIX 2: valor garantizado no-null
        "event_type": eventType,
        "payload": safePayload,
        "created_at": now,
        "hash": newHash,
        "prev_hash": prevHash,
      });

      _logDebug("EVENT_LOGGED", eventType, {
        "hash_prefix": newHash.substring(0, 8),
      });
    } catch (e) {
      _logDebug("AUDIT_ERROR", eventType, {"error": e.toString()});
      rethrow;
    }
  }

  static Future<void> logOdometerEvidence(OdometerEvidence evidence) async {
    try {
      final userId = db.auth.currentUser?.id;
      if (userId == null) {
        _logDebug("AUDIT_SKIP", "ODOMETER_EVIDENCE", {"reason": "user not authenticated"});
        return;
      }

      final now = DateTime.now().toIso8601String();
      final prevHash = await _getLastHash(evidence.sessionId);

      final newHash = hashJson({
        "sessionId": evidence.sessionId,
        "eventType": "ODOMETER_EVIDENCE",
        "sha256": evidence.sha256,
        "timestamp": now,
        "prevHash": prevHash,
      });

      await db.from("audit_events").insert({
        "session_id": evidence.sessionId,
        "section_id": null,              // odómetro es evento de sesión, no de sección
        "user_id": userId,               // FIX 2
        "event_type": "ODOMETER_EVIDENCE",
        "payload": evidence.toMap(),
        "created_at": now,
        "hash": newHash,
        "prev_hash": prevHash,
      });
    } catch (e) {
      _logDebug("ODOMETER_LOG_ERROR", "ODOMETER_EVIDENCE", {
        "error": e.toString(),
      });
      rethrow;
    }
  }

  static Future<String?> _getLastHash(String sessionId) async {
    final res = await db
        .from("audit_events")
        .select("hash")
        .eq("session_id", sessionId)
        .order("created_at", ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return res["hash"] as String?;
  }

  // ============================================================
  // VALIDATION & REPORTS
  // ============================================================

  Future<List<AuditEvent>> fetchAuditEvents(String sessionId) async {
    try {
      final response = await db
          .from("audit_events")
          .select()
          .eq("session_id", sessionId)
          .order("created_at", ascending: true);

      return (response as List<dynamic>)
          .map((map) => AuditEvent.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("[Audit Error] Failed to fetch events: $e");
      return [];
    }
  }

  bool verifyHashChain(List<AuditEvent> events) {
    if (events.isEmpty) return true;

    for (int i = 1; i < events.length; i++) {
      final previous = events[i - 1];
      final current = events[i];

      if (current.prevHash != previous.hash) {
        return false;
      }
    }
    return true;
  }

  // ============================================================
  // COMPATIBILITY ADAPTER (TrackingController)
  // FIX 1: sectionId ahora se pasa como columna, no en payload
  // ============================================================

  static Future<void> logEvent({
    required String sessionId,
    String? sectionId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    return logAuditEvent(
      sessionId: sessionId,
      sectionId: sectionId,   // FIX 1: columna real, no en payload
      eventType: eventType,
      payload: payload,
    );
  }

  // ============================================================
  // LOGGING UTILITY
  // ============================================================

  static void _logDebug(String ev, String msg, Map<String, dynamic> data) {
    debugPrint('[Audit] $ev: $msg $data');
  }
}