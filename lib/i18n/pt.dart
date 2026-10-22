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
  'route_map_show': "Mapa da rota",
  'route_map_hide': "Ocultar mapa",
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
  'camera_error_body': 'Não conseguimos acessar sua câmera. Verifique a permissão da câmera nas Configurações e tente novamente.',
  'odometer_not_detected': 'Odômetro não detectado',
  'center_odometer_numbers': 'Centralize os números do odômetro',
  'ai_processing': 'Processando foto',
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
  'send_feedback': 'Enviar sugestões',
  'send_feedback_no_mail_app': 'Nenhum app de e-mail encontrado. Escreva para support@controlmiles.com.',
  'send_feedback_email_subject': 'Sugestões para o ControlMiles',
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
  'password_too_weak': 'A senha deve incluir pelo menos uma letra e um número',
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
  'location_desc': "O ControlMiles coleta dados de localização para registrar suas viagens e calcular sua quilometragem, mesmo quando o app está fechado ou não está em uso.",
  'camera': 'Câmera',
  'camera_desc': 'Usada para capturar a leitura do odômetro como evidência de cada viagem.',
  'motion_detection': 'Movimento e atividade',
  'motion_desc': 'Usado para detectar quando você começa e para de dirigir.',
  'notifications_desc': 'Usadas para lembrar você de viagens ativas e enviar resumos semanais de quilometragem.',
  'accept_terms': "Confirmo que tenho pelo menos 18 anos e aceito os Termos de Serviço e a Política de Privacidade.",
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
  'specify_model': 'Especifique o modelo',
  'vehicle_model_hint': 'Escolha um modelo',
  'vehicle_model_other': 'Outro',
  'vehicle_model_pick_make_first': 'Escolha primeiro a marca',
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
  'premium_plan_description': "Desbloqueie a Detecção Automática e outros recursos premium. Até 5 veículos. Inclui um teste grátis de 15 dias.",
  'base_plan_description': "A experiência principal do ControlMiles. 1 veículo. Inclui um teste grátis de 15 dias.",
  'current_plan': 'Plano atual',
  'started_plan': 'Started (teste grátis)',
  'started_plan_description': 'Seu teste grátis de 15 dias. 1 veículo.',
  'trial_days_left': '{days} dias restantes',
  'subscriptions_not_configured': 'As assinaturas ainda não estão disponíveis.',

  // ============================================================
  // FROTA
  // ============================================================



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
  'shift_apps_picker_link': 'Escolher apps para este turno',
  'shift_apps_picker_title': 'Selecionar apps de gig',
  'shift_apps_picker_body': 'A detecção automática só vai reagir aos apps selecionados. Deixe tudo desmarcado para monitorar todos os apps.',
  'shift_apps_picker_clear': 'Limpar',
  'shift_apps_picker_save': 'Salvar',
  'background_reliability_section': 'Confiabilidade em segundo plano',
  'battery_optimization_title': 'Otimização de bateria',
  'battery_optimization_granted': 'Permitido executar em segundo plano',
  'battery_optimization_missing': 'Pode ser pausado em segundo plano, toque para corrigir',
  'exact_alarm_title': 'Alarmes exatos',
  'exact_alarm_granted': 'Os lembretes vão disparar na hora certa',
  'exact_alarm_missing': 'Os lembretes podem atrasar, toque para corrigir',
  'checking_status': 'Verificando...',
  'fix_it': 'Corrigir',
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
  'pause_reminder_notification_title': 'Sua viagem está pausada',
  'pause_reminder_notification_body': 'Está pausada há alguns minutos — abra o ControlMiles para retomar ou finalizar.',
  'paused_status_notification_title': 'ControlMiles',
  'paused_status_notification_body': 'Viagem pausada — toque para retomar ou finalizar.',
  'weekly_summary_notification_title': 'Seu resumo semanal está pronto',
  'weekly_summary_notification_body': 'Veja quantas milhas você registrou esta semana.',
  'torch_suggestion': 'Muito escuro? Toque para a lanterna',
  'ocr_unreadable_manual': 'Não deu para ler — digite manualmente',
  'ocr_detected': 'Detectado',
  'ocr_scanning': 'Escaneando...',
  'ocr_auto_badge': 'Detectado automaticamente',
  'odometer_value': 'Odômetro',
  'ocr_confirm_capture': 'Confirmar e capturar',
  'photo_blurry_warning': 'Esta foto parece borrada. Tire novamente para um registro claro e utilizável.',
  'retake_photo': 'Tirar novamente',
  'use_photo': 'Usar foto',
  'use_photo_anyway': 'Usar mesmo assim',
  'mid_trip_auto_switched_title': 'Alternado automaticamente',
  'mid_trip_auto_switched_body': 'Agora rastreando com',
  'auto_detect_tracking_with_label': 'Rastreando com:',
  'auto_detect_tracking_subtitle': 'A detecção automática está monitorando mudanças de app',
  'auto_detect_tracking_paused_subtitle': 'Viagem pausada',
  'recent_trips_title': 'Viagens recentes',
  'see_all_label': 'Ver todas',
  'no_trips_yet': 'Nenhuma viagem ainda',

  'waiting_for_gps': 'Aguardando sinal de GPS…',

  'terms_of_use': "Termos de uso",
  'licenses_map_data': "Licenças e dados do mapa",
  'ready_to_track': "Pronto para rastrear",
  'ready_to_track_body': "Escolha sua atividade e inicie sua viagem.",
  'tracking_paused_label': "Rastreamento pausado",
  'trip_route': "Trajeto da viagem",
  'trip_route_fit': "Ajustar trajeto",

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
  'purchase_success': "Seu plano está ativo. Obrigado!",
  'purchase_pending': "Seu pagamento está pendente. O plano é ativado assim que o Google Play confirmar.",
  'purchase_failed': "Não foi possível concluir a compra. Você não foi cobrado. Tente novamente.",
  'play_store_unavailable': "O Google Play não está disponível neste dispositivo, então não é possível comprar planos aqui.",
  'restore_purchases': "Restaurar compras",
  'continue_with_google': "Continuar com o Google",
  'or_divider': "ou",
  'login_tagline': "Cada milha, registrada.",
  'login_welcome_back': "Bem-vindo de volta",
  'login_welcome_back_sub': "Entre para continuar registrando cada milha.",
  'login_create_account_title': "Crie sua conta",
  'login_create_account_sub': "Comece a registrar suas milhas em minutos.",
  'no_account_prompt': "Novo no ControlMiles?",
  'have_account_prompt': "Já tem uma conta?",
  'create_account': "Criar conta",
  'google_sign_in_failed': "Não foi possível entrar com o Google. Tente novamente ou use seu e-mail.",
  'remember_my_email': "Lembrar meu e-mail",
  'stay_signed_in': "Manter conectado",
  'stay_signed_in_hint': "Deixe ativado para que suas viagens sejam registradas e detectadas em segundo plano. Desative em um celular compartilhado.",
  'odometer_below_registered_error': "Esta leitura é menor que as {value} mi já registradas para este veículo. Verifique se o veículo certo está selecionado.",
  'trip_discarded_no_miles': "Nenhuma milha foi registrada, então esta viagem não foi salva.",
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

  // Checkpoint semanal do odômetro (2026-09-03)
  'weekly_odometer_close_title': 'Fechamento semanal do odômetro',
  'weekly_odometer_close_body': 'Quer tirar agora a foto de fechamento do odômetro desta semana?',
  'weekly_odometer_close_title_mandatory': 'Fechamento semanal obrigatório',
  'weekly_odometer_close_body_mandatory': 'Tire a foto de fechamento do odômetro desta semana para continuar -- aos domingos isso não pode ser adiado.',
  'later': 'Mais tarde',
  'take_photo': 'Tirar foto',
  'odometer_evidence_label': 'Fotos do odômetro (evidência)',
  'gps_vs_odometer_disclaimer': 'Esses números nem sempre vão coincidir exatamente -- as milhas pessoais (não rastreadas) não são contadas pelo GPS, então alguma diferença é esperada.',

  // ============================================================
  // VEHICLE PROFILE (tela de detalhe somente leitura) + milhas na manutenção
  // ============================================================
  'vehicle_profile_title': 'Perfil do veículo',
  'tracked_miles_gps': 'Milhas registradas (GPS)',
  'odometer_checkpoints_title': 'Fechamentos semanais do odômetro',
  'no_odometer_checkpoints': 'Ainda não há fechamentos de odômetro',
  'checkpoint_week_label': 'Semana de {date}',
  'checkpoint_start': 'Início',
  'checkpoint_end': 'Fechamento',
  'checkpoint_pending_close': 'Fechamento pendente',
  'current_odometer': 'Odômetro atual',
  'miles_since_service': 'Milhas desde o último serviço',
  'no_service_recorded': 'Ainda não há serviços registrados',
  'next_service_due_miles': 'Próximo em {miles}',
  'service_overdue_miles': 'Atrasado em {miles}',
  'service_recommended_interval': 'Recomendado: a cada {miles}',

  // ============================================================
  // Auditoria de chaves faltantes (2026-09-03)
  // ============================================================
  'auth_error': 'Erro de autenticação. Tente novamente.',
  'header_miles_period': "Milhas no cabeçalho do início",
  'tour_step': "{n} de {total}",
  'tour_skip': "Pular",
  'tour_next': "Próximo",
  'tour_done': "Começar",
  'tour_got_it': "Entendi",
  'monitor_home_title': "Auxiliar do ônibus",
  'monitor_hello': "Olá, {name}",
  'monitor_hint': "Suas rotas escolares de hoje. Quando o motorista iniciar uma rota, abra-a e mantenha a lista de alunos em dia.",
  'monitor_waiting_driver': "Aguardando o motorista iniciar",
  'signup_check_email': "Conta criada. Confirme seu e-mail e depois entre aqui.",
  'signup_confirm_title': "Verifique seu e-mail",
  'login_sign_in_title': "Entrar",
  'login_sign_in_sub': "Entre para começar a registrar cada milha.",
  'invalid_credentials': 'E-mail ou senha inválidos.',
  'email_already_exists': 'Este e-mail já está registrado.',
  'camera_permission_denied_error': 'É necessário acesso à câmera para isso.',
  'no_internet_connection_error': 'Sem conexão com a internet.',
  'invalid_input_error': 'Verifique o que você digitou.',
  'local_storage_error': 'Não foi possível salvar localmente neste dispositivo.',
  'session_expired_error': 'Sua sessão expirou. Faça login novamente.',
  'vehicle_limit_reached_error': 'Você atingiu o limite de veículos do seu plano.',
  'rate_limited_error': 'Muitas tentativas. Tente novamente em alguns minutos.',
  'duplicate_entry_error': 'Isso já existe.',
  'unexpected_error': 'Algo deu errado.',
  'end': 'Fim',
  'navigation_error_title': 'Erro de Navegação',
  'route_not_found_message': 'Rota {route} não encontrada.\nContate a Olympus Mont Systems.',
  'switched_label': 'TROCADO',
  'trip_number_label': 'Viagem {number}',
  'trip_end_time_label': 'Fim: {time}',
  'sections_label': 'SEÇÕES',
  'vin_label': 'VIN',
  'odometer_cycle_label': 'Ciclo do odômetro',
  'odometer_cycle_weekly': 'Semanal',
  'odometer_cycle_biweekly': 'Quinzenal',
  'odometer_cycle_monthly': 'Mensal',
  'odometer_cycle_updated': 'Ciclo do odômetro atualizado.',
  'system_initializing_redirecting': 'Inicializando o sistema. Redirecionando...',
  'error_all_fields_required': 'Todos os campos são obrigatórios.',
  'error_invalid_vehicle_year': 'Ano do veículo inválido.',
  'error_odometer_negative_or_empty': 'O odômetro não pode ser negativo ou estar vazio.',
  'error_invalid_maintenance_type': 'Tipo de manutenção inválido.',
  'error_service_date_required': 'A data do serviço é obrigatória.',
  'sections_count_label': '{count} seções',
  'vehicle_make_other': 'Outra',
  'email_not_linked_to_controlmiles': 'Esse e-mail não está vinculado a nenhuma conta do ControlMiles.',

  'free_trial_expired_title': 'Seu teste grátis terminou',
  'free_trial_expired_body': 'Seus 15 dias de teste grátis terminaram. Assine o Basic ou Premium para continuar registrando viagens.',
  'vehicle_limit_reached_title': 'Limite de veículos atingido',
  'vehicle_limit_reached_body': 'Seu plano permite até {max} veículo(s). Faça upgrade para adicionar mais.',
  'export_limit_reached_title': 'Limite de exportação atingido',
  'export_limit_reached_body': 'O plano Basic inclui 2 exportações de PDF por mês. Faça upgrade para o Premium para exportações ilimitadas.',

  // Link de convite de frota (fechamento Sprint 1, 2026-09-09)

  // Código de acesso ao Report Portal, gerado no app (2026-09-09)
  'copy': 'Copiar',
  'copied_to_clipboard': 'Copiado para a área de transferência',
  'generate_report_code_title': 'Código de acesso ao relatório',
  'generate_report_code_body': 'Gere um código de uso único para um intervalo de datas das suas viagens. Seu contador o insere em controlmiles.com/portal/verify para ver um resumo de quilometragem somente leitura -- sem login, sem conta necessária do lado dele.',
  'generate_report_code_button': 'Gerar código',
  'generate_report_code_your_code': 'Compartilhe este código com seu contador',
  'generate_report_code_expires_in': 'Expira em {mmss}',
  'generate_report_code_expired': 'Este código expirou.',
  'generate_report_code_disclaimer': 'Utilizável até 2 vezes. Não garantido por este aplicativo -- para fins de dedução.',
  'report_portal_section': 'Report Portal',
  'report_portal_section_subtitle': 'Gere um código para seu contador',

  // 2026-09-16: claves que faltaban frente a en.dart (turno de cierre + errores de captura).
  'session_already_closed': 'Esta sessão já está encerrada e não pode ser modificada.',
  'session_not_found': 'Erro crítico: sessão ativa não encontrada.',
  'session_already_finalized': 'Esta sessão já foi finalizada.',
  'duplicate_capture': 'Já existe uma captura registrada para este evento.',
  'photo_size_out_of_range': 'A foto está fora do tamanho permitido ({min}KB–{max}MB). Tente novamente.',
  'photo_format_not_supported': 'Formato de foto não suportado. Formatos permitidos: {formats}.',


  // 2026-09-16: check 'no volver a mostrar' + toggles por tipo de aviso. Traducciones best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'dont_show_again': 'Não mostrar este aviso novamente',
  'notif_type_pause_reminder': 'Lembrete de viagem pausada',
  'notif_type_forgotten_trip': 'Lembrete de viagem esquecida',
  'notif_type_weekly_summary': 'Resumo semanal de milhas',
  'notif_type_gig_app_switch': 'Troca de app gig',
  'notif_type_auto_trip_started': 'Viagem iniciada automaticamente',
  'notification_types_manage_hint': 'Toque para escolher quais avisos receber',
  'notification_types_sheet_title': 'Tipos de aviso',


  // 2026-09-16: Usage Access en el onboarding de permisos + dialogo al activar auto-detect. Best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'usage_access': 'Acesso de uso de apps',
  'usage_access_desc': 'Permite que o ControlMiles veja qual app gig está aberto para iniciar sua viagem automaticamente.',
  'usage_access_onboarding_body': 'A detecção automática de viagens precisa do "Acesso de uso". O Android só concede isso pelas Configurações, não por um aviso comum. Você pode pular agora e ativar depois nas Configurações.',
  'usage_access_required_title': 'Falta o acesso de uso',
  'usage_access_required_body': 'Sem o "Acesso de uso", a detecção automática não consegue ver qual app gig está aberto. Conceda nas Configurações e ative a detecção automática novamente.',

  // Gig / Fleet split (2026-10-11).
  'active_fleet_trip_error': "Você tem uma viagem da empresa aberta no ControlMiles Fleet. Encerre-a lá antes de iniciar uma viagem pessoal.",
  'gig_fleet_app_hint': "Dirige para a frota de uma empresa? As viagens da empresa ficam no app ControlMiles Fleet. Este app guarda só suas milhas pessoais.",
  'get_fleet_app': "Baixar ControlMiles Fleet",

};