import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'platform_mock_data.dart';

/// Public visé par une annonce plateforme.
enum AnnouncementAudience { all, paying, trials, pastDue }

extension AnnouncementAudienceX on AnnouncementAudience {
  String get label => switch (this) {
        AnnouncementAudience.all => 'Toutes les écoles',
        AnnouncementAudience.paying => 'Écoles payantes',
        AnnouncementAudience.trials => 'Écoles en essai',
        AnnouncementAudience.pastDue => 'Écoles en impayé',
      };

  /// Nombre d'écoles ciblées (calculé sur les données actuelles).
  int get reach => switch (this) {
        AnnouncementAudience.all => PlatformMock.total,
        AnnouncementAudience.paying => PlatformMock.paying,
        AnnouncementAudience.trials => PlatformMock.trials,
        AnnouncementAudience.pastDue => PlatformMock.schools
            .where((s) => s.status == SubStatus.pastDue)
            .length,
      };
}

/// Nature de l'annonce (change l'icône / la couleur).
enum AnnouncementKind { info, maintenance, feature }

extension AnnouncementKindX on AnnouncementKind {
  String get label => switch (this) {
        AnnouncementKind.info => 'Information',
        AnnouncementKind.maintenance => 'Maintenance',
        AnnouncementKind.feature => 'Nouveauté',
      };

  IconData get icon => switch (this) {
        AnnouncementKind.info => Icons.campaign_rounded,
        AnnouncementKind.maintenance => Icons.build_rounded,
        AnnouncementKind.feature => Icons.auto_awesome_rounded,
      };

  Color get color => switch (this) {
        AnnouncementKind.info => ScolarisAccents.sapphire,
        AnnouncementKind.maintenance => ScolarisPalette.orange,
        AnnouncementKind.feature => ScolarisPalette.forestGreen,
      };
}

/// Une annonce diffusée aux écoles (mock — futur `platform_announcements`).
class PlatformAnnouncement {
  final String title;
  final String body;
  final AnnouncementAudience audience;
  final AnnouncementKind kind;
  final DateTime date;

  /// Nombre d'écoles atteintes au moment de la diffusion (figé).
  final int reach;

  const PlatformAnnouncement({
    required this.title,
    required this.body,
    required this.audience,
    required this.kind,
    required this.date,
    required this.reach,
  });
}

/// Magasin d'annonces — **maquette** (état en mémoire). En prod, diffusion via
/// une Edge Function `broadcast` (notifications + bannière in-app par école).
class PlatformAnnouncements {
  PlatformAnnouncements._();

  static final List<PlatformAnnouncement> items = [
    PlatformAnnouncement(
      title: 'Nouveau : bulletins PDF personnalisables',
      body: 'Vous pouvez désormais adapter l\'en-tête et le pied de page de vos '
          'bulletins depuis Réglages › Bulletins.',
      audience: AnnouncementAudience.all,
      kind: AnnouncementKind.feature,
      date: PlatformMock.now.subtract(const Duration(days: 4)),
      reach: 7,
    ),
    PlatformAnnouncement(
      title: 'Maintenance planifiée samedi 04:00–05:00',
      body: 'Scolaris sera momentanément indisponible pour une mise à jour. '
          'Aucune donnée ne sera perdue.',
      audience: AnnouncementAudience.all,
      kind: AnnouncementKind.maintenance,
      date: PlatformMock.now.subtract(const Duration(days: 12)),
      reach: 6,
    ),
    PlatformAnnouncement(
      title: 'Votre période d\'essai se termine bientôt',
      body: 'Passez à une offre payante pour continuer à profiter de toutes les '
          'fonctionnalités sans interruption.',
      audience: AnnouncementAudience.trials,
      kind: AnnouncementKind.info,
      date: PlatformMock.now.subtract(const Duration(days: 20)),
      reach: 2,
    ),
  ];

  static PlatformAnnouncement publish({
    required String title,
    required String body,
    required AnnouncementAudience audience,
    required AnnouncementKind kind,
  }) {
    final a = PlatformAnnouncement(
      title: title.trim(),
      body: body.trim(),
      audience: audience,
      kind: kind,
      date: PlatformMock.now,
      reach: audience.reach,
    );
    items.insert(0, a); // plus récente en haut
    return a;
  }
}
