import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/auth_providers.dart';

const _terra = Color(0xFF8B1A00);
const _muted = Color(0xFF7A5C44);
const _ink = Color(0xFF1A0A00);

/// Garde de page (défense en profondeur) : n'affiche [child] que si le membre
/// connecté possède la permission [permission]. Sinon, écran « accès refusé ».
///
/// Le menu filtre déjà les entrées par permission — cette garde protège les
/// autres chemins d'accès (intentions de navigation, liens directs, futurs
/// changements). `permission == null` = toujours autorisé.
class PermissionGuard extends ConsumerWidget {
  final String? permission;
  final Widget child;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final allowed = permission == null || (user?.can(permission!) ?? false);
    if (allowed) return child;

    return Container(
      color: const Color(0xFFF5EEE6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _terra.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline_rounded, color: _terra, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Accès non autorisé',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 6),
        const Text(
          'Vous n\'avez pas l\'autorisation d\'accéder à cette section.\n'
          'Contactez la direction de votre établissement.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
        ),
      ]),
    );
  }
}
