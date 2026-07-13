import 'package:flutter/material.dart';

import 'workspace/roles_permissions_workspace.dart';

/// Page permanente "Rôles & permissions" — accessible depuis la barre
/// latérale de l'administration. Utilise le même atelier (organigramme +
/// permissions + résumé) que la configuration initiale, mais en mode
/// gestion continue (pas de blocage, sauvegarde manuelle).
class RolesPermissionsPage extends StatelessWidget {
  const RolesPermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: RolesPermissionsWorkspace(onboarding: false),
    );
  }
}
