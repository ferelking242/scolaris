import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Container(
      color: _bg,
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
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(signOutUseCaseProvider)();
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
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: _white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Text(title,
                  style: const TextStyle(
                      color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
          ),
          Container(height: 1, color: _border.withOpacity(.4)),
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
    final settings = ref.watch(settingsProvider);
    final locale   = context.locale;
    final langName = AppLocales.label(locale);

    return _SubPageShell(
      title: 'Compte',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
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
              _SettingsItemToggle(
                icon: Icons.notifications_outlined,
                color: _gold,
                label: 'Notifications push',
                value: settings.notificationsPush,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setNotificationsPush(v),
              ),
              _SettingsItem(
                icon: Icons.language_outlined,
                color: _green,
                label: 'Langue',
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
class _AppearancePage extends ConsumerWidget {
  const _AppearancePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider).mode;
    final settings  = ref.watch(settingsProvider);
    final themeName = themeMode == ThemeMode.dark
        ? 'Sombre'
        : themeMode == ThemeMode.light ? 'Clair' : 'Système';

    return _SubPageShell(
      title: 'Apparence',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thème
            _SectionLabel('THÈME'),
            const SizedBox(height: 8),
            _SettingsCard(
              margin: EdgeInsets.zero,
              items: [
                _SettingsItemTheme(
                  icon: Icons.palette_outlined,
                  color: _terra,
                  label: 'Thème de l\'interface',
                  currentValue: themeName,
                  themeMode: themeMode,
                  onChanged: (m) =>
                      ref.read(themeControllerProvider.notifier).setMode(m),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Navigation
            _SectionLabel('NAVIGATION'),
            const SizedBox(height: 8),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Accessibilité
// ─────────────────────────────────────────────────────────────────────────────
class _AccessibilityPage extends ConsumerWidget {
  const _AccessibilityPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return _SubPageShell(
      title: 'Accessibilité',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('AFFICHAGE'),
            const SizedBox(height: 8),
            _SettingsCard(
              margin: EdgeInsets.zero,
              items: [
                _SettingsItemToggle(
                  icon: Icons.text_increase_rounded,
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
          ],
        ),
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
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return _SubPageShell(
      title: 'Confidentialité & Données',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                _SettingsItem(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFFF6B6B),
                  label: 'Supprimer le compte',
                  onTap: () => _showDeleteDialog(context),
                ),
              ],
            ),
          ],
        ),
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
                style: const TextStyle(
                    color: _ink, fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(currentValue,
                style: TextStyle(color: _muted.withOpacity(.8), fontSize: 12)),
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
