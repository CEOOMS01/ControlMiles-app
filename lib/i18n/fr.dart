// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/fr.dart - Français (FRA)

const Map<String, String> frTexts = {
  // ============================================================
  // APPLICATION GÉNÉRALE
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': 'Écran de démarrage',
  'not_found': 'Non trouvé',
  'error': 'Erreur',
  'system_error': 'Erreur système',
  'id_label': 'ID',
  'loading': 'Chargement...',
  'please_wait': 'Veuillez patienter...',

  // ============================================================
  // AUTHENTIFICATION
  // ============================================================
  'login': 'Connexion',
  'register': 'S\'inscrire',
  'signup': 'Créer un compte',
  'logout': 'Déconnexion',
  'logout_confirmation': 'Êtes-vous sûr de vouloir vous déconnecter ?',
  'forgot_password': 'Mot de passe oublié ?',
  'reset_password': 'Réinitialiser le mot de passe',
  'auth_session_expired': 'Session d\'authentification expirée',
  'email': 'Email',
  'password': 'Mot de passe',
  'confirm_password': 'Confirmer le mot de passe',
  'sign_in': 'Se connecter',
  'sign_up': 'Créer un compte',
  'sign_out': 'Se déconnecter',
  'active_activity': 'Activité active',
  'configuration_updated': 'Configuration mise à jour',

  // ============================================================
  // PROFIL UTILISATEUR
  // ============================================================
  'name': 'Prénom',
  'edit_name': 'Modifier le prénom',
  'last_name': 'Nom de famille',
  'adress': 'Adresse',
  'number': 'Numéro',
  'dark_mode': 'Mode sombre',
  'dark_mode_description': 'Basculer entre les thèmes clair et sombre',
  'profile_updated_success': 'Profil mis à jour avec succès',

  // ============================================================
  // NAVIGATION
  // ============================================================
  'dashboard': 'Accueil',
  'home': 'Accueil',
  'profile': 'Profil',
  'settings': 'Paramètres',
  'help': 'Aide',
  'about': 'À propos',
  'support': 'Support',

  // ============================================================
  // TRACKING (SUIVI)
  // ============================================================
  'tracking': 'Suivi',
  'tracking_active': 'Suivi actif',
  'tracking_paused': 'En pause',
  'tracking_stopped': 'Suivi arrêté',
  'start_tracking': 'COMMENCER LE SUIVI',
  'stop_tracking': 'ARRÊTER LE SUIVI',
  'pause_tracking': 'Mettre en pause',
  'resume_tracking': 'Reprendre',
  'trip_details': 'Détails du trajet',
  'route_map_show': "Carte du trajet",
  'route_map_hide': "Masquer la carte",
  'trip_history': 'Historique des trajets',
  'trip_ended': 'Trajet terminé',
  'miles': 'Miles',
  'kilometers': 'Kilomètres',
  'speed': 'Vitesse',
  'duration': 'Durée',
  'distance': 'Distance',
  'start_time': 'Heure de départ',
  'end_time': 'Heure d\'arrivée',
  'select_an_activity_before_starting_tracking': 'Sélectionnez une activité avant de commencer le suivi',

  // ============================================================
  // ODOMÈTRE
  // ============================================================
  'odometer': 'Odomètre',
  'odometer_capture': 'Capture d\'odomètre',
  'start_odometer_capture': 'Capturer l\'odomètre de départ',
  'end_odometer_capture': 'Capturer l\'odomètre d\'arrivée',
  'capture_photo': 'Prendre une photo',
  'retry_camera': 'Réessayer la caméra',
  'camera_error': 'Erreur de caméra',
  'camera_error_body': 'Impossible d\'accéder à votre caméra. Vérifiez l\'autorisation de la caméra dans les Paramètres, puis réessayez.',
  'odometer_not_detected': 'Odomètre non détecté',
  'center_odometer_numbers': 'Centrez les chiffres de l\'odomètre',
  'ai_processing': 'Traitement de la photo',
  'validating_mileage_gps_hash': 'Validation du kilométrage, GPS et hash',

  // ============================================================
  // GPS / LOCALISATION
  // ============================================================
  'gps': 'GPS',
  'gps_enabled': 'GPS activé',
  'gps_disabled': 'GPS désactivé',
  'location_permission_required': 'Permission de localisation requise',
  'location_permission_denied': 'Permission de localisation refusée',

  // ============================================================
  // HISTORIQUE ET RAPPORTS
  // ============================================================
  'history': 'Historique',
  'reports': 'Rapports',
  'audit_logs': 'Journaux d\'audit',
  'statistics': 'Statistiques',
  'summary': 'Résumé',
  'total_miles': 'Total des miles',
  'last_30_days': '30 derniers jours',
  'last_12_months': '12 derniers mois',
  'total_trips': 'Total des trajets',
  'average_speed': 'Vitesse moyenne',
  'RECENT_TRIPS': 'TRAJETS RÉCENTS',
  'SEE_ALL': 'VOIR TOUT',
  'not_trips_yet': 'Aucun trajet pour le moment',
  'generate_pdf': 'Générer PDF',


  // ============================================================
  // TRIP PURPOSES & IRS
  // ============================================================
  'select_trip_purpose': 'Sélectionnez le but du voyage',
  'irs_deduction_note': 'À des fins de déduction -- non garanti par cette application',
  'business_purpose': 'Affaires',
  'work_commute': 'Trajet travail',
  'medical': 'Médical',
  'moving': 'Déménagement',
  'charitable': 'Bénévolat / Caritatif',
  'education_study': 'Éducation / Études',
  'personal_other': 'Personnel / Autre',

  // ============================================================
  // PARAMÈTRES
  // ============================================================
  'preferences': 'Préférences',
  'language': 'Langue',
  'language_description': 'Sélectionnez votre langue préférée',
  'language_changed': 'Langue changée en',
  'notifications': 'Notifications',
  'notifications_description': 'Recevoir les notifications de l\'application',
  'notifications_enabled': 'Notifications activées',
  'notifications_disabled': 'Notifications désactivées',
  'analytics': 'Analytiques',
  'analytics_description': 'Partager les données d\'utilisation',

  // ============================================================
  // CONFIDENTIALITÉ ET SÉCURITÉ
  // ============================================================
  'privacy_security': 'Confidentialité et Sécurité',
  'privacy_policy': 'Politique de confidentialité',
  'terms_conditions': 'Conditions générales',
  'send_feedback': 'Envoyer des suggestions',
  'send_feedback_no_mail_app': "Aucune appli e-mail trouvée. Écrivez à support@controlmiles.com.",
  'send_feedback_email_subject': 'Suggestions pour ControlMiles',
  'trademark_disclaimer_short': 'ControlMiles est une application indépendante et n\'est affiliée à, approuvée par, ou parrainée par Uber, Lyft, DoorDash, Instacart, Amazon, Walmart, Shipt ou toute autre plateforme mentionnée dans cette application. Toutes les marques appartiennent à leurs propriétaires respectifs.',
  'age_terms_checkbox_prefix': 'Je confirme avoir au moins 18 ans et j\'accepte les',
  'age_terms_checkbox_and': 'et la',
  'age_terms_required_error': 'Veuillez confirmer que vous avez 18 ans ou plus et accepter les Conditions pour continuer.',
  'data_security': 'Sécurité des données',
  'security_audit': 'Audit de sécurité',

  // ============================================================
  // À PROPOS
  // ============================================================
  'about_app': 'À propos de l\'application',
  'app_version': 'Version de l\'application',
  'build_number': 'Numéro de build',
  'company': 'Entreprise',
  'copyright': 'Tous droits réservés',
  'developer': 'Développeur',

  // ============================================================
  // BOUTONS
  // ============================================================
  'ok': 'OK',
  'cancel': 'Annuler',
  'save': 'Enregistrer',
  'delete': 'Supprimer',
  'edit': 'Modifier',
  'close': 'Fermer',
  'refresh': 'Actualiser',
  'retry': 'Réessayer',
  'next': 'Suivant',
  'previous': 'Précédent',
  'done': 'Terminé',
  'submit': 'Envoyer',
  'continue': 'Continuer',
  'back': 'Retour',
  'start': 'Démarrer',
  'stop': 'Arrêter',
  'pause': 'PAUSE',
  'resume': 'REPRENDRE',
  'end_trip': 'TERMINER LE TRAJET',
  'skip': 'Passer',
  'confirm': 'Confirmer',

  // ============================================================
  // MESSAGES
  // ============================================================
  'success': 'Succès',
  'failed': 'Échec',
  'warning': 'Avertissement',
  'info': 'Information',
  'no_data': 'Aucune donnée',
  'no_results': 'Aucun résultat trouvé',
  'something_went_wrong': 'Quelque chose s\'est mal passé',
  'please_try_again': 'Veuillez réessayer',
  'network_error': 'Erreur réseau',
  'internet_required': 'Connexion internet requise',
  'offline_mode': 'Mode hors ligne',
  'syncing': 'Synchronisation...',
  'synced': 'Synchronisé',
  'feature_coming_soon': 'Fonctionnalité bientôt disponible',

  // ============================================================
  // STATUT DU CLOUD
  // ============================================================
  'cloud_status': 'Statut du cloud',
  'cloud_connected': 'Synchronisation cloud : Active et Sécurisée',
  'cloud_disconnected': 'Synchronisation cloud : Hors ligne / Problèmes',
  'audit_chain_healthy': 'Chaîne d\'audit saine',
  'audit_chain_compromised': 'Chaîne d\'audit compromise',

  // ============================================================
  // TEMPS
  // ============================================================
  'today': 'Aujourd\'hui',
  'yesterday': 'Hier',
  'this_week': 'Cette semaine',
  'this_month': 'Ce mois-ci',
  'this_year': 'Cette année',
  'all_time': 'Tout le temps',
  'january': 'Janvier',
  'february': 'Février',
  'march': 'Mars',
  'april': 'Avril',
  'may': 'Mai',
  'june': 'Juin',
  'july': 'Juillet',
  'august': 'Août',
  'september': 'Septembre',
  'october': 'Octobre',
  'november': 'Novembre',
  'december': 'Décembre',
  'monday': 'Lundi',
  'tuesday': 'Mardi',
  'wednesday': 'Mercredi',
  'thursday': 'Jeudi',
  'friday': 'Vendredi',
  'saturday': 'Samedi',
  'sunday': 'Dimanche',

  // ============================================================
  // UNITÉS
  // ============================================================
  'metric_system': 'Système métrique',
  'meter': 'mètre',
  'meter_short': 'm',
  'kilometer': 'kilomètre',
  'kilometer_short': 'km',
  'mile': 'mile',
  'mile_short': 'mi',
  'hour': 'heure',
  'minute': 'minute',
  'second': 'seconde',
  'kmh': 'km/h',
  'mph': 'mph',

  // ============================================================
  // VALIDATION
  // ============================================================
  'field_required': 'Ce champ est obligatoire',
  'powered_by_footer': 'Propulsé par',
  'invalid_email': 'Adresse email invalide',
  'password_too_short': 'Le mot de passe est trop court',
  'password_too_weak': 'Le mot de passe doit contenir au moins une lettre et un chiffre',
  'passwords_do_not_match': 'Les mots de passe ne correspondent pas',
  'invalid_input': 'Entrée invalide',

  // ============================================================
  // PERMISSIONS
  // ============================================================
  'permissions_required': 'Permissions requises',
  'camera_permission': 'Permission caméra',
  'location_permission': 'Permission de localisation',
  'storage_permission': 'Permission de stockage',
  'grant_permission': 'Accorder la permission',
  'deny_permission': 'Refuser la permission',
  'olympus_mont_systems': 'OLYMPUS MONT SYSTEMS',
  'secure_audit_programs': 'SÉCURITÉ / AUDIT / PROGRAMMES',
  'permissions_description': 'ControlMiles a besoin de ces permissions pour suivre vos trajets et enregistrer des preuves de kilométrage précises et défendables.',
  'location_access': 'Accès à la localisation',
  'location_desc': "ControlMiles collecte des données de localisation pour enregistrer vos trajets et calculer votre kilométrage, même lorsque l'application est fermée ou non utilisée.",
  'camera': 'Caméra',
  'camera_desc': 'Utilisée pour capturer le relevé du compteur kilométrique comme preuve pour chaque trajet.',
  'motion_detection': 'Mouvement et activité',
  'motion_desc': 'Utilisé pour détecter quand vous commencez et arrêtez de conduire.',
  'notifications_desc': 'Utilisées pour vous rappeler les trajets actifs et vous envoyer des résumés hebdomadaires de kilométrage.',
  'accept_terms': "Je confirme avoir au moins 18 ans et j'accepte les Conditions d'utilisation et la Politique de confidentialité.",
  'permission_required': 'Permission requise',
  'location_always_needed': 'ControlMiles a besoin de l\'accès à la localisation "Toujours autoriser" pour continuer à suivre votre trajet même quand l\'application n\'est pas ouverte. Activez-le dans les Paramètres.',
  'open_settings': 'Ouvrir les paramètres',

  // ============================================================
  // FONCTIONNALITÉS SPÉCIFIQUES
  // ============================================================
  'evidence': 'Preuve',
  'evidence_photo': 'Photo de preuve',
  'hash_verification': 'Vérification du hash',
  'verified': 'Vérifié',
  'unverified': 'Non vérifié',
  'blockchain_status': 'Statut blockchain',
  'integrity_check': 'Vérification d\'intégrité',
  'anomaly_detection': 'Détection d\'anomalies',
  'fraud_alert': 'Alerte de fraude',
  'suspicious_activity': 'Activité suspecte détectée',

  // ============================================================
  // VÉHICULES
  // ============================================================
  'vehicle': 'Véhicule',
  'vehicles': 'Véhicules',
  'add_vehicle': 'Ajouter un véhicule',
  'active_badge': 'ACTIF',
  'vehicle_make_hint': 'Ex: Toyota, Nissan',
  'specify_make': 'Précisez la marque',
  'specify_model': 'Précisez le modèle',
  'vehicle_model_hint': 'Choisissez un modèle',
  'vehicle_model_other': 'Autre',
  'vehicle_model_pick_make_first': 'Choisissez d’abord la marque',
  'mark_as_active': 'Marquer comme actif',
  'use_as_active_vehicle': 'Utiliser comme véhicule actif',
  'edit_vehicle': 'Modifier le véhicule',
  'delete_vehicle': 'Supprimer le véhicule',
  'vehicle_make': 'Marque',
  'vehicle_model': 'Modèle',
  'vehicle_color': 'Couleur',
  'vehicle_year': 'Année',
  'vehicle_mileage': 'Kilométrage',
  'vehicle_information': 'Informations du véhicule',
  'no_vehicle_registered': 'Aucun véhicule enregistré',

  // ============================================================
  // ABONNEMENT
  // ============================================================
  'subscription': 'Abonnement',
  'plan': 'Plan',
  'basic_plan': 'Plan basique',
  'premium_plan': 'Plan premium',
  'pro_plan': 'Plan pro',
  'upgrade_plan': 'Passer à un plan supérieur',
  'manage_subscription': 'Gérer l\'abonnement',
  'trial_period': 'Période d\'essai',
  'trial_expired': 'Essai expiré',
  'subscription_active': 'Abonnement actif',
  'subscription_required': 'Abonnement requis',
  'premium_plan_description': "Débloquez la Détection Automatique et d'autres fonctionnalités premium. Jusqu'à 5 véhicules. Inclut un essai gratuit de 15 jours.",
  'base_plan_description': "L'expérience ControlMiles de base. 1 véhicule. Inclut un essai gratuit de 15 jours.",
  'current_plan': 'Forfait actuel',
  'started_plan': 'Started (essai gratuit)',
  'started_plan_description': 'Votre essai gratuit de 15 jours. 1 véhicule.',
  'trial_days_left': '{days} jours restants',
  'subscriptions_not_configured': 'Les abonnements ne sont pas encore disponibles.',

  // ============================================================
  // FLOTTE
  // ============================================================




  'automatic_tracking_section': 'Suivi automatique',
  'auto_detect_toggle_title': 'Détection automatique des trajets',
  'auto_detect_toggle_subtitle': 'Détecte quand vous commencez à conduire et vous demande de confirmer le compteur immédiatement.',
  'premium_badge': 'PREMIUM',
  'premium_feature_locked_title': 'Fonctionnalité premium',
  'premium_feature_locked_body': 'La détection automatique des trajets est un module premium. Passez à un forfait supérieur pour l\'activer sur votre compte.',
  'auto_detect_intro_title': 'Détection Automatique',
  'auto_detect_intro_body': 'Lorsque vous ouvrez une application gig prise en charge, ControlMiles commence à suivre votre trajet automatiquement -- pas besoin d\'appuyer sur Démarrer. Vous capturez votre compteur une seule fois, maintenant; chaque trajet détecté ensuite reprend cette même lecture. Vous pouvez désactiver ceci à tout moment.',
  'auto_detect_failed_title': 'La détection automatique n\'a pas pu démarrer',
  'auto_detect_failed_body': 'Le suivi de localisation n\'est pas actif, donc les trajets ne seront pas détectés automatiquement pour l\'instant. Vérifiez que ControlMiles a l\'autorisation de localisation "Toujours autoriser", puis réessayez.',
  'auto_detect_apps_title_on': 'Détection Automatique Activée',
  'auto_detect_apps_title_off': 'Détecter les Applications',
  'auto_detect_apps_subtitle_on': 'La détection d\'applications gig est active',
  'auto_detect_apps_subtitle_off': 'Détecte les applications gig prises en charge pendant que vous conduisez.',
  'shift_apps_picker_link': 'Choisir les apps pour ce quart',
  'shift_apps_picker_title': 'Sélectionner les apps gig',
  'shift_apps_picker_body': 'La détection automatique ne réagira qu\'aux applications sélectionnées. Laissez tout décoché pour surveiller toutes les applications.',
  'shift_apps_picker_clear': 'Effacer',
  'shift_apps_picker_save': 'Enregistrer',
  'background_reliability_section': 'Fiabilité en arrière-plan',
  'battery_optimization_title': 'Optimisation de la batterie',
  'battery_optimization_granted': "Autorisé à s'exécuter en arrière-plan",
  'battery_optimization_missing': 'Peut être suspendu en arrière-plan, appuyez pour corriger',
  'exact_alarm_title': 'Alarmes exactes',
  'exact_alarm_granted': "Les rappels se déclencheront à l'heure",
  'exact_alarm_missing': 'Les rappels peuvent être retardés, appuyez pour corriger',
  'checking_status': 'Vérification...',
  'fix_it': 'Corriger',
  'auto_detect_apps_checking': 'Vérification des applications...',
  'gig_app_detection_title': 'Détection d\'application active',
  'gig_app_detection_subtitle_granted': 'Suggérera l\'application automatiquement quand vous l\'ouvrez',
  'gig_app_detection_subtitle_not_granted': 'Appuyez pour autoriser l\'accès à l\'utilisation et suggérer l\'application automatiquement',
  'carousel_manual_mode': 'Sélection manuelle',
  'auto_detect_status_listening': 'Détection Automatique',
  'auto_detect_status_listening_subtitle': 'En attente de l\'ouverture d\'une application de travail...',
  'auto_detect_status_found_label': 'Détecté :',
  'auto_detect_status_found_subtitle': 'Démarrage automatique de votre trajet...',
  'auto_trip_started_title': 'Trajet démarré automatiquement',
  'auto_trip_started_body': 'Suivi en cours avec',
  'forgotten_trip_notification_title': 'Votre trajet est toujours actif',
  'forgotten_trip_notification_body': 'Avez-vous oublié de le terminer ? Ouvrez ControlMiles pour le mettre en pause ou le terminer.',
  'pause_reminder_notification_title': 'Votre trajet est en pause',
  'pause_reminder_notification_body': 'Il est en pause depuis quelques minutes — ouvrez ControlMiles pour le reprendre ou le terminer.',
  'paused_status_notification_title': 'ControlMiles',
  'paused_status_notification_body': 'Trajet en pause — touchez pour le reprendre ou le terminer.',
  'weekly_summary_notification_title': 'Votre résumé hebdomadaire est prêt',
  'weekly_summary_notification_body': 'Découvrez combien de miles vous avez enregistrés cette semaine.',
  'torch_suggestion': 'Trop sombre ? Touchez pour la lampe torche',
  'ocr_unreadable_manual': 'Illisible — saisissez-le manuellement',
  'ocr_detected': 'Détecté',
  'ocr_scanning': 'Analyse en cours...',
  'ocr_auto_badge': 'Détecté automatiquement',
  'odometer_value': 'Compteur',
  'ocr_confirm_capture': 'Confirmer et capturer',
  'photo_blurry_warning': 'Cette photo semble floue. Reprenez-la pour un enregistrement clair et exploitable.',
  'retake_photo': 'Reprendre',
  'use_photo': 'Utiliser la photo',
  'use_photo_anyway': 'Utiliser quand même',
  'mid_trip_auto_switched_title': 'Changement automatique',
  'mid_trip_auto_switched_body': 'Suivi en cours avec',
  'auto_detect_tracking_with_label': 'Suivi avec :',
  'auto_detect_tracking_subtitle': 'La détection automatique surveille les changements d\'application',
  'auto_detect_tracking_paused_subtitle': 'Trajet en pause',
  'recent_trips_title': 'Trajets récents',
  'see_all_label': 'Tout voir',
  'no_trips_yet': 'Aucun trajet pour l\'instant',


  'waiting_for_gps': 'En attente du GPS…',

  'terms_of_use': "Conditions d'utilisation",
  'licenses_map_data': "Licences et données cartographiques",
  'ready_to_track': "Prêt à suivre",
  'ready_to_track_body': "Choisissez votre activité et démarrez votre trajet.",
  'tracking_paused_label': "Suivi en pause",
  'trip_route': "Itinéraire du trajet",
  'trip_route_fit': "Ajuster l'itinéraire",

  // ============================================================
  // RAPPORTS
  // ============================================================
  'report_generated': 'Rapport généré',
  'generating_report_progress': 'Génération du rapport...',
  'report_download': 'Télécharger le rapport',
  'report_verification': 'Vérification du rapport',
  'report_qr_verification': 'Vérification par QR',
  'report_integrity': 'Intégrité du rapport',

  // ============================================================
  // IMPÔTS / IRS
  // ============================================================
  'tax_deduction': 'Déduction fiscale',
  'irs_rate': 'IRS 2026',
  'estimated_deduction': 'Déduction estimée',
  'tax_summary': 'Résumé fiscal',

  // ============================================================
  // VÉRIFICATION QR
  // ============================================================
  'verification_page': 'Page de vérification',
  'scan_qr': 'Scanner le code QR',
  'verify_report': 'Vérifier le rapport',
  'session_hash': 'Hash de session',
  'section_hash': 'Hash de section',

  // ============================================================
  // FORMULAIRE VÉHICULE
  // ============================================================
  'enter_vehicle_make': 'Entrez la marque du véhicule',
  'enter_vehicle_model': 'Entrez le modèle du véhicule',
  'enter_vehicle_color': 'Entrez la couleur du véhicule',
  'enter_vehicle_year': 'Entrez l\'année du véhicule',
  'enter_vehicle_mileage': 'Entrez le kilométrage du véhicule',

  // ============================================================
  // SUCCÈS ET ALERTES
  // ============================================================
  'vehicle_added_success': 'Véhicule ajouté avec succès',
  'vehicle_deleted_success': 'Véhicule supprimé',
  'vehicle_saved': 'Véhicule enregistré',
  'vehicle_required': 'Véhicule requis',

  // 2026-08-24: filled in missing keys found by lib/tools/i18n_validator.dart
  // (feature drift -- these were added to en/es over time and never synced
  // here). Best-effort translation, not reviewed by a native speaker.
  'add_maintenance_record': 'Ajouter un enregistrement d\'entretien',
  'add_note': 'Ajouter une note',
  'add_vehicle_prompt': 'Aucun véhicule ajouté pour le moment',
  'delete_vehicle_confirmation': 'Êtes-vous sûr de vouloir supprimer ce véhicule ? Son historique de trajets sera conservé.',
  'back_to_login': 'Retour à la connexion',
  'confirm_new_password': 'Confirmer le nouveau mot de passe',
  'cost_optional': 'Coût (facultatif)',
  'current_trip': 'Trajet en cours',
  'danger_zone': 'Zone de danger',
  'delete_account': 'Supprimer le compte',
  'delete_account_confirm_body': 'Cela supprime définitivement votre compte et tout son contenu : véhicules, historique des trajets, relevés kilométriques et rapports. Cette action est irréversible.',
  'delete_account_confirm_title': 'Supprimer définitivement votre compte ?',
  'delete_account_success': 'Compte supprimé',
  'delete_account_type_to_confirm': 'Tapez DELETE pour confirmer',
  'delete_account_word': 'DELETE',
  'trip_sealed_badge': 'Scellé',
  'delete_trip': 'Supprimer le trajet',
  'delete_trip_confirm_body': 'Cela supprimera définitivement le trajet et tous ses kilomètres enregistrés de ControlMiles, y compris son enregistrement d\'audit. Cette action est irréversible et le trajet ne comptera plus dans vos rapports ni dans l\'estimation de déduction IRS.',
  'delete_trip_confirm_title': 'Supprimer définitivement ce trajet ?',
  'delete_trip_success': 'Trajet supprimé',
  'edit_note': 'Modifier la note',
  'end_trip_failed': 'Impossible de terminer le trajet — suivi toujours actif. Réessayez.',
  'purchase_success': "Votre abonnement est actif. Merci !",
  'purchase_pending': "Votre paiement est en attente. L'abonnement s'active dès que Google Play le confirme.",
  'purchase_failed': "L'achat n'a pas pu aboutir. Vous n'avez pas été débité. Réessayez.",
  'play_store_unavailable': "Google Play n'est pas disponible sur cet appareil : impossible d'acheter un abonnement ici.",
  'restore_purchases': "Restaurer les achats",
  'continue_with_google': "Continuer avec Google",
  'or_divider': "ou",
  'login_tagline': "Chaque mile, enregistré.",
  'login_welcome_back': "Bon retour",
  'login_welcome_back_sub': "Connectez-vous pour continuer à enregistrer chaque mile.",
  'login_create_account_title': "Créez votre compte",
  'login_create_account_sub': "Commencez à enregistrer vos miles en quelques minutes.",
  'no_account_prompt': "Nouveau sur ControlMiles ?",
  'have_account_prompt': "Vous avez déjà un compte ?",
  'create_account': "Créer un compte",
  'google_sign_in_failed': "La connexion avec Google a échoué. Réessayez ou utilisez votre e-mail.",
  'remember_my_email': "Se souvenir de mon e-mail",
  'stay_signed_in': "Rester connecté",
  'stay_signed_in_hint': "Laissez activé pour que vos trajets soient enregistrés et détectés en arrière-plan. Désactivez-le sur un téléphone partagé.",
  'odometer_below_registered_error': "Ce relevé est inférieur aux {value} mi déjà enregistrés pour ce véhicule. Vérifiez que le bon véhicule est sélectionné.",
  'trip_discarded_no_miles': "Aucun mile enregistré : ce trajet n'a pas été sauvegardé.",
  'enter_reset_code': 'Entrez le code reçu par email',
  'forgot_password_body': 'Entrez l\'email de votre compte et nous vous enverrons un code pour réinitialiser votre mot de passe.',
  'generate_global_pdf': 'Générer le PDF global',
  'greeting_afternoon': 'Bon après-midi',
  'greeting_evening': 'Bonsoir',
  'greeting_morning': 'Bonjour',
  'irs_estimate_disclaimer': 'Estimation basée sur les taux kilométriques standard IRS 2026 (\$0.725/mile du 1er janvier au 30 juin, \$0.76/mile du 1er juillet au 31 décembre — chaque trajet est calculé au taux en vigueur à sa propre date). ControlMiles n\'est affilié à aucune agence officielle, y compris l\'IRS, et n\'est pas approuvé par celle-ci. Ceci est une estimation informative uniquement, pas une déduction garantie — consultez un professionnel fiscal.',
  'irs_estimate_title': 'À propos de cette estimation',
  'maintenance': 'Entretien',
  'maintenance_record_added_success': 'Enregistrement d\'entretien ajouté',
  'maintenance_record_deleted_success': 'Enregistrement d\'entretien supprimé',
  'maintenance_type': 'Type',
  'maintenance_type_battery': 'Batterie',
  'maintenance_type_brake_service': 'Entretien des freins',
  'maintenance_type_inspection': 'Inspection',
  'maintenance_type_oil_change': 'Vidange d\'huile',
  'maintenance_type_other': 'Autre',
  'maintenance_type_registration': 'Immatriculation',
  'maintenance_type_tire_rotation': 'Permutation des pneus',
  'my_vehicle': 'Mon véhicule',
  'new_password': 'Nouveau mot de passe',
  'next_due_date_optional': 'Prochaine échéance (facultatif)',
  'next_due_odometer_optional': 'Prochain kilométrage prévu (facultatif)',
  'no_maintenance_records': 'Aucun enregistrement d\'entretien',
  'note_saved_success': 'Note enregistrée',
  'notes_optional': 'Notes (facultatif)',
  'odometer_at_service': 'Kilométrage lors de l\'entretien',
  'password_mismatch': 'Les mots de passe ne correspondent pas',
  'pause_failed': 'Impossible de mettre en pause — suivi toujours actif. Réessayez.',
  'resend_code': 'Renvoyer le code',
  'reset_code_hint': 'Code',
  'reset_code_sent': 'Vérifiez votre email pour le code',
  'reset_password_success': 'Mot de passe mis à jour. Vous pouvez vous connecter maintenant.',
  'reset_password_title': 'Réinitialiser votre mot de passe',
  'resume_failed': 'Impossible de reprendre le suivi. Réessayez.',
  'resume_to_switch_app': 'Reprenez le suivi pour changer d\'activité',
  'select_vehicle': 'Sélectionner un véhicule',
  'send_reset_code': 'Envoyer le code',
  'service_date': 'Date d\'entretien',
  'placed_in_service_date_optional': 'Date de mise en service (facultatif)',
  'vin_optional': 'NIV (facultatif)',
  'vin_helper': 'Si vous rajoutez ce véhicule plus tard, l\'odomètre ne pourra jamais être inférieur à celui déjà enregistré par ControlMiles pour ce NIV.',
  'vehicle_odometer_below_floor': 'Ce NIV a déjà un odomètre plus élevé enregistré ({floor} mi). Entrez une valeur égale ou supérieure.',
  'mileage_method_label': 'Méthode de déduction',
  'mileage_method_standard': 'Taux kilométrique standard',
  'mileage_method_actual': 'Dépenses réelles',
  'switch_activity_failed': 'Impossible de changer d\'activité — suivi toujours en cours sur la précédente. Réessayez.',
  'trip_note': 'Note de trajet',
  'trip_note_hint': 'ex. « 5 miles manqués — signal GPS perdu »',
  'vehicle_switch_blocked_active_session': 'Vous ne pouvez pas changer de véhicule actif pendant qu\'un trajet est en cours. Terminez d\'abord le trajet actuel.',
  'verify_code': 'Vérifier le code',
  'year_miles_deduction_estimate': 'Déduction est.',

  // ============================================================
  // FIN DE QUART
  // ============================================================
  'session_already_closed': 'Cette session est déjà clôturée et ne peut plus être modifiée.',
  'session_not_found': 'Erreur critique : session active introuvable.',
  'session_already_finalized': 'Cette session a déjà été finalisée.',
  'duplicate_capture': 'Une capture est déjà enregistrée pour cet événement.',
  'photo_size_out_of_range': 'La photo est hors de la plage autorisée ({min}Ko–{max}Mo). Réessayez.',
  'photo_format_not_supported': 'Format de photo non pris en charge. Formats autorisés : {formats}.',

  // Checkpoint hebdomadaire d'odomètre (2026-09-03)
  'weekly_odometer_close_title': 'Clôture hebdomadaire de l\'odomètre',
  'weekly_odometer_close_body': 'Voulez-vous prendre maintenant la photo de clôture de l\'odomètre de cette semaine ?',
  'weekly_odometer_close_title_mandatory': 'Clôture hebdomadaire obligatoire',
  'weekly_odometer_close_body_mandatory': 'Prenez la photo de clôture de l\'odomètre de cette semaine pour continuer -- impossible à reporter le dimanche.',
  'later': 'Plus tard',
  'take_photo': 'Prendre une photo',
  'odometer_evidence_label': 'Photos d\'odomètre (preuve)',
  'gps_vs_odometer_disclaimer': 'Ces chiffres ne correspondront pas toujours exactement -- les miles personnels (non suivis) ne sont pas comptés par le GPS, une certaine différence est donc normale.',

  // ============================================================
  // VEHICLE PROFILE (écran de détail en lecture seule) + kilométrage entretien
  // ============================================================
  'vehicle_profile_title': 'Profil du véhicule',
  'tracked_miles_gps': 'Miles suivis (GPS)',
  'odometer_checkpoints_title': "Clôtures hebdomadaires de l'odomètre",
  'no_odometer_checkpoints': "Aucune clôture d'odomètre pour l'instant",
  'checkpoint_week_label': 'Semaine du {date}',
  'checkpoint_start': 'Début',
  'checkpoint_end': 'Fin',
  'checkpoint_pending_close': 'Clôture en attente',
  'current_odometer': 'Odomètre actuel',
  'miles_since_service': 'Miles depuis le dernier entretien',
  'no_service_recorded': 'Aucun entretien enregistré',
  'next_service_due_miles': 'Prochain à {miles}',
  'service_overdue_miles': 'En retard de {miles}',
  'service_recommended_interval': 'Recommandé : tous les {miles}',

  // ============================================================
  // Audit des clés manquantes (2026-09-03)
  // ============================================================
  'auth_error': "Erreur d'authentification. Réessayez.",
  'header_miles_period': "Miles dans l'en-tête d'accueil",
  'tour_step': "{n} sur {total}",
  'tour_skip': "Passer",
  'tour_next': "Suivant",
  'tour_done': "Commencer",
  'tour_got_it': "Compris",
  'monitor_home_title': "Accompagnateur",
  'monitor_hello': "Bonjour, {name}",
  'monitor_hint': "Vos circuits scolaires du jour. Quand le chauffeur démarre un circuit, ouvrez-le et tenez la liste des élèves à jour.",
  'monitor_waiting_driver': "En attente du chauffeur",
  'signup_check_email': "Compte créé. Confirmez votre e-mail, puis connectez-vous ici.",
  'signup_confirm_title': "Vérifiez vos e-mails",
  'login_sign_in_title': "Connexion",
  'login_sign_in_sub': "Connectez-vous pour enregistrer chaque mile.",
  'invalid_credentials': 'E-mail ou mot de passe invalide.',
  'email_already_exists': 'Cet e-mail est déjà enregistré.',
  'camera_permission_denied_error': "L'accès à la caméra est nécessaire pour cela.",
  'no_internet_connection_error': 'Aucune connexion internet.',
  'invalid_input_error': 'Vérifiez ce que vous avez saisi.',
  'local_storage_error': "Impossible d'enregistrer localement sur cet appareil.",
  'session_expired_error': 'Votre session a expiré. Reconnectez-vous.',
  'vehicle_limit_reached_error': 'Vous avez atteint la limite de véhicules de votre forfait.',
  'rate_limited_error': 'Trop de tentatives. Réessayez dans quelques minutes.',
  'duplicate_entry_error': 'Ceci existe déjà.',
  'unexpected_error': "Une erreur s'est produite.",
  'end': 'Fin',
  'navigation_error_title': 'Erreur de navigation',
  'route_not_found_message': 'Route {route} introuvable.\nContactez Olympus Mont Systems.',
  'switched_label': 'CHANGÉ',
  'trip_number_label': 'Trajet {number}',
  'trip_end_time_label': 'Fin : {time}',
  'sections_label': 'SECTIONS',
  'vin_label': 'VIN',
  'odometer_cycle_label': 'Cycle de kilométrage',
  'odometer_cycle_weekly': 'Hebdomadaire',
  'odometer_cycle_biweekly': 'Bimensuel',
  'odometer_cycle_monthly': 'Mensuel',
  'odometer_cycle_updated': 'Cycle de kilométrage mis à jour.',
  'system_initializing_redirecting': 'Initialisation du système. Redirection...',
  'error_all_fields_required': 'Tous les champs sont obligatoires.',
  'error_invalid_vehicle_year': 'Année du véhicule invalide.',
  'error_odometer_negative_or_empty': "L'odomètre ne peut pas être négatif ou vide.",
  'error_invalid_maintenance_type': "Type d'entretien invalide.",
  'error_service_date_required': "La date d'entretien est obligatoire.",
  'sections_count_label': '{count} sections',
  'vehicle_make_other': 'Autre',

  'free_trial_expired_title': 'Votre essai gratuit est terminé',
  'free_trial_expired_body': "Votre essai gratuit de 15 jours est terminé. Abonnez-vous à Basic ou Premium pour continuer à suivre vos trajets.",
  'vehicle_limit_reached_title': 'Limite de véhicules atteinte',
  'vehicle_limit_reached_body': 'Votre forfait autorise jusqu\'à {max} véhicule(s). Passez à un forfait supérieur pour en ajouter.',
  'export_limit_reached_title': "Limite d'export atteinte",
  'export_limit_reached_body': "Le forfait Basic inclut 2 exports PDF par mois. Passez à Premium pour des exports illimités.",

  // Lien d'invitation de flotte (clôture Sprint 1, 2026-09-09)

  // Code d'accès au Report Portal, généré dans l'appli (2026-09-09)
  'copy': 'Copier',
  'copied_to_clipboard': 'Copié dans le presse-papiers',
  'generate_report_code_title': "Code d'accès au rapport",
  'generate_report_code_body': "Générez un code à usage unique pour une plage de dates de vos trajets. Votre comptable le saisit sur controlmiles.com/portal/verify pour voir un résumé de kilométrage en lecture seule -- aucune connexion, aucun compte requis de son côté.",
  'generate_report_code_button': 'Générer le code',
  'generate_report_code_your_code': 'Partagez ce code avec votre comptable',
  'generate_report_code_expires_in': 'Expire dans {mmss}',
  'generate_report_code_expired': 'Ce code a expiré.',
  'generate_report_code_disclaimer': "Utilisable jusqu'à 2 fois. Non garanti par cette application -- à des fins de déduction.",
  'report_portal_section': 'Report Portal',
  'report_portal_section_subtitle': 'Générez un code pour votre comptable',

  // 2026-09-16: check 'no volver a mostrar' + toggles por tipo de aviso. Traducciones best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'dont_show_again': 'Ne plus afficher cet avis',
  'notif_type_pause_reminder': 'Rappel de trajet en pause',
  'notif_type_forgotten_trip': 'Rappel de trajet oublié',
  'notif_type_weekly_summary': 'Récapitulatif hebdomadaire des miles',
  'notif_type_gig_app_switch': 'Changement d\'application gig',
  'notif_type_auto_trip_started': 'Trajet démarré automatiquement',
  'notification_types_manage_hint': 'Touchez pour choisir les alertes reçues',
  'notification_types_sheet_title': "Types d'alerte",


  // 2026-09-16: Usage Access en el onboarding de permisos + dialogo al activar auto-detect. Best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'usage_access': 'Accès à l\'utilisation des applis',
  'usage_access_desc': 'Permet à ControlMiles de voir quelle appli gig est ouverte pour démarrer votre trajet automatiquement.',
  'usage_access_onboarding_body': 'La détection automatique des trajets nécessite l\'"accès à l\'utilisation". Android ne l\'accorde que depuis les Paramètres, pas via une demande normale. Vous pouvez passer cette étape et l\'activer plus tard dans les Paramètres.',
  'usage_access_required_title': 'Accès à l\'utilisation requis',
  'usage_access_required_body': 'Sans l\'"accès à l\'utilisation", la détection automatique ne peut pas voir quelle appli gig est ouverte. Accordez-le dans les Paramètres, puis réactivez la détection automatique.',

  // Gig / Fleet split (2026-10-11).
  'active_fleet_trip_error': "Vous avez un trajet d'entreprise en cours dans ControlMiles Fleet. Terminez-le là-bas avant de commencer un trajet personnel.",
  'gig_fleet_app_hint': "Vous conduisez pour la flotte d'une entreprise ? Les trajets d'entreprise se font dans l'app ControlMiles Fleet. Cette app ne garde que vos miles personnels.",
  'get_fleet_app': "Télécharger ControlMiles Fleet",

};