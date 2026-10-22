// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/en.dart - English (ENG)

const Map<String, String> enTexts = {
  // ============================================================
  // APPLICATION GENERAL
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': 'Splash screen',
  'not_found': 'Not found',
  'error': 'Error',
  'system_error': 'System error',
  'id_label': 'ID',
  'loading': 'Loading...',
  'please_wait': 'Please wait...',

  // ============================================================
  // AUTHENTICATION    // TRIP PURPOSES & IRS.
  // ============================================================
  'login': 'Login',
  'register': 'Register',
  'signup': 'Sign up',
  'logout': 'Logout',
  'logout_confirmation': 'Are you sure you want to log out?',
  'forgot_password': 'Forgot password?',
  'reset_password': 'Reset password',
  'auth_session_expired': 'Authentication session expired',
  'email': 'Email',
  'password': 'Password',
  'confirm_password': 'Confirm password',
  'sign_in': 'Sign in',
  'sign_up': 'Create account',
  'sign_out': 'Sign out',
  'active_activity': 'Active activity',
  'configuration_updated': 'Configuration updated',
  // BUG FIX (pedido explícito, bug silencioso carrusel+pausa): tocar otra
  // gig app mientras el viaje está en pausa no cambiaba nada en el
  // backend (switchSection solo se llama con tracking corriendo), pero la
  // UI igual mostraba "SWITCHED" -- mentira visual. Ahora se bloquea el
  // tap y se explica por qué.
  'resume_to_switch_app': 'Resume tracking to switch activity',
  'switch_activity_failed': 'Could not switch activity — still tracking the previous one. Try again.',

  // ============================================================
  // USER PROFILE
  // ============================================================
  'name': 'Name',
  'edit_name': 'Edit name',
  'last_name': 'Last name',
  'adress': 'Address',
  'number': 'Number',
  'dark_mode': 'Dark Mode',
  'dark_mode_description': 'Switch between light and dark themes',
  'profile_updated_success': 'Profile updated successfully',

  // ============================================================
  // NAVIGATION
  // ============================================================
  'dashboard': 'Home',
  'home': 'Home',
  'profile': 'Profile',
  'settings': 'Settings',
  'help': 'Help',
  'about': 'About',
  'support': 'Support',

  // ============================================================
  // TRACKING
  // ============================================================
  'tracking': 'Tracking',
  'tracking_active': 'Tracking active',
  'tracking_paused': 'Paused',
  'tracking_stopped': 'Tracking stopped',
  'start_tracking': 'START TRACKING',
  'stop_tracking': 'STOP TRACKING',
  'pause_tracking': 'Pause tracking',
  'resume_tracking': 'Resume tracking',
  'trip_details': 'Trip details',
  'route_map_show': "Route map",
  'route_map_hide': "Hide map",
  'trip_history': 'Trip history',
  'trip_ended': 'Trip ended',
  'miles': 'Miles',
  'kilometers': 'Kilometers',
  'speed': 'Speed',
  'duration': 'Duration',
  'distance': 'Distance',
  // BUG FIX (pedido explícito): saludo dinámico del AppBar del Dashboard,
  // reemplaza el badge "IRS 2026 · X¢/mi". Sin el "!" ni el nombre --
  // dashboard_screen.dart arma "$greeting! $firstName".
  'greeting_morning': 'Good morning',
  'greeting_afternoon': 'Good afternoon',
  'greeting_evening': 'Good evening',
  'start_time': 'Start time',
  'end_time': 'End time',
  'select_an_activity_before_starting_tracking': 'Select an activity before starting tracking',
  // BUG FIX (pedido explícito, alerta de hallazgos relacionados): pause/
  // resume/stop ahora devuelven bool -- estos mensajes se muestran solo
  // cuando de verdad fallan, en vez de asumir éxito y animar la UI igual.
  'pause_failed': 'Could not pause — still tracking. Try again.',
  'resume_failed': 'Could not resume tracking. Try again.',
  'end_trip_failed': 'Could not end the trip — still tracking. Try again.',
  'purchase_success': "Your plan is active. Thanks!",
  'purchase_pending': "Your payment is pending. Your plan turns on as soon as Google Play confirms it.",
  'purchase_failed': "The purchase couldn't be completed. You weren't charged. Try again.",
  'play_store_unavailable': "Google Play isn't available on this device, so plans can't be bought here.",
  'restore_purchases': "Restore purchases",
  'continue_with_google': "Continue with Google",
  'or_divider': "or",
  'login_tagline': "Every mile, on the record.",
  'login_welcome_back': "Welcome back",
  'login_welcome_back_sub': "Sign in to keep every mile on the record.",
  'login_create_account_title': "Create your account",
  'login_create_account_sub': "Start logging your miles in minutes.",
  'no_account_prompt': "New to ControlMiles?",
  'have_account_prompt': "Already have an account?",
  'create_account': "Create account",
  'google_sign_in_failed': "Google sign-in didn't work. Try again or use your email.",
  'remember_my_email': "Remember my email",
  'stay_signed_in': "Stay signed in",
  'stay_signed_in_hint': "Keep this on so trips are recorded and detected in the background. Turn it off on a shared phone.",
  'odometer_below_registered_error': "This reading is lower than the {value} mi already on record for this vehicle. Check that the right vehicle is selected.",
  'trip_discarded_no_miles': "No miles were tracked, so this trip wasn't saved.",

  // ============================================================
  // ODOMETER
  // ============================================================
  'odometer': 'Odometer',
  'odometer_capture': 'Odometer capture',
  'start_odometer_capture': 'Capture starting odometer',
  'end_odometer_capture': 'Capture ending odometer',
  'capture_photo': 'Capture photo',
  'retry_camera': 'Retry camera',
  'camera_error': 'Camera error',
  'camera_error_body': 'We couldn\'t access your camera. Check camera permission in Settings, then try again.',
  'odometer_not_detected': 'Odometer not detected',
  'center_odometer_numbers': 'Center odometer numbers',
  'ai_processing': 'Processing photo',
  'validating_mileage_gps_hash': 'Validating mileage, GPS, and hash',

  // ============================================================
  // GPS / LOCATION
  // ============================================================
  'gps': 'GPS',
  'gps_enabled': 'GPS enabled',
  'gps_disabled': 'GPS disabled',
  'location_permission_required': 'Location permission required',
  'location_permission_denied': 'Location permission denied',

  // ============================================================
  // HISTORY & REPORTS
  // ============================================================
  'history': 'History',
  'reports': 'Reports',
  'audit_logs': 'Audit logs',
  'statistics': 'Statistics',
  'summary': 'Summary',
  'total_miles': 'Total miles',
  'last_30_days': 'Last 30 days',
  'last_12_months': 'Last 12 months',
  'total_trips': 'Total trips',
  'average_speed': 'Average speed',
  'RECENT_TRIPS': 'RECENT TRIPS',
  'SEE_ALL': 'SEE ALL',
  'not_trips_yet': 'No trips yet',
  'generate_pdf': 'Generate PDF',
  'generate_global_pdf': 'Generate Global PDF',
  'trip_note': 'Trip note',
  'trip_note_hint': 'e.g. "missed 5 miles — GPS signal lost"',
  'add_note': 'Add note',
  'edit_note': 'Edit note',
  'note_saved_success': 'Note saved',
  'trip_sealed_badge': 'Sealed',
  'delete_trip': 'Delete trip',
  'delete_trip_confirm_title': 'Delete this trip permanently?',
  'delete_trip_confirm_body': 'This will permanently remove the trip and all its tracked miles from ControlMiles, including its audit record. This cannot be undone and the trip will no longer count toward your reports or IRS deduction estimate.',
  'delete_trip_success': 'Trip deleted',
  'send_reset_code': 'Send code',
  'reset_code_sent': 'Check your email for a code',
  'enter_reset_code': 'Enter the code from your email',
  'reset_code_hint': 'Code',
  'verify_code': 'Verify code',
  'resend_code': 'Resend code',
  'new_password': 'New password',
  'confirm_new_password': 'Confirm new password',
  'password_mismatch': 'Passwords don\'t match',
  'reset_password_title': 'Reset your password',
  'forgot_password_body': 'Enter the email on your account and we\'ll send you a code to reset your password.',
  'reset_password_success': 'Password updated. You can sign in now.',
  'back_to_login': 'Back to login',
  'danger_zone': 'Danger zone',
  'delete_account': 'Delete account',
  'delete_account_confirm_title': 'Delete your account permanently?',
  'delete_account_confirm_body': 'This permanently deletes your account and everything in it: vehicles, trip history, mileage records, and reports. This cannot be undone.',
  'delete_account_type_to_confirm': 'Type DELETE to confirm',
  'delete_account_word': 'DELETE',
  'delete_account_success': 'Account deleted',
  // BUG FIX (pedido explícito): badge de millas del Dashboard reemplaza al
  // de "Cloud Sync" (roto — ver CloudStatusService). El disclaimer vive
  // detrás de un tap, nunca en el badge en sí.
  'year_miles_deduction_estimate': 'Est. deduction',
  'irs_estimate_title': 'About this estimate',
  'irs_estimate_disclaimer': 'Estimated using the IRS 2026 standard mileage rates (\$0.725/mile Jan 1-Jun 30, \$0.76/mile Jul 1-Dec 31 — each trip priced at the rate in effect on its own date). ControlMiles is not affiliated with or endorsed by the IRS or any official agency. This is an informational estimate only, not a guaranteed deduction — consult a tax professional.',

  // ============================================================
  // TRIP PURPOSES & IRS.
  // ============================================================
   'select_trip_purpose': 'Select Trip Purpose',
   'irs_deduction_note': 'For deduction purposes -- not guaranteed by this app',
   'business_purpose': 'Business',
   'work_commute': 'Work Commute',
   'medical': 'Medical',
   'moving': 'Moving',
   'charitable': 'Charitable',
   'education_study': 'Education',
   'personal_other': 'Personal / Other',

  // ============================================================
  // SETTINGS
  // ============================================================
  'preferences': 'Preferences',
  'language': 'Language',
  'language_description': 'Select your preferred language',
  'language_changed': 'Language changed to',
  'notifications': 'Notifications',
  'notifications_description': 'Receive app notifications',
  'notifications_enabled': 'Notifications enabled',
  'notifications_disabled': 'Notifications disabled',
  'analytics': 'Analytics',
  'analytics_description': 'Share usage data',

  // ============================================================
  // PRIVACY & SECURITY
  // ============================================================
  'privacy_security': 'Privacy & Security',
  'privacy_policy': 'Privacy policy',
  'terms_conditions': 'Terms & Conditions',
  'send_feedback': 'Send feedback',
  'send_feedback_no_mail_app': 'No email app found. Write to support@controlmiles.com.',
  'send_feedback_email_subject': 'ControlMiles feedback',
  'trademark_disclaimer_short': 'ControlMiles is an independent app and is not affiliated with, endorsed by, or sponsored by Uber, Lyft, DoorDash, Instacart, Amazon, Walmart, Shipt, or any other platform referenced in this app. All trademarks belong to their respective owners.',
  'age_terms_checkbox_prefix': 'I confirm I am at least 18 years old and agree to the',
  'age_terms_checkbox_and': 'and',
  'age_terms_required_error': 'Please confirm you are 18 or older and agree to the Terms to continue.',
  'data_security': 'Data security',
  'security_audit': 'Security audit',

  // ============================================================
  // ABOUT
  // ============================================================
  'about_app': 'About the app',
  'app_version': 'App version',
  'build_number': 'Build number',
  'company': 'Company',
  'copyright': 'All rights reserved',
  'developer': 'Developer',

  // ============================================================
  // BUTTONS
  // ============================================================
  'ok': 'OK',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'close': 'Close',
  'refresh': 'Refresh',
  'retry': 'Retry',
  'next': 'Next',
  'previous': 'Previous',
  'done': 'Done',
  'submit': 'Submit',
  'continue': 'Continue',
  'back': 'Back',
  'start': 'Start',
  'stop': 'Stop',
  'pause': 'PAUSE',
  'resume': 'RESUME',
  'end_trip': 'END TRIP',
  'skip': 'Skip',
  'confirm': 'Confirm',

  // ============================================================
  // MESSAGES
  // ============================================================
  'success': 'Success',
  'failed': 'Failed',
  'warning': 'Warning',
  'info': 'Info',
  'no_data': 'No data',
  'no_results': 'No results found',
  'something_went_wrong': 'Something went wrong',
  'please_try_again': 'Please try again',
  'network_error': 'Network error',
  'internet_required': 'Internet connection required',
  'offline_mode': 'Offline mode',
  'syncing': 'Syncing...',
  'synced': 'Synced',
  'feature_coming_soon': 'Feature coming soon',

  // ============================================================
  // CLOUD STATUS
  // ============================================================
  'cloud_status': 'Cloud status',
  'cloud_connected': 'Cloud Sync: Active & Secure',
  'cloud_disconnected': 'Cloud Sync: Offline / Issues',
  'audit_chain_healthy': 'Audit chain healthy',
  'audit_chain_compromised': 'Audit chain compromised',

  // ============================================================
  // TIME
  // ============================================================
  'today': 'Today',
  'yesterday': 'Yesterday',
  'this_week': 'This week',
  'this_month': 'This month',
  'this_year': 'This year',
  'all_time': 'All time',
  'january': 'January',
  'february': 'February',
  'march': 'March',
  'april': 'April',
  'may': 'May',
  'june': 'June',
  'july': 'July',
  'august': 'August',
  'september': 'September',
  'october': 'October',
  'november': 'November',
  'december': 'December',
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',

  // ============================================================
  // UNITS
  // ============================================================
  'metric_system': 'Metric System',
  'meter': 'meter',
  'meter_short': 'm',
  'kilometer': 'kilometer',
  'kilometer_short': 'km',
  'mile': 'mile',
  'mile_short': 'mi',
  'hour': 'hour',
  'minute': 'minute',
  'second': 'second',
  'kmh': 'km/h',
  'mph': 'mph',

  // ============================================================
  // VALIDATION
  // ============================================================
  'field_required': 'This field is required',
  'powered_by_footer': 'Powered by',
  'invalid_email': 'Invalid email address',
  'password_too_short': 'Password is too short',
  'password_too_weak': 'Password must include at least one letter and one number',
  'passwords_do_not_match': 'Passwords do not match',
  'invalid_input': 'Invalid input',

  // ============================================================
  // PERMISSIONS
  // ============================================================
  'permissions_required': 'Permissions required',
  'camera_permission': 'Camera permission',
  'location_permission': 'Location permission',
  'storage_permission': 'Storage permission',
  'grant_permission': 'Grant permission',
  'deny_permission': 'Deny permission',
  // BUG FIX (2026-08-28, "página de permisos no funcional, hardcodeada en
  // inglés"): welcome_page.dart and permission_recovery_service.dart call
  // appState.tr() with these exact keys, but none of them existed in ANY
  // language file (not even English) -- AppTexts.getText() falls back to
  // the raw key string when a key is missing, so every user, in every
  // language including English, saw literal snake_case ("location_access",
  // "camera_desc"...) on the app's very first onboarding screen instead of
  // real text. i18n_validator never caught this because it only diffs
  // non-English maps against the English one -- a key missing from ALL of
  // them, including English, is invisible to it.
  'olympus_mont_systems': 'OLYMPUS MONT SYSTEMS',
  'secure_audit_programs': 'SECURE / AUDIT / PROGRAMS',
  'permissions_description': 'ControlMiles needs these permissions to track your trips and log accurate, defensible mileage evidence.',
  'location_access': 'Location Access',
  'location_desc': "ControlMiles collects location data to record your trips and calculate your mileage, even when the app is closed or not in use.",
  'camera': 'Camera',
  'camera_desc': 'Used to capture your odometer reading as evidence for each trip.',
  'motion_detection': 'Motion & Activity',
  'motion_desc': 'Used to detect when you start and stop driving.',
  'notifications_desc': 'Used to remind you about active trips and send you weekly mileage summaries.',
  'accept_terms': "I confirm I am at least 18 years old and accept the Terms of Service and Privacy Policy.",
  'permission_required': 'Permission required',
  'location_always_needed': 'ControlMiles needs "Allow all the time" location access to keep tracking your trip even when the app isn\'t open. Please enable it in Settings.',
  'open_settings': 'Open Settings',

  // ============================================================
  // SPECIFIC FEATURES
  // ============================================================
  'evidence': 'Evidence',
  'evidence_photo': 'Evidence photo',
  'hash_verification': 'Hash verification',
  'verified': 'Verified',
  'unverified': 'Unverified',
  'blockchain_status': 'Blockchain status',
  'integrity_check': 'Integrity check',
  'anomaly_detection': 'Anomaly detection',
  'fraud_alert': 'Fraud alert',
  'suspicious_activity': 'Suspicious activity detected',

  // ============================================================
  // VEHICLES
  // ============================================================
  'vehicle': 'Vehicle',
  'vehicles': 'Vehicles',
  'add_vehicle': 'Add vehicle',
  'add_vehicle_prompt': 'No vehicle added yet',
  'active_badge': 'ACTIVE',
  'vehicle_make_hint': 'E.g. Toyota, Nissan',
  'specify_make': 'Specify the make',
  'specify_model': 'Specify the model',
  'vehicle_model_hint': 'Choose a model',
  'vehicle_model_other': 'Other',
  'vehicle_model_pick_make_first': 'Choose a make first',
  'mark_as_active': 'Mark as active',
  'use_as_active_vehicle': 'Use as active vehicle',
  'current_trip': 'Current trip',
  'edit_vehicle': 'Edit vehicle',
  'delete_vehicle': 'Delete vehicle',
  'vehicle_make': 'Make',
  'vehicle_model': 'Model',
  'vehicle_color': 'Color',
  'vehicle_year': 'Year',
  'vehicle_mileage': 'Mileage',
  'vehicle_information': 'Vehicle information',
  'no_vehicle_registered': 'No vehicle registered',
  'delete_vehicle_confirmation': 'Are you sure you want to delete this vehicle? Its trip history will be kept.',

  // ============================================================
  // VEHICLE — new screen (moved out of Settings) + maintenance module
  // ============================================================
  'my_vehicle': 'My Vehicle',
  'maintenance': 'Maintenance',
  'select_vehicle': 'Select vehicle',
  'add_maintenance_record': 'Add maintenance record',
  'maintenance_type': 'Type',
  'service_date': 'Service date',
  'placed_in_service_date_optional': 'Placed in service date (optional)',
  'vin_optional': 'VIN (optional)',
  'vin_helper': 'If you re-add this vehicle later, the odometer can never go below what ControlMiles already tracked for this VIN.',
  'vehicle_odometer_below_floor': 'This VIN already has a higher odometer on record ({floor} mi). Enter a value at or above that.',
  'mileage_method_label': 'Deduction method',
  'mileage_method_standard': 'Standard mileage rate',
  'mileage_method_actual': 'Actual expenses',
  'odometer_at_service': 'Odometer at service',
  'cost_optional': 'Cost (optional)',
  'next_due_odometer_optional': 'Next due at odometer (optional)',
  'next_due_date_optional': 'Next due date (optional)',
  'notes_optional': 'Notes (optional)',
  'no_maintenance_records': 'No maintenance records yet',
  'maintenance_record_added_success': 'Maintenance record added',
  'maintenance_record_deleted_success': 'Maintenance record deleted',
  'maintenance_type_oil_change': 'Oil change',
  'maintenance_type_tire_rotation': 'Tire rotation',
  'maintenance_type_brake_service': 'Brake service',
  'maintenance_type_inspection': 'Inspection',
  'maintenance_type_registration': 'Registration',
  'maintenance_type_battery': 'Battery',
  'maintenance_type_other': 'Other',

  // ============================================================
  // SUBSCRIPTION
  // ============================================================
  'subscription': 'Subscription',
  'plan': 'Plan',
  'basic_plan': 'Basic plan',
  'premium_plan': 'Premium plan',
  'pro_plan': 'Pro plan',
  'upgrade_plan': 'Upgrade plan',
  'manage_subscription': 'Manage subscription',
  'trial_period': 'Trial period',
  'trial_expired': 'Trial expired',
  'subscription_active': 'Subscription active',
  'subscription_required': 'Subscription required',
  'premium_plan_description': "Unlock Automatic Detection and other premium features. Up to 5 vehicles. Includes a 15-day free trial.",
  'base_plan_description': "The core ControlMiles experience. 1 vehicle. Includes a 15-day free trial.",
  'current_plan': 'Current plan',
  'started_plan': 'Started (free trial)',
  'started_plan_description': 'Your 15-day free trial. 1 vehicle.',
  'trial_days_left': '{days} days left',
  'subscriptions_not_configured': 'Subscriptions are not available yet.',

  // Automatic trip detection (premium Gig feature).
  'automatic_tracking_section': 'Automatic Tracking',
  'auto_detect_toggle_title': 'Automatic trip detection',
  'auto_detect_toggle_subtitle': 'Detects when you start driving and prompts you to confirm the odometer right away.',
  'premium_badge': 'PREMIUM',
  'premium_feature_locked_title': 'Premium feature',
  'premium_feature_locked_body': 'Automatic trip detection is a premium add-on. Upgrade to enable it on your account.',
  'auto_detect_intro_title': 'Automatic Detection',
  'auto_detect_intro_body': 'When you open a supported gig app, ControlMiles starts tracking your trip automatically -- no need to tap Start. You\'ll capture your odometer once, right now; every trip detected after that carries the same reading forward. You can turn this off anytime.',
  'auto_detect_failed_title': 'Automatic detection couldn\'t start',
  'auto_detect_failed_body': 'Location tracking isn\'t running, so trips won\'t be detected automatically right now. Check that ControlMiles has "Allow all the time" location permission, then try again.',
  'auto_detect_apps_title_on': 'Auto-Detection On',
  'auto_detect_apps_title_off': 'Auto-Detect Apps',
  'auto_detect_apps_subtitle_on': 'Gig app detection is active',
  'auto_detect_apps_subtitle_off': 'Detects supported gig apps while you drive.',
  'shift_apps_picker_link': 'Choose apps for this shift',
  'shift_apps_picker_title': 'Select gig apps',
  'shift_apps_picker_body': 'Auto-detect will only react to the apps you select. Leave everything unchecked to watch every app.',
  'shift_apps_picker_clear': 'Clear',
  'shift_apps_picker_save': 'Save',
  'background_reliability_section': 'Background reliability',
  'battery_optimization_title': 'Battery optimization',
  'battery_optimization_granted': 'Allowed to run in the background',
  'battery_optimization_missing': 'May be paused in the background -- tap to fix',
  'exact_alarm_title': 'Exact alarms',
  'exact_alarm_granted': 'Reminders will fire on time',
  'exact_alarm_missing': 'Reminders may be delayed -- tap to fix',
  'checking_status': 'Checking...',
  'fix_it': 'Fix',
  'auto_detect_apps_checking': 'Checking apps...',
  'gig_app_detection_title': 'Active app detection',
  'gig_app_detection_subtitle_granted': 'Will suggest the app automatically when you open it',
  'gig_app_detection_subtitle_not_granted': 'Tap to grant usage access and suggest the app automatically',
  'carousel_manual_mode': 'Manual selection',
  'auto_detect_status_listening': 'Automatic Detection',
  'auto_detect_status_listening_subtitle': 'Listening for a gig app to open...',
  'auto_detect_status_found_label': 'Detected:',
  'auto_detect_status_found_subtitle': 'Starting your trip automatically...',
  'auto_trip_started_title': 'Trip started automatically',
  'auto_trip_started_body': 'Now tracking with',
  'forgotten_trip_notification_title': 'Your trip is still active',
  'forgotten_trip_notification_body': 'Did you forget to end it? Check ControlMiles to pause or finish.',
  'pause_reminder_notification_title': 'Your trip is paused',
  'pause_reminder_notification_body': "It's been paused a few minutes — open ControlMiles to resume or end it.",
  'paused_status_notification_title': 'ControlMiles',
  'paused_status_notification_body': 'Trip paused — tap to resume or end it.',
  'weekly_summary_notification_title': 'Your weekly summary is ready',
  'weekly_summary_notification_body': 'Check how many miles you logged this week.',
  // BUG FIX (found live, screenshotted on a real device -- the odometer
  // capture screen, used on EVERY trip start/end, has shown these raw
  // key names instead of real text since these 7 keys were referenced
  // but never actually defined in any language file).
  'torch_suggestion': 'Too dark? Tap for flashlight',
  'ocr_unreadable_manual': 'Couldn\'t read it — enter manually',
  'ocr_detected': 'Detected',
  'ocr_scanning': 'Scanning...',
  'ocr_auto_badge': 'Auto-detected',
  'odometer_value': 'Odometer',
  'ocr_confirm_capture': 'Confirm & capture',
  'photo_blurry_warning': 'This photo looks blurry. Retake it for a clear, usable record.',
  'retake_photo': 'Retake',
  'use_photo': 'Use photo',
  'use_photo_anyway': 'Use anyway',
  // Mid-trip gig-app-switch detection (premium, explicit user follow-up).
  'mid_trip_auto_switched_title': 'Switched automatically',
  'mid_trip_auto_switched_body': 'Now tracking with',
  'auto_detect_tracking_with_label': 'Tracking with:',
  'auto_detect_tracking_subtitle': 'Auto-detect is monitoring for app changes',
  'auto_detect_tracking_paused_subtitle': 'Tracking paused',
  'recent_trips_title': 'Recent trips',
  'see_all_label': 'See all',
  'no_trips_yet': 'No trips yet',

  'waiting_for_gps': 'Waiting for GPS…',

  'terms_of_use': "Terms of use",
  'licenses_map_data': "Licenses & map data",
  'ready_to_track': "Ready to track",
  'ready_to_track_body': "Pick your activity and start your trip.",
  'tracking_paused_label': "Tracking paused",
  'trip_route': "Trip route",
  'trip_route_fit': "Fit route",

  // ============================================================
  // REPORT EXTENSIONS
  // ============================================================
  'report_generated': 'Report generated',
  'generating_report_progress': 'Generating report...',
  'report_download': 'Download report',
  'report_verification': 'Report verification',
  'report_qr_verification': 'QR verification',
  'report_integrity': 'Report integrity',

  // ============================================================
  // TAX / IRS
  // ============================================================
  'tax_deduction': 'Tax deduction',
  'irs_rate': 'IRS 2026',
  'estimated_deduction': 'Estimated deduction',
  'tax_summary': 'Tax summary',

  // ============================================================
  // QR VERIFICATION
  // ============================================================
  'verification_page': 'Verification page',
  'scan_qr': 'Scan QR code',
  'verify_report': 'Verify report',
  'session_hash': 'Session hash',
  'section_hash': 'Section hash',

  // ============================================================
  // VEHICLE FORM
  // ============================================================
  'enter_vehicle_make': 'Enter vehicle make',
  'enter_vehicle_model': 'Enter vehicle model',
  'enter_vehicle_color': 'Enter vehicle color',
  'enter_vehicle_year': 'Enter vehicle year',
  'enter_vehicle_mileage': 'Enter vehicle mileage',

  // ============================================================
  // SUCCESS / ALERTS
  // ============================================================
  'vehicle_added_success': 'Vehicle added successfully',
  'vehicle_deleted_success': 'Vehicle deleted',
  // BUG FIX (pedido explícito, nueva regla multi-auto): mensaje limpio
  // para cuando la DB rechaza un cambio de vehículo activo porque hay un
  // viaje sin cerrar (ver trigger tr_vehicles_block_switch_during_session).
  'vehicle_switch_blocked_active_session': 'You can\'t change your active vehicle while a trip is in progress. End the current trip first.',
  'vehicle_saved': 'Vehicle saved',
  'vehicle_required': 'Vehicle required',

  // ============================================================
  // END SHIFT
  // ============================================================
  'session_already_closed': 'This session is already closed and cannot be modified.',
  'session_not_found': 'Critical error: active session not found.',
  'session_already_finalized': 'This session was already finalized.',
  'duplicate_capture': 'A capture is already registered for this event.',
  'photo_size_out_of_range': 'Photo is outside the allowed size range ({min}KB–{max}MB). Try again.',
  'photo_format_not_supported': 'Photo format not supported. Allowed formats: {formats}.',

  // Weekly odometer checkpoint (2026-09-03)
  'weekly_odometer_close_title': 'Weekly odometer close',
  'weekly_odometer_close_body': 'Want to take this week\'s closing odometer photo now?',
  'weekly_odometer_close_title_mandatory': 'Weekly close required',
  'weekly_odometer_close_body_mandatory': 'Take this week\'s closing odometer photo to finish -- it can\'t be skipped on Sundays.',
  'later': 'Later',
  'take_photo': 'Take photo',
  'odometer_evidence_label': 'Odometer photos (evidence)',
  'gps_vs_odometer_disclaimer': 'These numbers won\'t always match exactly -- personal (untracked) miles aren\'t counted by GPS, so some difference is expected.',

  // ============================================================
  // VEHICLE PROFILE (read-only detail screen) + maintenance mileage
  // ============================================================
  'vehicle_profile_title': 'Vehicle Profile',
  'tracked_miles_gps': 'Tracked miles (GPS)',
  'odometer_checkpoints_title': 'Weekly odometer checkpoints',
  'no_odometer_checkpoints': 'No odometer checkpoints yet',
  'checkpoint_week_label': 'Week of {date}',
  'checkpoint_start': 'Start',
  'checkpoint_end': 'End',
  'checkpoint_pending_close': 'Pending close',
  'current_odometer': 'Current odometer',
  'miles_since_service': 'Miles since last service',
  'no_service_recorded': 'No service recorded yet',
  'next_service_due_miles': 'Next due at {miles}',
  'service_overdue_miles': 'Overdue by {miles}',
  'service_recommended_interval': 'Recommended: every {miles}',

  // ============================================================
  // Missing-key audit (2026-09-03): keys already referenced via .tr() in
  // code but never added to any dictionary -- tr() was silently rendering
  // the raw key string on screen. See feedback_i18n_hardcoded_strings.
  // ============================================================
  'auth_error': 'Authentication error. Please try again.',
  'header_miles_period': "Miles on the home header",
  'tour_step': "{n} of {total}",
  'tour_skip': "Skip",
  'tour_next': "Next",
  'tour_done': "Get started",
  'tour_got_it': "Got it",
  'monitor_home_title': "Bus aide",
  'monitor_hello': "Hi, {name}",
  'monitor_hint': "Your school routes for today. When the driver starts a route, open it and keep the student list up to date.",
  'monitor_waiting_driver': "Waiting for the driver to start",
  'signup_check_email': "Account created. Confirm your email, then sign in here.",
  'signup_confirm_title': "Check your email",
  'login_sign_in_title': "Sign in",
  'login_sign_in_sub': "Sign in to start logging every mile.",
  'invalid_credentials': 'Invalid email or password.',
  'email_already_exists': 'This email is already registered.',
  // AppError registry (lib/errors/app_error.dart) -- coded error
  // messages shown to the user, never raw exception/database text.
  'camera_permission_denied_error': 'Camera access is needed for this.',
  'no_internet_connection_error': 'No internet connection.',
  'invalid_input_error': 'Please check what you entered.',
  'local_storage_error': 'Could not save locally on this device.',
  'session_expired_error': 'Your session expired. Please sign in again.',
  'vehicle_limit_reached_error': "You've reached your plan's vehicle limit.",
  'rate_limited_error': 'Too many attempts. Try again in a few minutes.',
  'duplicate_entry_error': 'This already exists.',
  'unexpected_error': 'Something went wrong.',
  'end': 'End',
  'navigation_error_title': 'Navigation Error',
  'route_not_found_message': 'Route {route} not found.\nContact Olympus Mont Systems.',
  'switched_label': 'SWITCHED',
  'trip_number_label': 'Trip {number}',
  'trip_end_time_label': 'End: {time}',
  'sections_label': 'SECTIONS',
  'vin_label': 'VIN',
  'odometer_cycle_label': 'Odometer cycle',
  'odometer_cycle_weekly': 'Weekly',
  'odometer_cycle_biweekly': 'Biweekly',
  'odometer_cycle_monthly': 'Monthly',
  'odometer_cycle_updated': 'Odometer cycle updated.',
  'system_initializing_redirecting': 'System initializing. Redirecting...',
  'error_all_fields_required': 'All fields are required.',
  'error_invalid_vehicle_year': 'Invalid vehicle year.',
  'error_odometer_negative_or_empty': 'Odometer cannot be negative or empty.',
  'error_invalid_maintenance_type': 'Invalid maintenance type.',
  'error_service_date_required': 'Service date is required.',
  'sections_count_label': '{count} sections',
  // BUG FIX (hardcoded-string audit, vehicle screen): kOtherVehicleMake's
  // display text ('Otra') was rendered literally in the make dropdown
  // regardless of language -- only this one dropdown entry is UI text
  // needing tr(), the real brand names (Toyota, Honda, ...) are correct
  // as-is.
  'vehicle_make_other': 'Other',
  'email_not_linked_to_controlmiles': 'That email isn\'t linked to a ControlMiles account.',

  // ============================================================
  // SUBSCRIPTION-TIER ENFORCEMENT (2026-09-04)
  // ============================================================
  'free_trial_expired_title': 'Your free trial has ended',
  'free_trial_expired_body': 'Your 15-day free trial is over. Subscribe to Basic or Premium to keep tracking trips.',
  'vehicle_limit_reached_title': 'Vehicle limit reached',
  'vehicle_limit_reached_body': 'Your plan allows up to {max} vehicle(s). Upgrade to add more.',
  'export_limit_reached_title': 'Export limit reached',
  'export_limit_reached_body': 'Basic plans include 2 PDF exports per month. Upgrade to Premium for unlimited exports.',

  // Report Portal access code, generated in-app (explicit user
  // requirement, 2026-09-09) -- moved here from being web-only, since a
  // gig driver should never need to log into controlmiles.com at all.
  'copy': 'Copy',
  'copied_to_clipboard': 'Copied to clipboard',
  'generate_report_code_title': 'Report access code',
  'generate_report_code_body': 'Generate a one-time code for a date range of your trips. Your tax preparer enters it at controlmiles.com/portal/verify to view a read-only mileage summary -- no login, no account needed on their end.',
  'generate_report_code_button': 'Generate code',
  'generate_report_code_your_code': 'Share this code with your tax preparer',
  'generate_report_code_expires_in': 'Expires in {mmss}',
  'generate_report_code_expired': 'This code has expired.',
  'generate_report_code_disclaimer': 'Usable up to 2 times. Not guaranteed by this app -- for deduction purposes.',
  'report_portal_section': 'Report Portal',
  'report_portal_section_subtitle': 'Generate a code for your tax preparer',

  // 2026-09-16: check 'no volver a mostrar' + toggles por tipo de aviso. Traducciones best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'dont_show_again': 'Don\'t show this again',
  'notif_type_pause_reminder': 'Paused trip reminder',
  'notif_type_forgotten_trip': 'Forgotten trip reminder',
  'notif_type_weekly_summary': 'Weekly mileage summary',
  'notif_type_gig_app_switch': 'Gig app switched',
  'notif_type_auto_trip_started': 'Trip started automatically',
  'notification_types_manage_hint': 'Tap to choose which alerts you get',
  'notification_types_sheet_title': 'Alert types',


  // 2026-09-16: Usage Access en el onboarding de permisos + dialogo al activar auto-detect. Best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'usage_access': 'App usage access',
  'usage_access_desc': 'Lets ControlMiles see which gig app you have open, so it can start your trip automatically.',
  'usage_access_onboarding_body': 'Automatic trip detection needs "Usage access". Android only grants it from Settings, not from a normal prompt. You can skip this now and turn it on later from Settings.',
  'usage_access_required_title': 'Usage access needed',
  'usage_access_required_body': 'Automatic detection can\'t see which gig app is open without "Usage access". Grant it in Settings, then turn automatic detection on again.',

  // Gig / Fleet split (2026-10-11).
  'active_fleet_trip_error': "You have a company trip open in ControlMiles Fleet. End it there before starting a personal trip.",
  'gig_fleet_app_hint': "Drive for a company fleet? Company trips go in the ControlMiles Fleet app. This app keeps your personal miles only.",
  'get_fleet_app': "Get ControlMiles Fleet",

  // Product tour (2026-10-11): English + Spanish; other languages fall back to English.
  'ptour_welcome_title': "Welcome to ControlMiles",
  'ptour_welcome_body': "Take 30 seconds to see how to log your first trip and get a mileage report your tax preparer can trust.",
  'ptour_welcome_start': "Show me around",
  'ptour_welcome_later': "Not now",
  'ptour_help': "Show tips for this screen",
  'ptour_replay': "App tour",
  'ptour_after_trip': "End your trip first; the tour plays on the home screen when no trip is running.",
  'ptour_vehicle_title': "Your vehicle",
  'ptour_vehicle_body': "Every trip is logged to this vehicle. Tap the card to add a vehicle or switch to another one.",
  'ptour_apps_title': "Pick your gig app",
  'ptour_apps_body': "Choose the app you're driving for before you start. Switch apps mid-trip and each part is logged on its own.",
  'ptour_auto_title': "Automatic detection",
  'ptour_auto_body': "ControlMiles starts and stops trips for you when your gig app is open. You can turn it off any time.",
  'ptour_start_title': "Start your trip",
  'ptour_start_body': "Tap {start} when you begin driving and {end} when you're done. The route and the miles are recorded in the background.",
  'ptour_miles_title': "Your miles",
  'ptour_miles_body': "Your miles for the period you chose: this week, this month or this year. Change it in Profile.",
  'ptour_bottom_title': "History and reports",
  'ptour_bottom_body': "History shows every trip. Reports gives you your IRS mileage summary and a PDF.",
  'ptour_menu_title': "Menu",
  'ptour_menu_body': "Vehicles, profile, settings and language are here. Replay this tour from Settings any time.",
  'ptour_first_trip_title': "Trip saved",
  'ptour_first_trip_body': "Your first trip is in History. Open it to see the route, the miles and each gig app.",
  'ptour_range_title': "Choose the dates",
  'ptour_range_body': "Pick any date range, like a month or the whole tax year. Everything below follows it.",
  'ptour_summary_title': "Your totals",
  'ptour_summary_body': "Total miles and time for the range, plus today's total.",
  'ptour_pdf_title': "Your mileage report",
  'ptour_pdf_body': "Create a PDF with every trip, the route and the IRS deduction estimate, ready to share.",
  'ptour_trip_title': "Your trips",
  'ptour_trip_body': "Tap a trip to see its route, each gig app segment and your notes.",
  'ptour_history_empty': "Tap {start} on the home screen to log your first trip. It shows up here when you end it.",
  'ptour_portal_title': "Code for your tax preparer",
  'ptour_portal_body': "Create a short-lived code so your tax preparer can open your report on controlmiles.com, no login needed.",
  'ptour_reliability_title': "Keep tracking reliable",
  'ptour_reliability_body': "Check these so Android never pauses ControlMiles in the middle of a trip.",

};