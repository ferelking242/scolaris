import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/localization/locales.dart';
import '../../core/services/offline_storage.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import 'account_page.dart';

// ── Tokens ──────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Settings hub — navigation principale
// ─────────────────────────────────────────────────────────────────────────────
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user     = ref.watch(authSessionProvider);
    final name     = user?.fullName ?? 'Utilisateur';
    final email    = user?.email ?? '';
    final roleName = switch (user?.role) {
      UserRole.staff   => 'Administration',
      UserRole.teacher => 'Enseignant',
      UserRole.student => 'Élève',
      UserRole.parent  => 'Parent',
      null             => '—',
    };
    final seed = name.replaceAll(' ', '+');
    final avatarUrl =
        'https://api.dicebear.com/7.x/bottts-neutral/png?seed=$seed&size=128&backgroundColor=transparent';
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bannière + Avatar ──────────────────────────────────────────
            _ProfileBanner(
              name: name,
              email: email,
              roleName: roleName,
              initials: initials,
              avatarUrl: avatarUrl,
              onAccount: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AccountPage())),
            ),

            const SizedBox(height: 28),

            // ── Navigation sections ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                _SettingsNavCard(items: [
                  _SettingsNavRow(
                    icon: Icons.person_outline_rounded,
                    color: _terra,
                    title: 'Compte',
                    subtitle: 'Profil, mot de passe, notifications',
                    onTap: () => _push(context, _AccountSettingsPage(user: user)),
                  ),
                  _SettingsNavRow(
                    icon: Icons.palette_outlined,
                    color: _orange,
                    title: 'Apparence',
                    subtitle: 'Thème, affichage',
                    onTap: () => _push(context, const _AppearancePage()),
                  ),
                  _SettingsNavRow(
                    icon: Icons.accessibility_new_rounded,
                    color: _gold,
                    title: 'Accessibilité',
                    subtitle: 'Police, contraste, animations',
                    onTap: () => _push(context, const _AccessibilityPage()),
                  ),
                  _SettingsNavRow(
                    icon: Icons.security_outlined,
                    color: _green,
                    title: 'Confidentialité & Données',
                    subtitle: 'Usage, export, suppression',
                    onTap: () => _push(context, _PrivacyPage(user: user)),
                  ),
                  _SettingsNavRow(
                    icon: Icons.help_outline_rounded,
                    color: _muted,
                    title: 'Support',
                    subtitle: 'Aide, signalement, à propos',
                    onTap: () => _push(context, _SupportPage(user: user)),
                    isLast: true,
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 32),

            // ── Déconnexion ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: const Color(0xFFFF6B6B).withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _confirmSignOut(context, ref),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(.3)),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: Color(0xFFFF6B6B)),
                        SizedBox(width: 8),
                        Text('Se déconnecter',
                            style: TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
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

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter',
            style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: _muted, fontSize: 13),
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
              try {
                await ref.read(signOutUseCaseProvider)();
              } finally {
                if (context.mounted) context.go('/login');
              }
            },
            child: const Text('Déconnecter',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bannière profil — avatar à gauche avec arc de connexion
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBanner extends StatelessWidget {
  final String name, email, roleName, initials, avatarUrl;
  final VoidCallback onAccount;

  const _ProfileBanner({
    required this.name,
    required this.email,
    required this.roleName,
    required this.initials,
    required this.avatarUrl,
    required this.onAccount,
  });

  // Avatar: 84x84, positioned at left:20
  // Avatar center X = 20 + 42 = 62
  // Outer radius incl. border gap = 46
  static const double _avatarSize   = 84.0;
  static const double _avatarLeft   = 20.0;
  static const double _avatarCenterX = _avatarLeft + _avatarSize / 2; // 62
  static const double _arcRadius    = _avatarSize / 2 + 4;            // 46
  static const double _bannerH      = 140.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stack bannière + avatar ──────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Bannière clippée avec arc
            ClipPath(
              clipper: _BannerClipper(
                avatarCenterX: _avatarCenterX,
                arcRadius: _arcRadius,
              ),
              child: Container(
                height: _bannerH,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_sh1, _sh2, Color(0xFF6B1200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _HexPainter())),
                ]),
              ),
            ),

            // Avatar — centré sur l'arc
            Positioned(
              top: _bannerH - _avatarSize / 2,
              left: _avatarLeft,
              child: Container(
                width: _avatarSize,
                height: _avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 4),
                  gradient: const LinearGradient(
                    colors: [_terra, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(initials,
                          style: const TextStyle(
                              color: _white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bouton modifier bannière (haut-droite) ─────────────────
            Positioned(
              top: 10, right: 10,
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: _white,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _MediaSheet(
                      title: 'Changer la bannière', showTheme: true),
                ),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.38),
                    shape: BoxShape.circle,
                    border: Border.all(color: _white.withOpacity(.25)),
                  ),
                  child: const Icon(Icons.photo_camera_rounded,
                      color: _white, size: 15),
                ),
              ),
            ),

            // ── Bouton caméra avatar (bas-droite) ──────────────────────
            Positioned(
              top: _bannerH - _avatarSize / 2 + _avatarSize - 24,
              left: _avatarLeft + _avatarSize - 24,
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: _white,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => const _MediaSheet(
                      title: 'Changer la photo de profil', showTheme: false),
                ),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _terra,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: _white, size: 12),
                ),
              ),
            ),
          ],
        ),

        // ── Espace pour la moitié basse de l'avatar ───────────────────
        const SizedBox(height: _avatarSize / 2 + 12),

        // ── Nom + rôle + email ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(email,
                        style: const TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _terra.withOpacity(.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _terra.withOpacity(.25)),
                      ),
                      child: Text(roleName.toUpperCase(),
                          style: const TextStyle(
                              color: _terra,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onAccount,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _terra.withOpacity(.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _terra.withOpacity(.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded, size: 15, color: _terra),
                      SizedBox(width: 6),
                      Text('Voir profil',
                          style: TextStyle(
                              color: _terra,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner clipper — arc concave pour l'avatar
// ─────────────────────────────────────────────────────────────────────────────
class _BannerClipper extends CustomClipper<Path> {
  final double avatarCenterX;
  final double arcRadius;
  const _BannerClipper({required this.avatarCenterX, required this.arcRadius});

  @override
  Path getClip(Size size) {
    final h = size.height;
    final cx = avatarCenterX;
    final r  = arcRadius;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, h)
      ..lineTo(cx + r, h)
      ..arcToPoint(
        Offset(cx - r, h),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(0, h)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation card — contient des rows cliquables
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsNavCard extends StatelessWidget {
  final List<Widget> items;
  const _SettingsNavCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: items),
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _SettingsNavRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : BorderRadius.zero,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
              ]),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 68, endIndent: 0, color: _border.withOpacity(.5)),
      ],
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0.8,
            shadowColor: cs.shadow.withOpacity(0.1),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: cs.onSurface, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
              expandedTitleScale: 1.75,
              collapseMode: CollapseMode.pin,
              title: Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              background: Container(color: cs.surface),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child:
                  Container(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
            ),
          ),
        ],
        body: child,
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
    final settings = ref.watch(settingsProvider);
    final locale   = context.locale;
    final langName = AppLocales.label(locale);
    final user     = widget.user;

    return _SubPageShell(
      title: 'Compte',
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
              _SettingsItemToggle(
                icon: Icons.notifications_outlined,
                color: _terra,
                label: 'Notifications push',
                value: settings.notificationsPush,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setNotificationsPush(v),
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
  // 20 couleurs prédéfinies organisées par famille
  static const _presets = [
    // Africain chaud
    Color(0xFF8B1A00), Color(0xFFD4540A), Color(0xFFC17F24), Color(0xFF1B5E20),
    // Bleus institutionnels
    Color(0xFF0D47A1), Color(0xFF0277BD), Color(0xFF1565C0), Color(0xFF00695C),
    // Violet / rose
    Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF880E4F), Color(0xFFAD1457),
    // Neutrals
    Color(0xFF263238), Color(0xFF37474F), Color(0xFF4E342E), Color(0xFF212121),
    // Vifs
    Color(0xFFE53935), Color(0xFF43A047), Color(0xFFF57C00), Color(0xFF1E88E5),
  ];

  void _openPicker(BuildContext context, Color current) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HsvPickerSheet(
        initial: current,
        onApply: (c) => ref.read(themeControllerProvider.notifier).setAccent(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final ctrl      = ref.watch(themeControllerProvider);
    final themeMode = ctrl.mode;
    final accent    = ctrl.accent;
    final pureBlack = ctrl.pureBlack;
    final settings  = ref.watch(settingsProvider);
    final notifier  = ref.read(themeControllerProvider.notifier);

    return _SubPageShell(
      title: 'Apparence',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Thème ──────────────────────────────────────────────────────
          _SectionLabel('THÈME'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ThemeModeCard(
              icon: Icons.light_mode_rounded,
              label: 'Clair',
              previewBg: const Color(0xFFF5F5F5),
              previewFg: const Color(0xFF1A1A1A),
              selected: themeMode == ThemeMode.light && !pureBlack,
              accent: accent,
              onTap: () { notifier.setMode(ThemeMode.light); notifier.setPureBlack(false); },
            )),
            const SizedBox(width: 8),
            Expanded(child: _ThemeModeCard(
              icon: Icons.dark_mode_rounded,
              label: 'Sombre',
              previewBg: const Color(0xFF1C1C1E),
              previewFg: const Color(0xFFEEEEEE),
              selected: themeMode == ThemeMode.dark && !pureBlack,
              accent: accent,
              onTap: () { notifier.setMode(ThemeMode.dark); notifier.setPureBlack(false); },
            )),
            const SizedBox(width: 8),
            Expanded(child: _ThemeModeCard(
              icon: Icons.brightness_auto_rounded,
              label: 'Auto',
              previewBg: const Color(0xFF888888),
              previewFg: Colors.white,
              isAuto: true,
              selected: themeMode == ThemeMode.system && !pureBlack,
              accent: accent,
              onTap: () { notifier.setMode(ThemeMode.system); notifier.setPureBlack(false); },
            )),
            const SizedBox(width: 8),
            Expanded(child: _ThemeModeCard(
              icon: Icons.contrast_rounded,
              label: 'Noir pur',
              previewBg: Colors.black,
              previewFg: Colors.white,
              selected: pureBlack,
              accent: accent,
              onTap: () { notifier.setMode(ThemeMode.dark); notifier.setPureBlack(true); },
            )),
          ]),
          if (pureBlack) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 14, color: accent),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Mode Noir pur actif — fond #000000 pour écrans AMOLED.',
                  style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w500),
                )),
              ]),
            ),
          ],
          const SizedBox(height: 24),

          // ── Couleur d'accent ───────────────────────────────────────────
          _SectionLabel('COULEUR D\'ACCENT'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: accent.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3))],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Couleur active',
                      style: TextStyle(
                          color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    '#${accent.red.toRadixString(16).padLeft(2, '0')}'
                    '${accent.green.toRadixString(16).padLeft(2, '0')}'
                    '${accent.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase(),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5),
                  ),
                ])),
                GestureDetector(
                  onTap: () => _openPicker(context, accent),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.colorize_rounded, size: 13, color: accent),
                      const SizedBox(width: 5),
                      Text('Choisir',
                          style: TextStyle(
                              color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Text('Palettes prédéfinies',
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10,
                children: _presets.map((c) {
                  final sel = c.value == accent.value;
                  return GestureDetector(
                    onTap: () => notifier.setAccent(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: cs.onSurface, width: 2.5)
                            : Border.all(color: Colors.transparent),
                        boxShadow: [BoxShadow(
                            color: c.withOpacity(sel ? .5 : .15),
                            blurRadius: sel ? 8 : 3)],
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Affichage ──────────────────────────────────────────────────
          _SectionLabel('AFFICHAGE'),
          const SizedBox(height: 10),
          _SettingsCard(
            margin: EdgeInsets.zero,
            items: [
              _SettingsItemToggle(
                icon: Icons.tab_rounded,
                color: _orange,
                label: 'Barre d\'onglets',
                value: settings.afficherBarreOnglets,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setAfficherBarreOnglets(v),
              ),
              _SettingsItemToggle(
                icon: Icons.format_size_rounded,
                color: const Color(0xFF1565C0),
                label: 'Grande police (+20%)',
                value: settings.grandePolice,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setGrandePolice(v),
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
        ]),
      ),
    );
  }
}

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
        _MediaOption(
            icon: Icons.photo_camera_rounded, label: 'Prendre une photo'),
        const SizedBox(height: 10),
        _MediaOption(
            icon: Icons.photo_library_rounded, label: 'Choisir depuis la galerie'),
        if (showTheme) ...[
          const SizedBox(height: 10),
          _MediaOption(
              icon: Icons.palette_outlined, label: 'Couleur / thème de bannière'),
        ],
      ]),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MediaOption({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: _terra),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(
              color: _ink, fontSize: 13.5, fontWeight: FontWeight.w500)),
        ]),
      ),
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
  double _textScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

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
                          fontSize: 10 * _textScale,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Tableau de bord — Scolaris',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 15 * _textScale,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Terminale S · 28 élèves inscrits · Année 2025–26',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 12 * _textScale,
                          height: 1.4)),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.text_decrease_rounded, size: 15, color: _muted),
                Expanded(
                  child: Slider(
                    value: _textScale,
                    min: 0.8, max: 1.4, divisions: 6,
                    activeColor: _terra,
                    inactiveColor: _border,
                    onChanged: (v) => setState(() => _textScale = v),
                  ),
                ),
                const Icon(Icons.text_increase_rounded, size: 20, color: _muted),
              ]),
              Center(
                child: Text(
                  '${(_textScale * 100).round()} %',
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
  static final _lastLogin = DateTime.now().subtract(const Duration(hours: 2));

  static String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours} h';
    return 'Il y a ${diff.inDays} j';
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
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
                Text(_formatRelative(_lastLogin),
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
              _SettingsItem(
                icon: Icons.shield_outlined,
                color: const Color(0xFF1A237E),
                label: 'Politique de confidentialité',
                onTap: () =>
                    _launchUrl('https://ferelking242.github.io/scolaris/privacy'),
              ),
              _SettingsItem(
                icon: Icons.gavel_rounded,
                color: const Color(0xFF4A148C),
                label: 'Conditions d\'utilisation',
                onTap: () =>
                    _launchUrl('https://ferelking242.github.io/scolaris/terms'),
              ),
              _SettingsItem(
                icon: Icons.cookie_outlined,
                color: _gold,
                label: 'Politique des cookies',
                onTap: () =>
                    _launchUrl('https://ferelking242.github.io/scolaris/cookies'),
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
      await OfflineStorage.queueAction('delete_account_request', {
        'user_id': user.id,
        'email': user.email,
        'name': user.fullName,
        'requested_at': DateTime.now().toIso8601String(),
      });
      if (!context.mounted) return;
      _showSnack(context, '✅ Demande soumise. L\'administration vous contactera.',
          color: _green);
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, 'Erreur lors de l\'envoi de la demande.',
          color: const Color(0xFFFF6B6B));
    }
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(.8),
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
// Hex painter for banner
// ─────────────────────────────────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _white.withOpacity(.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const s = 28.0;
    final cols = (size.width  / s).ceil() + 2;
    final rows = (size.height / (s * 0.866)).ceil() + 2;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * s * 1.5 - s * 0.5;
        final cy = r * s * 0.866 + (c.isOdd ? s * 0.433 : 0);
        _hex(canvas, Offset(cx, cy), s * 0.5, paint);
      }
    }
  }

  void _hex(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 3 * i - math.pi / 6;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
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
                  color: cs.outlineVariant.withOpacity(.4)),
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
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500))),
            if (trailing != null) ...[
              Text(trailing!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18),
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
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500))),
        Switch(
          value: value,
          activeColor: Theme.of(context).colorScheme.primary,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Item Theme
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsItemTheme extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String currentValue;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;
  const _SettingsItemTheme({
    required this.icon, required this.color, required this.label,
    required this.currentValue, required this.themeMode, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(currentValue,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 50),
            Expanded(
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 14),
                      label: Text('Clair')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 14),
                      label: Text('Sombre')),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.phone_android_outlined, size: 14),
                      label: Text('Auto')),
                ],
                selected: {themeMode},
                showSelectedIcon: false,
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                onSelectionChanged: (s) => onChanged(s.first),
              ),
            ),
          ]),
        ],
      ),
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
          const Text('Choisir la langue',
              style: TextStyle(
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
      await OfflineStorage.queueAction('bug_report', {
        'type': _type,
        'description': desc,
        'user_id': widget.user?.id,
        'email': widget.user?.email,
        'reported_at': DateTime.now().toIso8601String(),
        'app_version': AppConfig.appVersion,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('✅ Signalement envoyé. Merci pour votre retour !',
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

// ─────────────────────────────────────────────────────────────────────────────
// _ThemeModeCard — carte visuelle de sélection du mode thème
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color previewBg;
  final Color previewFg;
  final bool selected;
  final bool isAuto;
  final Color accent;
  final VoidCallback onTap;

  const _ThemeModeCard({
    required this.icon,
    required this.label,
    required this.previewBg,
    required this.previewFg,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.isAuto = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 90,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : cs.outlineVariant.withOpacity(0.4),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: accent.withOpacity(0.18),
                  blurRadius: 10,
                  spreadRadius: 0)]
              : [],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mini-prévisualisation
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isAuto
                    ? Row(children: [
                        Expanded(
                          child: Container(
                            color: const Color(0xFFF5F5F5),
                            child: Column(children: [
                              Container(
                                  height: 8,
                                  color: Colors.white,
                                  margin: const EdgeInsets.all(3)),
                              Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDDDDDD),
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                            ]),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: const Color(0xFF1C1C1E),
                            child: Column(children: [
                              Container(
                                  height: 8,
                                  color: const Color(0xFF2C2C2E),
                                  margin: const EdgeInsets.all(3)),
                              Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF48484A),
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                            ]),
                          ),
                        ),
                      ])
                    : Container(
                        color: previewBg,
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // mini barre de nav
                            Container(
                              height: 7,
                              decoration: BoxDecoration(
                                color: previewFg.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              height: 3,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: previewFg.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              height: 3,
                              width: 28,
                              decoration: BoxDecoration(
                                color: previewFg.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                            const Spacer(),
                            // mini bouton accent
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                width: 18,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 5),
            // Icône + label
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 11,
                    color: selected ? accent : cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? accent : cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
