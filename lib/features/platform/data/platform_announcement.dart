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

  /// Clé stockée en base (colonne `audience`).
  String get code => switch (this) {
        AnnouncementAudience.all => 'all',
        AnnouncementAudience.paying => 'paying',
        AnnouncementAudience.trials => 'trials',
        AnnouncementAudience.pastDue => 'past_due',
      };

  /// Nombre d'écoles ciblées par cette audience, sur la liste RÉELLE fournie
  /// (cf. `platformSchoolsProvider`) — plus de dépendance à `PlatformMock`.
  int reachAmong(List<PlatformSchool> schools) => switch (this) {
        AnnouncementAudience.all => schools.length,
        AnnouncementAudience.paying => schools.where((s) => s.isPaying).length,
        AnnouncementAudience.trials =>
          schools.where((s) => s.status == SubStatus.trial).length,
        AnnouncementAudience.pastDue =>
          schools.where((s) => s.status == SubStatus.pastDue).length,
      };
}

AnnouncementAudience audienceFromCode(String? code) => switch (code) {
      'paying' => AnnouncementAudience.paying,
      'trials' => AnnouncementAudience.trials,
      'past_due' => AnnouncementAudience.pastDue,
      _ => AnnouncementAudience.all,
    };

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

  /// Clé stockée en base (colonne `kind`).
  String get code => switch (this) {
        AnnouncementKind.info => 'info',
        AnnouncementKind.maintenance => 'maintenance',
        AnnouncementKind.feature => 'feature',
      };
}

AnnouncementKind kindFromCode(String? code) => switch (code) {
      'maintenance' => AnnouncementKind.maintenance,
      'feature' => AnnouncementKind.feature,
      _ => AnnouncementKind.info,
    };

/// Une annonce diffusée aux écoles — table `platform_announcements`.
class PlatformAnnouncement {
  final String id;
  final String title;
  final String body;
  final AnnouncementAudience audience;
  final AnnouncementKind kind;
  final DateTime date;

  /// Nombre d'écoles atteintes au moment de la diffusion (figé).
  final int reach;

  /// Date à partir de laquelle l'annonce arrête d'être distribuée (null =
  /// pas d'expiration).
  final DateTime? expiresAt;

  /// Dépubliée manuellement depuis la console (null = toujours active).
  final DateTime? archivedAt;

  bool get isActive => archivedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  const PlatformAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.kind,
    required this.date,
    required this.reach,
    this.expiresAt,
    this.archivedAt,
  });
}

