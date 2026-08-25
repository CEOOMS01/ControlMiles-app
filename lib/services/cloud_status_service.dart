// Olympus Mont Systems LLC - ControlMiles
// lib/services/cloud_status_service.dart
// REAL-TIME INFRASTRUCTURE AND AUDIT MONITOR

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudStatusService {
  // 1. Singleton: Ensures a single instance across the app
  static final CloudStatusService _instance = CloudStatusService._internal();
  factory CloudStatusService() => _instance;
  CloudStatusService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  // 2. Stream Controllers (Broadcast for multiple listeners)
  final _isOnlineController = StreamController<bool>.broadcast();
  final _trackingActiveController = StreamController<bool>.broadcast();
  final _auditChainHealthyController = StreamController<bool>.broadcast();

  // 3. Timers (To manage background execution and battery life)
  Timer? _connectivityTimer;
  Timer? _trackingTimer;
  Timer? _auditTimer;

  // ============================================================
  // PUBLIC GETTERS (Compatibility with DashboardScreen)
  // ============================================================

  /// Main connectivity stream
  Stream<bool> get isOnlineStream => _isOnlineController.stream;

  /// Compatibility alias for connectivity changes
  Stream<bool> get onConnectivityChanged => _isOnlineController.stream;

  /// Tracking status stream
  Stream<bool> get trackingStream => _trackingActiveController.stream;

  /// Audit chain health stream (Blockchain-lite)
  Stream<bool> get auditChainStream => _auditChainHealthyController.stream;

  // ============================================================
  // MONITOR CONTROL
  // ============================================================

  void startMonitoring() {
    // Avoid duplicate timers if already running
    stopMonitoring();
    
    _monitorSupabaseConnection(); // Starts immediately
    _monitorTrackingStatus();
    _monitorAuditChainIntegrity();
  }

  void stopMonitoring() {
    _connectivityTimer?.cancel();
    _trackingTimer?.cancel();
    _auditTimer?.cancel();
  }

  // ============================================================
  // MONITORING LOGIC
  // ============================================================

  // 1. Connectivity: Verifies latency with Supabase
  void _monitorSupabaseConnection() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        // Lightweight ping using count()
        await supabase.from("tracking_sessions").select("id").limit(1).count();
        
        if (!_isOnlineController.isClosed) _isOnlineController.add(true);
      } catch (_) {
        // Ping failed, assume offline
        if (!_isOnlineController.isClosed) _isOnlineController.add(false);
      }
    });
  }

  // 2. Tracking Status: Is there an active session in the cloud?
  void _monitorTrackingStatus() {
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final res = await supabase
            .from("session_sections")
            .select("id")
            .eq("is_closed", false)
            .maybeSingle();
            
        final isActive = res != null;
        if (!_trackingActiveController.isClosed) _trackingActiveController.add(isActive);
      } catch (e) {
        debugPrint("[CloudStatus ERROR] Tracking check failed: $e");
        if (!_trackingActiveController.isClosed) _trackingActiveController.add(false);
      }
    });
  }

  // 3. Integrity: The "Digital Polygraph"
  void _monitorAuditChainIntegrity() {
    // Periodic check every 30 seconds to avoid network saturation
    _auditTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        // A. Look for active section
        final activeSection = await supabase
            .from("session_sections")
            .select("id")
            .eq("is_closed", false)
            .maybeSingle();

        if (activeSection == null) {
          // If no active trip, chain is considered healthy by default
          if (!_auditChainHealthyController.isClosed) _auditChainHealthyController.add(true);
          return;
        }

        final sectionId = activeSection["id"];

        // B. Fetch lightweight block chain (hashes only)
        final List<dynamic> events = await supabase
            .from("audit_events")
            .select("hash, prev_hash, event_index")
            .eq("section_id", sectionId)
            .order("event_index", ascending: true);

        if (events.isEmpty) {
           if (!_auditChainHealthyController.isClosed) _auditChainHealthyController.add(true);
           return;
        }

        // C. Mathematical Validation
        bool isHealthy = true;
        
        for (int i = 0; i < events.length; i++) {
          final current = events[i];
          
          // Cryptographic Verification (Hash Chaining)
          if (i > 0) {
            final previous = events[i - 1];
            if (current["prev_hash"] != previous["hash"]) {
              isHealthy = false;
              debugPrint("[AUDIT RISK] BREAK IN AUDIT CHAIN DETECTED AT INDEX $i");
              break;
            }
          }
        }
        
        if (!_auditChainHealthyController.isClosed) _auditChainHealthyController.add(isHealthy);

      } catch (e) {
        debugPrint("[CloudStatus ERROR] Audit monitoring failed: $e");
        // Maintain previous state on network error to avoid false positives
      }
    });
  }

  void dispose() {
    stopMonitoring();
    _isOnlineController.close();
    _trackingActiveController.close();
    _auditChainHealthyController.close();
  }
}