// Olympus Mont Systems LLC - ControlMiles
// lib/i18n/app_texts.dart - GLOBAL PRODUCTION VERSION
//
// 2026-11-06: five languages -- English, Spanish, French, Chinese and Hindi.
// Portuguese, Arabic, Japanese, Korean, German and Amharic were taken out (their
// files are kept in reference/i18n_removed_2026-11-06/). A driver whose saved
// language was one of them opens the app in English.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'en.dart';
import 'es.dart';
import 'fr.dart';
import 'hi.dart';
import 'zh.dart';

// ============================================================
// ENUM: IDIOMAS SOPORTADOS
// ============================================================

enum AppLanguage {
  en,
  es,
  fr,
  zh,
  hi,
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
      case AppLanguage.zh: return "zh";
      case AppLanguage.hi: return "hi";
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.en: return 'English';
      case AppLanguage.es: return 'Español';
      case AppLanguage.fr: return 'Français';
      case AppLanguage.zh: return '中文';
      case AppLanguage.hi: return 'हिन्दी';
    }
  }

  String get flag {
    switch (this) {
      case AppLanguage.en: return '🇺🇸';
      case AppLanguage.es: return '🇪🇸';
      case AppLanguage.fr: return '🇫🇷';
      case AppLanguage.zh: return '🇨🇳';
      case AppLanguage.hi: return '🇮🇳';
    }
  }

  /// None of the five languages is written right to left.
  TextDirection get textDirection => TextDirection.ltr;

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
    AppLanguage.zh: LanguageData(code: 'zh', texts: zhTexts),
    AppLanguage.hi: LanguageData(code: 'hi', texts: hiTexts),
  };

  /// Obtener texto traducido
  static String get(String key, String langCode) {
    final lang = AppLanguageExtension.fromCode(langCode);
    final text = _languages[lang]?.texts[key];

    if (text == null) {
      if (kDebugMode) {
        debugPrint('[AppTexts] Missing key "$key" in $langCode');
      }
      return enTexts[key] ?? key;
    }

    return text;
  }

  /// acceso rápido
  static String getText(String key, AppLanguage language) {
    // English fallback so a key that's missing in one language never
    // shows up as a raw key on screen.
    return _languages[language]?.texts[key] ?? enTexts[key] ?? key;
  }

  static List<AppLanguage> get supported => AppLanguage.values;

  static List<String> get codes =>
      AppLanguage.values.map((e) => e.code).toList();
}
