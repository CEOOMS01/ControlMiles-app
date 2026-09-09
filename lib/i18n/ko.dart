// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/ko.dart - 한국어 (Korean)

const Map<String, String> koTexts = {
  // ============================================================
  // 애플리케이션 일반
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': '스플래시 화면',
  'not_found': '찾을 수 없음',
  'error': '오류',
  'system_error': '시스템 오류',
  'loading': '로딩 중...',
  'please_wait': '잠시만 기다려주세요...',

  // ============================================================
  // 인증
  // ============================================================
  'login': '로그인',
  'register': '회원가입',
  'signup': '계정 만들기',
  'logout': '로그아웃',
  'forgot_password': '비밀번호를 잊으셨나요?',
  'reset_password': '비밀번호 재설정',
  'auth_session_expired': '인증 세션이 만료되었습니다',
  'email': '이메일',
  'password': '비밀번호',
  'confirm_password': '비밀번호 확인',
  'sign_in': '로그인',
  'sign_up': '회원가입',
  'sign_out': '로그아웃',
  'active_activity': '활성 활동',
  'configuration_updated': '설정이 업데이트되었습니다',

  // ============================================================
  // 사용자 프로필
  // ============================================================
  'name': '이름',
  'edit_name': '이름 수정',
  'last_name': '성',
  'adress': '주소',
  'number': '번호',
  'dark_mode': '다크 모드',
  'dark_mode_description': '밝은 테마와 어두운 테마 간 전환',
  'profile_updated_success': '프로필이 성공적으로 업데이트되었습니다',
  // ============================================================
  // 내비게이션
  // ============================================================
  'dashboard': '대시보드',
  'home': '홈',
  'profile': '프로필',
  'settings': '설정',
  'help': '도움말',
  'about': '앱 정보',
  'support': '지원',

  // ============================================================
  // 트래킹
  // ============================================================
  'tracking': '트래킹',
  'tracking_active': '트래킹 진행 중',
  'tracking_paused': '일시정지됨',
  'tracking_stopped': '트래킹 중지됨',
  'start_tracking': '트래킹 시작',
  'stop_tracking': '트래킹 중지',
  'pause_tracking': '트래킹 일시정지',
  'resume_tracking': '트래킹 재개',
  'trip_details': '주행 상세정보',
  'trip_history': '주행 기록',
  'trip_ended': '주행 종료',
  'miles': '마일',
  'kilometers': '킬로미터',
  'speed': '속도',
  'duration': '시간',
  'distance': '거리',
  'start_time': '시작 시간',
  'end_time': '종료 시간',
  'select_an_activity_before_starting_tracking': '트래킹을 시작하기 전에 활동을 선택해주세요',

  // ============================================================
  // 오도미터
  // ============================================================
  'odometer': '주행계',
  'odometer_capture': '주행계 촬영',
  'start_odometer_capture': '시작 주행계 촬영',
  'end_odometer_capture': '종료 주행계 촬영',
  'capture_photo': '사진 촬영',
  'retry_camera': '카메라 다시 시도',
  'camera_error': '카메라 오류',
  'odometer_not_detected': '주행계가 감지되지 않습니다',
  'center_odometer_numbers': '주행계 숫자를 중앙에 맞춰주세요',
  'ai_processing': 'AI 처리 중',
  'validating_mileage_gps_hash': '주행거리, GPS, 해시 검증 중',


  // ============================================================
  // TRIP PURPOSES & IRS
  // ============================================================
  'select_trip_purpose': '운행 목적 선택',
  'irs_deduction_note': '공제 목적용 -- 본 앱이 이를 보장하지 않습니다',
  'business_purpose': '비즈니스 / 업무',
  'work_commute': '출퇴근',
  'medical': '의료 / 병원',
  'moving': '이사',
  'charitable': '자선 / 봉사활동',
  'education_study': '교육 / 학업',
  'personal_other': '개인 용무 / 기타',

  // ============================================================
  // GPS / 위치
  // ============================================================
  'gps': 'GPS',
  'gps_enabled': 'GPS 활성화됨',
  'gps_disabled': 'GPS 비활성화됨',
  'location_permission_required': '위치 권한이 필요합니다',
  'location_permission_denied': '위치 권한이 거부되었습니다',

  // ============================================================
  // 기록 및 보고서
  // ============================================================
  'history': '기록',
  'reports': '보고서',
  'audit_logs': '감사 로그',
  'statistics': '통계',
  'summary': '요약',
  'total_miles': '총 마일',
  'total_trips': '총 주행 횟수',
  'average_speed': '평균 속도',
  'RECENT_TRIPS': '최근 주행',
  'SEE_ALL': '모두 보기',
  'not_trips_yet': '아직 주행 기록이 없습니다',
  'generate_pdf': 'PDF 생성',

  // ============================================================
  // 설정
  // ============================================================
  'preferences': '환경설정',
  'language': '언어',
  'language_description': '원하는 언어를 선택하세요',
  'language_changed': '언어가 변경되었습니다',
  'notifications': '알림',
  'notifications_description': '앱 알림 받기',
  'notifications_enabled': '알림 활성화됨',
  'notifications_disabled': '알림 비활성화됨',
  'analytics': '분석',
  'analytics_description': '사용 데이터 공유',

  // ============================================================
  // 개인정보 보호 및 보안
  // ============================================================
  'privacy_security': '개인정보 보호 및 보안',
  'privacy_policy': '개인정보 처리방침',
  'terms_conditions': '이용약관',
  'data_security': '데이터 보안',
  'security_audit': '보안 감사',

  // ============================================================
  // 앱 정보
  // ============================================================
  'about_app': '앱 정보',
  'app_version': '앱 버전',
  'build_number': '빌드 번호',
  'company': '회사',
  'copyright': 'All rights reserved',
  'developer': '개발자',

  // ============================================================
  // 버튼
  // ============================================================
  'ok': '확인',
  'cancel': '취소',
  'save': '저장',
  'delete': '삭제',
  'edit': '수정',
  'close': '닫기',
  'refresh': '새로고침',
  'retry': '다시 시도',
  'next': '다음',
  'previous': '이전',
  'done': '완료',
  'submit': '제출',
  'continue': '계속',
  'back': '뒤로',
  'start': '시작',
  'stop': '중지',
  'pause': '일시정지',
  'resume': '재개',
  'end_trip': '주행 종료',
  'skip': '건너뛰기',
  'confirm': '확인',

  // ============================================================
  // 메시지
  // ============================================================
  'success': '성공',
  'failed': '실패',
  'warning': '경고',
  'info': '정보',
  'no_data': '데이터 없음',
  'no_results': '결과를 찾을 수 없습니다',
  'something_went_wrong': '문제가 발생했습니다',
  'please_try_again': '다시 시도해주세요',
  'network_error': '네트워크 오류',
  'internet_required': '인터넷 연결이 필요합니다',
  'offline_mode': '오프라인 모드',
  'syncing': '동기화 중...',
  'synced': '동기화 완료',
  'feature_coming_soon': '기능 준비 중',

  // ============================================================
  // 클라우드 상태
  // ============================================================
  'cloud_status': '클라우드 상태',
  'cloud_connected': '클라우드 동기화: 활성 및 안전',
  'cloud_disconnected': '클라우드 동기화: 오프라인 / 문제 발생',
  'audit_chain_healthy': '감사 체인 정상',
  'audit_chain_compromised': '감사 체인 손상됨',

  // ============================================================
  // 시간
  // ============================================================
  'today': '오늘',
  'yesterday': '어제',
  'this_week': '이번 주',
  'this_month': '이번 달',
  'this_year': '올해',
  'all_time': '전체 기간',
  'january': '1월',
  'february': '2월',
  'march': '3월',
  'april': '4월',
  'may': '5월',
  'june': '6월',
  'july': '7월',
  'august': '8월',
  'september': '9월',
  'october': '10월',
  'november': '11월',
  'december': '12월',

  // ============================================================
  // 단위
  // ============================================================
  'metric_system': '미터법',
  'meter': '미터',
  'meter_short': 'm',
  'kilometer': '킬로미터',
  'kilometer_short': 'km',
  'mile': '마일',
  'mile_short': 'mi',
  'hour': '시간',
  'minute': '분',
  'second': '초',
  'kmh': 'km/h',
  'mph': 'mph',

  // ============================================================
  // 유효성 검사
  // ============================================================
  'field_required': '이 항목은 필수입니다',
  'powered_by_footer': '제공',
  'invalid_email': '유효하지 않은 이메일 주소',
  'password_too_short': '비밀번호가 너무 짧습니다',
  'passwords_do_not_match': '비밀번호가 일치하지 않습니다',
  'invalid_input': '잘못된 입력',

  // ============================================================
  // 권한
  // ============================================================
  'permissions_required': '권한이 필요합니다',
  'camera_permission': '카메라 권한',
  'location_permission': '위치 권한',
  'storage_permission': '저장소 권한',
  'grant_permission': '권한 허용',
  'deny_permission': '권한 거부',

  // ============================================================
  // 특정 기능
  // ============================================================
  'evidence': '증거',
  'evidence_photo': '증거 사진',
  'hash_verification': '해시 검증',
  'verified': '검증됨',
  'unverified': '미검증',
  'blockchain_status': '블록체인 상태',
  'integrity_check': '무결성 검사',
  'anomaly_detection': '이상 감지',
  'fraud_alert': '사기 경고',
  'suspicious_activity': '의심스러운 활동이 감지되었습니다',

  // ============================================================
  // 차량
  // ============================================================
  'vehicle': '차량',
  'vehicles': '차량',
  'add_vehicle': '차량 추가',
  'edit_vehicle': '차량 수정',
  'delete_vehicle': '차량 삭제',
  'vehicle_make': '제조사',
  'vehicle_model': '모델',
  'vehicle_color': '색상',
  'vehicle_year': '연식',
  'vehicle_mileage': '주행거리',
  'vehicle_information': '차량 정보',
  'no_vehicle_registered': '등록된 차량이 없습니다',

  // ============================================================
  // 구독
  // ============================================================
  'subscription': '구독',
  'plan': '플랜',
  'basic_plan': '기본 플랜',
  'premium_plan': '프리미엄 플랜',
  'pro_plan': '프로 플랜',
  'upgrade_plan': '플랜 업그레이드',
  'manage_subscription': '구독 관리',
  'trial_period': '체험 기간',
  'trial_expired': '체험 기간 만료',
  'subscription_active': '구독 활성',
  'subscription_required': '구독이 필요합니다',
  'premium_plan_description': '자동 감지 및 기타 프리미엄 기능 잠금 해제. 최대 5대 차량.',
  'base_plan_description': 'ControlMiles 핵심 경험. 차량 1대.',
  'current_plan': '현재 플랜',
  'started_plan': 'Started (무료 체험)',
  'started_plan_description': '30일 무료 체험. 차량 1대.',
  'trial_days_left': '{days}일 남음',

  // ============================================================
  // 플릿
  // ============================================================
  'fleet_management': '플릿 관리',
  'fleet_vehicle': '플릿 차량',
  'fleet_dashboard': '플릿 대시보드',
  'driver_management': '운전자 관리',
  'company_account': '회사 계정',

  // ============================================================
  // 보고서
  // ============================================================
  'report_generated': '보고서 생성됨',
  'report_download': '보고서 다운로드',
  'report_verification': '보고서 검증',
  'report_qr_verification': 'QR 검증',
  'report_integrity': '보고서 무결성',

  // ============================================================
  // 세금 / IRS
  // ============================================================
  'tax_deduction': '세금 공제',
  'irs_rate': 'IRS 2026',
  'estimated_deduction': '예상 공제액',
  'tax_summary': '세금 요약',

  // ============================================================
  // QR 검증
  // ============================================================
  'verification_page': '검증 페이지',
  'scan_qr': 'QR 코드 스캔',
  'verify_report': '보고서 검증',
  'session_hash': '세션 해시',
  'section_hash': '섹션 해시',

  // ============================================================
  // 차량 폼
  // ============================================================
  'enter_vehicle_make': '차량 제조사를 입력하세요',
  'enter_vehicle_model': '차량 모델을 입력하세요',
  'enter_vehicle_color': '차량 색상을 입력하세요',
  'enter_vehicle_year': '차량 연식을 입력하세요',
  'enter_vehicle_mileage': '차량 주행거리를 입력하세요',

  // ============================================================
  // 성공 및 알림
  // ============================================================
  'vehicle_added_success': '차량이 성공적으로 추가되었습니다',
  'vehicle_deleted_success': '차량이 삭제되었습니다',
  'vehicle_saved': '차량이 저장되었습니다',
  'vehicle_required': '차량이 필요합니다',

  // ============================================================
  // VEHICLE PROFILE (읽기 전용 상세 화면) + 정비 화면의 주행거리
  // ============================================================
  'vehicle_profile_title': '차량 프로필',
  'tracked_miles_gps': '추적된 마일 (GPS)',
  'odometer_checkpoints_title': '주간 주행거리계 체크포인트',
  'no_odometer_checkpoints': '아직 주행거리계 체크포인트가 없습니다',
  'checkpoint_week_label': '{date} 주',
  'checkpoint_start': '시작',
  'checkpoint_end': '종료',
  'checkpoint_pending_close': '종료 대기 중',
  'current_odometer': '현재 주행거리계',
  'miles_since_service': '마지막 서비스 이후 마일',
  'no_service_recorded': '아직 등록된 서비스가 없습니다',
  'next_service_due_miles': '다음 서비스: {miles}',
  'service_overdue_miles': '{miles} 초과',
  'service_recommended_interval': '권장: {miles}마다',

  // ============================================================
  // 누락된 키 감사 (2026-09-03)
  // ============================================================
  'auth_error': '인증 오류입니다. 다시 시도해 주세요.',
  'invalid_credentials': '이메일 또는 비밀번호가 올바르지 않습니다.',
  'email_already_exists': '이미 등록된 이메일입니다.',
  'camera_permission_denied_error': '이 작업에는 카메라 접근 권한이 필요합니다.',
  'no_internet_connection_error': '인터넷 연결이 없습니다.',
  'invalid_input_error': '입력한 내용을 확인해 주세요.',
  'local_storage_error': '이 기기에 로컬로 저장할 수 없습니다.',
  'session_expired_error': '세션이 만료되었습니다. 다시 로그인해 주세요.',
  'vehicle_limit_reached_error': '요금제의 차량 한도에 도달했습니다.',
  'rate_limited_error': '시도 횟수가 너무 많습니다. 몇 분 후 다시 시도해 주세요.',
  'duplicate_entry_error': '이미 존재합니다.',
  'unexpected_error': '문제가 발생했습니다.',
  'end': '종료',
  'navigation_error_title': '탐색 오류',
  'route_not_found_message': '경로 {route}를 찾을 수 없습니다.\nOlympus Mont Systems에 문의하세요.',
  'switched_label': '전환됨',
  'trip_number_label': '주행 {number}',
  'trip_end_time_label': '종료: {time}',
  'sections_label': '구간',
  'vin_label': 'VIN',
  'system_initializing_redirecting': '시스템 초기화 중입니다. 이동 중...',
  'error_all_fields_required': '모든 항목은 필수입니다.',
  'error_invalid_vehicle_year': '차량 연식이 유효하지 않습니다.',
  'error_odometer_negative_or_empty': '주행거리계는 음수이거나 비어 있을 수 없습니다.',
  'error_invalid_maintenance_type': '정비 유형이 유효하지 않습니다.',
  'error_service_date_required': '서비스 날짜는 필수입니다.',
  'sections_count_label': '구간 {count}개',
  'vehicle_make_other': '기타',
  'email_not_linked_to_controlmiles': '이 이메일은 ControlMiles 계정에 연결되어 있지 않습니다.',

  'free_trial_expired_title': '무료 체험이 종료되었습니다',
  'free_trial_expired_body': '30일 무료 체험이 종료되었습니다. 계속 이동 기록을 추적하려면 Basic 또는 Premium을 구독하세요.',
  'vehicle_limit_reached_title': '차량 한도에 도달했습니다',
  'vehicle_limit_reached_body': '현재 플랜은 최대 {max}대의 차량을 지원합니다. 더 추가하려면 업그레이드하세요.',
  'export_limit_reached_title': '내보내기 한도에 도달했습니다',
  'export_limit_reached_body': 'Basic 플랜은 월 2회 PDF 내보내기를 포함합니다. 무제한 내보내기를 위해 Premium으로 업그레이드하세요.',

  // Weekly odometer checkpoint (2026-09-03), added 2026-09-08 -- was
  // missing entirely for this language (dialog fell back to raw keys).
  'weekly_odometer_close_title': '주간 주행거리계 마감',
  'weekly_odometer_close_body': '지금 이번 주 마감 주행거리계 사진을 찍으시겠습니까?',
  'weekly_odometer_close_title_mandatory': '주간 마감이 필수입니다',
  'weekly_odometer_close_body_mandatory': '계속하려면 이번 주 마감 주행거리계 사진을 찍어야 합니다 -- 일요일에는 건너뛸 수 없습니다.',
  'later': '나중에',
  'take_photo': '사진 찍기',
  'odometer_evidence_label': '주행거리계 사진(증빙)',
  'gps_vs_odometer_disclaimer': '이 숫자들은 항상 정확히 일치하지 않을 수 있습니다 -- 개인(추적되지 않은) 마일은 GPS에 집계되지 않으므로 약간의 차이는 정상입니다.',

  // 플릿 초대 링크 (Sprint 1 마무리, 2026-09-09)
  'invite_landing_title': '{org}에서 가입을 초대했습니다',
  'invite_confirm_body': '{org}에서 귀하를 자사 플릿에 초대했습니다. 수락하시겠습니까?',
  'invite_login_prompt': '이 초대를 수락하려면 비밀번호를 입력하세요.',
  'invite_signup_prompt': '이 플릿에 가입하려면 계정을 만드세요.',
  'invite_accept_button': '초대 수락',
  'invite_invalid_title': '유효하지 않거나 만료된 초대',
  'invite_invalid_body': '이 초대 링크는 더 이상 유효하지 않습니다. 플릿 관리자에게 새 링크를 요청하세요.',
  'invite_confirm_email_first': '이메일을 확인하여 계정을 인증한 후 이 초대 링크를 다시 여세요.',

  // 듀얼 컨텍스트 전환기 (Fleet Sprint 2, 2026-09-09)
  'org_mode_personal': '개인',
  'org_mode_company': '회사: {org}',

  // 근무 종료 잠금 화면 (Fleet Sprint 3, 2026-09-09)
  'shift_ended_title': '근무 종료됨',
  'shift_ended_body': '다음 근무가 시작될 때까지 앱에 접근할 수 없습니다.',
  'shift_ended_start_next': '다음 근무 시작',

  // 접근 권한 취소 (Fleet Sprint 3, 2026-09-09)
  'org_access_revoked_title': '플릿 접근 권한이 제거되었습니다',
  'org_access_revoked_body': '플릿 관리자가 이 조직에 대한 귀하의 접근 권한을 제거했습니다. 계속하려면 로그아웃하세요.',

  // 개방형/순환 차량 배정 (Fleet Sprint 4, 2026-09-09)
  'fleet_select_vehicle_button': '차량 선택',
  'fleet_vehicle_picker_title': '차량 선택',
  'fleet_vehicle_picker_empty': '지금은 이용 가능한 차량이 없습니다 -- 모든 플릿 차량이 현재 사용 중입니다.',

  // 리포트 포털 접근 코드, 이제 앱 내에서 생성 (2026-09-09)
  'copy': '복사',
  'copied_to_clipboard': '클립보드에 복사됨',
  'generate_report_code_title': '보고서 접근 코드',
  'generate_report_code_body': '여행 날짜 범위에 대한 일회용 코드를 생성하세요. 세무 담당자가 controlmiles.com/portal/verify에서 이 코드를 입력하여 읽기 전용 주행거리 요약을 볼 수 있습니다 -- 로그인이나 계정이 필요하지 않습니다.',
  'generate_report_code_button': '코드 생성',
  'generate_report_code_your_code': '이 코드를 세무 담당자와 공유하세요',
  'generate_report_code_expires_in': '{mmss} 후 만료',
  'generate_report_code_expired': '이 코드는 만료되었습니다.',
  'generate_report_code_disclaimer': '최대 2회까지 사용 가능합니다. 이 앱이 보증하지 않습니다 -- 공제 목적으로만 사용하세요.',
  'report_portal_section': '리포트 포털',
  'report_portal_section_subtitle': '세무 담당자를 위한 코드를 생성하세요',
};