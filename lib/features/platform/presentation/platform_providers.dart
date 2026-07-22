import 'package:flutter_riverpod/flutter_riverpod.dart';

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
