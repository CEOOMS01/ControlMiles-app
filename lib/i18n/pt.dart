// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/pt.dart - Português

const Map<String, String> ptTexts = {
  // ============================================================
  // APLICAÇÃO GERAL
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': 'Tela de inicialização',
  'not_found': 'Não encontrado',
  'error': 'Erro',
  'system_error': 'Erro do sistema',
  'id_label': 'ID',
  'loading': 'Carregando...',
  'please_wait': 'Por favor, aguarde...',

  // ============================================================
  // AUTENTICAÇÃO
  // ============================================================
  'login': 'Entrar',
  'register': 'Cadastrar',
  'signup': 'Criar conta',
  'logout': 'Sair',
  'logout_confirmation': 'Tem certeza de que deseja sair?',
  'forgot_password': 'Esqueceu a senha?',
  'reset_password': 'Redefinir senha',
  'auth_session_expired': 'Sessão de autenticação expirada',
  'email': 'Email',
  'password': 'Senha',
  'confirm_password': 'Confirmar senha',
  'sign_in': 'Entrar',
  'sign_up': 'Criar conta',
  'sign_out': 'Sair',
  'active_activity': 'Atividade ativa',
  'configuration_updated': 'Configuração atualizada',

  // ============================================================
  // PERFIL DO USUÁRIO
  // ============================================================
  'name': 'Nome',
  'edit_name': 'Editar nome',
  'last_name': 'Sobrenome',
  'adress': 'Endereço',
  'number': 'Número',
  'dark_mode': 'Modo Escuro',
  'dark_mode_description': 'Alternar entre os temas claro e escuro',
  'profile_updated_success': 'Perfil atualizado com sucesso',

  // ============================================================
  // NAVEGAÇÃO
  // ============================================================
  'dashboard': 'Início',
  'home': 'Início',
  'profile': 'Perfil',
  'settings': 'Configurações',
  'help': 'Ajuda',
  'about': 'Sobre',
  'support': 'Suporte',

  // ============================================================
  // TRACKING (Rastreamento)
  // ============================================================
  'tracking': 'Rastreamento',
  'tracking_active': 'Rastreamento ativo',
  'tracking_paused': 'Pausado',
  'tracking_stopped': 'Rastreamento parado',
  'start_tracking': 'INICIAR RASTREAMENTO',
  'stop_tracking': 'PARAR RASTREAMENTO',
  'pause_tracking': 'Pausar rastreamento',
  'resume_tracking': 'Retomar rastreamento',
  'trip_details': 'Detalhes da viagem',
  'trip_history': 'Histórico de viagens',
  'trip_ended': 'Viagem finalizada',
  'miles': 'Milhas',
  'kilometers': 'Quilômetros',
  'speed': 'Velocidade',
  'duration': 'Duração',
  'distance': 'Distância',
  'start_time': 'Hora de início',
  'end_time': 'Hora de término',
  'select_an_activity_before_starting_tracking': 'Selecione uma atividade antes de iniciar o rastreamento',

  // ============================================================
  // ODOMETER (Odômetro)
  // ============================================================
  'odometer': 'Odômetro',
  'odometer_capture': 'Captura de odômetro',
  'start_odometer_capture': 'Capturar odômetro inicial',
  'end_odometer_capture': 'Capturar odômetro final',
  'capture_photo': 'Tirar foto',
  'retry_camera': 'Tentar câmera novamente',
  'camera_error': 'Erro na câmera',
  'odometer_not_detected': 'Odômetro não detectado',
  'center_odometer_numbers': 'Centralize os números do odômetro',
  'ai_processing': 'Processando com IA',
  'validating_mileage_gps_hash': 'Validando milhagem, GPS e hash',

  // ============================================================
  // GPS / LOCALIZAÇÃO
  // ============================================================
  'gps': 'GPS',
  'gps_enabled': 'GPS ativado',
  'gps_disabled': 'GPS desativado',
  'location_permission_required': 'Permissão de localização necessária',
  'location_permission_denied': 'Permissão de localização negada',

  // ============================================================
  // HISTÓRICO E RELATÓRIOS
  // ============================================================
  'history': 'Histórico',
  'reports': 'Relatórios',
  'audit_logs': 'Logs de auditoria',
  'statistics': 'Estatísticas',
  'summary': 'Resumo',
  'total_miles': 'Total de milhas',
  'last_30_days': 'Últimos 30 dias',
  'last_12_months': 'Últimos 12 meses',
  'total_trips': 'Total de viagens',
  'average_speed': 'Velocidade média',
  'RECENT_TRIPS': 'VIAGENS RECENTES',
  'SEE_ALL': 'VER TODAS',
  'not_trips_yet': 'Nenhuma viagem ainda',
  'generate_pdf': 'Gerar PDF',

  // ============================================================
  // TRIP PURPOSES & IRS
  // ============================================================
  'select_trip_purpose': 'Selecione o objetivo da viagem',
  'irs_deduction_note': 'Para fins de dedução -- não garantido por este app',
  'business_purpose': 'Negócios',
  'work_commute': 'Deslocamento de trabalho',
  'medical': 'Médico',
  'moving': 'Mudança',
  'charitable': 'Caridade / Voluntariado',
  'education_study': 'Educação / Estudo',
  'personal_other': 'Pessoal / Outro',

  // ============================================================
  // CONFIGURAÇÕES
  // ============================================================
  'preferences': 'Preferências',
  'language': 'Idioma',
  'language_description': 'Selecione seu idioma preferido',
  'language_changed': 'Idioma alterado para',
  'notifications': 'Notificações',
  'notifications_description': 'Receber notificações do app',
  'notifications_enabled': 'Notificações ativadas',
  'notifications_disabled': 'Notificações desativadas',
  'analytics': 'Análises',
  'analytics_description': 'Compartilhar dados de uso',

  // ============================================================
  // PRIVACIDADE E SEGURANÇA
  // ============================================================
  'privacy_security': 'Privacidade e Segurança',
  'privacy_policy': 'Política de privacidade',
  'terms_conditions': 'Termos e Condições',
  'trademark_disclaimer_short': 'O ControlMiles é um aplicativo independente e não é afiliado, endossado ou patrocinado por Uber, Lyft, DoorDash, Instacart, Amazon, Walmart, Shipt ou qualquer outra plataforma mencionada neste aplicativo. Todas as marcas pertencem aos seus respectivos proprietários.',
  'age_terms_checkbox_prefix': 'Confirmo que tenho pelo menos 18 anos e concordo com os',
  'age_terms_checkbox_and': 'e a',
  'age_terms_required_error': 'Confirme que você tem 18 anos ou mais e concorde com os Termos para continuar.',
  'data_security': 'Segurança de dados',
  'security_audit': 'Auditoria de segurança',

  // ============================================================
  // SOBRE
  // ============================================================
  'about_app': 'Sobre o aplicativo',
  'app_version': 'Versão do app',
  'build_number': 'Número da build',
  'company': 'Empresa',
  'copyright': 'Todos os direitos reservados',
  'developer': 'Desenvolvedor',

  // ============================================================
  // BOTÕES
  // ============================================================
  'ok': 'OK',
  'cancel': 'Cancelar',
  'save': 'Salvar',
  'delete': 'Excluir',
  'edit': 'Editar',
  'close': 'Fechar',
  'refresh': 'Atualizar',
  'retry': 'Tentar novamente',
  'next': 'Próximo',
  'previous': 'Anterior',
  'done': 'Concluído',
  'submit': 'Enviar',
  'continue': 'Continuar',
  'back': 'Voltar',
  'start': 'Iniciar',
  'stop': 'Parar',
  'pause': 'PAUSAR',
  'resume': 'RETOMAR',
  'end_trip': 'FINALIZAR VIAGEM',
  'skip': 'Pular',
  'confirm': 'Confirmar',

  // ============================================================
  // MENSAGENS
  // ============================================================
  'success': 'Sucesso',
  'failed': 'Falhou',
  'warning': 'Aviso',
  'info': 'Informação',
  'no_data': 'Sem dados',
  'no_results': 'Nenhum resultado encontrado',
  'something_went_wrong': 'Algo deu errado',
  'please_try_again': 'Por favor, tente novamente',
  'network_error': 'Erro de rede',
  'internet_required': 'Conexão com a internet necessária',
  'offline_mode': 'Modo offline',
  'syncing': 'Sincronizando...',
  'synced': 'Sincronizado',
  'feature_coming_soon': 'Recurso em breve',

  // ============================================================
  // STATUS DA NUVEM
  // ============================================================
  'cloud_status': 'Status da nuvem',
  'cloud_connected': 'Sincronização na nuvem: Ativa e Segura',
  'cloud_disconnected': 'Sincronização na nuvem: Offline / Problemas',
  'audit_chain_healthy': 'Cadeia de auditoria saudável',
  'audit_chain_compromised': 'Cadeia de auditoria comprometida',

  // ============================================================
  // TEMPO
  // ============================================================
  'today': 'Hoje',
  'yesterday': 'Ontem',
  'this_week': 'Esta semana',
  'this_month': 'Este mês',
  'this_year': 'Este ano',
  'all_time': 'Todo o tempo',
  'january': 'Janeiro',
  'february': 'Fevereiro',
  'march': 'Março',
  'april': 'Abril',
  'may': 'Maio',
  'june': 'Junho',
  'july': 'Julho',
  'august': 'Agosto',
  'september': 'Setembro',
  'october': 'Outubro',
  'november': 'Novembro',
  'december': 'Dezembro',

  // ============================================================
  // UNIDADES
  // ============================================================
  'metric_system': 'Sistema Métrico',
  'meter': 'metro',
  'meter_short': 'm',
  'kilometer': 'quilômetro',
  'kilometer_short': 'km',
  'mile': 'milha',
  'mile_short': 'mi',
  'hour': 'hora',
  'minute': 'minuto',
  'second': 'segundo',
  'kmh': 'km/h',
  'mph': 'mph',

  // ============================================================
  // VALIDAÇÃO
  // ============================================================
  'field_required': 'Este campo é obrigatório',
  'powered_by_footer': 'Desenvolvido por',
  'invalid_email': 'Endereço de email inválido',
  'password_too_short': 'A senha é muito curta',
  'passwords_do_not_match': 'As senhas não coincidem',
  'invalid_input': 'Entrada inválida',

  // ============================================================
  // PERMISSÕES
  // ============================================================
  'permissions_required': 'Permissões necessárias',
  'camera_permission': 'Permissão de câmera',
  'location_permission': 'Permissão de localização',
  'storage_permission': 'Permissão de armazenamento',
  'grant_permission': 'Conceder permissão',
  'deny_permission': 'Negar permissão',
  'olympus_mont_systems': 'OLYMPUS MONT SYSTEMS',
  'secure_audit_programs': 'SEGURANÇA / AUDITORIA / PROGRAMAS',
  'permissions_description': 'O ControlMiles precisa dessas permissões para rastrear suas viagens e registrar evidências de quilometragem precisas e defensáveis.',
  'location_access': 'Acesso à localização',
  'location_desc': 'Usado para rastrear suas viagens e calcular a quilometragem automaticamente, mesmo com o app em segundo plano.',
  'camera': 'Câmera',
  'camera_desc': 'Usada para capturar a leitura do odômetro como evidência de cada viagem.',
  'motion_detection': 'Movimento e atividade',
  'motion_desc': 'Usado para detectar quando você começa e para de dirigir.',
  'notifications_desc': 'Usadas para lembrar você de viagens ativas e enviar resumos semanais de quilometragem.',
  'accept_terms': 'Li e aceito os Termos de Serviço e a Política de Privacidade.',
  'permission_required': 'Permissão necessária',
  'location_always_needed': 'O ControlMiles precisa do acesso à localização "Permitir o tempo todo" para continuar rastreando sua viagem mesmo quando o app não está aberto. Ative isso nas Configurações.',
  'open_settings': 'Abrir Configurações',

  // ============================================================
  // RECURSOS ESPECÍFICOS
  // ============================================================
  'evidence': 'Evidência',
  'evidence_photo': 'Foto de evidência',
  'hash_verification': 'Verificação de hash',
  'verified': 'Verificado',
  'unverified': 'Não verificado',
  'blockchain_status': 'Status da blockchain',
  'integrity_check': 'Verificação de integridade',
  'anomaly_detection': 'Detecção de anomalia',
  'fraud_alert': 'Alerta de fraude',
  'suspicious_activity': 'Atividade suspeita detectada',

  // ============================================================
  // VEÍCULOS
  // ============================================================
  'vehicle': 'Veículo',
  'vehicles': 'Veículos',
  'add_vehicle': 'Adicionar veículo',
  'active_badge': 'ATIVO',
  'vehicle_make_hint': 'Ex: Toyota, Nissan',
  'specify_make': 'Especifique a marca',
  'mark_as_active': 'Marcar como ativo',
  'use_as_active_vehicle': 'Usar como veículo ativo',
  'edit_vehicle': 'Editar veículo',
  'delete_vehicle': 'Excluir veículo',
  'vehicle_make': 'Marca',
  'vehicle_model': 'Modelo',
  'vehicle_color': 'Cor',
  'vehicle_year': 'Ano',
  'vehicle_mileage': 'Quilometragem',
  'vehicle_information': 'Informações do veículo',
  'no_vehicle_registered': 'Nenhum veículo cadastrado',

  // ============================================================
  // ASSINATURA
  // ============================================================
  'subscription': 'Assinatura',
  'plan': 'Plano',
  'basic_plan': 'Plano básico',
  'premium_plan': 'Plano premium',
  'pro_plan': 'Plano pro',
  'upgrade_plan': 'Fazer upgrade',
  'manage_subscription': 'Gerenciar assinatura',
  'trial_period': 'Período de teste',
  'trial_expired': 'Teste expirado',
  'subscription_active': 'Assinatura ativa',
  'subscription_required': 'Assinatura necessária',
  'premium_plan_description': 'Desbloqueie a Detecção Automática e outros recursos premium.',
  'base_plan_description': 'A experiência principal do ControlMiles.',
  'current_plan': 'Plano atual',
  'subscriptions_not_configured': 'As assinaturas ainda não estão disponíveis.',

  // ============================================================
  // FROTA
  // ============================================================
  'fleet_management': 'Gestão de frota',
  'fleet_vehicle': 'Veículo da frota',
  'fleet_dashboard': 'Painel da frota',
  'driver_management': 'Gestão de motoristas',
  'company_account': 'Conta da empresa',

  // First-launch role chooser (before login/signup, shown once per device)
  // + the driver-slot claim screen it can lead to.
  'role_chooser_title': 'O que te traz ao ControlMiles?',
  'role_chooser_subtitle': 'Escolha o que combina com você. Isso configura sua conta desde o início.',
  'role_gig_title': 'Motorista de app gig',
  'role_gig_desc': 'Registre sua própria quilometragem para Uber, DoorDash e mais.',
  'role_fleet_driver_title': 'Motorista de frota',
  'role_fleet_driver_desc': 'Seu administrador de frota te deu um código? Junte-se à sua equipe.',
  'role_fleet_admin_title': 'Administrador de frota',
  'role_fleet_admin_desc': 'Gerencie motoristas, veículos e relatórios da sua frota.',
  'role_chooser_have_account': 'Já tem uma conta? Entrar',
  'claim_driver_slot_title': 'Junte-se à sua frota',
  'claim_driver_slot_subtitle': 'Digite o código que seu administrador de frota compartilhou.',
  'claim_driver_slot_code_label': 'Código de acesso',
  'claim_driver_slot_button': 'Entrar na frota',
  'claim_driver_slot_skip': 'Não tenho um código -- continuar como motorista individual',

  // Account mode switcher (Settings)
  'account_mode_title': 'Modo de conta',
  'account_mode_gig': 'Individual (Gig)',
  'account_mode_fleet_admin': 'Administrador de frota',
  'account_mode_fleet_driver': 'Motorista de frota',

  'dvir_required_before_start': 'Conclua a inspeção pré-viagem de hoje antes de iniciar.',

  'organization_section_title': 'Organização',
  'org_rename_hint': 'Toque para renomear',
  'org_rename_title': 'Renomear organização',
  'org_name_label': 'Nome da organização',
  'org_renamed_success': 'Organização renomeada',
  'org_delete_button': 'Excluir organização',
  'org_delete_confirm_title': 'Excluir esta organização?',
  'org_delete_confirm_body': 'Isso exclui permanentemente a organização, seus veículos, equipe, rotas, inspeções e registros de manutenção. Os motoristas mantêm seu próprio histórico de viagens, mas perdem sua atribuição de frota. Isso não pode ser desfeito.',
  'org_delete_type_to_confirm': 'Digite o nome da organização para confirmar',
  'org_deleted_success': 'Organização excluída',

  'automatic_tracking_section': 'Rastreamento automático',
  'auto_detect_toggle_title': 'Detecção automática de viagens',
  'auto_detect_toggle_subtitle': 'Detecta quando você começa a dirigir e pede para confirmar o odômetro na hora.',
  'premium_badge': 'PREMIUM',
  'premium_feature_locked_title': 'Recurso premium',
  'premium_feature_locked_body': 'A detecção automática de viagens é um complemento premium. Faça upgrade para ativá-la na sua conta.',
  'auto_detect_intro_title': 'Detecção Automática',
  'auto_detect_intro_body': 'Quando você abrir um app gig compatível, o ControlMiles vai começar a rastrear sua viagem automaticamente -- sem precisar tocar em Start. Você vai capturar seu odômetro uma única vez, agora; cada viagem detectada depois disso usa essa mesma leitura. Você pode desativar isso quando quiser.',
  'auto_detect_failed_title': 'A detecção automática não pôde ser iniciada',
  'auto_detect_failed_body': 'O rastreamento de localização não está ativo, então as viagens não serão detectadas automaticamente por enquanto. Verifique se o ControlMiles tem a permissão de localização "Permitir o tempo todo" e tente novamente.',
  'auto_detect_apps_title_on': 'Detecção Automática Ativa',
  'auto_detect_apps_title_off': 'Detectar Apps Automaticamente',
  'auto_detect_apps_subtitle_on': 'A detecção de apps gig está ativa',
  'auto_detect_apps_subtitle_off': 'Detecta apps gig compatíveis enquanto você dirige.',
  'auto_detect_apps_checking': 'Verificando apps...',
  'gig_app_detection_title': 'Detecção de app ativo',
  'gig_app_detection_subtitle_granted': 'Sugerirá o app automaticamente quando você o abrir',
  'gig_app_detection_subtitle_not_granted': 'Toque para conceder acesso de uso e sugerir o app automaticamente',
  'carousel_manual_mode': 'Seleção manual',
  'auto_detect_status_listening': 'Detecção Automática',
  'auto_detect_status_listening_subtitle': 'Aguardando você abrir um app de trabalho...',
  'auto_detect_status_found_label': 'Detectado:',
  'auto_detect_status_found_subtitle': 'Iniciando sua viagem automaticamente...',
  'auto_trip_started_title': 'Viagem iniciada automaticamente',
  'auto_trip_started_body': 'Rastreando agora com',
  'forgotten_trip_notification_title': 'Sua viagem ainda está ativa',
  'forgotten_trip_notification_body': 'Esqueceu de finalizá-la? Abra o ControlMiles para pausar ou finalizar.',
  'weekly_summary_notification_title': 'Seu resumo semanal está pronto',
  'weekly_summary_notification_body': 'Veja quantas milhas você registrou esta semana.',
  'torch_suggestion': 'Muito escuro? Toque para a lanterna',
  'ocr_unreadable_manual': 'Não deu para ler — digite manualmente',
  'ocr_detected': 'Detectado',
  'ocr_scanning': 'Escaneando...',
  'ocr_auto_badge': 'Detectado automaticamente',
  'odometer_value': 'Odômetro',
  'ocr_confirm_capture': 'Confirmar e capturar',
  'mid_trip_auto_switched_title': 'Alternado automaticamente',
  'mid_trip_auto_switched_body': 'Agora rastreando com',
  'auto_detect_tracking_with_label': 'Rastreando com:',
  'auto_detect_tracking_subtitle': 'A detecção automática está monitorando mudanças de app',
  'auto_detect_tracking_paused_subtitle': 'Viagem pausada',
  'recent_trips_title': 'Viagens recentes',
  'see_all_label': 'Ver todas',
  'no_trips_yet': 'Nenhuma viagem ainda',

  // Fleet Phase 1: account-type choice + create-fleet screens
  'account_type_title': 'Como você vai usar o ControlMiles?',
  'account_type_subtitle': 'Essa escolha define como sua conta funciona. Selecione a opção que combina com você.',
  'account_type_gig_title': 'ControlMiles Individual',
  'account_type_gig_desc': 'Registre suas próprias milhas para apps como Uber, Lyft ou DoorDash.',
  'account_type_fleet_desc': 'Crie uma frota de empresa e gerencie vários motoristas e veículos.',
  'create_fleet_title': 'Configure sua frota',
  'create_fleet_subtitle': 'Dê um nome à sua empresa ou frota. Você será o proprietário.',
  'fleet_name_label': 'Nome da frota ou empresa',
  'create_fleet_button': 'Criar frota',
  'fleet_stat_members': 'Membros',
  'fleet_stat_month_miles': 'Milhas neste mês',
  'fleet_invite_title': 'Você foi convidado para uma frota',
  'fleet_invite_role_driver': 'Você entrará como motorista',
  'fleet_invite_accept': 'Aceitar',
  'fleet_invite_decline': 'Recusar',
  'fleet_no_vehicle_assigned': 'Nenhum veículo atribuído ainda',
  'fleet_invite_dialog_title': 'Convidar motorista',
  'fleet_invite_send': 'Enviar convite',
  'fleet_assign_vehicle_title': 'Atribuir veículo',
  'fleet_vehicle_already_assigned': 'Já atribuído a outro motorista',
  'fleet_invite_driver': 'Convidar motorista',
  'fleet_invite_pending': 'PENDENTE',

  // Fleet Fase 4 -- inspeções pré/pós-viagem estilo DVIR
  'inspection_start': 'Inspecionar veículo',
  'inspection_pre_trip': 'Antes da viagem',
  'inspection_post_trip': 'Depois da viagem',
  'inspection_category_tires_wheels': 'Pneus e rodas',
  'inspection_category_brakes': 'Freios',
  'inspection_category_lights_signals': 'Luzes e setas',
  'inspection_category_mirrors': 'Espelhos',
  'inspection_category_windshield_wipers': 'Para-brisa e limpadores',
  'inspection_category_horn': 'Buzina',
  'inspection_category_steering': 'Direção',
  'inspection_category_fluid_leaks': 'Vazamentos de fluido',
  'inspection_category_seatbelts': 'Cintos de segurança',
  'inspection_category_body_damage': 'Danos na carroceria',
  'inspection_category_other': 'Outro',
  'inspection_status_ok': 'OK',
  'inspection_status_defect': 'Defeito',
  'inspection_defect_note_hint': 'Descreva o problema',
  'inspection_defect_note_required': 'Adicione uma nota para cada defeito antes de enviar.',
  'inspection_photo_optional': 'Adicionar foto',
  'inspection_photo_added': 'Foto adicionada',
  'inspection_odometer_optional': 'Hodômetro (opcional)',
  'inspection_submit': 'Enviar inspeção',
  'inspection_result_pass': 'Inspeção aprovada -- nenhum defeito encontrado',
  'inspection_result_fail': 'Inspeção enviada -- defeitos reportados ao seu gerente de frota',

  'driver_ops_title': 'Viagem de hoje',
  'driver_ops_checklist_required': 'Complete o checklist antes de iniciar',
  'driver_ops_live_location': 'Localização em tempo real',
  'waiting_for_gps': 'Aguardando sinal de GPS…',
  'report_incident_button': 'Reportar imprevisto',
  'report_incident_title': 'Reportar um imprevisto',
  'report_incident_category_label': 'O que aconteceu?',
  'incident_category_breakdown': 'Pane no veículo',
  'incident_category_accident': 'Acidente',
  'incident_category_delay': 'Atraso',
  'incident_category_other': 'Outro',
  'report_incident_description_label': 'Descreva o que aconteceu',
  'report_incident_description_hint': 'ex. Pneu furado na I-95, parei em segurança',
  'report_incident_submit': 'Enviar relatório',
  'report_incident_success': 'Imprevisto reportado ao seu administrador de frota',

  // Fleet Fase 5 -- mapa ao vivo / geocercas
  'fleet_live_map_title': 'Mapa ao vivo',
  'fleet_live_map_no_vehicles': 'Nenhum veículo está reportando posição ao vivo ainda',
  'fleet_live_map_tap_to_place': 'Toque no mapa para posicionar o centro da geocerca',
  'fleet_live_map_add_geofence': 'Adicionar geocerca',
  'fleet_live_map_new_geofence': 'Nova geocerca',
  'fleet_live_map_geofence_name': 'Nome da zona',
  'fleet_live_map_geofence_radius': 'Raio',
  'fleet_live_map_create': 'Criar',
  'fleet_live_map_alerts_title': 'Alertas de geocerca',
  'fleet_live_map_no_alerts': 'Sem alertas',

  // Fleet Fase 6 -- milhas por estado IFTA (peça 1: só milhas, não é uma
  // declaração IFTA apresentável -- ver ifta_service.dart)
  'ifta_state_mileage_title': 'Milhas por estado',
  'ifta_pick_range': 'Escolher período',
  'ifta_all_vehicles': 'Todos os veículos',
  'ifta_total_miles': 'Milhas totais',
  'ifta_no_org': 'Nenhuma organização encontrada para esta conta.',
  'ifta_no_mileage': 'Nenhuma milhagem registrada para este período',
  'ifta_disclaimer': 'Milhas por estado, calculadas a partir do rastro GPS. Isto não é uma declaração IFTA apresentável -- o cálculo real do imposto precisa de galões de combustível por jurisdição, que este app não rastreia.',

  // ============================================================
  // RELATÓRIOS
  // ============================================================
  'report_generated': 'Relatório gerado',
  'generating_report_progress': 'Gerando relatório...',
  'report_download': 'Baixar relatório',
  'report_verification': 'Verificação do relatório',
  'report_qr_verification': 'Verificação por QR',
  'report_integrity': 'Integridade do relatório',

  // ============================================================
  // IMPOSTOS / IRS
  // ============================================================
  'tax_deduction': 'Dedução fiscal',
  'irs_rate': 'IRS 2026',
  'estimated_deduction': 'Dedução estimada',
  'tax_summary': 'Resumo fiscal',

  // ============================================================
  // VERIFICAÇÃO QR
  // ============================================================
  'verification_page': 'Página de verificação',
  'scan_qr': 'Escanear código QR',
  'verify_report': 'Verificar relatório',
  'session_hash': 'Hash da sessão',
  'section_hash': 'Hash da seção',

  // ============================================================
  // FORMULÁRIO DE VEÍCULO
  // ============================================================
  'enter_vehicle_make': 'Digite a marca do veículo',
  'enter_vehicle_model': 'Digite o modelo do veículo',
  'enter_vehicle_color': 'Digite a cor do veículo',
  'enter_vehicle_year': 'Digite o ano do veículo',
  'enter_vehicle_mileage': 'Digite a quilometragem do veículo',

  // ============================================================
  // SUCESSOS E ALERTAS
  // ============================================================
  'vehicle_added_success': 'Veículo adicionado com sucesso',
  'vehicle_deleted_success': 'Veículo excluído',
  'vehicle_saved': 'Veículo salvo',
  'vehicle_required': 'Veículo obrigatório',

  // 2026-08-24: filled in missing keys found by lib/tools/i18n_validator.dart
  // (feature drift -- these were added to en/es over time and never synced
  // here). Best-effort translation, not reviewed by a native speaker.
  'monday': 'Segunda-feira',
  'tuesday': 'Terça-feira',
  'wednesday': 'Quarta-feira',
  'thursday': 'Quinta-feira',
  'friday': 'Sexta-feira',
  'saturday': 'Sábado',
  'sunday': 'Domingo',
  'add_maintenance_record': 'Adicionar registro de manutenção',
  'add_note': 'Adicionar nota',
  'add_vehicle_prompt': 'Nenhum veículo adicionado ainda',
  'delete_vehicle_confirmation': 'Tem certeza de que deseja excluir este veículo? O histórico de viagens será mantido.',
  'back_to_login': 'Voltar ao login',
  'confirm_new_password': 'Confirmar nova senha',
  'cost_optional': 'Custo (opcional)',
  'current_trip': 'Viagem atual',
  'danger_zone': 'Zona de perigo',
  'delete_account': 'Excluir conta',
  'delete_account_confirm_body': 'Isso exclui permanentemente sua conta e tudo nela: veículos, histórico de viagens, registros de quilometragem e relatórios. Isso não pode ser desfeito.',
  'delete_account_confirm_title': 'Excluir sua conta permanentemente?',
  'delete_account_success': 'Conta excluída',
  'delete_account_type_to_confirm': 'Digite DELETE para confirmar',
  'delete_account_word': 'DELETE',
  'trip_sealed_badge': 'Selado',
  'delete_trip': 'Excluir viagem',
  'delete_trip_confirm_body': 'Isso removerá permanentemente a viagem e todas as milhas registradas do ControlMiles, incluindo seu registro de auditoria. Isso não pode ser desfeito e a viagem não contará mais para seus relatórios ou estimativa de dedução do IRS.',
  'delete_trip_confirm_title': 'Excluir esta viagem permanentemente?',
  'delete_trip_success': 'Viagem excluída',
  'edit_note': 'Editar nota',
  'end_trip_failed': 'Não foi possível encerrar a viagem — o rastreamento continua ativo. Tente novamente.',
  'enter_reset_code': 'Digite o código recebido por email',
  'forgot_password_body': 'Digite o email da sua conta e enviaremos um código para redefinir sua senha.',
  'generate_global_pdf': 'Gerar PDF global',
  'greeting_afternoon': 'Boa tarde',
  'greeting_evening': 'Boa noite',
  'greeting_morning': 'Bom dia',
  'irs_estimate_disclaimer': 'Estimado usando as taxas padrão de milhagem do IRS 2026 (\$0.725/milha de 1º de janeiro a 30 de junho, \$0.76/milha de 1º de julho a 31 de dezembro — cada viagem é calculada com a taxa vigente na sua própria data). O ControlMiles não é afiliado nem endossado pelo IRS ou qualquer agência oficial. Esta é apenas uma estimativa informativa, não uma dedução garantida — consulte um profissional de impostos.',
  'irs_estimate_title': 'Sobre esta estimativa',
  'maintenance': 'Manutenção',
  'maintenance_record_added_success': 'Registro de manutenção adicionado',
  'maintenance_record_deleted_success': 'Registro de manutenção excluído',
  'maintenance_type': 'Tipo',
  'maintenance_type_battery': 'Bateria',
  'maintenance_type_brake_service': 'Serviço de freios',
  'maintenance_type_inspection': 'Inspeção',
  'maintenance_type_oil_change': 'Troca de óleo',
  'maintenance_type_other': 'Outro',
  'maintenance_type_registration': 'Registro/Licenciamento',
  'maintenance_type_tire_rotation': 'Rodízio de pneus',
  'my_vehicle': 'Meu veículo',
  'new_password': 'Nova senha',
  'next_due_date_optional': 'Próxima data prevista (opcional)',
  'next_due_odometer_optional': 'Próxima quilometragem prevista (opcional)',
  'no_maintenance_records': 'Nenhum registro de manutenção ainda',
  'note_saved_success': 'Nota salva',
  'notes_optional': 'Notas (opcional)',
  'odometer_at_service': 'Quilometragem na manutenção',
  'password_mismatch': 'As senhas não coincidem',
  'pause_failed': 'Não foi possível pausar — o rastreamento continua ativo. Tente novamente.',
  'resend_code': 'Reenviar código',
  'reset_code_hint': 'Código',
  'reset_code_sent': 'Verifique seu email para o código',
  'reset_password_success': 'Senha atualizada. Você já pode entrar.',
  'reset_password_title': 'Redefinir sua senha',
  'resume_failed': 'Não foi possível retomar o rastreamento. Tente novamente.',
  'resume_to_switch_app': 'Retome o rastreamento para trocar de atividade',
  'select_vehicle': 'Selecionar veículo',
  'send_reset_code': 'Enviar código',
  'service_date': 'Data do serviço',
  'placed_in_service_date_optional': 'Data de início de uso (opcional)',
  'vin_optional': 'VIN (opcional)',
  'vin_helper': 'Se você adicionar este veículo novamente depois, o odômetro nunca poderá ser menor do que o já registrado pelo ControlMiles para este VIN.',
  'vehicle_odometer_below_floor': 'Este VIN já tem um odômetro mais alto registrado ({floor} mi). Insira um valor igual ou maior.',
  'mileage_method_label': 'Método de dedução',
  'mileage_method_standard': 'Taxa padrão de milhagem',
  'mileage_method_actual': 'Despesas reais',
  'switch_activity_failed': 'Não foi possível trocar de atividade — ainda rastreando a anterior. Tente novamente.',
  'trip_note': 'Nota da viagem',
  'trip_note_hint': 'ex. "perdi 5 milhas — sinal de GPS perdido"',
  'vehicle_switch_blocked_active_session': 'Você não pode trocar seu veículo ativo enquanto uma viagem está em andamento. Encerre a viagem atual primeiro.',
  'verify_code': 'Verificar código',
  'year_miles_deduction_estimate': 'Dedução est.',
};