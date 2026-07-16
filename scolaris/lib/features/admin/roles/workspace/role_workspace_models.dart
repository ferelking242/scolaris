import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/staff_roles_source.dart';

/// Niveaux hiérarchiques affichés dans l'organigramme, du plus haut pouvoir
/// au plus bas.
const kRoleLevels = <String>['Direction', 'Administration', 'Pédagogique', 'Support / Famille'];

const kRoleIcons = <String, IconData>{
  'gavel': Icons.gavel_rounded,
  'shield': Icons.shield_rounded,
  'visibility': Icons.visibility_rounded,
  'folder': Icons.folder_rounded,
  'payments': Icons.payments_rounded,
  'school': Icons.school_rounded,
  'badge': Icons.badge_rounded,
  'star': Icons.star_rounded,
  'group': Icons.group_rounded,
  'family': Icons.family_restroom_rounded,
};

IconData iconForKey(String key) => kRoleIcons[key] ?? Icons.badge_rounded;

Color colorFromHex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

String colorToHex(Color c) =>
    '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

/// Brouillon éditable d'un rôle dans l'atelier — reflète [SbStaffRole] mais
/// vit en mémoire tant que l'utilisateur n'a pas sauvegardé.
class RoleDraft {
  final String draftId; // stable en mémoire (id réel si existant, sinon uuid local)
  String? persistedId; // null tant que non sauvegardé côté serveur
  String name;
  String description;
  bool isAdminRole;
  bool isNew;
  bool isDirty;
  bool markedForDeletion;
  String level;
  String color;
  String iconKey;
  String? parentDraftId;
  Set<String> grants;
  final String? basedOnTemplateId;

  RoleDraft({
    required this.draftId,
    this.persistedId,
    required this.name,
    this.description = '',
    this.isAdminRole = false,
    this.isNew = false,
    this.isDirty = false,
    this.markedForDeletion = false,
    this.level = 'Pédagogique',
    this.color = '#8B1A00',
    this.iconKey = 'badge',
    this.parentDraftId,
    Set<String>? grants,
    this.basedOnTemplateId,
  }) : grants = grants ?? {};

  bool get locked => isAdminRole;

  factory RoleDraft.fromStaffRole(SbStaffRole r) => RoleDraft(
        draftId: r.id,
        persistedId: r.id,
        name: r.name,
        description: r.description ?? '',
        isAdminRole: r.isAdminRole,
        level: r.level,
        color: r.color,
        iconKey: r.iconKey,
        parentDraftId: r.parentRoleId,
        grants: {...r.grants},
      );

  factory RoleDraft.fromTemplate(SbRoleTemplate t, {required String draftId}) => RoleDraft(
        draftId: draftId,
        name: t.name,
        description: t.description ?? '',
        isNew: true,
        isDirty: true,
        level: t.level,
        color: t.color,
        iconKey: t.iconKey,
        grants: {...t.grants},
        basedOnTemplateId: t.id,
      );

  factory RoleDraft.blank({required String draftId}) => RoleDraft(
        draftId: draftId,
        name: 'Nouveau rôle',
        description: 'Décrivez ce que ce rôle peut faire…',
        isNew: true,
        isDirty: true,
        level: 'Support / Famille',
        color: colorToHex(ScolarisAccents.all[(DateTime.now().millisecond) % ScolarisAccents.all.length]),
        iconKey: 'star',
      );
}
