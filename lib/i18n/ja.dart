// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/ja.dart - 日本語 (Japanese)

const Map<String, String> jaTexts = {
  // ============================================================
  // アプリケーション全般
  // ============================================================
  'app_name': 'ControlMiles',
  'splash': '起動画面',
  'not_found': '見つかりません',
  'error': 'エラー',
  'system_error': 'システムエラー',
  'loading': '読み込み中...',
  'please_wait': 'お待ちください...',

  // ============================================================
  // 認証
  // ============================================================
  'login': 'ログイン',
  'register': '登録',
  'signup': 'アカウント作成',
  'logout': 'ログアウト',
  'forgot_password': 'パスワードをお忘れですか？',
  'reset_password': 'パスワードをリセット',
  'auth_session_expired': '認証セッションが期限切れです',
  'email': 'メールアドレス',
  'password': 'パスワード',
  'confirm_password': 'パスワード確認',
  'sign_in': 'ログイン',
  'sign_up': 'アカウント作成',
  'sign_out': 'ログアウト',
  'active_activity': 'アクティブな活動',
  'configuration_updated': '設定を更新しました',

  // ============================================================
  // ユーザープロフィール
  // ============================================================
  'name': '名前',
  'edit_name': '名前を編集',
  'last_name': '姓',
  'adress': '住所',
  'number': '番号',
  'dark_mode': 'ダークモード',
  'dark_mode_description': 'ライトテーマとダークテーマを切り替える',
  'profile_updated_success': 'プロフィールが正常に更新されました',
  // ============================================================
  // ナビゲーション
  // ============================================================
  'dashboard': 'ダッシュボード',
  'home': 'ホーム',
  'profile': 'プロフィール',
  'settings': '設定',
  'help': 'ヘルプ',
  'about': 'アプリについて',
  'support': 'サポート',

  // ============================================================
  // トラッキング
  // ============================================================
  'tracking': 'トラッキング',
  'tracking_active': 'トラッキング中',
  'tracking_paused': '一時停止中',
  'tracking_stopped': 'トラッキング停止',
  'start_tracking': 'トラッキング開始',
  'stop_tracking': 'トラッキング停止',
  'pause_tracking': '一時停止',
  'resume_tracking': '再開',
  'trip_details': '走行詳細',
  'trip_history': '走行履歴',
  'trip_ended': '走行終了',
  'miles': 'マイル',
  'kilometers': 'キロメートル',
  'speed': '速度',
  'duration': '時間',
  'distance': '距離',
  'start_time': '開始時間',
  'end_time': '終了時間',
  'select_an_activity_before_starting_tracking': 'トラッキングを開始する前に活動を選択してください',

  // ============================================================
  // オドメーター
  // ============================================================
  'odometer': 'オドメーター',
  'odometer_capture': 'オドメーター撮影',
  'start_odometer_capture': '開始オドメーターを撮影',
  'end_odometer_capture': '終了オドメーターを撮影',
  'capture_photo': '写真を撮影',
  'retry_camera': 'カメラを再試行',
  'camera_error': 'カメラエラー',
  'odometer_not_detected': 'オドメーターが検出されません',
  'center_odometer_numbers': 'オドメーターの数字を中央に合わせる',
  'ai_processing': 'AI処理中',
  'validating_mileage_gps_hash': '走行距離、GPS、ハッシュを検証中',

  // ============================================================
  // GPS / 位置情報
  // ============================================================
  'gps': 'GPS',
  'gps_enabled': 'GPS有効',
  'gps_disabled': 'GPS無効',
  'location_permission_required': '位置情報の許可が必要です',
  'location_permission_denied': '位置情報の許可が拒否されました',

  // ============================================================
  // 履歴とレポート
  // ============================================================
  'history': '履歴',
  'reports': 'レポート',
  'audit_logs': '監査ログ',
  'statistics': '統計',
  'summary': '概要',
  'total_miles': '総マイル',
  'total_trips': '総走行回数',
  'average_speed': '平均速度',
  'RECENT_TRIPS': '最近の走行',
  'SEE_ALL': 'すべて表示',
  'not_trips_yet': 'まだ走行がありません',
  'generate_pdf': 'PDFを生成',


  // ============================================================
  // TRIP PURPOSES & IRS (JAPANESE - 日本語)
  // ============================================================
  'select_trip_purpose': '走行目的を選択',
  'irs_deduction_note': 'IRS（内国歳入庁）の所得控除用',
  'business_purpose': 'ビジネス / 業務',
  'work_commute': '通勤',
  'medical': '医療 / 通院',
  'moving': '引越し',
  'charitable': '慈善活動 / ボランティア',
  'education_study': '教育 / 学習',
  'personal_other': '個人用 / その他',
  // ============================================================
  // 設定
  // ============================================================
  'preferences': '設定',
  'language': '言語',
  'language_description': '希望の言語を選択してください',
  'language_changed': '言語を変更しました',
  'notifications': '通知',
  'notifications_description': 'アプリの通知を受け取る',
  'notifications_enabled': '通知が有効です',
  'notifications_disabled': '通知が無効です',
  'analytics': '分析',
  'analytics_description': '使用データを共有',

  // ============================================================
  // プライバシーとセキュリティ
  // ============================================================
  'privacy_security': 'プライバシーとセキュリティ',
  'privacy_policy': 'プライバシーポリシー',
  'terms_conditions': '利用規約',
  'data_security': 'データセキュリティ',
  'security_audit': 'セキュリティ監査',

  // ============================================================
  // アプリについて
  // ============================================================
  'about_app': 'アプリについて',
  'app_version': 'アプリバージョン',
  'build_number': 'ビルド番号',
  'company': '会社',
  'copyright': 'All rights reserved',
  'developer': '開発者',

  // ============================================================
  // ボタン
  // ============================================================
  'ok': 'OK',
  'cancel': 'キャンセル',
  'save': '保存',
  'delete': '削除',
  'edit': '編集',
  'close': '閉じる',
  'refresh': '更新',
  'retry': '再試行',
  'next': '次へ',
  'previous': '前へ',
  'done': '完了',
  'submit': '送信',
  'continue': '続行',
  'back': '戻る',
  'start': '開始',
  'stop': '停止',
  'pause': '一時停止',
  'resume': '再開',
  'end_trip': '走行終了',
  'skip': 'スキップ',
  'confirm': '確認',

  // ============================================================
  // メッセージ
  // ============================================================
  'success': '成功',
  'failed': '失敗',
  'warning': '警告',
  'info': '情報',
  'no_data': 'データがありません',
  'no_results': '結果が見つかりません',
  'something_went_wrong': '問題が発生しました',
  'please_try_again': 'もう一度お試しください',
  'network_error': 'ネットワークエラー',
  'internet_required': 'インターネット接続が必要です',
  'offline_mode': 'オフラインモード',
  'syncing': '同期中...',
  'synced': '同期完了',
  'feature_coming_soon': '近日公開予定',

  // ============================================================
  // クラウドステータス
  // ============================================================
  'cloud_status': 'クラウド状態',
  'cloud_connected': 'クラウド同期：有効かつ安全',
  'cloud_disconnected': 'クラウド同期：オフライン / 問題あり',
  'audit_chain_healthy': '監査チェーンは正常です',
  'audit_chain_compromised': '監査チェーンが破損しています',

  // ============================================================
  // 時間
  // ============================================================
  'today': '今日',
  'yesterday': '昨日',
  'this_week': '今週',
  'this_month': '今月',
  'this_year': '今年',
  'all_time': '全期間',
  'january': '1月',
  'february': '2月',
  'march': '3月',
  'april': '4月',
  'may': '5月',
  'june': '6月',
  'july': '7月',
  'august': '8月',
  'september': '9月',
  'october': '10月',
  'november': '11月',
  'december': '12月',

  // ============================================================
  // 単位
  // ============================================================
  'metric_system': 'メートル法',
  'meter': 'メートル',
  'meter_short': 'm',
  'kilometer': 'キロメートル',
  'kilometer_short': 'km',
  'mile': 'マイル',
  'mile_short': 'mi',
  'hour': '時間',
  'minute': '分',
  'second': '秒',
  'kmh': 'km/h',
  'mph': 'mph',

  // ============================================================
  // バリデーション
  // ============================================================
  'field_required': 'この項目は必須です',
  'data_protected_footer': 'あなたのデータは保護されています',
  'invalid_email': 'メールアドレスが無効です',
  'password_too_short': 'パスワードが短すぎます',
  'passwords_do_not_match': 'パスワードが一致しません',
  'invalid_input': '入力が無効です',

  // ============================================================
  // 権限
  // ============================================================
  'permissions_required': '権限が必要です',
  'camera_permission': 'カメラ権限',
  'location_permission': '位置情報権限',
  'storage_permission': 'ストレージ権限',
  'grant_permission': '権限を許可',
  'deny_permission': '権限を拒否',

  // ============================================================
  // 特定機能
  // ============================================================
  'evidence': '証拠',
  'evidence_photo': '証拠写真',
  'hash_verification': 'ハッシュ検証',
  'verified': '検証済み',
  'unverified': '未検証',
  'blockchain_status': 'ブロックチェーン状態',
  'integrity_check': '整合性チェック',
  'anomaly_detection': '異常検知',
  'fraud_alert': '不正アラート',
  'suspicious_activity': '不審な活動が検出されました',

  // ============================================================
  // 車両
  // ============================================================
  'vehicle': '車両',
  'vehicles': '車両',
  'add_vehicle': '車両を追加',
  'edit_vehicle': '車両を編集',
  'delete_vehicle': '車両を削除',
  'vehicle_make': 'メーカー',
  'vehicle_model': 'モデル',
  'vehicle_color': '色',
  'vehicle_year': '年式',
  'vehicle_mileage': '走行距離',
  'vehicle_information': '車両情報',
  'no_vehicle_registered': '登録された車両がありません',

  // ============================================================
  // サブスクリプション
  // ============================================================
  'subscription': 'サブスクリプション',
  'plan': 'プラン',
  'basic_plan': 'ベーシックプラン',
  'premium_plan': 'プレミアムプラン',
  'pro_plan': 'プロプラン',
  'upgrade_plan': 'プランをアップグレード',
  'manage_subscription': 'サブスクリプション管理',
  'trial_period': 'トライアル期間',
  'trial_expired': 'トライアル期間が終了しました',
  'subscription_active': 'サブスクリプション有効',
  'subscription_required': 'サブスクリプションが必要です',

  // ============================================================
  // フリート
  // ============================================================
  'fleet_management': 'フリート管理',
  'fleet_vehicle': 'フリート車両',
  'fleet_dashboard': 'フリートダッシュボード',
  'driver_management': 'ドライバー管理',
  'company_account': '会社アカウント',

  // ============================================================
  // レポート
  // ============================================================
  'report_generated': 'レポート生成済み',
  'report_download': 'レポートをダウンロード',
  'report_verification': 'レポート検証',
  'report_qr_verification': 'QR検証',
  'report_integrity': 'レポートの完全性',

  // ============================================================
  // 税金 / IRS
  // ============================================================
  'tax_deduction': '税控除',
  'irs_rate': 'IRS 2026',
  'estimated_deduction': '推定控除額',
  'tax_summary': '税務概要',

  // ============================================================
  // QR検証
  // ============================================================
  'verification_page': '検証ページ',
  'scan_qr': 'QRコードをスキャン',
  'verify_report': 'レポートを検証',
  'session_hash': 'セッションハッシュ',
  'section_hash': 'セクションハッシュ',

  // ============================================================
  // 車両フォーム
  // ============================================================
  'enter_vehicle_make': '車両のメーカーを入力',
  'enter_vehicle_model': '車両のモデルを入力',
  'enter_vehicle_color': '車両の色を入力',
  'enter_vehicle_year': '車両の年式を入力',
  'enter_vehicle_mileage': '車両の走行距離を入力',

  // ============================================================
  // 成功とアラート
  // ============================================================
  'vehicle_added_success': '車両が正常に追加されました',
  'vehicle_deleted_success': '車両が削除されました',
  'vehicle_saved': '車両が保存されました',
  'vehicle_required': '車両が必要です',
};