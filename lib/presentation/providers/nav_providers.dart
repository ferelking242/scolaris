import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Intention de navigation interne au shell : une page (widget, ex. le tableau
/// de bord) demande au shell d'aller vers l'entrée de nav portant ce `labelKey`
/// (ex. 'nav.users'). Le shell écoute, change d'onglet, puis remet à `null`.
///
/// Permet aux « actions rapides » du dashboard de naviguer sans coupler le
/// contenu au shell.
final navIntentProvider = StateProvider<String?>((ref) => null);
