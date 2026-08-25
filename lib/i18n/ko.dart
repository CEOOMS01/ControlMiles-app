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
  'irs_deduction_note': 'IRS 세금 공제용',
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
  'data_protected_footer': '귀하의 데이터는 보호됩니다',
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
};