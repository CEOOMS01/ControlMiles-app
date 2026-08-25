// Olympus Mont Systems LLC - ControlMiles
// lib/utils/deployment_validator.dart - PRODUCTION COMPLIANCE

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class DeploymentValidator {
  
  /// Checks if critical permissions are ALREADY granted.
  static Future<bool> areCriticalPermissionsGranted() async {
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;
    final activityStatus = await Permission.activityRecognition.status;
    final notificationStatus = await Permission.notification.status;

    return cameraStatus.isGranted &&
           locationStatus.isGranted &&
           activityStatus.isGranted &&
           notificationStatus.isGranted;
  }

  /// Visual Branding Header for Olympus Mont Systems
  /// To be used in WelcomePage or Permission screens.
  static Widget buildCompanyBranding() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Integration
        Image.asset(
          'assets/images/logo_olympus.png',
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => 
            const Icon(Icons.business, size: 80, color: Colors.grey),
        ),
        const SizedBox(height: 15),
        
        // Primary Title
        const Text(
          "Olympus Mont Systems",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF1A1A1A),
          ),
        ),
        
        // Secondary Slogan
        const Text(
          "SECURE  /  AUDIT  /  PROGRAMS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 3.0,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }

  static Future<void> goToSettings() async {
    await openAppSettings();
  }
}