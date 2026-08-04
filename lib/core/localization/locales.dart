import 'package:flutter/widgets.dart';

/// Supported locales for Scolaris.
class AppLocales {
  AppLocales._();

  static const Locale fr = Locale('fr');
  // Autres langues retirées temporairement : traductions incomplètes.
  // static const Locale en = Locale('en');
  // static const Locale sw = Locale('sw');
  // static const Locale ln = Locale('ln');

  static const List<Locale> supported = [fr];
  static const Locale fallback = fr;
  static const String path = 'assets/translations';

  static String label(Locale l) {
    switch (l.languageCode) {
      case 'fr':
      default:
        return 'Français';
    }
  }
}
