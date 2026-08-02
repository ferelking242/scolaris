import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_announcement.dart';
import '../data/platform_mock_data.dart';
import '../data/platform_repository.dart';

/// École actuellement ouverte dans la console (vue détail inline). `null` = on
/// affiche la liste. Partagé pour que le tableau de bord puisse aussi ouvrir
/// une école (en basculant sur l'onglet « Écoles »).
final selectedPlatformSchoolProvider =
    StateProvider<PlatformSchool?>((ref) => null);

/// Les vraies écoles (remplace `PlatformMock.schools` au Dashboard). Nécessite
/// que le compte connecté soit un admin plateforme (cf.
/// 20260757_platform_dashboard_read.sql) — sinon la RLS ne renverrait rien.
final platformSchoolsProvider =
    FutureProvider<List<PlatformSchool>>((ref) => PlatformRepository.getSchools());

/// Nombre total d'élèves, toutes écoles confondues.
final platformTotalStudentsProvider =
    FutureProvider<int>((ref) => PlatformRepository.getTotalStudents());

/// Versements d'abonnement en attente de vérification, toutes écoles.
final platformPendingPaymentsProvider = FutureProvider<List<PlatformPendingPayment>>(
    (ref) => PlatformRepository.getPendingSubscriptionPayments());

/// Tarifs réels des offres (Congo/XAF/mensuel) — page Réglages.
final platformPlanSettingsProvider = FutureProvider<
    Map<PlatformPlan, ({int price, int? limit})>>(
  (ref) => PlatformRepository.getPlanSettings(),
);

/// Équipe super-admin réelle (lecture seule) — page Réglages.
final platformAdminsProvider =
    FutureProvider<List<({String email, String fullName})>>(
  (ref) => PlatformRepository.getPlatformAdmins(),
);

/// Roster réel des élèves d'une école — onglet Élèves de la fiche.
final platformSchoolStudentsProvider = FutureProvider.autoDispose
    .family<List<PlatformStudentRow>, String>(
  (ref, schoolId) => PlatformRepository.getSchoolStudents(schoolId),
);

/// Historique réel des paiements d'abonnement d'une école — onglet Facturation.
final platformSchoolPaymentsProvider = FutureProvider.autoDispose
    .family<List<PlatformPayment>, String>(
  (ref, schoolId) => PlatformRepository.getSchoolPayments(schoolId),
);

/// Vrai journal d'événements d'une école — onglets Activité/Journal.
final platformSchoolEventsProvider = FutureProvider.autoDispose
    .family<List<PlatformEvent>, String>(
  (ref, schoolId) => PlatformRepository.getSchoolEvents(schoolId),
);

/// Historique réel des annonces plateforme — page Annonces (console).
final platformAnnouncementsProvider =
    FutureProvider<List<PlatformAnnouncement>>(
  (ref) => PlatformRepository.getAnnouncements(),
);
