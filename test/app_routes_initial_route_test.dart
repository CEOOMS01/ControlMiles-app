// ControlMiles (personal app) opens on sign-in, then the permissions
// onboarding, then the personal dashboard -- fleets have their own app
// (ControlMiles Fleet, ../controlmiles-fleet) since 2026-10-19.

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/routes/app_routes.dart';

void main() {
  test('signed out -> login', () {
    expect(
      AppRoutes.getInitialRoute(isAuthenticated: false, onboardingCompleted: false),
      AppRoutes.login,
    );
  });

  test('signed in, onboarding not done -> welcome', () {
    expect(
      AppRoutes.getInitialRoute(isAuthenticated: true, onboardingCompleted: false),
      AppRoutes.welcome,
    );
  });

  test('signed in and onboarded -> personal dashboard', () {
    expect(
      AppRoutes.getInitialRoute(isAuthenticated: true, onboardingCompleted: true),
      AppRoutes.dashboard,
    );
  });
}
