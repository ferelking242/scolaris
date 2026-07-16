import 'package:flutter/widgets.dart';

/// Supported locales for Scolaris.
class AppLocales {
  AppLocales._();

  static const Locale en = Locale('en');
  static const Locale fr = Locale('fr');
  static const Locale sw = Locale('sw');
  static const Locale ln = Locale('ln'); // Lingala

  static const List<Locale> supported = [en, fr, sw, ln];
  static const Locale fallback = en;
  static const String path = 'assets/translations';

  static String label(Locale l) {
    switch (l.languageCode) {
      case 'fr':
        return 'Français';
      case 'sw':
        return 'Kiswahili';
      case 'ln':
        return 'Lingála';
      case 'en':
      default:
        return 'English';
    }
  }
}
