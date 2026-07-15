import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/localization/locales.dart';
import '../../core/permissions/staff_permissions.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../domain/entities/user_entity.dart';
import '../../features/admin/presentation/pages/admin_school_page.dart';
import '../../presentation/providers/auth_providers.dart';
import 'account_page.dart';

// ── Tokens communs ──────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);
const _sh1    = Color(0xFF1A0A00);
const _sh2    = Color(0xFF3E1A00);

// shadcn zinc (hub uniquement)
const _zinc50  = Color(0xFFFAFAFA);
const _zinc100 = Color(0xFFF4F4F5);
const _zinc200 = Color(0xFFE4E4E7);
const _zinc400 = Color(0xFFA1A1AA);
const _zinc600 = Color(0xFF52525B);
const _zinc700 = Color(0xFF3F3F46);
const _zinc900 = Color(0xFF18181B);

// ═══════════════════════════════════════════════════════════════════════════════
// SettingsPage — hub principal style Facebook × shadcn
// ═══════════════════════════════════════════════════════════════════════════════
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user     = ref.watch(authSessionProvider);
    final name     = user?.fullName ?? 'Utilisateur';
    final email    = user?.email ?? '';
    final accent   = ref.watch(themeControllerProvider).accent;
    final roleName = switch (user?.role) {
      UserRole.staff   => 'settings.roles.admin'.tr(),
      UserRole.teacher => 'settings.roles.teacher'.tr(),
      UserRole.student => 'settings.roles.student'.tr(),
      UserRole.parent  => 'settings.roles.parent'.tr(),
      null             => '—',
    };
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Titre ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
              child: Text('Paramètres',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.6,
                      height: 1.1)),
            ),
            const SizedBox(height: 8),

            // ── Profil — avatar GAUCHE, nom+rôle DROITE sur la même ligne ─
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProfileCard(
                name: name,
                email: email,
                roleName: roleName,
                initials: initials,
                accent: accent,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AccountPage())),
              ),
            ),
            const SizedBox(height: 20),

            // ── COMPTE ─────────────────────────────────────────────────────
            _SettingsGroupLabel('COMPTE'),
            _SettingsTileGroup(items: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                color: _terra,
                title: 'settings.account'.tr(),
                subtitle: 'settings.account_sub'.tr(),
                onTap: () => _push(context, _AccountSettingsPage(user: user)),
              ),
              if (user?.can(StaffPermissions.schoolConfig) ?? false)
                _SettingsTile(
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFF0D47A1),
                  title: 'settings.school'.tr(),
                  subtitle: 'settings.school_sub'.tr(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: _zinc100,
                      appBar: AppBar(
                        backgroundColor: _sh1, foregroundColor: _white,
                        elevation: 0,
                        title: Text('settings.school'.tr(),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      body: const AdminSchoolPage(),
                    ),
                  )),
                ),
            ]),
            const SizedBox(height: 16),

            // ── PRÉFÉRENCES ────────────────────────────────────────────────
            _SettingsGroupLabel('PRÉFÉRENCES'),
            _SettingsTileGroup(items: [
              _SettingsTile(
                icon: Icons.palette_outlined,
                color: _orange,
                title: 'settings.appearance'.tr(),
                subtitle: 'settings.appearance_sub'.tr(),
                onTap: () => _push(context, const _AppearancePage()),
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                color: const Color(0xFF0E5FA3),
                title: 'Notifications',
                subtitle: 'Alertes, rappels et badges',
                onTap: () => _push(context, const _NotificationsSettingsPage()),
              ),
              _SettingsTile(
                icon: Icons.accessibility_new_rounded,
                color: _gold,
                title: 'settings.accessibility'.tr(),
                subtitle: 'settings.accessibility_sub'.tr(),
                onTap: () => _push(context, const _AccessibilityPage()),
              ),
              _SettingsTile(
                icon: Icons.security_outlined,
                color: _green,
                title: 'settings.privacy'.tr(),
                subtitle: 'settings.privacy_sub'.tr(),
                onTap: () => _push(context, _PrivacyPage(user: user)),
              ),
              _SettingsTile(
                icon: Icons.storage_outlined,
                color: const Color(0xFF00695C),
                title: 'Stockage & Cache',
                subtitle: 'Données hors-ligne et cache local',
                onTap: () => _push(context, const _StoragePage()),
              ),
            ]),
            const SizedBox(height: 16),

            // ── AIDE ───────────────────────────────────────────────────────
            _SettingsGroupLabel('AIDE'),
            _SettingsTileGroup(items: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                color: _zinc600,
                title: 'settings.support'.tr(),
                subtitle: 'settings.support_sub'.tr(),
                onTap: () => _push(context, _SupportPage(user: user)),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF37474F),
                title: 'À propos de Scolaris',
                subtitle: 'Version ${AppConfig.appVersion} · Licences',
                onTap: () => _showAboutDialog(context),
              ),
            ]),
            const SizedBox(height: 32),

            // ── Déconnexion — bouton NOIR PUR shadcn ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BlackButton(
                label: 'settings.logout'.tr(),
                icon: Icons.logout_rounded,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext ctx, Widget page) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => page));

  void _showAboutDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dCtx) => Dialog(
        backgroundColor: Theme.of(dCtx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_sh1, _terra, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            Text('Scolaris',
                style: TextStyle(
                    color: Theme.of(dCtx).colorScheme.onSurface,
                    fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Version ${AppConfig.appVersion}',
                style: TextStyle(
                    color: Theme.of(dCtx).colorScheme.onSurface.withOpacity(.5),
                    fontSize: 13)),
            const SizedBox(height: 16),
            Text('Plateforme de gestion scolaire nouvelle génération.\nConçue pour les établissements africains.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(dCtx).colorScheme.onSurface.withOpacity(.65),
                    fontSize: 12.5, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _terra,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, size: 22, color: _zinc900),
          SizedBox(width: 10),
          Text('Déconnexion',
              style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
        content: Text('settings.logout_confirm'.tr(),
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(signOutUseCaseProvider)();
            },
            child: Text('settings.logout_btn'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profil — style Facebook : avatar GAUCHE, nom + rôle DROITE (même ligne)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final String name, email, roleName, initials;
  final Color accent;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.roleName,
    required this.initials,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(.35),
              width: 1.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05),
                blurRadius: 12, offset: const Offset(0, 3), spreadRadius: -2),
          ],
        ),
        child: Row(children: [
          // ── Avatar rond avec gradient accent ──────────────────────────
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(.65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withOpacity(.3),
                    blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -2),
              ],
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: _white, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 14),

          // ── Nom + rôle à DROITE (même ligne que l'avatar) ─────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 2),
              Text(email,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(.5),
                      fontSize: 12.5),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(.09),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent.withOpacity(.25)),
                ),
                child: Text(roleName.toUpperCase(),
                    style: TextStyle(
                        color: accent, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: .9)),
              ),
            ]),
          ),

          // ── Chevron + "Voir profil" ────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_right_rounded, color: _zinc400, size: 22),
              const SizedBox(height: 2),
              Text('Voir profil',
                  style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label — style shadcn (caps espacés, zinc-400)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsGroupLabel extends StatelessWidget {
  final String text;
  const _SettingsGroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
        child: Text(text,
            style: const TextStyle(
                color: _zinc400,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Groupe de tiles — carte blanche, items séparés (style iOS Settings)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTileGroup extends StatelessWidget {
  final List<Widget> items;
  const _SettingsTileGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(.3),
              width: 1.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.04),
                blurRadius: 8, offset: const Offset(0, 2), spreadRadius: -1),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: List.generate(items.length, (i) => Column(children: [
              items[i],
              if (i < items.length - 1)
                Divider(height: 1, indent: 62, endIndent: 0,
                    color: Theme.of(context).colorScheme.outline.withOpacity(.2)),
            ])),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile — ligne cliquable style iOS 18 / shadcn
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            // Icône carrée colorée (style macOS / iOS 18)
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: _white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(.5),
                          fontSize: 12,
                          height: 1.3)),
              ]),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(.35),
                size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton noir pur — style shadcn "primary" CTA
// ─────────────────────────────────────────────────────────────────────────────
class _BlackButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _BlackButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-page scaffold commun
// ─────────────────────────────────────────────────────────────────────────────
class _SubPageShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _SubPageShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: Theme.of(context).colorScheme.onSurface, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Text(title,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          Divider(height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Compte
// ─────────────────────────────────────────────────────────────────────────────
class _AccountSettingsPage extends ConsumerStatefulWidget {
  final AppUser? user;
  const _AccountSettingsPage({this.user});
  @override
  ConsumerState<_AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<_AccountSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final locale   = context.locale;
    final langName = AppLocales.label(locale);
    final user     = widget.user;

    return _SubPageShell(
      title: 'settings.account'.tr(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Identité ───────────────────────────────────────────────────
          if (user != null) ...[
            _SectionLabel('IDENTITÉ'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(children: [
                _InfoRow(
                  label: 'Nom complet',
                  value: user.fullName,
                  icon: Icons.badge_outlined,
                ),
                Divider(height: 18, color: _border.withOpacity(.5)),
                _InfoRow(
                  label: 'Email',
                  value: user.email,
                  icon: Icons.alternate_email_rounded,
                ),
                Divider(height: 18, color: _border.withOpacity(.5)),
                _InfoRow(
                  label: 'Rôle',
                  value: switch (user.role) {
                    UserRole.staff   => 'Administration',
                    UserRole.teacher => 'Enseignant',
                    UserRole.student => 'Élève',
                    UserRole.parent  => 'Parent',
                  },
                  icon: Icons.school_outlined,
                ),
                Divider(height: 18, color: _border.withOpacity(.5)),
                _InfoRow(
                  label: 'ID utilisateur',
                  value: user.id.length >= 8
                      ? '#${user.id.substring(0, 8).toUpperCase()}'
                      : '#${user.id.toUpperCase()}',
                  icon: Icons.fingerprint_rounded,
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // ── Modification ───────────────────────────────────────────────
          _SectionLabel('MODIFICATION'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItem(
                icon: Icons.person_outline_rounded,
                color: _terra,
                label: 'Gérer le profil',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AccountPage())),
              ),
              _SettingsItem(
                icon: Icons.lock_outline_rounded,
                color: _orange,
                label: 'Mot de passe & Sécurité',
                onTap: () => _showPasswordSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Sécurité avancée ───────────────────────────────────────────
          _SectionLabel('SÉCURITÉ AVANCÉE'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemComingSoon(
                icon: Icons.verified_user_outlined,
                color: _green,
                label: 'Authentification à deux facteurs',
                description: 'Protection renforcée par code OTP',
              ),
              _SettingsItemComingSoon(
                icon: Icons.devices_rounded,
                color: _gold,
                label: 'Appareils connectés',
                description: 'Voir et révoquer vos sessions actives',
              ),
              _SettingsItemComingSoon(
                icon: Icons.history_rounded,
                color: const Color(0xFF1A237E),
                label: 'Historique des connexions',
                description: 'Dernières activités de votre compte',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Notifications ──────────────────────────────────────────────
          _SectionLabel('NOTIFICATIONS'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemComingSoon(
                icon: Icons.notifications_outlined,
                color: _terra,
                label: 'Notifications push',
                description: 'Alertes en temps réel (web & mobile)',
              ),
              _SettingsItemComingSoon(
                icon: Icons.email_outlined,
                color: _orange,
                label: 'Notifications par email',
                description: 'Résumés et alertes par email',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Langue ─────────────────────────────────────────────────────
          _SectionLabel('LANGUE'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItem(
                icon: Icons.language_outlined,
                color: const Color(0xFF0D47A1),
                label: 'Langue de l\'interface',
                trailing: langName,
                onTap: () => _showLanguagePicker(context),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _LanguagePicker(),
    );
  }

  void _showPasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _PasswordSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Apparence
// ─────────────────────────────────────────────────────────────────────────────
class _AppearancePage extends ConsumerStatefulWidget {
  const _AppearancePage();
  @override
  ConsumerState<_AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<_AppearancePage> {
  // Palettes vedettes — nom, couleur, icône
  static const List<(String, Color, IconData)> _featured = [
    ('Scolaris',   Color(0xFF8B1A00), Icons.school_rounded),
    ('Océan',      Color(0xFF0E5FA3), Icons.waves_rounded),
    ('Forêt',      Color(0xFF1B5E20), Icons.park_rounded),
    ('Nuit',       Color(0xFF1A237E), Icons.nightlight_round),
    ('Amethyste',  Color(0xFF6A1B9A), Icons.auto_awesome_rounded),
    ('Saphir',     Color(0xFF1565C0), Icons.diamond_outlined),
    ('Émeraude',   Color(0xFF00695C), Icons.spa_outlined),
    ('Rubis',      Color(0xFFB71C1C), Icons.favorite_border_rounded),
    ('Rose Gold',  Color(0xFFBE185D), Icons.local_florist_outlined),
    ('Ardoise',    Color(0xFF37474F), Icons.layers_outlined),
    ('Ambre',      Color(0xFFC17F24), Icons.wb_sunny_outlined),
    ('Sombre',     Color(0xFF1A1A2E), Icons.dark_mode_outlined),
  ];

  static const List<Color> _presets = [
    Color(0xFF8B1A00), Color(0xFF0E5FA3), Color(0xFFC17F24), Color(0xFF1B5E20),
    Color(0xFF1565C0), Color(0xFF1A237E), Color(0xFF6A1B9A), Color(0xFFB71C1C),
    Color(0xFFBE185D), Color(0xFF00695C), Color(0xFF37474F), Color(0xFF1A1A2E),
  ];

  static final List<(String, String, Locale)> _langs = [
    ('🇫🇷', 'Français',  const Locale('fr')),
    ('🇬🇧', 'English',   const Locale('en')),
    ('🇰🇪', 'Kiswahili', const Locale('sw')),
    ('🇨🇩', 'Lingála',   const Locale('ln')),
  ];

  void _openPicker(BuildContext context, Color current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _HsvPickerSheet(
        initial: current,
        onApply: (c) => ref.read(themeControllerProvider.notifier).setAccent(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent    = ref.watch(themeControllerProvider).accent;
    final settings  = ref.watch(settingsProvider);
    final locale    = context.locale;
    final isDark    = false; // thème clair uniquement

    return _SubPageShell(
      title: 'settings.appearance'.tr(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Contraste élevé ────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: settings.contrasteEleve
                  ? Colors.black.withOpacity(.08)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: settings.contrasteEleve
                    ? (isDark ? Colors.white.withOpacity(.25) : Colors.black.withOpacity(.3))
                    : Theme.of(context).colorScheme.outline.withOpacity(.25),
                width: settings.contrasteEleve ? 1.6 : 1.0,
              ),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: settings.contrasteEleve
                      ? (isDark ? Colors.white.withOpacity(.12) : Colors.black.withOpacity(.1))
                      : Theme.of(context).colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.contrast_rounded, size: 18,
                    color: settings.contrasteEleve
                        ? (isDark ? Colors.white : Colors.black)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(.55)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Contraste élevé',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(isDark
                    ? 'Mode sombre pur — fond noir absolu'
                    : 'Texte et bordures plus marqués',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
                        fontSize: 11.5)),
              ])),
              Switch.adaptive(
                value: settings.contrasteEleve,
                activeColor: accent,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setContrasteEleve(v),
              ),
            ]),
          ),
          const SizedBox(height: 22),

          // ── Langue ──────────────────────────────────────────────────────
          _SectionLabel('settings.section.lang'.tr()),
          const SizedBox(height: 4),
          Text('settings.lang.subtitle'.tr(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(.5),
                  fontSize: 11.5)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: _langs.map((l) {
              final selected = locale == l.$3;
              return GestureDetector(
                onTap: () => context.setLocale(l.$3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withOpacity(.08)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? accent.withOpacity(.55)
                          : Theme.of(context).colorScheme.outline.withOpacity(.3),
                      width: selected ? 1.6 : 1.0,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: accent.withOpacity(.1), blurRadius: 8)]
                        : [],
                  ),
                  child: Row(children: [
                    Text(l.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.$2,
                        style: TextStyle(
                          color: selected
                              ? accent
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded, color: accent, size: 16),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // ── Palettes recommandées ───────────────────────────────────────
          _SectionLabel('PALETTES'),
          const SizedBox(height: 4),
          Text('Choisissez un style en un clic',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
                  fontSize: 11.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _featured.length,
              itemBuilder: (ctx, i) {
                final (name, color, icon) = _featured[i];
                final sel = color.value == accent.value;
                return GestureDetector(
                  onTap: () => ref.read(themeControllerProvider.notifier).setAccent(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 70,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(.12) : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? color.withOpacity(.6) : Theme.of(context).colorScheme.outline.withOpacity(.25),
                        width: sel ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: color.withOpacity(.4), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Icon(icon, size: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      Text(name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                              color: sel ? color : Theme.of(context).colorScheme.onSurface.withOpacity(.6))),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          // ── Couleur d'accent ─────────────────────────────────────────────
          _SectionLabel('settings.section.accent'.tr()),
          const SizedBox(height: 8),
          // Accent actuel + picker HSV
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Swatch couleur actuelle
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: accent.withOpacity(.35), blurRadius: 8, offset: const Offset(0,3))],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('settings.accent.current'.tr(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text(
                    '#${accent.red.toRadixString(16).padLeft(2,'0')}'
                    '${accent.green.toRadixString(16).padLeft(2,'0')}'
                    '${accent.blue.toRadixString(16).padLeft(2,'0')}'.toUpperCase(),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
                        fontSize: 11.5),
                  ),
                ])),
                const SizedBox(width: 8),
                // Bouton picker custom
                GestureDetector(
                  onTap: () => _openPicker(context, accent),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withOpacity(.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.colorize_rounded, size: 14, color: accent),
                      const SizedBox(width: 5),
                      Text('settings.accent.custom'.tr(),
                          style: TextStyle(
                              color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Étiquette presets
              Text('settings.accent.presets'.tr(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
                      fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // Grille presets — cercles 36px avec label en dessous
              Wrap(
                spacing: 12, runSpacing: 14,
                children: _presets.indexed.map(((int, Color) entry) {
                  final idx = entry.$1;
                  final c   = entry.$2;
                  final sel = c.value == accent.value;
                  final names = [
                    'Scolaris','Océan','Ambre','Forêt',
                    'Saphir','Nuit','Amethyste','Rubis',
                    'Rose Gold','Émeraude','Ardoise','Sombre',
                  ];
                  return GestureDetector(
                    onTap: () => ref.read(themeControllerProvider.notifier).setAccent(c),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: sel
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: c.withOpacity(sel ? .45 : .2),
                                blurRadius: sel ? 8 : 4),
                          ],
                        ),
                        child: sel
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(idx < names.length ? names[idx] : '',
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel
                                  ? accent
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(.45))),
                    ]),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 22),

          // ── Navigation ──────────────────────────────────────────────────
          _SectionLabel('settings.section.nav'.tr()),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemToggle(
                icon: Icons.tab_rounded,
                color: _orange,
                label: 'settings.nav_tab'.tr(),
                value: settings.afficherBarreOnglets,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setAfficherBarreOnglets(v),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview card
// ─────────────────────────────────────────────────────────────────────────────
class _ThemePreviewCard extends StatelessWidget {
  final Color accent;
  final bool isDark;
  const _ThemePreviewCard({required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg   = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final surf = isDark ? const Color(0xFF252525) : const Color(0xFFF5EEE6);
    final txt  = isDark ? Colors.white : const Color(0xFF1A0A00);
    final sub  = isDark ? const Color(0xFFB0A090) : const Color(0xFF7A5C44);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFDDCCBB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 4)],
          ),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: const Center(child: Text('S',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 8),
            Text('Scolaris', style: TextStyle(
                color: txt, fontSize: 12, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: accent.withOpacity(.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.notifications_outlined, size: 13, color: accent),
            ),
            const SizedBox(width: 6),
            CircleAvatar(radius: 11,
              backgroundColor: accent.withOpacity(.15),
              child: Icon(Icons.person_outline, size: 13, color: accent)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _MiniStatCard(color: accent,
              label: 'Notes', value: '16.2', bg: bg, txt: txt, sub: sub),
          const SizedBox(width: 6),
          _MiniStatCard(color: const Color(0xFF1B5E20),
              label: 'Présences', value: '94%', bg: bg, txt: txt, sub: sub),
          const SizedBox(width: 6),
          _MiniStatCard(color: const Color(0xFFC17F24),
              label: 'Scolarité', value: 'OK', bg: bg, txt: txt, sub: sub),
        ]),
      ]),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final Color color, bg, txt, sub;
  final String label, value;
  const _MiniStatCard({
    required this.color, required this.label, required this.value,
    required this.bg, required this.txt, required this.sub,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(
              color: sub, fontSize: 9, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme mode card (Light / Dark / System)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Media choice bottom sheet (avatar / banner)
// ─────────────────────────────────────────────────────────────────────────────
class _MediaSheet extends StatelessWidget {
  final String title;
  final bool showTheme;
  const _MediaSheet({required this.title, required this.showTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        // Upload d'image pas encore disponible (nécessite Supabase Storage).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _gold.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withOpacity(.25)),
          ),
          child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 20, color: _gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bientôt disponible',
                      style: TextStyle(
                          color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    'L\'import de photo arrivera dans une prochaine version. '
                    'En attendant, votre avatar affiche vos initiales.',
                    style: TextStyle(
                        color: _muted, fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photoshop-style HSV color picker
// ─────────────────────────────────────────────────────────────────────────────
class _HsvPickerSheet extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onApply;
  const _HsvPickerSheet({required this.initial, required this.onApply});
  @override
  State<_HsvPickerSheet> createState() => _HsvPickerSheetState();
}

class _HsvPickerSheetState extends State<_HsvPickerSheet> {
  late double _hue, _sat, _val;
  late TextEditingController _hexCtrl;
  double _sqW = 0, _slW = 0;
  static const double _sqH = 180;

  @override
  void initState() {
    super.initState();
    final h = HSVColor.fromColor(widget.initial);
    _hue = h.hue; _sat = h.saturation; _val = h.value;
    _hexCtrl = TextEditingController(text: _toHex(_current));
  }

  @override
  void dispose() { _hexCtrl.dispose(); super.dispose(); }

  Color get _current => HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();

  String _toHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  void _fromHex(String v) {
    final h = v.replaceAll('#', '').trim();
    if (h.length != 6) return;
    try {
      final c = Color(int.parse('FF$h', radix: 16));
      final hsv = HSVColor.fromColor(c);
      setState(() { _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value; });
    } catch (_) {}
  }

  void _svPan(Offset local) {
    if (_sqW == 0) return;
    setState(() {
      _sat = (local.dx / _sqW).clamp(0.0, 1.0);
      _val = (1.0 - local.dy / _sqH).clamp(0.0, 1.0);
      _hexCtrl.text = _toHex(_current);
    });
  }

  void _huePan(double x) {
    if (_slW == 0) return;
    setState(() {
      _hue = (x / _slW * 360.0).clamp(0.0, 360.0);
      _hexCtrl.text = _toHex(_current);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final color  = _current;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, math.max(bottom, 24) + 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Row(children: [
          Container(width: 22, height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  border: Border.all(color: _border))),
          const SizedBox(width: 10),
          const Text('Couleur d\'accent',
              style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, color: _muted, size: 20)),
        ]),
        const SizedBox(height: 16),

        LayoutBuilder(builder: (_, c) {
          _sqW = c.maxWidth;
          return GestureDetector(
            onPanDown:   (d) => _svPan(d.localPosition),
            onPanUpdate: (d) => _svPan(d.localPosition),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                size: Size(_sqW, _sqH),
                painter: _SvPainter(hue: _hue, sat: _sat, val: _val),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),

        LayoutBuilder(builder: (_, c) {
          _slW = c.maxWidth;
          return GestureDetector(
            onPanDown:   (d) => _huePan(d.localPosition.dx),
            onPanUpdate: (d) => _huePan(d.localPosition.dx),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                size: Size(_slW, 22),
                painter: _HuePainter(hue: _hue),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),

        Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border))),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _hexCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Hex', prefixText: '#',
                isDense: true, border: OutlineInputBorder(),
              ),
              onChanged: _fromHex,
            ),
          ),
        ]),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: _white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () { Navigator.pop(context); widget.onApply(color); },
            child: const Text('Appliquer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _SvPainter extends CustomPainter {
  final double hue, sat, val;
  const _SvPainter({required this.hue, required this.sat, required this.val});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final hc   = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(rect,
        Paint()..shader = LinearGradient(colors: [Colors.white, hc]).createShader(rect));
    canvas.drawRect(rect,
        Paint()..shader = const LinearGradient(
          colors: [Colors.transparent, Colors.black],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ).createShader(rect));
    final cx = sat * size.width;
    final cy = (1 - val) * size.height;
    canvas.drawCircle(Offset(cx, cy), 9,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawCircle(Offset(cx, cy), 7,
        Paint()..color = HSVColor.fromAHSV(1, hue, sat, val).toColor());
  }

  @override
  bool shouldRepaint(_SvPainter o) =>
      o.hue != hue || o.sat != sat || o.val != val;
}

class _HuePainter extends CustomPainter {
  final double hue;
  const _HuePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
      Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
    ];
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect,
        Paint()..shader = const LinearGradient(colors: colors).createShader(rect));
    final x  = (hue / 360 * size.width).clamp(2.0, size.width - 2);
    final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2, 0, 4, size.height), const Radius.circular(2));
    canvas.drawRRect(rr,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawRRect(rr, Paint()..color = Colors.black.withOpacity(.25));
  }

  @override
  bool shouldRepaint(_HuePainter o) => o.hue != hue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Accessibilité
// ─────────────────────────────────────────────────────────────────────────────
class _AccessibilityPage extends ConsumerStatefulWidget {
  const _AccessibilityPage();
  @override
  ConsumerState<_AccessibilityPage> createState() => _AccessibilityPageState();
}

class _AccessibilityPageState extends ConsumerState<_AccessibilityPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final textScale = settings.textScale;

    return _SubPageShell(
      title: 'Accessibilité',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Taille du texte ────────────────────────────────────────────
          _SectionLabel('TAILLE DU TEXTE'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Aperçu de l\'interface',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 10 * textScale,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Tableau de bord — Scolaris',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 15 * textScale,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Terminale S · 28 élèves inscrits · Année 2025–26',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 12 * textScale,
                          height: 1.4)),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.text_decrease_rounded, size: 15, color: _muted),
                Expanded(
                  child: Slider(
                    value: textScale,
                    min: 0.8, max: 1.4, divisions: 6,
                    activeColor: _terra,
                    inactiveColor: _border,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setTextScale(v),
                  ),
                ),
                const Icon(Icons.text_increase_rounded, size: 20, color: _muted),
              ]),
              Center(
                child: Text(
                  '${(textScale * 100).round()} %',
                  style: const TextStyle(
                      color: _muted, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Affichage ──────────────────────────────────────────────────
          _SectionLabel('AFFICHAGE'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemToggle(
                icon: Icons.format_size_rounded,
                color: _terra,
                label: 'Grande police',
                value: settings.grandePolice,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setGrandePolice(v),
              ),
              _SettingsItemToggle(
                icon: Icons.contrast_rounded,
                color: _orange,
                label: 'Contraste élevé',
                value: settings.contrasteEleve,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setContrasteEleve(v),
              ),
              _SettingsItemToggle(
                icon: Icons.animation_rounded,
                color: _gold,
                label: 'Réduire les animations',
                value: settings.reduireAnimations,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setReduireAnimations(v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Interaction ────────────────────────────────────────────────
          _SectionLabel('INTERACTION'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemComingSoon(
                icon: Icons.keyboard_rounded,
                color: const Color(0xFF1A237E),
                label: 'Navigation clavier complète',
                description: 'Tab / Flèches pour naviguer dans l\'app',
              ),
              _SettingsItemComingSoon(
                icon: Icons.record_voice_over_outlined,
                color: const Color(0xFF00838F),
                label: 'Lecteur d\'écran',
                description: 'Synthèse vocale pour les éléments UI',
              ),
              _SettingsItemComingSoon(
                icon: Icons.touch_app_outlined,
                color: _muted,
                label: 'Zone de touche élargie',
                description: 'Boutons et liens plus faciles à taper',
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(.25)),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 15, color: _gold),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Les options marquées "Bientôt disponible" seront déployées dans une prochaine mise à jour de Scolaris.',
                style: TextStyle(color: _gold, fontSize: 11.5, height: 1.5),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Confidentialité & Données
// ─────────────────────────────────────────────────────────────────────────────
class _PrivacyPage extends ConsumerStatefulWidget {
  final AppUser? user;
  const _PrivacyPage({this.user});
  @override
  ConsumerState<_PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<_PrivacyPage> {
  static String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours} h';
    return 'Il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return _SubPageShell(
      title: 'Confidentialité & Données',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Sécurité de session ────────────────────────────────────────
          _SectionLabel('SESSION'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: _green.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.verified_user_outlined, size: 18, color: _green),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dernière connexion',
                    style: TextStyle(
                        color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    widget.user?.lastSeenAt != null
                        ? _formatRelative(widget.user!.lastSeenAt!)
                        : 'Première connexion',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: _green.withOpacity(.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('Actif',
                    style: TextStyle(
                        color: _green, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Données ───────────────────────────────────────────────────
          _SectionLabel('DONNÉES'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemToggle(
                icon: Icons.analytics_outlined,
                color: _terra,
                label: 'Partager les données d\'usage',
                value: settings.partagerDonnees,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setPartagerDonnees(v),
              ),
              _SettingsItem(
                icon: Icons.download_outlined,
                color: _green,
                label: 'Exporter mes données',
                onTap: () => _showExportSheet(context, widget.user),
              ),
              _SettingsItemComingSoon(
                icon: Icons.storage_rounded,
                color: _gold,
                label: 'Gérer le stockage local',
                description: 'Voir et vider le cache hors-ligne',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Légal ──────────────────────────────────────────────────────
          _SectionLabel('LÉGAL'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemComingSoon(
                icon: Icons.shield_outlined,
                color: const Color(0xFF1A237E),
                label: 'Politique de confidentialité',
                description: 'Document en cours de publication',
              ),
              _SettingsItemComingSoon(
                icon: Icons.gavel_rounded,
                color: const Color(0xFF4A148C),
                label: 'Conditions d\'utilisation',
                description: 'Document en cours de publication',
              ),
              _SettingsItemComingSoon(
                icon: Icons.cookie_outlined,
                color: _gold,
                label: 'Politique des cookies',
                description: 'Document en cours de publication',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // RGPD banner
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0D47A1).withOpacity(.2)),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.euro_symbol_rounded, size: 14, color: Color(0xFF0D47A1)),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Scolaris est conforme au RGPD. Vos données sont hébergées '
                'en Europe sur Supabase et ne sont jamais revendues à des tiers.',
                style: TextStyle(
                    color: Color(0xFF0D47A1), fontSize: 11.5, height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Zone critique ──────────────────────────────────────────────
          _SectionLabel('ZONE CRITIQUE'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItem(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFFF6B6B),
                label: 'Supprimer le compte',
                onTap: () => _showDeleteDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'La suppression du compte nécessite validation de l\'établissement.',
              style: TextStyle(
                  color: _muted.withOpacity(.65), fontSize: 11, height: 1.4),
            ),
          ),
        ]),
      ),
    );
  }

  void _showExportSheet(BuildContext context, AppUser? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExportSheet(user: user),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 22),
          SizedBox(width: 8),
          Text('Supprimer le compte',
              style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'La suppression d\'un compte scolaire est une opération administrative. '
          'Votre demande sera transmise à l\'administration de votre établissement '
          'qui traitera la désinscription officielle.\n\n'
          'Voulez-vous soumettre cette demande ?',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: _white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _submitDeleteRequest(context);
            },
            child: const Text('Soumettre la demande',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDeleteRequest(BuildContext context) async {
    final user = widget.user;
    if (user == null) return;
    try {
      // Demande envoyée par email (canal réel) à l'administration / support.
      final subject = Uri.encodeComponent('Demande de suppression de compte');
      final body = Uri.encodeComponent(
        'Bonjour,\n\n'
        'Je demande la suppression de mon compte Scolaris.\n\n'
        'Nom : ${user.fullName}\n'
        'Email : ${user.email}\n'
        'ID : ${user.id}\n\n'
        'Merci de traiter cette demande.');
      final uri = Uri.parse('mailto:support@scolaris.app?subject=$subject&body=$body');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!context.mounted) return;
      _showSnack(context, 'Votre logiciel mail va s\'ouvrir pour confirmer la demande.',
          color: _green);
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Impossible d\'ouvrir le logiciel mail.',
          color: const Color(0xFFFF6B6B));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Notifications (Settings)
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsSettingsPage extends ConsumerWidget {
  const _NotificationsSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;

    return _SubPageShell(
      title: 'Notifications',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _SectionLabel('ALERTES EN TEMPS RÉEL'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemToggle(
                icon: Icons.notifications_outlined,
                color: const Color(0xFF0E5FA3),
                label: 'Notifications push',
                value: settings.notificationsPush,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setNotificationsPush(v),
              ),
              _SettingsItemComingSoon(
                icon: Icons.mail_outline_rounded,
                color: const Color(0xFF6A1B9A),
                label: 'Récapitulatif par email',
                description: 'Résumé hebdomadaire des activités',
              ),
              _SettingsItemComingSoon(
                icon: Icons.campaign_outlined,
                color: _terra,
                label: 'Annonces de l\'établissement',
                description: 'Nouvelles et communications officielles',
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel('SCOLARITÉ'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemComingSoon(
                icon: Icons.grade_outlined,
                color: _gold,
                label: 'Nouvelles notes',
                description: 'Alertes dès qu\'une note est publiée',
              ),
              _SettingsItemComingSoon(
                icon: Icons.event_available_rounded,
                color: _green,
                label: 'Absences & retards',
                description: 'Notification instantanée aux parents',
              ),
              _SettingsItemComingSoon(
                icon: Icons.payment_outlined,
                color: _orange,
                label: 'Paiements & scolarité',
                description: 'Rappels d\'échéances et reçus',
              ),
              _SettingsItemComingSoon(
                icon: Icons.assignment_outlined,
                color: const Color(0xFF1A237E),
                label: 'Devoirs & évaluations',
                description: 'Rappel 24h avant les évaluations',
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel('SILENCIEUX'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemComingSoon(
                icon: Icons.bedtime_outlined,
                color: const Color(0xFF37474F),
                label: 'Mode Ne pas déranger',
                description: 'Silencieux la nuit et le week-end',
              ),
              _SettingsItemComingSoon(
                icon: Icons.schedule_outlined,
                color: _muted,
                label: 'Plages horaires',
                description: 'Définir les heures de réception',
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 15, color: cs.onSurface.withOpacity(.45)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Les notifications nécessitent l\'autorisation de votre appareil. '
                'Activez-les dans les réglages système si elles ne s\'affichent pas.',
                style: TextStyle(
                    color: cs.onSurface.withOpacity(.55),
                    fontSize: 11.5, height: 1.5),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Stockage & Cache
// ─────────────────────────────────────────────────────────────────────────────
class _StoragePage extends StatelessWidget {
  const _StoragePage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _SubPageShell(
      title: 'Stockage & Cache',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _SectionLabel('CACHE LOCAL'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withOpacity(.25)),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withOpacity(.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storage_outlined, size: 20,
                      color: Color(0xFF00695C)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cache de l\'application',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Données hors-ligne et ressources mises en cache',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(.5),
                          fontSize: 11.5)),
                ])),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _StorageBar(
                    label: 'Cours', value: 0.35, color: const Color(0xFF0E5FA3)),
                const SizedBox(width: 8),
                _StorageBar(
                    label: 'Notes', value: 0.2, color: _gold),
                const SizedBox(width: 8),
                _StorageBar(
                    label: 'Médias', value: 0.15, color: _terra),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                  label: const Text('Vider le cache',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00695C),
                    side: const BorderSide(color: Color(0xFF00695C)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showClearCacheDialog(context),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          _SectionLabel('MODE HORS-LIGNE'),
          const SizedBox(height: 8),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemComingSoon(
                icon: Icons.wifi_off_rounded,
                color: const Color(0xFF1A237E),
                label: 'Télécharger les cours',
                description: 'Accéder aux cours sans connexion internet',
              ),
              _SettingsItemComingSoon(
                icon: Icons.sync_rounded,
                color: _green,
                label: 'Synchronisation auto',
                description: 'Sync dès que la connexion est rétablie',
              ),
            ],
          ),
        ]),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.cleaning_services_outlined,
              color: const Color(0xFF00695C), size: 22),
          const SizedBox(width: 8),
          Text('Vider le cache',
              style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          'Le cache sera supprimé. L\'application rechargera les données '
          'depuis le serveur lors de la prochaine utilisation.',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface.withOpacity(.6),
              fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(.6),
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00695C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showSnack(context, 'Cache vidé avec succès', color: _green);
            },
            child: const Text('Vider', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StorageBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StorageBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: cs.onSurface.withOpacity(.55),
                fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: cs.outline.withOpacity(.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 2),
        Text('${(value * 100).round()}%',
            style: TextStyle(
                color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Support
// ─────────────────────────────────────────────────────────────────────────────
class _SupportPage extends ConsumerWidget {
  final AppUser? user;
  const _SupportPage({this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SubPageShell(
      title: 'Support',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('AIDE'),
            const SizedBox(height: 8),
            _SettingsCard(
              margin: EdgeInsets.zero,
              items: [
                _SettingsItem(
                  icon: Icons.help_outline_rounded,
                  color: _gold,
                  label: 'Aide & Centre de support',
                  onTap: () => _launchUrl('mailto:support@scolaris.app?subject=Aide%20Scolaris'),
                ),
                _SettingsItem(
                  icon: Icons.bug_report_outlined,
                  color: _orange,
                  label: 'Signaler un problème',
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: _white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => _ReportSheet(user: user),
                  ),
                ),
                _SettingsItem(
                  icon: Icons.star_outline_rounded,
                  color: _gold,
                  label: 'Noter l\'application',
                  onTap: () =>
                      _launchUrl('https://play.google.com/store/apps/details?id=app.scolaris'),
                ),
                _SettingsItem(
                  icon: Icons.info_outline_rounded,
                  color: _muted,
                  label: 'À propos de Scolaris',
                  trailing: 'v${AppConfig.appVersion}',
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_sh1, _terra, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.school_rounded, color: _white, size: 38),
              ),
              const SizedBox(height: 16),
              const Text('Scolaris',
                  style: TextStyle(
                      color: _ink, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Version ${AppConfig.appVersion}',
                  style: const TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Savoir, Héritage, Avenir',
                  style: TextStyle(
                      color: _terra, fontSize: 12, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: const Column(
                  children: [
                    _AboutRow(icon: Icons.flutter_dash, label: 'Flutter 3.32.0 (stable)'),
                    SizedBox(height: 6),
                    _AboutRow(icon: Icons.storage_rounded, label: 'Supabase — PostgreSQL + Auth'),
                    SizedBox(height: 6),
                    _AboutRow(icon: Icons.public_rounded, label: 'Stack : Dart · Riverpod · GoRouter'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _launchUrl('https://ferelking242.github.io/scolaris/');
                    },
                    child: const Text('Site web',
                        style: TextStyle(color: _terra, fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _terra,
                      foregroundColor: _white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text,
        style: TextStyle(
            color: _muted.withOpacity(.7),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// About row widget
// ─────────────────────────────────────────────────────────────────────────────
class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AboutRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: _terra),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ]);
}


// ─────────────────────────────────────────────────────────────────────────────
// Settings Card
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> items;
  final EdgeInsets margin;
  const _SettingsCard({required this.items, required this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: List.generate(
          items.length,
          (i) => Column(children: [
            items[i],
            if (i < items.length - 1)
              Divider(
                  height: 1,
                  indent: 62,
                  endIndent: 0,
                  color: _border.withOpacity(.5)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Item
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _SettingsItem({
    required this.icon,
    required this.color,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label,
                style: const TextStyle(
                    color: _ink, fontSize: 14, fontWeight: FontWeight.w500))),
            if (trailing != null) ...[
              Text(trailing!,
                  style: TextStyle(
                      color: _muted.withOpacity(.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Item Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsItemToggle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsItemToggle({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: const TextStyle(
                color: _ink, fontSize: 14, fontWeight: FontWeight.w500))),
        Switch(
          value: value,
          activeColor: _terra,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language Picker
// ─────────────────────────────────────────────────────────────────────────────
class _LanguagePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('settings.lang.title'.tr(),
              style: const TextStyle(
                  color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...AppLocales.supported.map((l) {
            final selected = context.locale == l;
            return GestureDetector(
              onTap: () { context.setLocale(l); Navigator.pop(context); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? _terra.withOpacity(.08) : _white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? _terra.withOpacity(.4) : _border),
                ),
                child: Row(children: [
                  Text(AppLocales.label(l),
                      style: TextStyle(
                          color: selected ? _terra : _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: _terra, size: 20),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password change bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();
  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPwd  = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (newPwd.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (newPwd != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPwd));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('✅ Mot de passe modifié avec succès.',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF1B5E20),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on AuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Une erreur est survenue. Réessayez.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _orange.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: _orange, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Changer le mot de passe',
                style: TextStyle(
                    color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),
          _PwdField(
            controller: _newCtrl,
            label: 'Nouveau mot de passe',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 12),
          _PwdField(
            controller: _confirmCtrl,
            label: 'Confirmer le mot de passe',
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: Color(0xFFFF6B6B)),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFFF6B6B), fontSize: 12))),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _terra,
                foregroundColor: _white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: _white, strokeWidth: 2))
                  : const Text('Modifier le mot de passe',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PwdField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  const _PwdField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted, fontSize: 13),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _terra, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _muted, size: 18),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export données bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ExportSheet extends StatefulWidget {
  final AppUser? user;
  const _ExportSheet({required this.user});
  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = widget.user;
      if (user == null) throw Exception('Non connecté');
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('auth_uid', user.id)
          .maybeSingle();
      setState(() {
        _profile = data ?? {
          'email': user.email,
          'full_name': user.fullName,
          'role': user.role.name,
        };
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _copyToClipboard() {
    if (_profile == null) return;
    final lines = _profile!.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: lines));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: const Text('Données copiées dans le presse-papiers.',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _green.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.download_outlined, color: _green, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Mes données',
                style: TextStyle(
                    color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (!_loading && _profile != null)
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: _terra, size: 20),
                tooltip: 'Copier',
                onPressed: _copyToClipboard,
              ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: _terra, strokeWidth: 2),
              ),
            )
          else if (_error != null)
            _ErrorBanner(message: _error!)
          else if (_profile != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in _profile!.entries)
                    if (entry.value != null && entry.value.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(entry.key,
                                  style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              child: Text(entry.value.toString(),
                                  style: const TextStyle(
                                      color: _ink, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _terra.withOpacity(.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _terra.withOpacity(.2)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _terra),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ces données sont stockées de façon sécurisée sur nos serveurs Supabase.',
                  style: TextStyle(color: _terra, fontSize: 11.5, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report problem bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ReportSheet extends StatefulWidget {
  final AppUser? user;
  const _ReportSheet({required this.user});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _ctrl  = TextEditingController();
  String _type = 'Bug';
  bool _loading = false;

  final _types = ['Bug', 'Problème de connexion', 'Contenu incorrect',
                  'Interface', 'Performance', 'Autre'];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final desc = _ctrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('Décrivez le problème avant d\'envoyer.'),
          backgroundColor: _orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      // Envoi par email (canal réel) — pas de backend de tickets pour l'instant.
      final subject = Uri.encodeComponent('Signalement Scolaris — $_type');
      final body = Uri.encodeComponent(
        '$desc\n\n'
        '-----------------------------\n'
        'Utilisateur : ${widget.user?.email ?? "?"}\n'
        'ID : ${widget.user?.id ?? "?"}\n'
        'Version : ${AppConfig.appVersion}');
      final uri = Uri.parse('mailto:support@scolaris.app?subject=$subject&body=$body');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('Votre logiciel mail va s\'ouvrir pour envoyer le signalement.',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _orange.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bug_report_outlined, color: _orange, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Signaler un problème',
                style: TextStyle(
                    color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _types.map((t) {
              final selected = _type == t;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? _terra.withOpacity(.1) : _bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? _terra.withOpacity(.4) : _border),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          color: selected ? _terra : _muted,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Décrivez le problème en détail…',
              hintStyle: TextStyle(color: _muted.withOpacity(.6), fontSize: 13),
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _terra, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _terra,
                foregroundColor: _white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: _white, strokeWidth: 2))
                  : const Text('Envoyer le signalement',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row — clé / valeur read-only dans une card
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _InfoRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
          color: _terra.withOpacity(.08),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: _terra),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 1),
      Text(value,
          style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w500)),
    ])),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings item "Bientôt disponible" (disabled, badge)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsItemComingSoon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, description;
  const _SettingsItemComingSoon({
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: color.withOpacity(.5)),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: _ink.withOpacity(.45),
                fontSize: 13.5,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 1),
        Text(description,
            style: TextStyle(
                color: _muted.withOpacity(.55), fontSize: 11)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _gold.withOpacity(.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _gold.withOpacity(.3)),
        ),
        child: Text('Bientôt',
            style: TextStyle(
                color: _gold.withOpacity(.9),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4)),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFFF6B6B)),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: const TextStyle(
                  color: Color(0xFFFF6B6B), fontSize: 12))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Snack helper
// ─────────────────────────────────────────────────────────────────────────────
void _showSnack(BuildContext context, String msg, {required Color color}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
