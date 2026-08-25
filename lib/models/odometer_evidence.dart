// Olympus Mont Systems LLC - ControlMiles
// lib/models/odometer_evidence.dart

class OdometerEvidence {
  final String sessionId;
  final String cloudPath;
  final String publicUrl;
  final String sha256;
  final double latitude;
  final double longitude;
  final bool isStartPhoto;
  final double odometerValue;

  OdometerEvidence({
    required this.sessionId,
    required this.cloudPath,
    required this.publicUrl,
    required this.sha256,
    required this.latitude,
    required this.longitude,
    required this.isStartPhoto,
    this.odometerValue = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'cloudPath': cloudPath,
      'publicUrl': publicUrl,
      'sha256': sha256,
      'latitude': latitude,
      'longitude': longitude,
      'isStartPhoto': isStartPhoto,
      'odometerValue': odometerValue,
    };
  }
}