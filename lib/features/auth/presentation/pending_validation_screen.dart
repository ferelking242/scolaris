import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../presentation/providers/auth_providers.dart';

/// Écran d'attente affiché à l'admin fondateur juste après la création de
/// son école (self-signup, `SchoolRegistrationScreen`) : le compte est
/// connecté, mais `schools.is_active = false` tant que l'équipe Scolaris
/// n'a pas validé l'établissement (cf. `platform_schools_page.dart`). Le
/// routeur (`app_router.dart`) cantonne tout compte
/// `isSchoolPendingValidation` ici, quelle que soit la route demandée.
class PendingValidationScreen extends ConsumerWidget {
  const PendingValidationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    return Scaffold(
      backgroundColor: ScolarisPalette.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      color: ScolarisPalette.gold.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded,
                        color: ScolarisPalette.gold, size: 40),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Votre école est en cours de validation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: Color(0xFF1A0A00)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bienvenue${user?.fullName.isNotEmpty == true ? ', ${user!.fullName}' : ''} ! '
                    'Notre équipe vérifie les informations de votre établissement — '
                    'généralement sous 24 heures ouvrées. Vous recevrez un email dès '
                    'que l\'accès complet est activé.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5, height: 1.5, color: Color(0xFF7A5C44)),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(signOutUseCaseProvider)(),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Se déconnecter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7A5C44),
                      side: const BorderSide(color: Color(0xFFDDCCBB)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
