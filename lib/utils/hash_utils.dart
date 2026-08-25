// Olympus Mont Systems LLC - ControlMiles
// lib/utils/hash_utils.dart

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// ---------------------------------------------------------------------------
/// FILE HASHING (Memory-Safe Streaming)
/// ---------------------------------------------------------------------------
/// Generates a SHA-256 hash without loading the entire file into RAM.
/// Critical for high-resolution odometer photos.
Future<String> generateFileSHA256(File file) async {
  final stream = file.openRead();
  final digest = await sha256.bind(stream).first;
  return digest.toString();
}

/// ---------------------------------------------------------------------------
/// JSON HASHING (Deterministic & Audit-Ready)
/// ---------------------------------------------------------------------------
/// Creates a unique fingerprint of a data map.
String hashJson(Map<String, dynamic> data) {
  final canonical = _canonicalJson(data);
  final bytes = utf8.encode(canonical);
  return sha256.convert(bytes).toString();
}

/// ---------------------------------------------------------------------------
/// CANONICAL JSON (Ensures consistent key ordering)
/// ---------------------------------------------------------------------------
/// Recursively sorts all keys in maps to ensure that the same data
/// always produces the same JSON string, and thus the same Hash.
String _canonicalJson(dynamic value) {
  if (value is Map) {
    final sortedKeys = value.keys.toList()..sort();
    final sortedMap = {
      for (final k in sortedKeys) k: _canonicalJson(value[k])
    };
    return jsonEncode(sortedMap);
  } else if (value is List) {
    return jsonEncode(value.map(_canonicalJson).toList());
  } else {
    // Basic types (String, int, bool, null)
    return jsonEncode(value);
  }
}