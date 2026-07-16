import 'package:flutter/material.dart';

import '../../../domain/entities/user_entity.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import 'pages/platform_announcements_page.dart';
import 'pages/platform_dashboard.dart';
import 'pages/platform_schools_page.dart';
import 'pages/platform_settings_page.dart';
import 'pages/platform_subscriptions_page.dart';

/// Console **super-admin plateforme** — la « tour de contrôle » des créateurs
/// de Scolaris (au-dessus de toutes les écoles). Réservée aux emails autorisés
/// (cf. [PlatformAdmins]). v1 = maquette, observation seule.
class PlatformHome extends StatelessWidget {
  const PlatformHome({super.key});

  static const List<RoleNavGroup> _groups = [
    RoleNavGroup(labelKey: 'Plateforme', entries: [
      RoleNavEntry(
        icon: Icons.dashboard_rounded,
        labelKey: 'Vue plateforme',
        page: PlatformDashboard(),
      ),
      RoleNavEntry(
        icon: Icons.apartment_rounded,
        labelKey: 'Écoles',
        page: PlatformSchoolsPage(),
      ),
      RoleNavEntry(
        icon: Icons.workspace_premium_rounded,
        labelKey: 'Abonnements',
        page: PlatformSubscriptionsPage(),
      ),
      RoleNavEntry(
        icon: Icons.campaign_rounded,
        labelKey: 'Annonces',
        page: PlatformAnnouncementsPage(),
      ),
      RoleNavEntry(
        icon: Icons.settings_rounded,
        labelKey: 'Réglages',
        page: PlatformSettingsPage(),
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return const ResponsiveRoleShell(
      role: UserRole.staff,
      title: 'Scolaris · Console',
      groups: _groups,
    );
  }
}
