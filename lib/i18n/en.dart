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
  'loading': 'Loading...',
  'please_wait': 'Please wait...',

  // ============================================================
  // AUTHENTICATION    // TRIP PURPOSES & IRS.
  // ============================================================
  'login': 'Login',
  'register': 'Register',
  'signup': 'Sign up',
  'logout': 'Logout',
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
  'dashboard': 'Dashboard',
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
  'odometer_not_detected': 'Odometer not detected',
  'center_odometer_numbers': 'Center odometer numbers',
  'ai_processing': 'AI processing',
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
  'irs_estimate_disclaimer': 'Estimated using the IRS 2026 standard mileage rate (\$0.725/mile). ControlMiles is not affiliated with or endorsed by the IRS or any official agency. This is an informational estimate only, not a guaranteed deduction — consult a tax professional.',

  // ============================================================
  // TRIP PURPOSES & IRS.
  // ============================================================
   'select_trip_purpose': 'Select Trip Purpose',
   'irs_deduction_note': 'For IRS tax deduction purposes',
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
  'data_protected_footer': 'Your data is protected',
  'invalid_email': 'Invalid email address',
  'password_too_short': 'Password is too short',
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

  // ============================================================
  // FLEET
  // ============================================================
  'fleet_management': 'Fleet management',
  'fleet_vehicle': 'Fleet vehicle',
  'fleet_dashboard': 'Fleet dashboard',
  'driver_management': 'Driver management',
  'company_account': 'Company account',

  // Fleet Phase 1: account-type choice + create-fleet screens
  'account_type_title': 'How will you use ControlMiles?',
  'account_type_subtitle': 'This choice decides how your account works. Pick the option that fits you.',
  'account_type_gig_title': 'ControlMiles Individual',
  'account_type_gig_desc': 'Track your own mileage for apps like Uber, Lyft, or DoorDash.',
  'account_type_fleet_desc': 'Create a company fleet and manage multiple drivers and vehicles.',
  'account_type_have_invite_title': 'I have an invite code',
  'account_type_have_invite_desc': 'Coming soon — join a fleet your manager already set up.',
  'create_fleet_title': 'Set up your fleet',
  'create_fleet_subtitle': 'Give your company or fleet a name. You\'ll be its owner.',
  'fleet_name_label': 'Fleet or company name',
  'create_fleet_button': 'Create fleet',
  'fleet_stat_members': 'Members',
  'fleet_stat_month_miles': 'Miles this month',
  'fleet_invite_title': 'You\'ve been invited to join a fleet',
  'fleet_invite_role_driver': 'You\'ll join as a driver',
  'fleet_invite_accept': 'Accept',
  'fleet_invite_decline': 'Decline',
  'fleet_no_vehicle_assigned': 'No vehicle assigned yet',
  'fleet_invite_dialog_title': 'Invite a driver',
  'fleet_invite_send': 'Send invite',
  'fleet_assign_vehicle_title': 'Assign a vehicle',
  'fleet_vehicle_already_assigned': 'Already assigned to another driver',
  'fleet_invite_driver': 'Invite driver',
  'fleet_invite_pending': 'PENDING',

  // Fleet Phase 4 -- DVIR-style pre/post-trip inspections
  'inspection_start': 'Inspect vehicle',
  'inspection_pre_trip': 'Pre-trip',
  'inspection_post_trip': 'Post-trip',
  'inspection_category_tires_wheels': 'Tires & wheels',
  'inspection_category_brakes': 'Brakes',
  'inspection_category_lights_signals': 'Lights & signals',
  'inspection_category_mirrors': 'Mirrors',
  'inspection_category_windshield_wipers': 'Windshield & wipers',
  'inspection_category_horn': 'Horn',
  'inspection_category_steering': 'Steering',
  'inspection_category_fluid_leaks': 'Fluid leaks',
  'inspection_category_seatbelts': 'Seatbelts',
  'inspection_category_body_damage': 'Body damage',
  'inspection_category_other': 'Other',
  'inspection_status_ok': 'OK',
  'inspection_status_defect': 'Defect',
  'inspection_defect_note_hint': 'Describe the issue',
  'inspection_defect_note_required': 'Add a note for each defect before submitting.',
  'inspection_photo_optional': 'Add photo',
  'inspection_photo_added': 'Photo added',
  'inspection_odometer_optional': 'Odometer (optional)',
  'inspection_submit': 'Submit inspection',
  'inspection_result_pass': 'Inspection passed -- no defects found',
  'inspection_result_fail': 'Inspection submitted -- defects reported to your fleet manager',

  // Fleet Phase 5 -- live map / geofencing
  'fleet_live_map_title': 'Live map',
  'fleet_live_map_no_vehicles': 'No vehicles reporting a live position yet',
  'fleet_live_map_tap_to_place': 'Tap the map to place the geofence center',
  'fleet_live_map_add_geofence': 'Add geofence',
  'fleet_live_map_new_geofence': 'New geofence',
  'fleet_live_map_geofence_name': 'Zone name',
  'fleet_live_map_geofence_radius': 'Radius',
  'fleet_live_map_create': 'Create',
  'fleet_live_map_alerts_title': 'Geofence alerts',
  'fleet_live_map_no_alerts': 'No alerts',

  // ============================================================
  // REPORT EXTENSIONS
  // ============================================================
  'report_generated': 'Report generated',
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
};