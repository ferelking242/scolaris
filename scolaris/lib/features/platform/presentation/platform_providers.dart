import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_mock_data.dart';

/// École actuellement ouverte dans la console (vue détail inline). `null` = on
/// affiche la liste. Partagé pour que le tableau de bord puisse aussi ouvrir
/// une école (en basculant sur l'onglet « Écoles »).
final selectedPlatformSchoolProvider =
    StateProvider<PlatformSchool?>((ref) => null);
