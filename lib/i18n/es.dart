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
  'id_label': 'ID',
  'loading': 'Cargando...',
  'please_wait': 'Por favor espera...',

  // ============================================================
  // AUTENTICACIÓN
  // ============================================================
  'login': 'Iniciar sesión',
  'register': 'Registrarse',
  'signup': 'Crear cuenta',
  'logout': 'Cerrar sesión',
  'logout_confirmation': '¿Estás seguro de que quieres cerrar sesión?',
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
  'camera_error_body': 'No pudimos acceder a tu cámara. Revisa el permiso de cámara en Ajustes y vuelve a intentarlo.',
  'odometer_not_detected': 'Odómetro no detectado',
  'center_odometer_numbers': 'Centra los números del odómetro',
  'ai_processing': 'Procesando foto',
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
  'trip_sealed_badge': 'Sellado',
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
  'irs_estimate_disclaimer': 'Estimado según las tarifas estándar de millaje del IRS 2026 (\$0.725/milla del 1 de enero al 30 de junio, \$0.76/milla del 1 de julio al 31 de diciembre — cada viaje se calcula con la tarifa vigente en su propia fecha). ControlMiles no está afiliado ni respaldado por el IRS ni ninguna entidad oficial. Es solo una referencia informativa, no una deducción garantizada — consulta a un profesional de impuestos.',

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
  'send_feedback': 'Enviar sugerencias',
  'send_feedback_no_mail_app': 'No se encontró una app de correo. Escribí a contact@controlmiles.com.',
  'send_feedback_email_subject': 'Sugerencias para ControlMiles',
  'trademark_disclaimer_short': 'ControlMiles es una aplicación independiente y no está afiliada, respaldada ni patrocinada por Uber, Lyft, DoorDash, Instacart, Amazon, Walmart, Shipt ni ninguna otra plataforma mencionada en esta aplicación. Todas las marcas pertenecen a sus respectivos dueños.',
  'age_terms_checkbox_prefix': 'Confirmo que tengo al menos 18 años y acepto los',
  'age_terms_checkbox_and': 'y la',
  'age_terms_required_error': 'Confirma que tienes 18 años o más y acepta los Términos para continuar.',
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
  'powered_by_footer': 'Desarrollado por',
  'invalid_email': 'Correo electrónico inválido',
  'password_too_short': 'La contraseña es demasiado corta',
  'password_too_weak': 'La contraseña debe incluir al menos una letra y un número',
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
  'olympus_mont_systems': 'OLYMPUS MONT SYSTEMS',
  'secure_audit_programs': 'SEGURO / AUDITORÍA / PROGRAMAS',
  'permissions_description': 'ControlMiles necesita estos permisos para rastrear tus viajes y registrar evidencia de millaje precisa y defendible.',
  'location_access': 'Acceso a ubicación',
  'location_desc': 'Se usa para rastrear tus viajes y calcular el millaje automáticamente, incluso con la app en segundo plano.',
  'camera': 'Cámara',
  'camera_desc': 'Se usa para capturar la lectura del odómetro como evidencia de cada viaje.',
  'motion_detection': 'Movimiento y actividad',
  'motion_desc': 'Se usa para detectar cuándo empiezas y dejas de manejar.',
  'notifications_desc': 'Se usa para recordarte viajes activos y enviarte resúmenes semanales de millaje.',
  'accept_terms': 'He leído y acepto los Términos de Servicio y la Política de Privacidad.',
  'permission_required': 'Permiso requerido',
  'location_always_needed': 'ControlMiles necesita el acceso a ubicación "Permitir todo el tiempo" para seguir rastreando tu viaje incluso cuando la app no está abierta. Actívalo en Ajustes.',
  'open_settings': 'Abrir Ajustes',

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
  'active_badge': 'ACTIVO',
  'vehicle_make_hint': 'Ej: Toyota, Nissan',
  'specify_make': 'Especifica la marca',
  'mark_as_active': 'Marcar como activo',
  'use_as_active_vehicle': 'Usar como vehículo activo',
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
  'placed_in_service_date_optional': 'Fecha de puesta en servicio (opcional)',
  'vin_optional': 'VIN (opcional)',
  'vin_helper': 'Si vuelves a agregar este vehículo más adelante, el odómetro nunca podrá ser menor al que ControlMiles ya registró para este VIN.',
  'vehicle_odometer_below_floor': 'Este VIN ya tiene un odómetro más alto registrado ({floor} mi). Ingresa un valor igual o mayor.',
  'mileage_method_label': 'Método de deducción',
  'mileage_method_standard': 'Tarifa estándar de millaje',
  'mileage_method_actual': 'Gastos reales',
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
  'premium_plan_description': 'Desbloquea la Detección Automática y otras funciones premium. Hasta 5 vehículos.',
  'base_plan_description': 'La experiencia principal de ControlMiles. 1 vehículo.',
  'current_plan': 'Plan actual',
  'started_plan': 'Started (prueba gratis)',
  'started_plan_description': 'Tu prueba gratuita de 30 días. 1 vehículo.',
  'trial_days_left': '{days} días restantes',
  'subscriptions_not_configured': 'Las suscripciones aún no están disponibles.',

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
  'premium_feature_locked_body': 'La detección automática de viajes es un complemento premium. Mejora tu plan para habilitarla en tu cuenta.',
  'auto_detect_intro_title': 'Detección Automática',
  'auto_detect_intro_body': 'Cuando abras una app gig compatible, ControlMiles empezará a rastrear tu viaje automáticamente -- sin tocar Start. Vas a capturar tu odómetro una sola vez, ahora mismo; cada viaje detectado después lleva esa misma lectura. Puedes desactivar esto cuando quieras.',
  'auto_detect_failed_title': 'La detección automática no pudo iniciarse',
  'auto_detect_failed_body': 'El rastreo de ubicación no está activo, así que los viajes no se detectarán automáticamente por ahora. Verifica que ControlMiles tenga permiso de ubicación "Permitir todo el tiempo" y vuelve a intentarlo.',
  'auto_detect_apps_title_on': 'Detección Automática Activa',
  'auto_detect_apps_title_off': 'Detectar Apps Automáticamente',
  'auto_detect_apps_subtitle_on': 'La detección de apps gig está activa',
  'auto_detect_apps_subtitle_off': 'Detecta apps gig compatibles mientras manejas.',
  'auto_detect_apps_checking': 'Revisando apps...',
  'gig_app_detection_title': 'Detección de app activa',
  'gig_app_detection_subtitle_granted': 'Sugerirá la app automáticamente cuando la abras',
  'gig_app_detection_subtitle_not_granted': 'Toca para otorgar acceso de uso y sugerir la app automáticamente',
  'carousel_manual_mode': 'Selección manual',
  'auto_detect_status_listening': 'Detección Automática',
  'auto_detect_status_listening_subtitle': 'Esperando a que abras una app de trabajo...',
  'auto_detect_status_found_label': 'Detectado:',
  'auto_detect_status_found_subtitle': 'Iniciando tu viaje automáticamente...',
  'auto_trip_started_title': 'Viaje iniciado automáticamente',
  'auto_trip_started_body': 'Ahora rastreando con',
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
  'mid_trip_auto_switched_title': 'Cambio automático',
  'mid_trip_auto_switched_body': 'Ahora rastreando con',
  'auto_detect_tracking_with_label': 'Rastreando con:',
  'auto_detect_tracking_subtitle': 'La detección automática está monitoreando cambios de app',
  'auto_detect_tracking_paused_subtitle': 'Viaje en pausa',
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
  'generating_report_progress': 'Generando reporte...',
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

  // ============================================================
  // FIN DE TURNO
  // ============================================================
  'end_shift': 'FIN DE TURNO',
  'end_shift_tooltip': 'Toca para cerrar tu turno de trabajo',
  'end_shift_failed': 'No se pudo cerrar el turno — aún en seguimiento. Intenta de nuevo.',
  'session_already_closed': 'Esta sesión ya está cerrada y no admite más cambios.',
  'session_not_found': 'Error crítico: no se encontró la sesión activa.',
  'session_already_finalized': 'Esta sesión ya fue finalizada anteriormente.',
  'duplicate_capture': 'Ya existe una captura registrada para este evento.',
  'photo_size_out_of_range': 'La foto está fuera del rango permitido ({min}KB–{max}MB). Intenta de nuevo.',
  'photo_format_not_supported': 'Formato de foto no soportado. Formatos permitidos: {formats}.',

  // Checkpoint semanal de odómetro (2026-09-03)
  'weekly_odometer_close_title': 'Cierre semanal de odómetro',
  'weekly_odometer_close_body': '¿Quieres tomar ahora la foto de cierre del odómetro de esta semana?',
  'weekly_odometer_close_title_mandatory': 'Cierre semanal obligatorio',
  'weekly_odometer_close_body_mandatory': 'Toma la foto de cierre del odómetro de esta semana para continuar -- los domingos no se puede posponer.',
  'later': 'Más tarde',
  'take_photo': 'Tomar foto',
  'odometer_evidence_label': 'Fotos de odómetro (evidencia)',
  'gps_vs_odometer_disclaimer': 'Estos números no siempre coincidirán exactamente -- las millas personales (sin trackear) no las cuenta el GPS, así que cierta diferencia es normal.',

  // ============================================================
  // VEHICLE PROFILE (pantalla de detalle, solo lectura) + millas en mantenimiento
  // ============================================================
  'vehicle_profile_title': 'Perfil del vehículo',
  'tracked_miles_gps': 'Millas registradas (GPS)',
  'odometer_checkpoints_title': 'Cierres semanales de odómetro',
  'no_odometer_checkpoints': 'Aún no hay cierres de odómetro',
  'checkpoint_week_label': 'Semana del {date}',
  'checkpoint_start': 'Inicio',
  'checkpoint_end': 'Cierre',
  'checkpoint_pending_close': 'Pendiente de cierre',
  'current_odometer': 'Odómetro actual',
  'miles_since_service': 'Millas desde el último servicio',
  'no_service_recorded': 'Aún no hay servicios registrados',
  'next_service_due_miles': 'Próximo a las {miles}',
  'service_overdue_miles': 'Vencido por {miles}',
  'service_recommended_interval': 'Recomendado: cada {miles}',

  // ============================================================
  // Auditoría de claves faltantes (2026-09-03): claves ya referenciadas
  // con .tr() en el código pero nunca agregadas a ningún diccionario --
  // tr() mostraba en pantalla la clave cruda en silencio.
  // ============================================================
  'auth_error': 'Error de autenticación. Intenta de nuevo.',
  'invalid_credentials': 'Correo o contraseña inválidos.',
  'email_already_exists': 'Este correo ya está registrado.',
  'camera_permission_denied_error': 'Se necesita acceso a la cámara para esto.',
  'no_internet_connection_error': 'Sin conexión a internet.',
  'invalid_input_error': 'Revisá lo que ingresaste.',
  'local_storage_error': 'No se pudo guardar localmente en este dispositivo.',
  'session_expired_error': 'Tu sesión expiró. Iniciá sesión de nuevo.',
  'vehicle_limit_reached_error': 'Alcanzaste el límite de vehículos de tu plan.',
  'rate_limited_error': 'Demasiados intentos. Probá de nuevo en unos minutos.',
  'duplicate_entry_error': 'Esto ya existe.',
  'unexpected_error': 'Algo salió mal.',
  'end': 'Fin',
  'navigation_error_title': 'Error de Navegación',
  'route_not_found_message': 'Ruta {route} no encontrada.\nContacta a Olympus Mont Systems.',
  'switched_label': 'CAMBIADO',
  'trip_number_label': 'Viaje {number}',
  'trip_end_time_label': 'Fin: {time}',
  'sections_label': 'SECCIONES',
  'vin_label': 'VIN',
  'system_initializing_redirecting': 'Inicializando el sistema. Redirigiendo...',
  'error_all_fields_required': 'Todos los campos son obligatorios.',
  'error_invalid_vehicle_year': 'Año de vehículo inválido.',
  'error_odometer_negative_or_empty': 'El odómetro no puede ser negativo o estar vacío.',
  'error_invalid_maintenance_type': 'Tipo de mantenimiento inválido.',
  'error_service_date_required': 'La fecha de servicio es obligatoria.',
  'sections_count_label': '{count} secciones',
  'vehicle_make_other': 'Otra',
  'email_not_linked_to_controlmiles': 'Ese correo no está vinculado a ninguna cuenta de ControlMiles.',

  'free_trial_expired_title': 'Tu prueba gratis terminó',
  'free_trial_expired_body': 'Tus 30 días de prueba gratis se acabaron. Suscribite a Basic o Premium para seguir registrando viajes.',
  'vehicle_limit_reached_title': 'Límite de vehículos alcanzado',
  'vehicle_limit_reached_body': 'Tu plan permite hasta {max} vehículo(s). Mejorá tu plan para agregar más.',
  'export_limit_reached_title': 'Límite de exportación alcanzado',
  'export_limit_reached_body': 'El plan Basic incluye 2 exportaciones de PDF por mes. Mejorá a Premium para exportar sin límite.',

  // Enlace de invitación de flota (cierre Sprint 1, 2026-09-09)
  'invite_landing_title': '{org} te invitó a unirte',
  'invite_confirm_body': '{org} te ha invitado a unirte a su flota. ¿Aceptar?',
  'invite_login_prompt': 'Ingresa tu contraseña para aceptar esta invitación.',
  'invite_signup_prompt': 'Crea tu cuenta para unirte a esta flota.',
  'invite_accept_button': 'Aceptar invitación',
  'invite_invalid_title': 'Invitación inválida o expirada',
  'invite_invalid_body': 'Este enlace de invitación ya no es válido. Pídele al administrador de la flota que envíe uno nuevo.',
  'invite_confirm_email_first': 'Revisa tu correo para confirmar tu cuenta, luego abre este enlace de invitación de nuevo.',

  // Selector de contexto dual (Fleet Sprint 2, 2026-09-09)
  'org_mode_personal': 'Personal',
  'org_mode_company': 'Empresa: {org}',

  // Pantalla de bloqueo de turno finalizado (Fleet Sprint 3, 2026-09-09)
  'shift_ended_title': 'Turno finalizado',
  'shift_ended_body': 'No tienes acceso a la app hasta que empiece tu próximo turno.',
  'shift_ended_start_next': 'Iniciar próximo turno',

  // Revocación (Fleet Sprint 3, 2026-09-09)
  'org_access_revoked_title': 'Acceso a la flota removido',
  'org_access_revoked_body': 'El administrador de tu flota removió tu acceso a esta organización. Cierra sesión para continuar.',

  // Asignación de vehículo abierta/rotativa (Fleet Sprint 4, 2026-09-09)
  'fleet_select_vehicle_button': 'Seleccionar vehículo',
  'fleet_vehicle_picker_title': 'Elige un vehículo',
  'fleet_vehicle_picker_empty': 'No hay vehículos disponibles ahora mismo -- todos los vehículos de la flota están en uso.',

  // Código de acceso al Report Portal, generado desde la app (pedido
  // explícito, 2026-09-09) -- se movió aquí porque antes solo existía en
  // la web, y un chofer gig nunca debería necesitar iniciar sesión en
  // controlmiles.com.
  'copy': 'Copiar',
  'copied_to_clipboard': 'Copiado al portapapeles',
  'generate_report_code_title': 'Código de acceso al reporte',
  'generate_report_code_body': 'Genera un código de un solo uso para un rango de fechas de tus viajes. Tu contador lo ingresa en controlmiles.com/portal/verify para ver un resumen de millas de solo lectura -- sin login ni cuenta de su parte.',
  'generate_report_code_button': 'Generar código',
  'generate_report_code_your_code': 'Comparte este código con tu contador',
  'generate_report_code_expires_in': 'Expira en {mmss}',
  'generate_report_code_expired': 'Este código ya expiró.',
  'generate_report_code_disclaimer': 'Usable hasta 2 veces. No garantizado por esta app -- para fines de deducción.',
  'report_portal_section': 'Report Portal',
  'report_portal_section_subtitle': 'Genera un código para tu contador',
};
