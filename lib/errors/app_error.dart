// Olympus Mont Systems LLC - ControlMiles
// lib/errors/app_error.dart
//
// Explicit user requirement (2026-09-09): no raw database/exception text
// ever reaches the UI. Every error the user can see must carry a stable
// numeric code from the shared registry (see ERROR_CODES.md at the repo
// root -- kept in sync by hand with controlmiles-web's copy of the same
// file, since the two are separate repos/languages and can't literally
// share one source file). Three ranges, matching where the error
// actually originates:
//
//   1xx-3xx  LOCAL       client-side only -- permissions, validation,
//                        connectivity, local storage. Never touches the
//                        network.
//   4xx-6xx  BACKEND     a real, named business-rule rejection from
//                        Supabase (a Postgres RAISE EXCEPTION with a
//                        recognizable message, a Postgrest/Auth error we
//                        know how to interpret).
//   7xx-9xx  PRODUCTION  anything else -- caught, but not one of the
//                        known cases above. The catch-all. Still shows a
//                        safe generic message + the code, never the raw
//                        exception.
//
// AppError.from(...) is the ONLY sanctioned way to turn a caught
// exception into UI-facing text -- screens should stop hand-rolling their
// own "if error.contains(...)" checks (see login_screen.dart's old
// _getErrorMessage, being replaced by this).

class AppError {
  final int code;
  final String messageKey; // i18n key -- resolve via appState.tr(messageKey)
  /// Set only for AppError.businessRuleRejection -- a hand-written RAISE
  /// EXCEPTION sentence from one of our own RPCs, already in English
  /// with no i18n entry of its own. When set, display() uses this
  /// directly instead of the localized messageKey lookup.
  final String? literalMessage;

  const AppError(this.code, this.messageKey, {this.literalMessage});

  /// What's safe to show a user: "Something went wrong (720)" style,
  /// never the raw exception. Callers still run messageKey through
  /// AppState.tr() for localization; this only formats the code suffix
  /// (or substitutes literalMessage when set, ignoring the tr() result).
  String display(String localizedMessage) =>
      '${literalMessage ?? localizedMessage} ($code)';

  // ── LOCAL (1xx-3xx) ─────────────────────────────────────────
  // Reuses this codebase's existing i18n keys where one was already a
  // good fit (location_permission_denied); only adds new keys for
  // genuine gaps.
  static const cameraPermissionDenied = AppError(101, 'camera_permission_denied_error');
  static const locationPermissionDenied = AppError(102, 'location_permission_denied');
  static const noInternetConnection = AppError(110, 'no_internet_connection_error');
  static const invalidFormInput = AppError(120, 'invalid_input_error');
  static const localStorageFailure = AppError(150, 'local_storage_error');

  // ── BACKEND (4xx-6xx) -- real, named rejections we already raise ──
  static const invalidCredentials = AppError(400, 'invalid_credentials');
  static const emailAlreadyExists = AppError(401, 'email_already_exists');
  static const sessionExpired = AppError(402, 'session_expired_error');
  static const vehicleLimitReached = AppError(410, 'vehicle_limit_reached_error');
  static const freeTrialExpired = AppError(411, 'free_trial_expired_body');
  static const orgMembershipRevoked = AppError(412, 'org_access_revoked_body');
  static const rateLimited = AppError(420, 'rate_limited_error');
  static const duplicateEntry = AppError(430, 'duplicate_entry_error');
  static const subscriptionsNotConfigured = AppError(440, 'subscriptions_not_configured');

  /// A hand-written RAISE EXCEPTION sentence from one of our own
  /// SECURITY DEFINER RPCs (e.g. "Only an org admin or owner can invite
  /// members") -- not raw Postgres/system internals, safe to show
  /// verbatim, but still routed through the registry so it carries a
  /// code. See _looksLikeRawDbError's own doc comment for what
  /// disqualifies a message from landing here instead of the generic
  /// fallback.
  static AppError businessRuleRejection(String message) =>
      AppError(450, '', literalMessage: message);

  // ── PRODUCTION (7xx-9xx) -- catch-all, unclassified ──────────
  static const unexpectedClient = AppError(700, 'unexpected_error');
  static const unexpectedServer = AppError(701, 'unexpected_error');
  /// Reserved for critical flows specifically (payment, org deletion,
  /// anything money- or data-loss-adjacent) -- the same generic message
  /// as unexpectedServer, but its own code so these are easy to find in
  /// logs/support tickets separately from routine 701s.
  static const unexpectedCritical = AppError(720, 'unexpected_error');

  /// True when [text] looks like a raw Postgres/system error rather
  /// than one of our own hand-written RAISE EXCEPTION sentences --
  /// schema internals (column/relation/constraint names), SQL syntax
  /// errors, or anything long enough to plausibly be a stack trace.
  static bool _looksLikeRawDbError(String text) {
    if (text.length > 160) return true;
    final rawPatterns = [
      RegExp(r'column "', caseSensitive: false),
      RegExp(r'relation "', caseSensitive: false),
      RegExp(r'constraint "', caseSensitive: false),
      RegExp(r'duplicate key value', caseSensitive: false),
      RegExp(r'violates', caseSensitive: false),
      RegExp(r'syntax error', caseSensitive: false),
      RegExp(r'permission denied for', caseSensitive: false),
      RegExp(r'null value in column', caseSensitive: false),
      RegExp(r'invalid input syntax', caseSensitive: false),
      RegExp(r'PGRST\d'),
      RegExp(r'^\d{5}:'),
    ];
    return rawPatterns.any((p) => p.hasMatch(text));
  }

  /// Maps a caught exception to the best-matching known AppError.
  /// Recognizes this project's own real exception shapes (Postgres
  /// RAISE EXCEPTION messages from the triggers/RPCs already in this
  /// codebase -- VEHICLE_LIMIT_REACHED, FREE_TRIAL_EXPIRED,
  /// ORG_MEMBERSHIP_REVOKED -- and common Supabase Auth error text)
  /// rather than guessing. A message that isn't one of the
  /// specifically-named codes but also doesn't look like raw Postgres/
  /// system internals is treated as one of our own safe hand-written
  /// RPC exceptions (code 450) rather than downgraded to the fully
  /// generic fallback. Only text that actually looks like a raw
  /// database/system error falls through to 701/720.
  static AppError from(Object error, {bool critical = false}) {
    final text = error.toString().replaceFirst('Exception: ', '');

    if (text.contains('VEHICLE_LIMIT_REACHED')) return vehicleLimitReached;
    if (text.contains('FREE_TRIAL_EXPIRED')) return freeTrialExpired;
    if (text.contains('ORG_MEMBERSHIP_REVOKED')) return orgMembershipRevoked;
    if (text.contains('Invalid login credentials') || text.contains('Invalid credentials')) {
      return invalidCredentials;
    }
    if (text.contains('Email already registered') || text.contains('already exists')) {
      return emailAlreadyExists;
    }
    if (text.contains('JWT') || text.contains('session') || text.contains('not authenticated')) {
      return sessionExpired;
    }
    if (text.contains('rate limit') || text.contains('Too many attempts')) {
      return rateLimited;
    }
    if (text.contains('duplicate key value')) return duplicateEntry;
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return noInternetConnection;
    }

    if (text.isNotEmpty && !_looksLikeRawDbError(text)) {
      return businessRuleRejection(text);
    }

    return critical ? unexpectedCritical : unexpectedServer;
  }
}
