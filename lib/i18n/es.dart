// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/es.dart - Español (ESP)

const Map<String, String> esTexts = {
  // ============================================================
  // APLICACIÓN GENERAL
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': 'Pantalla de inicio',
  'not_found': 'No encontrado',
  'error': 'Error',
  'system_error': 'Error del sistema',
  'loading': 'Cargando...',
  'please_wait': 'Por favor espera...',

  // ============================================================
  // AUTENTICACIÓN
  // ============================================================
  'login': 'Iniciar sesión',
  'register': 'Registrarse',
  'signup': 'Crear cuenta',
  'logout': 'Cerrar sesión',
  'forgot_password': '¿Olvidaste tu contraseña?',
  'reset_password': 'Restablecer contraseña',
  'auth_session_expired': 'Sesión de autenticación expirada',
  'email': 'Correo electrónico',
  'password': 'Contraseña',
  'confirm_password': 'Confirmar contraseña',
  'sign_in': 'Iniciar sesión',
  'sign_up': 'Crear cuenta',
  'sign_out': 'Cerrar sesión',
  'active_activity': 'Actividad activa',
  'configuration_updated': 'Configuración actualizada',
  // BUG FIX (pedido explícito, bug silencioso carrusel+pausa): tocar otra
  // gig app mientras el viaje está en pausa no cambiaba nada en el
  // backend (switchSection solo se llama con tracking corriendo), pero la
  // UI igual mostraba "SWITCHED" -- mentira visual. Ahora se bloquea el
  // tap y se explica por qué.
  'resume_to_switch_app': 'Reanuda el seguimiento para cambiar de actividad',
  'switch_activity_failed': 'No se pudo cambiar de actividad — sigues en la anterior. Intenta de nuevo.',

  // ============================================================
  // PERFIL DE USUARIO
  // ============================================================
  'name': 'Nombre',
  'edit_name': 'Editar nombre',
  'last_name': 'Apellido',
  'adress': 'Dirección',
  'number': 'Número',
  'dark_mode': 'Modo Oscuro',
  'dark_mode_description': 'Cambiar entre tema claro y oscuro',
  'profile_updated_success': 'Perfil actualizado correctamente',

  // ============================================================
  // NAVEGACIÓN
  // ============================================================
  'dashboard': 'Inicio',
  'home': 'Inicio',
  'profile': 'Perfil',
  'settings': 'Ajustes',
  'help': 'Ayuda',
  'about': 'Acerca de',
  'support': 'Soporte',

  // ============================================================
  // TRACKING (SEGUIMIENTO)
  // ============================================================
  'tracking': 'Seguimiento',
  'tracking_active': 'Seguimiento activo',
  'tracking_paused': 'En pausa',
  'tracking_stopped': 'Seguimiento detenido',
  'start_tracking': 'INICIAR SEGUIMIENTO',
  'stop_tracking': 'DETENER SEGUIMIENTO',
  'pause_tracking': 'Pausar seguimiento',
  'resume_tracking': 'Reanudar seguimiento',
  'trip_details': 'Detalles del viaje',
  'trip_history': 'Historial de viajes',
  'trip_ended': 'Viaje finalizado',
  'miles': 'Millas',
  'kilometers': 'Kilómetros',
  'speed': 'Velocidad',
  'duration': 'Duración',
  'distance': 'Distancia',
  // BUG FIX (pedido explícito): saludo dinámico del AppBar del Dashboard,
  // reemplaza el badge "IRS 2026 · X¢/mi". Sin el "!" ni el nombre --
  // dashboard_screen.dart arma "$greeting! $firstName".
  'greeting_morning': 'Buenos días',
  'greeting_afternoon': 'Buenas tardes',
  'greeting_evening': 'Buenas noches',
  'start_time': 'Hora de inicio',
  'end_time': 'Hora de fin',
  'select_an_activity_before_starting_tracking': 'Selecciona una actividad antes de iniciar el seguimiento',
  // BUG FIX (pedido explícito, alerta de hallazgos relacionados): pause/
  // resume/stop ahora devuelven bool -- estos mensajes se muestran solo
  // cuando de verdad fallan, en vez de asumir éxito y animar la UI igual.
  'pause_failed': 'No se pudo pausar — sigue en seguimiento. Intenta de nuevo.',
  'resume_failed': 'No se pudo reanudar el seguimiento. Intenta de nuevo.',
  'end_trip_failed': 'No se pudo terminar el viaje — sigue activo. Intenta de nuevo.',

  // ============================================================
  // ODOMETER (ODÓMETRO)
  // ============================================================
  'odometer': 'Odómetro',
  'odometer_capture': 'Captura de odómetro',
  'start_odometer_capture': 'Capturar odómetro inicial',
  'end_odometer_capture': 'Capturar odómetro final',
  'capture_photo': 'Capturar foto',
  'retry_camera': 'Reintentar cámara',
  'camera_error': 'Error en la cámara',
  'odometer_not_detected': 'Odómetro no detectado',
  'center_odometer_numbers': 'Centra los números del odómetro',
  'ai_processing': 'Procesando con IA',
  'validating_mileage_gps_hash': 'Validando millas, GPS y hash',

  // ============================================================
  // GPS / UBICACIÓN
  // ============================================================
  'gps': 'GPS',
  'gps_enabled': 'GPS activado',
  'gps_disabled': 'GPS desactivado',
  'location_permission_required': 'Se requiere permiso de ubicación',
  'location_permission_denied': 'Permiso de ubicación denegado',

  // ============================================================
  // HISTORIAL Y REPORTES
  // ============================================================
  'history': 'Historial',
  'reports': 'Reportes',
  'audit_logs': 'Registros de auditoría',
  'statistics': 'Estadísticas',
  'summary': 'Resumen',
  'total_miles': 'Total de millas',
  'last_30_days': 'Últimos 30 días',
  'last_12_months': 'Últimos 12 meses',
  'total_trips': 'Total de viajes',
  'average_speed': 'Velocidad promedio',
  'RECENT_TRIPS': 'VIAJES RECIENTES',
  'SEE_ALL': 'VER TODO',
  'not_trips_yet': 'Aún no hay viajes',
  'generate_pdf': 'Generar PDF',
  'generate_global_pdf': 'Generar PDF Global',
  'trip_note': 'Nota del viaje',
  'trip_note_hint': 'ej. "faltaron 5 millas — se perdió señal GPS"',
  'add_note': 'Agregar nota',
  'edit_note': 'Editar nota',
  'note_saved_success': 'Nota guardada',
  'delete_trip': 'Eliminar viaje',
  'delete_trip_confirm_title': '¿Eliminar este viaje de forma permanente?',
  'delete_trip_confirm_body': 'Esto eliminará el viaje y todas sus millas registradas de ControlMiles de forma permanente, incluyendo su registro de auditoría. No se puede deshacer y el viaje dejará de contar en tus reportes y en el estimado de deducción del IRS.',
  'delete_trip_success': 'Viaje eliminado',
  'send_reset_code': 'Enviar código',
  'reset_code_sent': 'Revisa tu email, te enviamos un código',
  'enter_reset_code': 'Ingresa el código que recibiste por email',
  'reset_code_hint': 'Código',
  'verify_code': 'Verificar código',
  'resend_code': 'Reenviar código',
  'new_password': 'Nueva contraseña',
  'confirm_new_password': 'Confirmar nueva contraseña',
  'password_mismatch': 'Las contraseñas no coinciden',
  'reset_password_title': 'Restablece tu contraseña',
  'forgot_password_body': 'Ingresa el email de tu cuenta y te enviaremos un código para restablecer tu contraseña.',
  'reset_password_success': 'Contraseña actualizada. Ya puedes iniciar sesión.',
  'back_to_login': 'Volver a iniciar sesión',
  'danger_zone': 'Zona de peligro',
  'delete_account': 'Eliminar cuenta',
  'delete_account_confirm_title': '¿Eliminar tu cuenta de forma permanente?',
  'delete_account_confirm_body': 'Esto elimina tu cuenta y todo lo que contiene: vehículos, historial de viajes, registros de millas y reportes, de forma permanente. No se puede deshacer.',
  'delete_account_type_to_confirm': 'Escribe DELETE para confirmar',
  'delete_account_word': 'DELETE',
  'delete_account_success': 'Cuenta eliminada',
  // BUG FIX (pedido explícito): badge de millas del Dashboard reemplaza al
  // de "Cloud Sync" (roto — ver CloudStatusService). El disclaimer vive
  // detrás de un tap, nunca en el badge en sí.
  'year_miles_deduction_estimate': 'Deducción est.',
  'irs_estimate_title': 'Sobre este estimado',
  'irs_estimate_disclaimer': 'Estimado según la tarifa estándar de millaje del IRS 2026 (\$0.725/milla). ControlMiles no está afiliado ni respaldado por el IRS ni ninguna entidad oficial. Es solo una referencia informativa, no una deducción garantizada — consulta a un profesional de impuestos.',

  // ============================================================
  // TRIP PURPOSES & IRS
  // ============================================================
  'select_trip_purpose': 'Seleccione el propósito del viaje',
  'irs_deduction_note': 'Para fines de deducción -- no garantizado por esta app',
  'business_purpose': 'Negocios',
  'work_commute': 'Trayecto al trabajo',
  'medical': 'Médico',
  'moving': 'Mudanza',
  'charitable': 'Caridad / Voluntariado',
  'education_study': 'Educación / Estudio',
  'personal_other': 'Personal / Otros',

  // ============================================================
  // AJUSTES
  // ============================================================
  'preferences': 'Preferencias',
  'language': 'Idioma',
  'language_description': 'Selecciona tu idioma preferido',
  'language_changed': 'Idioma cambiado a',
  'notifications': 'Notificaciones',
  'notifications_description': 'Recibir notificaciones de la app',
  'notifications_enabled': 'Notificaciones activadas',
  'notifications_disabled': 'Notificaciones desactivadas',
  'analytics': 'Analíticas',
  'analytics_description': 'Compartir datos de uso',

  // ============================================================
  // PRIVACIDAD Y SEGURIDAD
  // ============================================================
  'privacy_security': 'Privacidad y Seguridad',
  'privacy_policy': 'Política de privacidad',
  'terms_conditions': 'Términos y Condiciones',
  'data_security': 'Seguridad de datos',
  'security_audit': 'Auditoría de seguridad',

  // ============================================================
  // ACERCA DE
  // ============================================================
  'about_app': 'Acerca de la aplicación',
  'app_version': 'Versión de la app',
  'build_number': 'Número de compilación',
  'company': 'Empresa',
  'copyright': 'Todos los derechos reservados',
  'developer': 'Desarrollador',

  // ============================================================
  // BOTONES
  // ============================================================
  'ok': 'OK',
  'cancel': 'Cancelar',
  'save': 'Guardar',
  'delete': 'Eliminar',
  'edit': 'Editar',
  'close': 'Cerrar',
  'refresh': 'Actualizar',
  'retry': 'Reintentar',
  'next': 'Siguiente',
  'previous': 'Anterior',
  'done': 'Listo',
  'submit': 'Enviar',
  'continue': 'Continuar',
  'back': 'Atrás',
  'start': 'Iniciar',
  'stop': 'Detener',
  'pause': 'PAUSAR',
  'resume': 'REANUDAR',
  'end_trip': 'FINALIZAR VIAJE',
  'skip': 'Saltar',
  'confirm': 'Confirmar',

  // ============================================================
  // MENSAJES
  // ============================================================
  'success': 'Éxito',
  'failed': 'Falló',
  'warning': 'Advertencia',
  'info': 'Información',
  'no_data': 'Sin datos',
  'no_results': 'No se encontraron resultados',
  'something_went_wrong': 'Algo salió mal',
  'please_try_again': 'Por favor inténtalo de nuevo',
  'network_error': 'Error de red',
  'internet_required': 'Se requiere conexión a internet',
  'offline_mode': 'Modo sin conexión',
  'syncing': 'Sincronizando...',
  'synced': 'Sincronizado',
  'feature_coming_soon': 'Función próximamente',

  // ============================================================
  // ESTADO DE LA NUBE
  // ============================================================
  'cloud_status': 'Estado de la nube',
  'cloud_connected': 'Sincronización en la nube: Activa y Segura',
  'cloud_disconnected': 'Sincronización en la nube: Sin conexión / Problemas',
  'audit_chain_healthy': 'Cadena de auditoría saludable',
  'audit_chain_compromised': 'Cadena de auditoría comprometida',

  // ============================================================
  // TIEMPO
  // ============================================================
  'today': 'Hoy',
  'yesterday': 'Ayer',
  'this_week': 'Esta semana',
  'this_month': 'Este mes',
  'this_year': 'Este año',
  'all_time': 'Todo el tiempo',
  'january': 'Enero',
  'february': 'Febrero',
  'march': 'Marzo',
  'april': 'Abril',
  'may': 'Mayo',
  'june': 'Junio',
  'july': 'Julio',
  'august': 'Agosto',
  'september': 'Septiembre',
  'october': 'Octubre',
  'november': 'Noviembre',
  'december': 'Diciembre',
  'monday': 'Lunes',
  'tuesday': 'Martes',
  'wednesday': 'Miércoles',
  'thursday': 'Jueves',
  'friday': 'Viernes',
  'saturday': 'Sábado',
  'sunday': 'Domingo',

  // ============================================================
  // UNIDADES
  // ============================================================
  'metric_system': 'Sistema Métrico',
  'meter': 'metro',
  'meter_short': 'm',
  'kilometer': 'kilómetro',
  'kilometer_short': 'km',
  'mile': 'milla',
  'mile_short': 'mi',
  'hour': 'hora',
  'minute': 'minuto',
  'second': 'segundo',
  'kmh': 'km/h',
  'mph': 'mph',

  // ============================================================
  // VALIDACIÓN
  // ============================================================
  'field_required': 'Este campo es obligatorio',
  'data_protected_footer': 'Tus datos están protegidos',
  'invalid_email': 'Correo electrónico inválido',
  'password_too_short': 'La contraseña es demasiado corta',
  'passwords_do_not_match': 'Las contraseñas no coinciden',
  'invalid_input': 'Entrada inválida',

  // ============================================================
  // PERMISOS
  // ============================================================
  'permissions_required': 'Se requieren permisos',
  'camera_permission': 'Permiso de cámara',
  'location_permission': 'Permiso de ubicación',
  'storage_permission': 'Permiso de almacenamiento',
  'grant_permission': 'Conceder permiso',
  'deny_permission': 'Denegar permiso',

  // ============================================================
  // CARACTERÍSTICAS ESPECÍFICAS
  // ============================================================
  'evidence': 'Evidencia',
  'evidence_photo': 'Foto de evidencia',
  'hash_verification': 'Verificación de hash',
  'verified': 'Verificado',
  'unverified': 'No verificado',
  'blockchain_status': 'Estado de blockchain',
  'integrity_check': 'Verificación de integridad',
  'anomaly_detection': 'Detección de anomalías',
  'fraud_alert': 'Alerta de fraude',
  'suspicious_activity': 'Actividad sospechosa detectada',

  // ============================================================
  // VEHÍCULOS
  // ============================================================
  'vehicle': 'Vehículo',
  'vehicles': 'Vehículos',
  'add_vehicle': 'Agregar vehículo',
  'add_vehicle_prompt': 'Aún no agregaste un vehículo',
  'current_trip': 'Viaje actual',
  'edit_vehicle': 'Editar vehículo',
  'delete_vehicle': 'Eliminar vehículo',
  'vehicle_make': 'Marca',
  'vehicle_model': 'Modelo',
  'vehicle_color': 'Color',
  'vehicle_year': 'Año',
  'vehicle_mileage': 'Kilometraje',
  'vehicle_information': 'Información del vehículo',
  'no_vehicle_registered': 'No hay vehículo registrado',
  'delete_vehicle_confirmation': '¿Estás seguro de eliminar este vehículo? Su historial de viajes se conservará.',

  // ============================================================
  // VEHÍCULO — pantalla nueva (separada de Settings) + mantenimiento
  // ============================================================
  'my_vehicle': 'Mi Vehículo',
  'maintenance': 'Mantenimiento',
  'select_vehicle': 'Seleccionar vehículo',
  'add_maintenance_record': 'Agregar registro de mantenimiento',
  'maintenance_type': 'Tipo',
  'service_date': 'Fecha de servicio',
  'odometer_at_service': 'Odómetro al momento del servicio',
  'cost_optional': 'Costo (opcional)',
  'next_due_odometer_optional': 'Próximo cambio a las (millas, opcional)',
  'next_due_date_optional': 'Próxima fecha (opcional)',
  'notes_optional': 'Notas (opcional)',
  'no_maintenance_records': 'Todavía no hay registros de mantenimiento',
  'maintenance_record_added_success': 'Registro de mantenimiento agregado',
  'maintenance_record_deleted_success': 'Registro de mantenimiento eliminado',
  'maintenance_type_oil_change': 'Cambio de aceite',
  'maintenance_type_tire_rotation': 'Rotación de llantas',
  'maintenance_type_brake_service': 'Servicio de frenos',
  'maintenance_type_inspection': 'Inspección',
  'maintenance_type_registration': 'Registro/placa',
  'maintenance_type_battery': 'Batería',
  'maintenance_type_other': 'Otro',

  // ============================================================
  // SUSCRIPCIÓN
  // ============================================================
  'subscription': 'Suscripción',
  'plan': 'Plan',
  'basic_plan': 'Plan básico',
  'premium_plan': 'Plan premium',
  'pro_plan': 'Plan pro',
  'upgrade_plan': 'Mejorar plan',
  'manage_subscription': 'Gestionar suscripción',
  'trial_period': 'Período de prueba',
  'trial_expired': 'Prueba expirada',
  'subscription_active': 'Suscripción activa',
  'subscription_required': 'Se requiere suscripción',

  // ============================================================
  // FLOTA
  // ============================================================
  'fleet_management': 'Gestión de flota',
  'fleet_vehicle': 'Vehículo de flota',
  'fleet_dashboard': 'Panel de flota',
  'driver_management': 'Gestión de conductores',
  'company_account': 'Cuenta de empresa',

  // First-launch role chooser (before login/signup, shown once per device)
  // + the driver-slot claim screen it can lead to.
  'role_chooser_title': '¿Qué te trae a ControlMiles?',
  'role_chooser_subtitle': 'Elige lo que te corresponda. Esto configura tu cuenta desde el inicio.',
  'role_gig_title': 'Conductor de apps gig',
  'role_gig_desc': 'Registra tu propio kilometraje para Uber, DoorDash y más.',
  'role_fleet_driver_title': 'Conductor de flota',
  'role_fleet_driver_desc': '¿Tu administrador de flota te dio un código? Únete a tu equipo.',
  'role_fleet_admin_title': 'Administrador de flota',
  'role_fleet_admin_desc': 'Gestiona conductores, vehículos y reportes de tu flota.',
  'role_chooser_have_account': '¿Ya tienes una cuenta? Inicia sesión',
  'claim_driver_slot_title': 'Únete a tu flota',
  'claim_driver_slot_subtitle': 'Ingresa el código que te compartió tu administrador de flota.',
  'claim_driver_slot_code_label': 'Código de acceso',
  'claim_driver_slot_button': 'Unirme a la flota',
  'claim_driver_slot_skip': 'No tengo un código -- continuar como conductor individual',

  // Account mode switcher (Settings)
  'account_mode_title': 'Modo de cuenta',
  'account_mode_gig': 'Individual (Gig)',
  'account_mode_fleet_admin': 'Administrador de flota',
  'account_mode_fleet_driver': 'Conductor de flota',

  'dvir_required_before_start': 'Completa la inspección previa al viaje de hoy antes de comenzar.',

  'organization_section_title': 'Organización',
  'org_rename_hint': 'Toca para renombrar',
  'org_rename_title': 'Renombrar organización',
  'org_name_label': 'Nombre de la organización',
  'org_renamed_success': 'Organización renombrada',
  'org_delete_button': 'Eliminar organización',
  'org_delete_confirm_title': '¿Eliminar esta organización?',
  'org_delete_confirm_body': 'Esto elimina permanentemente la organización, sus vehículos, el roster, las rutas, las inspecciones y los registros de mantenimiento. Los conductores conservan su propio historial de viajes, pero pierden su asignación de flota. Esto no se puede deshacer.',
  'org_delete_type_to_confirm': 'Escribe el nombre de la organización para confirmar',
  'org_deleted_success': 'Organización eliminada',

  'automatic_tracking_section': 'Tracking automático',
  'auto_detect_toggle_title': 'Detección automática de viajes',
  'auto_detect_toggle_subtitle': 'Detecta cuando empiezas a manejar y te pide confirmar el odómetro en ese momento.',
  'premium_badge': 'PREMIUM',
  'premium_feature_locked_title': 'Función premium',
  'premium_feature_locked_body': 'La detección automática de viajes es un complemento premium. Contacta a soporte para habilitarla en tu cuenta.',
  'auto_trip_prompt_title': 'Viaje detectado',
  'auto_trip_prompt_body': 'Detectamos que empezaste a moverte. Elige la app y confirma ahora para registrar el odómetro de este viaje.',
  'auto_trip_prompt_confirm': 'Confirmar y comenzar',
  'auto_trip_prompt_dismiss': 'No es un viaje de trabajo',
  'gig_app_detection_title': 'Detección de app activa',
  'gig_app_detection_subtitle_granted': 'Sugerirá la app automáticamente cuando la abras',
  'gig_app_detection_subtitle_not_granted': 'Toca para otorgar acceso de uso y sugerir la app automáticamente',
  'carousel_manual_mode': 'Selección manual',
  'auto_detect_status_listening': 'Detección Automática',
  'auto_detect_status_listening_subtitle': 'Esperando a que abras una app de trabajo...',
  'auto_detect_status_found_label': 'Detectado:',
  'auto_detect_status_found_subtitle': 'Te pediremos confirmar en cuanto empieces a manejar.',
  'auto_trip_notification_tap_hint': 'Toca para confirmar y registrar el odómetro ahora.',
  'forgotten_trip_notification_title': 'Tu viaje sigue activo',
  'forgotten_trip_notification_body': '¿Olvidaste terminarlo? Revisa ControlMiles para pausar o finalizar.',
  'weekly_summary_notification_title': 'Tu resumen semanal está listo',
  'weekly_summary_notification_body': 'Revisa cuántas millas registraste esta semana en ControlMiles.',
  'torch_suggestion': '¿Muy oscuro? Toca para usar el flash',
  'ocr_unreadable_manual': 'No se pudo leer — ingrésalo a mano',
  'ocr_detected': 'Detectado',
  'ocr_scanning': 'Escaneando...',
  'ocr_auto_badge': 'Detectado automáticamente',
  'odometer_value': 'Odómetro',
  'ocr_confirm_capture': 'Confirmar y capturar',
  'mid_trip_switch_suggested_title': 'Se detectó otra app',
  'mid_trip_switch_suggested_body': 'Abre ControlMiles para cambiar a',
  'mid_trip_auto_switched_title': 'Cambio automático',
  'mid_trip_auto_switched_body': 'Ahora rastreando con',
  'auto_detect_tracking_with_label': 'Rastreando con:',
  'auto_detect_tap_to_switch': 'Toca para cambiar',
  'auto_detect_tracking_subtitle': 'La detección automática está monitoreando cambios de app',
  'auto_detect_tracking_paused_subtitle': 'Viaje en pausa',
  'auto_switch_toggle_title': 'Cambiar de app automáticamente',
  'auto_switch_toggle_subtitle': 'Cambia automáticamente en vez de preguntar primero',
  'recent_trips_title': 'Viajes recientes',
  'see_all_label': 'Ver todos',
  'no_trips_yet': 'Aún no hay viajes',

  // Fleet Phase 1: account-type choice + create-fleet screens
  'account_type_title': '¿Cómo vas a usar ControlMiles?',
  'account_type_subtitle': 'Esta elección decide cómo funciona tu cuenta. Elige la opción que te corresponda.',
  'account_type_gig_title': 'ControlMiles Individual',
  'account_type_gig_desc': 'Registra tus propias millas para apps como Uber, Lyft o DoorDash.',
  'account_type_fleet_desc': 'Crea una flota de empresa y administra varios conductores y vehículos.',
  'create_fleet_title': 'Configura tu flota',
  'create_fleet_subtitle': 'Dale un nombre a tu empresa o flota. Serás su propietario.',
  'fleet_name_label': 'Nombre de la flota o empresa',
  'create_fleet_button': 'Crear flota',
  'fleet_stat_members': 'Miembros',
  'fleet_stat_month_miles': 'Millas este mes',
  'fleet_invite_title': 'Te invitaron a unirte a una flota',
  'fleet_invite_role_driver': 'Te unirás como conductor',
  'fleet_invite_accept': 'Aceptar',
  'fleet_invite_decline': 'Rechazar',
  'fleet_no_vehicle_assigned': 'Aún no tienes vehículo asignado',
  'fleet_invite_dialog_title': 'Invitar a un conductor',
  'fleet_invite_send': 'Enviar invitación',
  'fleet_assign_vehicle_title': 'Asignar vehículo',
  'fleet_vehicle_already_assigned': 'Ya asignado a otro conductor',
  'fleet_invite_driver': 'Invitar conductor',
  'fleet_invite_pending': 'PENDIENTE',

  // Fleet Fase 4 -- inspecciones pre/post-viaje estilo DVIR
  'inspection_start': 'Inspeccionar vehículo',
  'inspection_pre_trip': 'Antes del viaje',
  'inspection_post_trip': 'Después del viaje',
  'inspection_category_tires_wheels': 'Llantas y ruedas',
  'inspection_category_brakes': 'Frenos',
  'inspection_category_lights_signals': 'Luces y direccionales',
  'inspection_category_mirrors': 'Espejos',
  'inspection_category_windshield_wipers': 'Parabrisas y limpiaparabrisas',
  'inspection_category_horn': 'Bocina',
  'inspection_category_steering': 'Dirección',
  'inspection_category_fluid_leaks': 'Fugas de fluidos',
  'inspection_category_seatbelts': 'Cinturones de seguridad',
  'inspection_category_body_damage': 'Daños en la carrocería',
  'inspection_category_other': 'Otro',
  'inspection_status_ok': 'OK',
  'inspection_status_defect': 'Defecto',
  'inspection_defect_note_hint': 'Describe el problema',
  'inspection_defect_note_required': 'Agrega una nota para cada defecto antes de enviar.',
  'inspection_photo_optional': 'Agregar foto',
  'inspection_photo_added': 'Foto agregada',
  'inspection_odometer_optional': 'Odómetro (opcional)',
  'inspection_submit': 'Enviar inspección',
  'inspection_result_pass': 'Inspección aprobada -- sin defectos encontrados',
  'inspection_result_fail': 'Inspección enviada -- defectos reportados a tu gerente de flotilla',

  'driver_ops_title': 'Viaje de hoy',
  'driver_ops_checklist_required': 'Completa el checklist antes de arrancar',
  'driver_ops_live_location': 'Ubicación en vivo',
  'waiting_for_gps': 'Esperando señal GPS…',
  'report_incident_button': 'Reportar imprevisto',
  'report_incident_title': 'Reportar un imprevisto',
  'report_incident_category_label': '¿Qué pasó?',
  'incident_category_breakdown': 'Avería del vehículo',
  'incident_category_accident': 'Accidente',
  'incident_category_delay': 'Retraso',
  'incident_category_other': 'Otro',
  'report_incident_description_label': 'Describe lo que pasó',
  'report_incident_description_hint': 'ej. Llanta ponchada en la I-95, me orillé con seguridad',
  'report_incident_submit': 'Enviar reporte',
  'report_incident_success': 'Imprevisto reportado a tu administrador de flota',

  // Fleet Fase 5 -- mapa en vivo / geocercas
  'fleet_live_map_title': 'Mapa en vivo',
  'fleet_live_map_no_vehicles': 'Ningún vehículo está reportando posición en vivo todavía',
  'fleet_live_map_tap_to_place': 'Toca el mapa para colocar el centro de la geocerca',
  'fleet_live_map_add_geofence': 'Agregar geocerca',
  'fleet_live_map_new_geofence': 'Nueva geocerca',
  'fleet_live_map_geofence_name': 'Nombre de la zona',
  'fleet_live_map_geofence_radius': 'Radio',
  'fleet_live_map_create': 'Crear',
  'fleet_live_map_alerts_title': 'Alertas de geocerca',
  'fleet_live_map_no_alerts': 'Sin alertas',

  // Fleet Fase 6 -- millas por estado IFTA (pieza 1: solo millas, no es un
  // reporte IFTA presentable -- ver comentario en ifta_service.dart)
  'ifta_state_mileage_title': 'Millas por estado',
  'ifta_pick_range': 'Elegir rango de fechas',
  'ifta_all_vehicles': 'Todos los vehículos',
  'ifta_total_miles': 'Millas totales',
  'ifta_no_org': 'No se encontró organización para esta cuenta.',
  'ifta_no_mileage': 'No hay millas registradas en este rango',
  'ifta_disclaimer': 'Millas por estado, calculadas a partir del rastro GPS. Esto no es un reporte IFTA presentable -- el cálculo real del impuesto necesita galones de combustible por jurisdicción, algo que esta app no rastrea.',

  // ============================================================
  // REPORTES
  // ============================================================
  'report_generated': 'Reporte generado',
  'report_download': 'Descargar reporte',
  'report_verification': 'Verificación de reporte',
  'report_qr_verification': 'Verificación por QR',
  'report_integrity': 'Integridad del reporte',

  // ============================================================
  // IMPUESTOS / IRS
  // ============================================================
  'tax_deduction': 'Deducciones fiscales',
  'irs_rate': 'IRS 2026',
  'estimated_deduction': 'Deducción estimada',
  'tax_summary': 'Resumen fiscal',

  // ============================================================
  // VERIFICACIÓN QR
  // ============================================================
  'verification_page': 'Página de verificación',
  'scan_qr': 'Escanear código QR',
  'verify_report': 'Verificar reporte',
  'session_hash': 'Hash de sesión',
  'section_hash': 'Hash de sección',

  // ============================================================
  // FORMULARIO DE VEHÍCULO
  // ============================================================
  'enter_vehicle_make': 'Ingresa la marca del vehículo',
  'enter_vehicle_model': 'Ingresa el modelo del vehículo',
  'enter_vehicle_color': 'Ingresa el color del vehículo',
  'enter_vehicle_year': 'Ingresa el año del vehículo',
  'enter_vehicle_mileage': 'Ingresa el kilometraje del vehículo',

  // ============================================================
  // ÉXITOS Y ALERTAS
  // ============================================================
  'vehicle_added_success': 'Vehículo agregado correctamente',
  'vehicle_deleted_success': 'Vehículo eliminado',
  // BUG FIX (pedido explícito, nueva regla multi-auto): mensaje limpio
  // para cuando la DB rechaza un cambio de vehículo activo porque hay un
  // viaje sin cerrar (ver trigger tr_vehicles_block_switch_during_session).
  'vehicle_switch_blocked_active_session': 'No puedes cambiar de vehículo activo mientras tienes un viaje en curso. Termina el viaje actual primero.',
  'vehicle_saved': 'Vehículo guardado',
  'vehicle_required': 'Se requiere un vehículo',
};
