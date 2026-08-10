import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../presentation/providers/nav_providers.dart';

/// Message d'erreur DB prêt à afficher à l'utilisateur.
///
/// Beaucoup de triggers Postgres (`enforce_subscription_active*`,
/// `guard_grade_period`, `guard_user_privileges`…) rédigent déjà un message
/// français directement utilisable dans leur `RAISE EXCEPTION`. Mais
/// Postgrest enveloppe tout dans `PostgrestException(message: ..., code:
/// ..., details: ..., hint: ...)` — brut, ce texte est illisible une fois
/// collé dans une SnackBar. On en extrait juste le message utile.
String friendlyDbError(Object e) {
  if (e is PostgrestException) {
    if (e.code == '42501' && e.message.trim().isNotEmpty) {
      // Message déjà rédigé pour l'utilisateur par le trigger DB.
      return e.message;
    }
    if (e.code == '23505') return 'Cette donnée existe déjà.';
    if (e.code == '23502') return 'Un champ obligatoire est manquant.';
    return 'Erreur serveur (${e.code ?? '?'}) : ${e.message}';
  }
  return e.toString();
}

/// true si l'erreur correspond au blocage « abonnement en lecture seule »
/// — même message partagé par les quatre triggers `enforce_subscription_
/// active`, `_via_fk`, `_self` et `_submitted`.
bool isSubscriptionReadOnlyError(Object e) =>
    e is PostgrestException &&
    e.code == '42501' &&
    e.message.contains('Abonnement en lecture seule');

/// Affiche une SnackBar d'erreur DB lisible. Si le blocage vient d'un
/// abonnement expiré, ajoute une action « Voir les offres » qui route vers
/// la page abonnement via [navIntentProvider] au lieu de juste dire non.
void showDbErrorSnackBar(
  BuildContext context,
  WidgetRef ref,
  Object e, {
  String? prefix,
  Color color = const Color(0xFF8B1A00),
}) {
  final messenger = ScaffoldMessenger.of(context);
  final readOnly = isSubscriptionReadOnlyError(e);
  final text = friendlyDbError(e);
  messenger.showSnackBar(SnackBar(
    content: Text(readOnly || prefix == null ? text : '$prefix : $text'),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    action: readOnly
        ? SnackBarAction(
            label: 'Voir les offres',
            textColor: Colors.white,
            onPressed: () =>
                ref.read(navIntentProvider.notifier).state = 'nav.subscription',
          )
        : null,
  ));
}
