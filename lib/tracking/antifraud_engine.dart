// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/antifraud_engine.dart
// VERSIÓN ALINEADA Y OPTIMIZADA - Anti-fraude GPS

import 'dart:collection';
import 'dart:math';

class AntifraudResult {
  final bool isValid;
  final String reason;
  final double drivingSignatureScore;

  AntifraudResult(this.isValid, this.reason, this.drivingSignatureScore);

  static AntifraudResult ok(double score) =>
      AntifraudResult(true, "OK", score);

  static AntifraudResult reject(String reason, double score) =>
      AntifraudResult(false, reason, score);
}

class AntifraudEngine {
  // =====================================================
  // Constantes de negocio (ajustadas para uso real)
  // =====================================================
  static const double maxAllowedSpeedMps      = 55.0;   // ~198 km/h
  static const double maxAllowedAccuracy      = 80.0;   // metros
  static const double maxJumpDistanceMeters   = 1500.0; // anti-teleport
  static const double maxAccelerationMps2     = 8.0;    // aceleración brusca
  static const double minRealMovementMeters   = 1.5;    // movimiento mínimo real
  static const double minDeltaTimeSeconds     = 0.25;   // anti-jitter

  // Detección de patrones artificiales (mejorado)
  static const double artificialVarianceThreshold = 0.0012;   // permite variación natural
  static const double artificialSpeedThresholdMps = 8.0;      // ~29 km/h

  // =====================================================
  // Estado interno
  // =====================================================
  static double? lastLat;
  static double? lastLng;
  static DateTime? lastTimestamp;
  static double? lastSpeed;

  static final Queue<double> _speedHistory = Queue<double>();
  static const int _speedHistoryMaxSize = 20;

  static void reset() {
    lastLat = null;
    lastLng = null;
    lastTimestamp = null;
    lastSpeed = null;
    _speedHistory.clear();
  }

  /// Evalúa si un tick GPS es legítimo
  static AntifraudResult evaluate({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
    required DateTime timestamp,
    bool isMock = false,
  }) {
    // 1. Detección de ubicación falsa (Mock)
    if (isMock) {
      return AntifraudResult.reject("Mock location detected", 0.0);
    }

    // 2. Velocidad negativa (común en algunos GPS defectuosos)
    if (speed < 0.0) {
      return AntifraudResult.reject("Negative speed value", 0.0);
    }

    // 3. Precisión GPS demasiado baja
    // BUG FIX: antes esto actualizaba lastLat/lastLng con una posición que el
    // propio motor acaba de decir que no es confiable. El siguiente punto
    // válido terminaba calculando distancia desde una posición mala. Ahora
    // se descarta el punto sin mover el baseline — se mantiene la última
    // posición realmente buena hasta que llegue un punto confiable de nuevo.
    if (accuracy > maxAllowedAccuracy) {
      return AntifraudResult.reject("Low precision GPS (${accuracy.toStringAsFixed(1)}m)", 0.5);
    }

    double? realSpeed;

    // Si tenemos datos previos → validaciones avanzadas
    if (lastLat != null && lastLng != null && lastTimestamp != null) {
      final distance = _distanceMeters(lastLat!, lastLng!, latitude, longitude);
      final timeDiff = timestamp.difference(lastTimestamp!).inMilliseconds / 1000.0;

      // Timestamp inválido
      // BUG FIX: no mover el baseline con un timestamp que no es confiable
      // (mismo razonamiento que el fix de precisión baja arriba).
      if (timeDiff <= 0) {
        return AntifraudResult.reject("Invalid timestamp", 0.0);
      }

      if (timeDiff < minDeltaTimeSeconds) {
        _updateLastPosition(latitude, longitude, timestamp);
        return AntifraudResult.reject("Timestamp jitter", 0.6);
      }

      // Teleport / salto imposible
      // BUG FIX: un salto imposible casi siempre es un fix de GPS defectuoso
      // (un solo punto malo). Antes ese punto malo se volvía el baseline del
      // siguiente cálculo, lo cual podía inyectar millas falsas o comerse
      // millas reales en el siguiente tick. Ahora se descarta sin mover el
      // baseline — se sigue comparando contra la última posición buena.
      if (distance > maxJumpDistanceMeters) {
        return AntifraudResult.reject("Impossible movement jump", 0.0);
      }

      // Jitter estático (movimiento muy pequeño + velocidad baja)
      if (distance < minRealMovementMeters && speed < 0.3) {
        _updateLastPosition(latitude, longitude, timestamp);
        return AntifraudResult.reject("Static jitter", 0.25);
      }

      // Velocidad real calculada
      realSpeed = distance / timeDiff;

      // BUG FIX: mismo problema — no contaminar el baseline con un punto que
      // el propio motor está rechazando por implicar velocidad imposible.
      if (realSpeed > maxAllowedSpeedMps) {
        return AntifraudResult.reject("Impossible real speed", 0.0);
      }

      // Aceleración brusca
      if (lastSpeed != null) {
        final acceleration = (realSpeed - lastSpeed!).abs() / timeDiff;
        if (acceleration > maxAccelerationMps2) {
          return AntifraudResult.reject("Impossible acceleration", 0.15);
        }
      }

      lastSpeed = realSpeed;
    }

    // Análisis de firma de conducción (variabilidad natural)
    final score = _calculateDrivingScore(realSpeed ?? speed);

    // Actualizar estado para el siguiente tick (este punto SÍ pasó todas las
    // validaciones geométricas de arriba, es un punto confiable).
    _updateLastPosition(latitude, longitude, timestamp);

    // BUG FIX: antes, velocidad constante con varianza baja (score < 0.15)
    // se rechazaba como "patrón artificial" — pero eso también describe
    // manejar en autopista con crucero activado, un caso 100% legítimo y
    // común en apps de gig driving. Rechazar aquí borraba millas reales del
    // usuario. Ahora el punto se acepta siempre (la distancia se cuenta) y
    // el score bajo queda registrado en el audit log para revisión — se
    // marca la sospecha sin penalizar al usuario por manejar derecho.
    return AntifraudResult.ok(score);
  }

  // Actualiza la posición anterior de forma centralizada
  static void _updateLastPosition(double lat, double lng, DateTime ts) {
    lastLat = lat;
    lastLng = lng;
    lastTimestamp = ts;
  }

  // Calcula score basado en variabilidad de velocidad
  static double _calculateDrivingScore(double speedLike) {
    _speedHistory.addLast(speedLike);
    if (_speedHistory.length > _speedHistoryMaxSize) {
      _speedHistory.removeFirst();
    }

    if (_speedHistory.length < 5) return 1.0;

    final variance = _variance(_speedHistory.toList());

    // Si va a velocidad significativa pero varianza muy baja → sospechoso
    if (speedLike > artificialSpeedThresholdMps &&
        variance < artificialVarianceThreshold) {
      return 0.12; // umbral suave
    }

    return 1.0;
  }

  static double _variance(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    final avg = samples.reduce((a, b) => a + b) / samples.length;
    return samples
            .map((x) => pow(x - avg, 2))
            .reduce((a, b) => a + b) /
        samples.length;
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000.0; // Radio de la Tierra en metros
    const double p = 0.017453292519943295; // π/180

    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 2 * R * asin(sqrt(a));
  }
}