// Gig / Fleet split (2026-10-11): tests run without --flavor, i.e. as the
// gig app (AppFlavor.isGig). The gig app is personal-only, so nothing
// fleet-related may route a signed-in account away from the dashboard.

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/config/app_flavor.dart';
import 'package:controlmiles/routes/app_routes.dart';

void main() {
  test('tests run as the gig app', () {
    expect(AppFlavor.isGig, isTrue);
  });

  test('signed out -> login, onboarding not done -> welcome', () {
    expect(
      AppRoutes.getInitialRoute(isAuthenticated: false, onboardingCompleted: false),
      AppRoutes.login,
    );
    expect(
      AppRoutes.getInitialRoute(isAuthenticated: true, onboardingCompleted: false),
      AppRoutes.welcome,
    );
  });

  test('a fleet invite, fleet role or unchosen type never leaves the dashboard', () {
    for (final args in [
      (invites: true, admin: false, driver: false, chosen: true),
      (invites: false, admin: true, driver: false, chosen: true),
      (invites: false, admin: false, driver: true, chosen: true),
      (invites: false, admin: false, driver: false, chosen: false),
    ]) {
      expect(
        AppRoutes.getInitialRoute(
          isAuthenticated: true,
          onboardingCompleted: true,
          hasPendingInvites: args.invites,
          isFleetAdmin: args.admin,
          isFleetDriver: args.driver,
          accountTypeChosen: args.chosen,
        ),
        AppRoutes.dashboard,
        reason: '$args',
      );
    }
  });
}
