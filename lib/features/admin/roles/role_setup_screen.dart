import 'package:flutter/material.dart';

import 'workspace/roles_permissions_workspace.dart';

/// Étape post-inscription : configuration de la hiérarchie des rôles du
/// personnel. S'affiche une seule fois, à la première connexion du
/// fondateur/admin, tant qu'aucun rôle n'existe. Réutilise l'atelier complet
/// (organigramme + permissions + résumé) — voir `workspace/`.
class RoleSetupScreen extends StatelessWidget {
  final VoidCallback onDone;
  const RoleSetupScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return RolesPermissionsWorkspace(onboarding: true, onDone: onDone);
  }
}
