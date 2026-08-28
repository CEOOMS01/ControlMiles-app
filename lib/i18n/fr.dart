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
  'odometer_not_detected': 'Odomètre non détecté',
  'center_odometer_numbers': 'Centrez les chiffres de l\'odomètre',
  'ai_processing': 'Traitement par IA',
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
  'premium_plan_description': 'Débloquez la Détection Automatique et d\'autres fonctionnalités premium.',
  'base_plan_description': 'L\'expérience ControlMiles de base.',
  'current_plan': 'Forfait actuel',
  'subscriptions_not_configured': 'Les abonnements ne sont pas encore disponibles.',

  // ============================================================
  // FLOTTE
  // ============================================================
  'fleet_management': 'Gestion de flotte',
  'fleet_vehicle': 'Véhicule de flotte',
  'fleet_dashboard': 'Tableau de bord flotte',
  'driver_management': 'Gestion des conducteurs',
  'company_account': 'Compte entreprise',

  // Fleet Phase 1: account-type choice + create-fleet screens
  'account_type_title': 'Comment allez-vous utiliser ControlMiles ?',
  'role_chooser_title': 'Qu\'est-ce qui vous amène à ControlMiles ?',
  'role_chooser_subtitle': 'Choisissez ce qui vous correspond. Cela configure votre compte dès le départ.',
  'role_gig_title': 'Chauffeur d\'app gig',
  'role_gig_desc': 'Suivez votre propre kilométrage pour Uber, DoorDash et plus.',
  'role_fleet_driver_title': 'Chauffeur de flotte',
  'role_fleet_driver_desc': 'Votre administrateur de flotte vous a donné un code ? Rejoignez votre équipe.',
  'role_fleet_admin_title': 'Administrateur de flotte',
  'role_fleet_admin_desc': 'Gérez les chauffeurs, véhicules et rapports de votre flotte.',
  'role_chooser_have_account': 'Vous avez déjà un compte ? Connectez-vous',
  'claim_driver_slot_title': 'Rejoignez votre flotte',
  'claim_driver_slot_subtitle': 'Entrez le code partagé par votre administrateur de flotte.',
  'claim_driver_slot_code_label': 'Code d\'accès',
  'claim_driver_slot_button': 'Rejoindre la flotte',
  'claim_driver_slot_skip': 'Je n\'ai pas de code -- continuer en tant que chauffeur indépendant',

  'account_mode_title': 'Mode de compte',
  'account_mode_gig': 'Individuel (Gig)',
  'account_mode_fleet_admin': 'Administrateur de flotte',
  'account_mode_fleet_driver': 'Chauffeur de flotte',

  'dvir_required_before_start': 'Terminez l\'inspection avant trajet du jour avant de démarrer.',

  'organization_section_title': 'Organisation',
  'org_rename_hint': 'Touchez pour renommer',
  'org_rename_title': 'Renommer l\'organisation',
  'org_name_label': 'Nom de l\'organisation',
  'org_renamed_success': 'Organisation renommée',
  'org_delete_button': 'Supprimer l\'organisation',
  'org_delete_confirm_title': 'Supprimer cette organisation ?',
  'org_delete_confirm_body': 'Cela supprime définitivement l\'organisation, ses véhicules, son effectif, ses itinéraires, ses inspections et ses registres d\'entretien. Les chauffeurs conservent leur propre historique de trajets, mais perdent leur affectation de flotte. Cette action est irréversible.',
  'org_delete_type_to_confirm': 'Tapez le nom de l\'organisation pour confirmer',
  'org_deleted_success': 'Organisation supprimée',

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
  'weekly_summary_notification_title': 'Votre résumé hebdomadaire est prêt',
  'weekly_summary_notification_body': 'Découvrez combien de miles vous avez enregistrés cette semaine.',
  'torch_suggestion': 'Trop sombre ? Touchez pour la lampe torche',
  'ocr_unreadable_manual': 'Illisible — saisissez-le manuellement',
  'ocr_detected': 'Détecté',
  'ocr_scanning': 'Analyse en cours...',
  'ocr_auto_badge': 'Détecté automatiquement',
  'odometer_value': 'Compteur',
  'ocr_confirm_capture': 'Confirmer et capturer',
  'mid_trip_auto_switched_title': 'Changement automatique',
  'mid_trip_auto_switched_body': 'Suivi en cours avec',
  'auto_detect_tracking_with_label': 'Suivi avec :',
  'auto_detect_tracking_subtitle': 'La détection automatique surveille les changements d\'application',
  'auto_detect_tracking_paused_subtitle': 'Trajet en pause',
  'recent_trips_title': 'Trajets récents',
  'see_all_label': 'Tout voir',
  'no_trips_yet': 'Aucun trajet pour l\'instant',

  'account_type_subtitle': 'Ce choix détermine le fonctionnement de votre compte. Sélectionnez l\'option qui vous correspond.',
  'account_type_gig_title': 'ControlMiles Individuel',
  'account_type_gig_desc': 'Suivez vos propres kilomètres pour des applications comme Uber, Lyft ou DoorDash.',
  'account_type_fleet_desc': 'Créez une flotte d\'entreprise et gérez plusieurs chauffeurs et véhicules.',
  'create_fleet_title': 'Configurez votre flotte',
  'create_fleet_subtitle': 'Donnez un nom à votre entreprise ou flotte. Vous en serez le propriétaire.',
  'fleet_name_label': 'Nom de la flotte ou de l\'entreprise',
  'create_fleet_button': 'Créer la flotte',
  'fleet_stat_members': 'Membres',
  'fleet_stat_month_miles': 'Miles ce mois-ci',
  'fleet_invite_title': 'Vous avez été invité à rejoindre une flotte',
  'fleet_invite_role_driver': 'Vous rejoindrez en tant que chauffeur',
  'fleet_invite_accept': 'Accepter',
  'fleet_invite_decline': 'Refuser',
  'fleet_no_vehicle_assigned': 'Aucun véhicule assigné pour le moment',
  'fleet_invite_dialog_title': 'Inviter un chauffeur',
  'fleet_invite_send': 'Envoyer l\'invitation',
  'fleet_assign_vehicle_title': 'Assigner un véhicule',
  'fleet_vehicle_already_assigned': 'Déjà assigné à un autre chauffeur',
  'fleet_invite_driver': 'Inviter un chauffeur',
  'fleet_invite_pending': 'EN ATTENTE',

  // Fleet Phase 4 -- inspections avant/après trajet, style DVIR
  'inspection_start': 'Inspecter le véhicule',
  'inspection_pre_trip': 'Avant le trajet',
  'inspection_post_trip': 'Après le trajet',
  'inspection_category_tires_wheels': 'Pneus et roues',
  'inspection_category_brakes': 'Freins',
  'inspection_category_lights_signals': 'Feux et clignotants',
  'inspection_category_mirrors': 'Rétroviseurs',
  'inspection_category_windshield_wipers': 'Pare-brise et essuie-glaces',
  'inspection_category_horn': 'Klaxon',
  'inspection_category_steering': 'Direction',
  'inspection_category_fluid_leaks': 'Fuites de liquide',
  'inspection_category_seatbelts': 'Ceintures de sécurité',
  'inspection_category_body_damage': 'Dommages à la carrosserie',
  'inspection_category_other': 'Autre',
  'inspection_status_ok': 'OK',
  'inspection_status_defect': 'Défaut',
  'inspection_defect_note_hint': 'Décrivez le problème',
  'inspection_defect_note_required': 'Ajoutez une note pour chaque défaut avant d\'envoyer.',
  'inspection_photo_optional': 'Ajouter une photo',
  'inspection_photo_added': 'Photo ajoutée',
  'inspection_odometer_optional': 'Odomètre (facultatif)',
  'inspection_submit': 'Envoyer l\'inspection',
  'inspection_result_pass': 'Inspection réussie -- aucun défaut trouvé',
  'inspection_result_fail': 'Inspection envoyée -- défauts signalés à votre gestionnaire de flotte',

  'driver_ops_title': 'Trajet du jour',
  'driver_ops_checklist_required': 'Complétez la liste de contrôle avant de démarrer',
  'driver_ops_live_location': 'Position en direct',
  'waiting_for_gps': 'En attente du GPS…',
  'report_incident_button': 'Signaler un incident',
  'report_incident_title': 'Signaler un incident',
  'report_incident_category_label': 'Que s\'est-il passé ?',
  'incident_category_breakdown': 'Panne du véhicule',
  'incident_category_accident': 'Accident',
  'incident_category_delay': 'Retard',
  'incident_category_other': 'Autre',
  'report_incident_description_label': 'Décrivez ce qui s\'est passé',
  'report_incident_description_hint': 'ex. Pneu crevé sur l\'I-95, arrêté en sécurité',
  'report_incident_submit': 'Envoyer le signalement',
  'report_incident_success': 'Incident signalé à votre administrateur de flotte',

  // Fleet Phase 5 -- carte en direct / géorepérage
  'fleet_live_map_title': 'Carte en direct',
  'fleet_live_map_no_vehicles': 'Aucun véhicule ne signale de position en direct pour le moment',
  'fleet_live_map_tap_to_place': 'Touchez la carte pour placer le centre de la géozone',
  'fleet_live_map_add_geofence': 'Ajouter une géozone',
  'fleet_live_map_new_geofence': 'Nouvelle géozone',
  'fleet_live_map_geofence_name': 'Nom de la zone',
  'fleet_live_map_geofence_radius': 'Rayon',
  'fleet_live_map_create': 'Créer',
  'fleet_live_map_alerts_title': 'Alertes de géozone',
  'fleet_live_map_no_alerts': 'Aucune alerte',

  // Fleet Phase 6 -- kilométrage IFTA par État (pièce 1 : miles seulement,
  // pas une déclaration IFTA déposable -- voir ifta_service.dart)
  'ifta_state_mileage_title': 'Kilométrage par État',
  'ifta_pick_range': 'Choisir la période',
  'ifta_all_vehicles': 'Tous les véhicules',
  'ifta_total_miles': 'Total des miles',
  'ifta_no_org': 'Aucune organisation trouvée pour ce compte.',
  'ifta_no_mileage': 'Aucun kilométrage enregistré pour cette période',
  'ifta_disclaimer': 'Miles par État, calculés à partir du tracé GPS. Ce n\'est pas une déclaration IFTA déposable -- le calcul réel de la taxe nécessite les gallons de carburant par juridiction, non suivis dans cette application.',

  // ============================================================
  // RAPPORTS
  // ============================================================
  'report_generated': 'Rapport généré',
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
  'switch_activity_failed': 'Impossible de changer d\'activité — suivi toujours en cours sur la précédente. Réessayez.',
  'trip_note': 'Note de trajet',
  'trip_note_hint': 'ex. « 5 miles manqués — signal GPS perdu »',
  'vehicle_switch_blocked_active_session': 'Vous ne pouvez pas changer de véhicule actif pendant qu\'un trajet est en cours. Terminez d\'abord le trajet actuel.',
  'verify_code': 'Vérifier le code',
  'year_miles_deduction_estimate': 'Déduction est.',
};