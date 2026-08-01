import 'package:flutter/material.dart';

import '../../core/platform/platform_utils.dart';
import '../../domain/entities/user_entity.dart';
import '../desktop_shell/desktop_shell.dart';
import '../mobile_shell/mobile_shell.dart';

/// Description of a single navigable destination — platform-agnostic.
class RoleNavEntry {
  final IconData icon;
  final IconData? activeIcon;
  final String labelKey;
  final Widget page;

  /// Permission staff requise pour voir cette entrée (clé de StaffPermissions).
  /// `null` = visible par tout membre ayant accès au shell (ex. tableau de bord).
  final String? permission;

  /// Module optionnel choisi par l'école à l'inscription (cf.
  /// `school_registration_screen.dart` → `schools.metadata.modules`).
  /// `null` = fonctionnalité « core », toujours visible quels que soient les
  /// modules choisis par l'école.
  final String? module;

  const RoleNavEntry({
    required this.icon,
    this.activeIcon,
    required this.labelKey,
    required this.page,
    this.permission,
    this.module,
  });
}

/// A grouping of nav entries (used by the desktop sidebar — SETUP, ACTIVITY, etc.).
class RoleNavGroup {
  final String labelKey;
  final List<RoleNavEntry> entries;
  const RoleNavGroup({required this.labelKey, required this.entries});
}

class ResponsiveRoleShell extends StatelessWidget {
  final UserRole role;
  final String title;
  final List<RoleNavGroup> groups;

  /// Bottom-dock items on mobile (≤5). If null, a flat take(5) is used.
  final List<RoleNavEntry>? mobileDockEntries;

  const ResponsiveRoleShell({
    super.key,
    required this.role,
    required this.title,
    required this.groups,
    this.mobileDockEntries,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final allEntries = [for (final g in groups) ...g.entries];
    if (PlatformUtils.isLargeFormFactor(width)) {
      return DesktopShell(
        role: role,
        title: title,
        groups: groups
            .map((g) => DesktopNavGroup(
                  labelKey: g.labelKey,
                  items: g.entries
                      .map((e) => DesktopNavItem(
                            icon: e.icon,
                            labelKey: e.labelKey,
                            page: e.page,
                          ))
                      .toList(),
                ))
            .toList(),
      );
    }
    final dockEntries = (mobileDockEntries ?? allEntries.take(5).toList());
    return MobileShell(
      role: role,
      title: title,
      dockEntries: dockEntries,
      drawerEntries: allEntries,
    );
  }
}
