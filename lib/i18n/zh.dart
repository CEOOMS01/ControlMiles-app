// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/zh.dart - 中文（简体）

const Map<String, String> zhTexts = {
  // ============================================================
  // 应用通用
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': '启动屏幕',
  'not_found': '未找到',
  'error': '错误',
  'system_error': '系统错误',
  'id_label': 'ID',
  'loading': '加载中...',
  'please_wait': '请稍候...',

  // ============================================================
  // 认证
  // ============================================================
  'login': '登录',
  'register': '注册',
  'signup': '创建账号',
  'logout': '退出登录',
  'logout_confirmation': '您确定要退出登录吗?',
  'forgot_password': '忘记密码？',
  'reset_password': '重置密码',
  'auth_session_expired': '认证会话已过期',
  'email': '邮箱',
  'password': '密码',
  'confirm_password': '确认密码',
  'sign_in': '登录',
  'sign_up': '注册',
  'sign_out': '退出',
  'active_activity': '活动进行中',
  'configuration_updated': '配置已更新',

  // ============================================================
  // 用户资料
  // ============================================================
  'name': '姓名',
  'edit_name': '编辑姓名',
  'last_name': '姓氏',
  'adress': '地址',
  'number': '号码',
  'dark_mode': '深色模式',
  'dark_mode_description': '在浅色和深色主题之间切换',
  'profile_updated_success': '个人资料已成功更新',

  // ============================================================
  // 导航
  // ============================================================
  'dashboard': '首页',
  'home': '首页',
  'profile': '个人资料',
  'settings': '设置',
  'help': '帮助',
  'about': '关于',
  'support': '支持',

  // ============================================================
  // 追踪
  // ============================================================
  'tracking': '追踪',
  'tracking_active': '追踪进行中',
  'tracking_paused': '已暂停',
  'tracking_stopped': '已停止',
  'start_tracking': '开始追踪',
  'stop_tracking': '停止追踪',
  'pause_tracking': '暂停追踪',
  'resume_tracking': '继续追踪',
  'trip_details': '行程详情',
  'route_map_show': "路线地图",
  'route_map_hide': "隐藏地图",
  'trip_history': '行程历史',
  'trip_ended': '行程结束',
  'miles': '英里',
  'kilometers': '公里',
  'speed': '速度',
  'duration': '时长',
  'distance': '距离',
  'start_time': '开始时间',
  'end_time': '结束时间',
  'select_an_activity_before_starting_tracking': '开始追踪前请选择一项活动',

  // ============================================================
  // 里程表
  // ============================================================
  'odometer': '里程表',
  'odometer_capture': '里程表拍摄',
  'start_odometer_capture': '拍摄起始里程',
  'end_odometer_capture': '拍摄结束里程',
  'capture_photo': '拍摄照片',
  'retry_camera': '重试相机',
  'camera_error': '相机错误',
  'camera_error_body': '无法访问您的相机。请在设置中检查相机权限，然后重试。',
  'odometer_not_detected': '未检测到里程表',
  'center_odometer_numbers': '请将里程表数字置于中央',
  'ai_processing': '正在处理照片',
  'validating_mileage_gps_hash': '正在验证里程、GPS 和哈希',

  // ============================================================
  // GPS / 定位
  // ============================================================
  'gps': 'GPS',
  'gps_enabled': 'GPS 已启用',
  'gps_disabled': 'GPS 已禁用',
  'location_permission_required': '需要位置权限',
  'location_permission_denied': '位置权限被拒绝',

  // ============================================================
  // 历史记录与报告
  // ============================================================
  'history': '历史记录',
  'reports': '报告',
  'audit_logs': '审计日志',
  'statistics': '统计数据',
  'summary': '摘要',
  'total_miles': '总里程',
  'last_30_days': '过去30天',
  'last_12_months': '过去12个月',
  'total_trips': '总行程',
  'average_speed': '平均速度',
  'RECENT_TRIPS': '最近行程',
  'SEE_ALL': '查看全部',
  'not_trips_yet': '暂无行程',
  'generate_pdf': '生成 PDF',

  // ============================================================
  // TRIP PURPOSES & IRS
  // ============================================================
  'select_trip_purpose': '选择行程目的',
  'irs_deduction_note': '用于抵扣目的 -- 本应用不作任何担保',
  'business_purpose': '商务 / 业务',
  'work_commute': '上下班通勤',
  'medical': '医疗',
  'moving': '搬家',
  'charitable': '慈善 / 志愿者',
  'education_study': '教育 / 学习',
  'personal_other': '个人 / 其他',

  // ============================================================
  // 设置
  // ============================================================
  'preferences': '偏好设置',
  'language': '语言',
  'language_description': '选择您喜欢的语言',
  'language_changed': '语言已更改为',
  'notifications': '通知',
  'notifications_description': '接收应用通知',
  'notifications_enabled': '通知已启用',
  'notifications_disabled': '通知已禁用',
  'analytics': '分析',
  'analytics_description': '分享使用数据',

  // ============================================================
  // 隐私与安全
  // ============================================================
  'privacy_security': '隐私与安全',
  'privacy_policy': '隐私政策',
  'terms_conditions': '服务条款',
  'send_feedback': '发送建议',
  'send_feedback_no_mail_app': '未找到邮件应用，请写信至 support@controlmiles.com。',
  'send_feedback_email_subject': 'ControlMiles 建议反馈',
  'trademark_disclaimer_short': 'ControlMiles 是一款独立应用程序,与 Uber、Lyft、DoorDash、Instacart、Amazon、Walmart、Shipt 及本应用中提及的任何其他平台均无关联,未获其认可或赞助。所有商标均归其各自所有者所有。',
  'age_terms_checkbox_prefix': '我确认我已年满18周岁,并同意',
  'age_terms_checkbox_and': '和',
  'age_terms_required_error': '请确认您已年满18周岁并同意相关条款以继续。',
  'data_security': '数据安全',
  'security_audit': '安全审计',

  // ============================================================
  // 关于
  // ============================================================
  'about_app': '关于应用',
  'app_version': '应用版本',
  'build_number': '构建号',
  'company': '公司',
  'copyright': '版权所有',
  'developer': '开发者',

  // ============================================================
  // 按钮
  // ============================================================
  'ok': '确定',
  'cancel': '取消',
  'save': '保存',
  'delete': '删除',
  'edit': '编辑',
  'close': '关闭',
  'refresh': '刷新',
  'retry': '重试',
  'next': '下一步',
  'previous': '上一步',
  'done': '完成',
  'submit': '提交',
  'continue': '继续',
  'back': '返回',
  'start': '开始',
  'stop': '停止',
  'pause': '暂停',
  'resume': '继续',
  'end_trip': '结束行程',
  'skip': '跳过',
  'confirm': '确认',

  // ============================================================
  // 消息
  // ============================================================
  'success': '成功',
  'failed': '失败',
  'warning': '警告',
  'info': '信息',
  'no_data': '暂无数据',
  'no_results': '未找到结果',
  'something_went_wrong': '出了点问题',
  'please_try_again': '请重试',
  'network_error': '网络错误',
  'internet_required': '需要网络连接',
  'offline_mode': '离线模式',
  'syncing': '正在同步...',
  'synced': '已同步',
  'feature_coming_soon': '功能即将推出',

  // ============================================================
  // 云端状态
  // ============================================================
  'cloud_status': '云端状态',
  'cloud_connected': '云同步：活跃且安全',
  'cloud_disconnected': '云同步：离线 / 出现问题',
  'audit_chain_healthy': '审计链健康',
  'audit_chain_compromised': '审计链已受损',

  // ============================================================
  // 时间
  // ============================================================
  'today': '今天',
  'yesterday': '昨天',
  'this_week': '本周',
  'this_month': '本月',
  'this_year': '今年',
  'all_time': '全部时间',
  'january': '一月',
  'february': '二月',
  'march': '三月',
  'april': '四月',
  'may': '五月',
  'june': '六月',
  'july': '七月',
  'august': '八月',
  'september': '九月',
  'october': '十月',
  'november': '十一月',
  'december': '十二月',

  // ============================================================
  // 单位
  // ============================================================
  'metric_system': '公制',
  'meter': '米',
  'meter_short': '米',
  'kilometer': '公里',
  'kilometer_short': '公里',
  'mile': '英里',
  'mile_short': '英里',
  'hour': '小时',
  'minute': '分钟',
  'second': '秒',
  'kmh': '公里/小时',
  'mph': '英里/小时',

  // ============================================================
  // 验证
  // ============================================================
  'field_required': '此字段为必填项',
  'powered_by_footer': '技术支持',
  'invalid_email': '邮箱地址无效',
  'password_too_short': '密码太短',
  'password_too_weak': '密码必须包含至少一个字母和一个数字',
  'passwords_do_not_match': '两次输入的密码不一致',
  'invalid_input': '输入无效',

  // ============================================================
  // 权限
  // ============================================================
  'permissions_required': '需要权限',
  'camera_permission': '相机权限',
  'location_permission': '位置权限',
  'storage_permission': '存储权限',
  'grant_permission': '授予权限',
  'deny_permission': '拒绝权限',
  'olympus_mont_systems': 'OLYMPUS MONT SYSTEMS',
  'secure_audit_programs': '安全 / 审计 / 项目',
  'permissions_description': 'ControlMiles 需要这些权限来追踪您的行程，并记录准确、可靠的里程证据。',
  'location_access': '位置访问',
  'location_desc': "ControlMiles 会收集位置数据以记录你的行程并计算里程，即使应用已关闭或未在使用中。",
  'camera': '相机',
  'camera_desc': '用于拍摄里程表读数，作为每次行程的证据。',
  'motion_detection': '运动与活动',
  'motion_desc': '用于检测您何时开始和停止驾驶。',
  'notifications_desc': '用于提醒您正在进行的行程，并发送每周里程摘要。',
  'accept_terms': "我确认我已年满 18 岁，并接受服务条款和隐私政策。",
  'permission_required': '需要权限',
  'location_always_needed': 'ControlMiles 需要"始终允许"位置权限，以便在应用未打开时也能继续追踪您的行程。请在设置中启用此权限。',
  'open_settings': '打开设置',

  // ============================================================
  // 特定功能
  // ============================================================
  'evidence': '证据',
  'evidence_photo': '证据照片',
  'hash_verification': '哈希验证',
  'verified': '已验证',
  'unverified': '未验证',
  'blockchain_status': '区块链状态',
  'integrity_check': '完整性检查',
  'anomaly_detection': '异常检测',
  'fraud_alert': '欺诈警报',
  'suspicious_activity': '检测到可疑活动',

  // ============================================================
  // 车辆
  // ============================================================
  'vehicle': '车辆',
  'vehicles': '车辆',
  'add_vehicle': '添加车辆',
  'active_badge': '使用中',
  'vehicle_make_hint': '例如：丰田、日产',
  'specify_make': '请填写品牌',
  'specify_model': '请指定型号',
  'vehicle_model_hint': '选择型号',
  'vehicle_model_other': '其他',
  'vehicle_model_pick_make_first': '请先选择品牌',
  'mark_as_active': '设为当前车辆',
  'use_as_active_vehicle': '设为当前使用车辆',
  'edit_vehicle': '编辑车辆',
  'delete_vehicle': '删除车辆',
  'vehicle_make': '品牌',
  'vehicle_model': '型号',
  'vehicle_color': '颜色',
  'vehicle_year': '年份',
  'vehicle_mileage': '里程',
  'vehicle_information': '车辆信息',
  'no_vehicle_registered': '未注册车辆',

  // ============================================================
  // 订阅
  // ============================================================
  'subscription': '订阅',
  'plan': '套餐',
  'basic_plan': '基础套餐',
  'premium_plan': '高级套餐',
  'pro_plan': '专业套餐',
  'upgrade_plan': '升级套餐',
  'manage_subscription': '管理订阅',
  'trial_period': '试用期',
  'trial_expired': '试用期已过期',
  'subscription_active': '订阅已激活',
  'subscription_required': '需要订阅',
  'premium_plan_description': "解锁自动检测和其他高级功能。最多5辆车。含15天免费试用。",
  'base_plan_description': "ControlMiles 核心体验。1辆车。含15天免费试用。",
  'current_plan': '当前套餐',
  'started_plan': 'Started（免费试用）',
  'started_plan_description': '您的15天免费试用。1辆车。',
  'trial_days_left': '剩余{days}天',
  'subscriptions_not_configured': '订阅功能尚未开放。',

  // ============================================================
  // 车队
  // ============================================================



  'automatic_tracking_section': '自动追踪',
  'auto_detect_toggle_title': '自动行程检测',
  'auto_detect_toggle_subtitle': '检测到您开始驾驶时，会立即提示您确认里程表读数。',
  'premium_badge': '高级版',
  'premium_feature_locked_title': '高级功能',
  'premium_feature_locked_body': '自动行程检测是高级附加功能。升级即可为您的账户启用此功能。',
  'auto_detect_intro_title': '自动检测',
  'auto_detect_intro_body': '当您打开受支持的兼职应用时，ControlMiles 会自动开始追踪您的行程——无需点击开始。您现在只需拍摄一次里程表；此后检测到的每次行程都会沿用这个读数。您可以随时关闭此功能。',
  'auto_detect_failed_title': '自动检测未能启动',
  'auto_detect_failed_body': '位置追踪当前未运行，因此暂时无法自动检测行程。请检查 ControlMiles 是否已获得"始终允许"的位置权限，然后重试。',
  'auto_detect_apps_title_on': '自动检测已开启',
  'auto_detect_apps_title_off': '自动检测应用',
  'auto_detect_apps_subtitle_on': '兼职应用检测已启用',
  'auto_detect_apps_subtitle_off': '驾驶时自动检测受支持的兼职应用。',
  'shift_apps_picker_link': '选择本班次使用的应用',
  'shift_apps_picker_title': '选择兼职应用',
  'shift_apps_picker_body': '自动检测只会响应您选中的应用。全部不勾选则监控所有应用。',
  'shift_apps_picker_clear': '清除',
  'shift_apps_picker_save': '保存',
  'background_reliability_section': '后台可靠性',
  'battery_optimization_title': '电池优化',
  'battery_optimization_granted': '允许在后台运行',
  'battery_optimization_missing': '可能在后台被暂停，点击修复',
  'exact_alarm_title': '精确闹钟',
  'exact_alarm_granted': '提醒将按时触发',
  'exact_alarm_missing': '提醒可能延迟，点击修复',
  'checking_status': '正在检查...',
  'fix_it': '修复',
  'auto_detect_apps_checking': '正在检查应用...',
  'gig_app_detection_title': '活跃应用检测',
  'gig_app_detection_subtitle_granted': '打开应用时将自动建议',
  'gig_app_detection_subtitle_not_granted': '点击以授予使用情况访问权限并自动建议应用',
  'carousel_manual_mode': '手动选择',
  'auto_detect_status_listening': '自动检测',
  'auto_detect_status_listening_subtitle': '正在等待你打开一个工作应用……',
  'auto_detect_status_found_label': '已检测到：',
  'auto_detect_status_found_subtitle': '正在自动开始行程...',
  'auto_trip_started_title': '行程已自动开始',
  'auto_trip_started_body': '正在追踪：',
  'forgotten_trip_notification_title': '你的行程仍在进行中',
  'forgotten_trip_notification_body': '忘记结束行程了吗？打开 ControlMiles 暂停或结束。',
  'pause_reminder_notification_title': '你的行程已暂停',
  'pause_reminder_notification_body': '已暂停几分钟了 — 打开 ControlMiles 继续或结束行程。',
  'paused_status_notification_title': 'ControlMiles',
  'paused_status_notification_body': '行程已暂停 — 点击继续或结束。',
  'weekly_summary_notification_title': '你的每周摘要已就绪',
  'weekly_summary_notification_body': '查看本周记录的里程数。',
  'torch_suggestion': '太暗了？点击开启手电筒',
  'ocr_unreadable_manual': '无法识别 — 请手动输入',
  'ocr_detected': '已识别',
  'ocr_scanning': '正在扫描...',
  'ocr_auto_badge': '自动识别',
  'odometer_value': '里程表',
  'ocr_confirm_capture': '确认并拍摄',
  'photo_blurry_warning': '这张照片似乎模糊。请重拍一张清晰可用的照片。',
  'retake_photo': '重拍',
  'use_photo': '使用照片',
  'use_photo_anyway': '仍然使用',
  'mid_trip_auto_switched_title': '已自动切换',
  'mid_trip_auto_switched_body': '当前正在追踪：',
  'auto_detect_tracking_with_label': '追踪中：',
  'auto_detect_tracking_subtitle': '自动检测正在监控应用变化',
  'auto_detect_tracking_paused_subtitle': '行程已暂停',
  'recent_trips_title': '最近行程',
  'see_all_label': '查看全部',
  'no_trips_yet': '暂无行程',

  'waiting_for_gps': '正在等待GPS信号…',

  'terms_of_use': "使用条款",
  'licenses_map_data': "许可证与地图数据",
  'ready_to_track': "准备记录",
  'ready_to_track_body': "选择您的活动并开始行程。",
  'tracking_paused_label': "记录已暂停",
  'trip_route': "行程路线",
  'trip_route_fit': "适配路线",

  // ============================================================
  // 报告
  // ============================================================
  'report_generated': '报告已生成',
  'generating_report_progress': '正在生成报告…',
  'report_download': '下载报告',
  'report_verification': '报告验证',
  'report_qr_verification': 'QR 验证',
  'report_integrity': '报告完整性',

  // ============================================================
  // 税务 / IRS
  // ============================================================
  'tax_deduction': '税务扣除',
  'irs_rate': 'IRS 2026',
  'estimated_deduction': '预计扣除额',
  'tax_summary': '税务摘要',

  // ============================================================
  // QR 验证
  // ============================================================
  'verification_page': '验证页面',
  'scan_qr': '扫描二维码',
  'verify_report': '验证报告',
  'session_hash': '会话哈希',
  'section_hash': '分段哈希',

  // ============================================================
  // 车辆表单
  // ============================================================
  'enter_vehicle_make': '请输入车辆品牌',
  'enter_vehicle_model': '请输入车辆型号',
  'enter_vehicle_color': '请输入车辆颜色',
  'enter_vehicle_year': '请输入车辆年份',
  'enter_vehicle_mileage': '请输入车辆里程',

  // ============================================================
  // 成功与提示
  // ============================================================
  'vehicle_added_success': '车辆添加成功',
  'vehicle_deleted_success': '车辆已删除',
  'vehicle_saved': '车辆已保存',
  'vehicle_required': '需要车辆',

  // 2026-08-24: filled in missing keys found by lib/tools/i18n_validator.dart
  // (feature drift -- these were added to en/es over time and never synced
  // here). Best-effort translation, not reviewed by a native speaker.
  'monday': '星期一',
  'tuesday': '星期二',
  'wednesday': '星期三',
  'thursday': '星期四',
  'friday': '星期五',
  'saturday': '星期六',
  'sunday': '星期日',
  'add_maintenance_record': '添加保养记录',
  'add_note': '添加备注',
  'add_vehicle_prompt': '尚未添加车辆',
  'delete_vehicle_confirmation': '确定要删除此车辆吗？其行程记录将会保留。',
  'back_to_login': '返回登录',
  'confirm_new_password': '确认新密码',
  'cost_optional': '费用（可选）',
  'current_trip': '当前行程',
  'danger_zone': '危险区域',
  'delete_account': '删除账户',
  'delete_account_confirm_body': '这将永久删除您的账户及其中的所有内容：车辆、行程记录、里程记录和报告。此操作无法撤销。',
  'delete_account_confirm_title': '永久删除您的账户？',
  'delete_account_success': '账户已删除',
  'delete_account_type_to_confirm': '输入 DELETE 以确认',
  'delete_account_word': 'DELETE',
  'trip_sealed_badge': '已封存',
  'delete_trip': '删除行程',
  'delete_trip_confirm_body': '这将从 ControlMiles 中永久删除该行程及其所有已记录的里程，包括其审计记录。此操作无法撤销，该行程也将不再计入您的报告或 IRS 抵扣估算。',
  'delete_trip_confirm_title': '永久删除此行程？',
  'delete_trip_success': '行程已删除',
  'edit_note': '编辑备注',
  'end_trip_failed': '无法结束行程 — 仍在跟踪中。请重试。',
  'purchase_success': "你的方案已生效。谢谢！",
  'purchase_pending': "你的付款正在处理中。Google Play 确认后方案即会生效。",
  'purchase_failed': "购买未能完成，未向你收费。请重试。",
  'play_store_unavailable': "此设备不支持 Google Play，因此无法在此购买方案。",
  'restore_purchases': "恢复购买",
  'continue_with_google': "使用 Google 继续",
  'or_divider': "或",
  'login_tagline': "每一英里，都有记录。",
  'login_welcome_back': "欢迎回来",
  'login_welcome_back_sub': "登录以继续记录每一英里。",
  'login_create_account_title': "创建账户",
  'login_create_account_sub': "几分钟内开始记录你的里程。",
  'no_account_prompt': "初次使用 ControlMiles？",
  'have_account_prompt': "已有账户？",
  'create_account': "创建账户",
  'google_sign_in_failed': "Google 登录失败。请重试或使用邮箱登录。",
  'remember_my_email': "记住我的邮箱",
  'stay_signed_in': "保持登录",
  'stay_signed_in_hint': "保持开启，以便在后台记录和检测行程。在共用手机上请关闭。",
  'odometer_below_registered_error': "此读数低于该车辆已记录的 {value} 英里。请确认选择了正确的车辆。",
  'trip_discarded_no_miles': "未记录任何里程，因此未保存此行程。",
  'enter_reset_code': '输入您邮箱收到的验证码',
  'forgot_password_body': '输入您账户的邮箱地址，我们会发送验证码以重置密码。',
  'generate_global_pdf': '生成全局 PDF',
  'greeting_afternoon': '下午好',
  'greeting_evening': '晚上好',
  'greeting_morning': '早上好',
  'irs_estimate_disclaimer': '根据 2026 年 IRS 标准里程费率估算（1月1日至6月30日每英里 \$0.725，7月1日至12月31日每英里 \$0.76 — 每次行程按其实际日期适用的费率计算）。ControlMiles 与 IRS 或任何官方机构无关联，也未获得其认可。这仅是参考性估算，并非保证的抵扣额 — 请咨询税务专业人士。',
  'irs_estimate_title': '关于此估算',
  'maintenance': '保养',
  'maintenance_record_added_success': '保养记录已添加',
  'maintenance_record_deleted_success': '保养记录已删除',
  'maintenance_type': '类型',
  'maintenance_type_battery': '电池',
  'maintenance_type_brake_service': '刹车保养',
  'maintenance_type_inspection': '检查',
  'maintenance_type_oil_change': '换机油',
  'maintenance_type_other': '其他',
  'maintenance_type_registration': '车辆登记',
  'maintenance_type_tire_rotation': '轮胎换位',
  'my_vehicle': '我的车辆',
  'new_password': '新密码',
  'next_due_date_optional': '下次到期日期（可选）',
  'next_due_odometer_optional': '下次到期里程（可选）',
  'no_maintenance_records': '暂无保养记录',
  'note_saved_success': '备注已保存',
  'notes_optional': '备注（可选）',
  'odometer_at_service': '保养时里程数',
  'password_mismatch': '密码不匹配',
  'pause_failed': '无法暂停 — 仍在跟踪中。请重试。',
  'resend_code': '重新发送验证码',
  'reset_code_hint': '验证码',
  'reset_code_sent': '请查收邮箱中的验证码',
  'reset_password_success': '密码已更新，现在可以登录了。',
  'reset_password_title': '重置密码',
  'resume_failed': '无法恢复跟踪，请重试。',
  'resume_to_switch_app': '恢复跟踪以切换活动',
  'select_vehicle': '选择车辆',
  'send_reset_code': '发送验证码',
  'service_date': '保养日期',
  'placed_in_service_date_optional': '开始使用日期（可选）',
  'vin_optional': '车辆识别码 VIN（可选）',
  'vin_helper': '如果您以后重新添加此车辆，里程表读数不能低于 ControlMiles 已为该 VIN 记录的数值。',
  'vehicle_odometer_below_floor': '此 VIN 已记录更高的里程表读数（{floor} 英里）。请输入等于或大于该值的数值。',
  'mileage_method_label': '抵扣方法',
  'mileage_method_standard': '标准里程费率',
  'mileage_method_actual': '实际费用',
  'switch_activity_failed': '无法切换活动 — 仍在跟踪之前的活动。请重试。',
  'trip_note': '行程备注',
  'trip_note_hint': '例如：「漏记5英里 — GPS信号丢失」',
  'vehicle_switch_blocked_active_session': '行程进行中无法更换当前车辆，请先结束当前行程。',
  'verify_code': '验证验证码',
  'year_miles_deduction_estimate': '预估抵扣',

  // 每周里程表检查点 (2026-09-03)
  'weekly_odometer_close_title': '每周里程表结算',
  'weekly_odometer_close_body': '要现在拍摄本周的结算里程表照片吗？',
  'weekly_odometer_close_title_mandatory': '每周结算为必填项',
  'weekly_odometer_close_body_mandatory': '请拍摄本周的结算里程表照片以继续——周日无法跳过此步骤。',
  'later': '稍后',
  'take_photo': '拍照',
  'odometer_evidence_label': '里程表照片（凭证）',
  'gps_vs_odometer_disclaimer': '这两个数字不会总是完全一致——私人（未追踪）里程不会被GPS计入，因此存在一定差异属于正常情况。',

  // ============================================================
  // VEHICLE PROFILE（只读详情页）+ 保养里程
  // ============================================================
  'vehicle_profile_title': '车辆档案',
  'tracked_miles_gps': '已记录里程（GPS）',
  'odometer_checkpoints_title': '每周里程表结算记录',
  'no_odometer_checkpoints': '暂无里程表结算记录',
  'checkpoint_week_label': '{date} 当周',
  'checkpoint_start': '起始',
  'checkpoint_end': '结算',
  'checkpoint_pending_close': '待结算',
  'current_odometer': '当前里程表读数',
  'miles_since_service': '距上次保养的里程',
  'no_service_recorded': '暂无保养记录',
  'next_service_due_miles': '下次保养里程：{miles}',
  'service_overdue_miles': '已超期 {miles}',
  'service_recommended_interval': '建议：每 {miles}',

  // ============================================================
  // 缺失键审计 (2026-09-03)
  // ============================================================
  'auth_error': '身份验证错误，请重试。',
  'header_miles_period': "首页顶部显示的里程",
  'tour_step': "第 {n}/{total} 步",
  'tour_skip': "跳过",
  'tour_next': "下一步",
  'tour_done': "开始使用",
  'tour_got_it': "知道了",
  'monitor_home_title': "校车随车员",
  'monitor_hello': "您好，{name}",
  'monitor_hint': "这是您今天的校车路线。司机开始路线后，请打开并保持学生名单最新。",
  'monitor_waiting_driver': "等待司机开始",
  'signup_check_email': "账户已创建。请确认您的邮箱，然后在此登录。",
  'signup_confirm_title': "请查看您的邮箱",
  'login_sign_in_title': "登录",
  'login_sign_in_sub': "登录后开始记录每一英里。",
  'invalid_credentials': '邮箱或密码无效。',
  'email_already_exists': '该邮箱已被注册。',
  'camera_permission_denied_error': '需要相机权限才能执行此操作。',
  'no_internet_connection_error': '没有网络连接。',
  'invalid_input_error': '请检查您输入的内容。',
  'local_storage_error': '无法在此设备上本地保存。',
  'session_expired_error': '您的会话已过期，请重新登录。',
  'vehicle_limit_reached_error': '您已达到套餐的车辆数量上限。',
  'rate_limited_error': '尝试次数过多，请几分钟后再试。',
  'duplicate_entry_error': '该项已存在。',
  'unexpected_error': '出了点问题。',
  'end': '结束',
  'navigation_error_title': '导航错误',
  'route_not_found_message': '未找到路由 {route}。\n请联系 Olympus Mont Systems。',
  'switched_label': '已切换',
  'trip_number_label': '行程 {number}',
  'trip_end_time_label': '结束：{time}',
  'sections_label': '路段',
  'vin_label': 'VIN',
  'odometer_cycle_label': '里程表周期',
  'odometer_cycle_weekly': '每周',
  'odometer_cycle_biweekly': '每两周',
  'odometer_cycle_monthly': '每月',
  'odometer_cycle_updated': '里程表周期已更新。',
  'system_initializing_redirecting': '系统初始化中，正在跳转...',
  'error_all_fields_required': '所有字段均为必填项。',
  'error_invalid_vehicle_year': '车辆年份无效。',
  'error_odometer_negative_or_empty': '里程表不能为负数或为空。',
  'error_invalid_maintenance_type': '保养类型无效。',
  'error_service_date_required': '服务日期为必填项。',
  'sections_count_label': '{count} 个路段',
  'vehicle_make_other': '其他',

  'free_trial_expired_title': '免费试用已结束',
  'free_trial_expired_body': '您的 15 天免费试用已结束。订阅 Basic 或 Premium 以继续记录行程。',
  'vehicle_limit_reached_title': '已达车辆数量上限',
  'vehicle_limit_reached_body': '您的套餐最多支持 {max} 辆车。升级套餐以添加更多车辆。',
  'export_limit_reached_title': '已达导出次数上限',
  'export_limit_reached_body': 'Basic 套餐每月可导出 2 次 PDF。升级到 Premium 可无限导出。',

  // 车队邀请链接（Sprint 1 收尾，2026-09-09）

  // 报告门户访问码，现在可在应用内生成（2026-09-09）
  'copy': '复制',
  'copied_to_clipboard': '已复制到剪贴板',
  'generate_report_code_title': '报告访问码',
  'generate_report_code_body': '为你行程的某个日期范围生成一次性代码。你的报税员在 controlmiles.com/portal/verify 输入该代码即可查看只读的里程摘要——他们无需登录或账户。',
  'generate_report_code_button': '生成代码',
  'generate_report_code_your_code': '将此代码分享给你的报税员',
  'generate_report_code_expires_in': '{mmss} 后过期',
  'generate_report_code_expired': '此代码已过期。',
  'generate_report_code_disclaimer': '最多可使用2次。本应用不保证其有效性——仅供抵扣用途参考。',
  'report_portal_section': '报告门户',
  'report_portal_section_subtitle': '为你的报税员生成一个代码',

  // 2026-09-16: claves que faltaban frente a en.dart (turno de cierre + errores de captura).
  'session_already_closed': '此会话已关闭，无法修改。',
  'session_not_found': '严重错误：未找到进行中的会话。',
  'session_already_finalized': '此会话已完成。',
  'duplicate_capture': '此事件已登记过一次拍摄记录。',
  'photo_size_out_of_range': '照片大小超出允许范围（{min}KB–{max}MB）。请重试。',
  'photo_format_not_supported': '不支持该照片格式。允许的格式：{formats}。',


  // 2026-09-16: check 'no volver a mostrar' + toggles por tipo de aviso. Traducciones best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'dont_show_again': '不再显示此提示',
  'notif_type_pause_reminder': '行程暂停提醒',
  'notif_type_forgotten_trip': '忘记结束行程提醒',
  'notif_type_weekly_summary': '每周里程汇总',
  'notif_type_gig_app_switch': '已切换零工应用',
  'notif_type_auto_trip_started': '行程已自动开始',
  'notification_types_manage_hint': '点击选择要接收的提醒',
  'notification_types_sheet_title': '提醒类型',


  // 2026-09-16: Usage Access en el onboarding de permisos + dialogo al activar auto-detect. Best-effort, no revisadas por nativos (hi/ar/ja/ko/am).
  'usage_access': '应用使用情况访问权限',
  'usage_access_desc': '让 ControlMiles 知道您打开了哪个零工应用，以便自动开始行程。',
  'usage_access_onboarding_body': '自动行程检测需要“使用情况访问权限”。安卓只能在设置中授予，无法通过普通弹窗授予。您可以先跳过，之后在设置中开启。',
  'usage_access_required_title': '需要使用情况访问权限',
  'usage_access_required_body': '没有“使用情况访问权限”，自动检测无法知道哪个零工应用已打开。请在设置中授予，然后重新开启自动检测。',

  // Gig / Fleet split (2026-10-11).
  'active_fleet_trip_error': "您在 ControlMiles Fleet 中有一个未结束的公司行程。请先在那里结束，再开始个人行程。",
  'gig_fleet_app_hint': "您为公司车队驾驶吗？公司行程请使用 ControlMiles Fleet 应用。本应用只记录您的个人里程。",
  'get_fleet_app': "下载 ControlMiles Fleet",

};