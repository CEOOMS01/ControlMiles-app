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

  // First-launch role chooser (before login/signup, shown once per device)
  // + the driver-slot claim screen it can lead to.
  'role_chooser_title': 'What brings you to ControlMiles?',
  'role_chooser_subtitle': 'Pick what fits you. This sets up your account from the start.',
  'role_gig_title': 'Gig App Driver',
  'role_gig_desc': 'Track your own mileage for Uber, DoorDash, and more.',
  'role_fleet_driver_title': 'Fleet Driver',
  'role_fleet_driver_desc': 'Your fleet admin gave you a code? Join your team.',
  'role_fleet_admin_title': 'Fleet Admin',
  'role_fleet_admin_desc': 'Manage drivers, vehicles, and reports for your fleet.',
  'role_chooser_have_account': 'Already have an account? Sign in',
  'claim_driver_slot_title': 'Join your fleet',
  'claim_driver_slot_subtitle': 'Enter the code your fleet admin shared with you.',
  'claim_driver_slot_code_label': 'Claim code',
  'claim_driver_slot_button': 'Join fleet',
  'claim_driver_slot_skip': 'I don\'t have a code -- continue as an individual driver',

  // Account mode switcher (Settings) -- explicit user requirement: a
  // hybrid account can move between Gig/Fleet Admin/Fleet Driver at
  // will, for testing and for real hybrid use.
  'account_mode_title': 'Account mode',
  'account_mode_gig': 'Individual (Gig)',
  'account_mode_fleet_admin': 'Fleet Admin',
  'account_mode_fleet_driver': 'Fleet Driver',

  // DVIR gating (roadmap gap closed): shown when a driver tries to start
  // tracking without a passing, same-day pre-trip inspection on record.
  'dvir_required_before_start': 'Complete today\'s pre-trip inspection before starting a trip.',

  // Organization rename/delete (mobile Settings, fleet_admin only).
  'organization_section_title': 'Organization',
  'org_rename_hint': 'Tap to rename',
  'org_rename_title': 'Rename organization',
  'org_name_label': 'Organization name',
  'org_renamed_success': 'Organization renamed',
  'org_delete_button': 'Delete organization',
  'org_delete_confirm_title': 'Delete this organization?',
  'org_delete_confirm_body': 'This permanently deletes the organization, its vehicles, roster, routes, inspections, and maintenance records. Drivers keep their own trip history, but lose their fleet assignment. This cannot be undone.',
  'org_delete_type_to_confirm': 'Type the organization name to confirm',
  'org_deleted_success': 'Organization deleted',

  // Automatic trip detection (premium Gig feature).
  'automatic_tracking_section': 'Automatic Tracking',
  'auto_detect_toggle_title': 'Automatic trip detection',
  'auto_detect_toggle_subtitle': 'Detects when you start driving and prompts you to confirm the odometer right away.',
  'premium_badge': 'PREMIUM',
  'premium_feature_locked_title': 'Premium feature',
  'premium_feature_locked_body': 'Automatic trip detection is a premium add-on. Contact support to enable it on your account.',
  'auto_trip_prompt_title': 'Trip detected',
  'auto_trip_prompt_body': 'We detected you started moving. Pick the app and confirm now to log the odometer for this trip.',
  'auto_trip_prompt_confirm': 'Confirm and start',
  'auto_trip_prompt_dismiss': 'Not a work trip',
  'gig_app_detection_title': 'Active app detection',
  'gig_app_detection_subtitle_granted': 'Will suggest the app automatically when you open it',
  'gig_app_detection_subtitle_not_granted': 'Tap to grant usage access and suggest the app automatically',
  'carousel_manual_mode': 'Manual selection',
  'auto_detect_status_listening': 'Automatic Detection',
  'auto_detect_status_listening_subtitle': 'Listening for a gig app to open...',
  'auto_detect_status_found_label': 'Detected:',
  'auto_detect_status_found_subtitle': 'We\'ll ask you to confirm once you start driving.',
  'auto_trip_notification_tap_hint': 'Tap to confirm and log the odometer now.',
  'forgotten_trip_notification_title': 'Your trip is still active',
  'forgotten_trip_notification_body': 'Did you forget to end it? Check ControlMiles to pause or finish.',
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
  // Mid-trip gig-app-switch detection (premium, explicit user follow-up).
  'mid_trip_switch_suggested_title': 'Different app detected',
  'mid_trip_switch_suggested_body': 'Open ControlMiles to switch to',
  'mid_trip_auto_switched_title': 'Switched automatically',
  'mid_trip_auto_switched_body': 'Now tracking with',
  'auto_detect_tracking_with_label': 'Tracking with:',
  'auto_detect_tap_to_switch': 'Tap to switch',
  'auto_detect_tracking_subtitle': 'Auto-detect is monitoring for app changes',
  'auto_detect_tracking_paused_subtitle': 'Tracking paused',
  'auto_switch_toggle_title': 'Auto-switch detected app',
  'auto_switch_toggle_subtitle': 'Switch automatically instead of asking first',
  'recent_trips_title': 'Recent trips',
  'see_all_label': 'See all',
  'no_trips_yet': 'No trips yet',

  // Fleet Phase 1: account-type choice + create-fleet screens
  'account_type_title': 'How will you use ControlMiles?',
  'account_type_subtitle': 'This choice decides how your account works. Pick the option that fits you.',
  'account_type_gig_title': 'ControlMiles Individual',
  'account_type_gig_desc': 'Track your own mileage for apps like Uber, Lyft, or DoorDash.',
  'account_type_fleet_desc': 'Create a company fleet and manage multiple drivers and vehicles.',
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

  // Driver Operations screen (dedicated fleet_driver home) + mid-trip
  // incident reporting -- distinct from the DVIR checklist's own defect
  // notes, which only cover the pre/post-trip moment.
  'driver_ops_title': 'Today\'s trip',
  'driver_ops_checklist_required': 'Complete the pre-trip checklist before starting',
  'driver_ops_live_location': 'Live location',
  'waiting_for_gps': 'Waiting for GPS…',
  'report_incident_button': 'Report incident',
  'report_incident_title': 'Report an incident',
  'report_incident_category_label': 'What happened?',
  'incident_category_breakdown': 'Vehicle breakdown',
  'incident_category_accident': 'Accident',
  'incident_category_delay': 'Delay',
  'incident_category_other': 'Other',
  'report_incident_description_label': 'Describe what happened',
  'report_incident_description_hint': 'e.g. Flat tire on I-95, pulled over safely',
  'report_incident_submit': 'Submit report',
  'report_incident_success': 'Incident reported to your fleet admin',

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

  // Fleet Phase 6 -- IFTA state mileage (piece 1: miles per state, not a
  // fileable IFTA return -- see ifta_service.dart's own comment)
  'ifta_state_mileage_title': 'State mileage',
  'ifta_pick_range': 'Pick date range',
  'ifta_all_vehicles': 'All vehicles',
  'ifta_total_miles': 'Total miles',
  'ifta_no_org': 'No organization found for this account.',
  'ifta_no_mileage': 'No mileage recorded for this range',
  'ifta_disclaimer': 'Miles per state, computed from GPS breadcrumbs. This is not a fileable IFTA return -- fuel gallons per jurisdiction are needed for the actual tax calculation and are not tracked in this app.',

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