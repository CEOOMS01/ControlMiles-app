// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/app_texts.dart - GLOBAL PRODUCTION VERSION

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'en.dart';
import 'es.dart';
import 'fr.dart';
import 'hi.dart';
import 'ar.dart';
import 'zh.dart';
import 'pt.dart';
import 'ja.dart';
import 'am.dart'; // Amharic
import 'de.dart'; // German
import 'ko.dart'; // Korean

// ============================================================
// ENUM: IDIOMAS SOPORTADOS
// ============================================================

enum AppLanguage {
  en,
  es,
  fr,
  hi,
  ar,
  zh,
  pt,
  ja,
  am,
  de,
  ko
}

// ============================================================
// EXTENSION: METADATOS DEL IDIOMA
// ============================================================

extension AppLanguageExtension on AppLanguage {

  /// Getter para obtener el código ISO del idioma (Soluciona errores de compilación)
  String get code {
    switch (this) {
      case AppLanguage.en: return "en";
      case AppLanguage.es: return "es";
      case AppLanguage.fr: return "fr";
      case AppLanguage.hi: return "hi";
      case AppLanguage.ar: return "ar";
      case AppLanguage.zh: return "zh";
      case AppLanguage.pt: return "pt";
      case AppLanguage.ja: return "ja";
      case AppLanguage.am: return "am";
      case AppLanguage.de: return "de";
      case AppLanguage.ko: return "ko";
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.en: return 'English';
      case AppLanguage.es: return 'Español';
      case AppLanguage.fr: return 'Français';
      case AppLanguage.hi: return 'हिन्दी';
      case AppLanguage.ar: return 'العربية';
      case AppLanguage.zh: return '中文';
      case AppLanguage.pt: return 'Português';
      case AppLanguage.ja: return '日本語';
      case AppLanguage.am: return 'አማርኛ';
      case AppLanguage.de: return 'Deutsch';
      case AppLanguage.ko: return '한국어';
    }
  }

  String get flag {
    switch (this) {
      case AppLanguage.en: return '🇺🇸';
      case AppLanguage.es: return '🇪🇸';
      case AppLanguage.fr: return '🇫🇷';
      case AppLanguage.hi: return '🇮🇳';
      case AppLanguage.ar: return '🇸🇦';
      case AppLanguage.zh: return '🇨🇳';
      case AppLanguage.pt: return '🇧🇷';
      case AppLanguage.ja: return '🇯🇵';
      case AppLanguage.am: return '🇪🇹';
      case AppLanguage.de: return '🇩🇪';
      case AppLanguage.ko: return '🇰🇷';
    }
  }

  /// RTL solo para árabe
  TextDirection get textDirection {
    return this == AppLanguage.ar
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  static AppLanguage fromCode(String? code) {
    try {
      return AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.en,
      );
    } catch (_) {
      return AppLanguage.en;
    }
  }
}

// ============================================================
// CLASS: DATOS DE UN IDIOMA
// ============================================================

class LanguageData {
  final String code;
  final Map<String, String> texts;

  const LanguageData({
    required this.code,
    required this.texts,
  });
}

// ============================================================
// CLASS: PUNTO CENTRAL DE TRADUCCIONES
// ============================================================

class AppTexts {

  static final Map<AppLanguage, LanguageData> _languages = {
    AppLanguage.en: LanguageData(code: 'en', texts: enTexts),
    AppLanguage.es: LanguageData(code: 'es', texts: esTexts),
    AppLanguage.fr: LanguageData(code: 'fr', texts: frTexts),
    AppLanguage.hi: LanguageData(code: 'hi', texts: hiTexts),
    AppLanguage.ar: LanguageData(code: 'ar', texts: arTexts),
    AppLanguage.zh: LanguageData(code: 'zh', texts: zhTexts),
    AppLanguage.pt: LanguageData(code: 'pt', texts: ptTexts),
    AppLanguage.ja: LanguageData(code: 'ja', texts: jaTexts),
    AppLanguage.am: LanguageData(code: 'am', texts: amTexts),
    AppLanguage.de: LanguageData(code: 'de', texts: deTexts),
    AppLanguage.ko: LanguageData(code: 'ko', texts: koTexts),
  };

  /// Obtener texto traducido
  static String get(String key, String langCode) {
    final lang = AppLanguageExtension.fromCode(langCode);
    final text = _languages[lang]?.texts[key];

    if (text == null) {
      if (kDebugMode) {
        debugPrint('[AppTexts] Missing key "$key" in $langCode');
      }
      return key;
    }

    return text;
  }

  /// acceso rápido
  static String getText(String key, AppLanguage language) {
    return _languages[language]?.texts[key] ?? key;
  }

  static List<AppLanguage> get supported => AppLanguage.values;

  static List<String> get codes =>
      AppLanguage.values.map((e) => e.code).toList();
}