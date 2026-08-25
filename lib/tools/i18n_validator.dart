// ignore_for_file: avoid_print
// Standalone CLI script (dart run lib/tools/i18n_validator.dart), never
// part of the app's runtime -- print() to stdout is the entire point here,
// not something to swap for debugPrint (a Flutter-widget-tree debugging
// tool with truncation behavior that doesn't fit a CLI script).

import '../i18n/en.dart';
import '../i18n/es.dart';
import '../i18n/fr.dart';
import '../i18n/hi.dart';
import '../i18n/ar.dart';
import '../i18n/zh.dart';
import '../i18n/pt.dart';
import '../i18n/ja.dart';
import '../i18n/am.dart';
import '../i18n/de.dart';
import '../i18n/ko.dart';

void main() {
  // Usamos el archivo de inglés como la fuente de verdad (base)
  final base = enTexts.keys.toSet();

  void check(String lang, Map<String, String> map) {
    final missing = base.difference(map.keys.toSet());
    final extra = map.keys.toSet().difference(base);

    print('----------------------------');
    print('Checking $lang');

    if (missing.isEmpty) {
      print('✅ No missing keys');
    } else {
      print('❌ Missing keys (${missing.length}):');
      for (final key in missing) {
        print('  - $key');
      }
    }

    if (extra.isNotEmpty) {
      print('⚠️ Extra keys (${extra.length}):');
      for (final key in extra) {
        print('  - $key');
      }
    }
  }

  // Validar los 10 idiomas adicionales contra el inglés
  check("Spanish", esTexts);
  check("French", frTexts);
  check("Hindi", hiTexts);
  check("Arabic", arTexts);
  check("Chinese", zhTexts);
  check("Portuguese", ptTexts);
  check("Japanese", jaTexts);
  check("Amharic", amTexts);
  check("German", deTexts);
  check("Korean", koTexts);

  print('----------------------------');
  print('Validation Process Finished');
}