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

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final Set<String> _closed = {};

  void _toggle(String key) => setState(() {
        if (_closed.contains(key)) {
          _closed.remove(key);
        } else {
          _closed.add(key);
        }
      });

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(authSessionProvider);
    final themeCtrl = ref.watch(themeControllerProvider);
    final themeMode = themeCtrl.mode;
    final pureBlack = themeCtrl.pureBlack;
    final accent    = themeCtrl.accent;
    final settings  = ref.watch(settingsProvider);
    final locale    = context.locale;

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

    final themeName = themeMode == ThemeMode.dark
        ? 'Sombre'
        : themeMode == ThemeMode.light ? 'Clair' : 'Système';
    final langName = AppLocales.label(locale);

    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Bannière ─────────────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 160,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_sh1, _sh2, Color(0xFF6B1200)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _HexPainter())),
                    Positioned(
                      top: 0, left: 0,
                      child: SafeArea(
                        child: GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _white.withOpacity(.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: _white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),

                // Avatar
                Positioned(
                  bottom: -44, left: 24,
                  child: Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 4),
                      gradient: const LinearGradient(
                        colors: [_terra, _orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _terra.withOpacity(.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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

                // Badge rôle
                Positioned(
                  bottom: -36, left: 120,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _terra.withOpacity(.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _terra.withOpacity(.3)),
                    ),
                    child: Text(roleName.toUpperCase(),
                        style: const TextStyle(
                            color: _terra,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ),
                ),

                const SizedBox(height: 210),
              ],
            ),

            // ── Nom + email ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(email,
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const AccountPage())),
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

            const SizedBox(height: 28),

            // ── Section : Compte ─────────────────────────────────────────────
            _SectionHeader(
              title: 'COMPTE',
              sectionKey: 'compte',
              closed: _closed.contains('compte'),
              onTap: () => _toggle('compte'),
            ),
            if (!_closed.contains('compte'))
              _SettingsCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    onTap: () => _showPasswordSheet(context, ref),
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

            const SizedBox(height: 20),

            // ── Section : Apparence ──────────────────────────────────────────
            _SectionHeader(
              title: 'APPARENCE',
              sectionKey: 'apparence',
              closed: _closed.contains('apparence'),
              onTap: () => _toggle('apparence'),
            ),
            if (!_closed.contains('apparence'))
              _SettingsCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                items: [
                  _SettingsItemTheme(
                    icon: Icons.palette_outlined,
                    color: _terra,
                    label: 'Thème',
                    currentValue: themeName,
                    themeMode: themeMode,
                    onChanged: (m) =>
                        ref.read(themeControllerProvider.notifier).setMode(m),
                  ),
                  _AccentPicker(
                    current: accent,
                    onPick: (c) =>
                        ref.read(themeControllerProvider.notifier).setAccent(c),
                  ),
                  if (themeMode != ThemeMode.light)
                    _SettingsItemToggle(
                      icon: Icons.phone_iphone_rounded,
                      color: const Color(0xFF303030),
                      label: 'Écran AMOLED (noir pur)',
                      value: pureBlack,
                      onChanged: (v) =>
                          ref.read(themeControllerProvider.notifier).setPureBlack(v),
                    ),
                ],
              ),

            const SizedBox(height: 20),

            // ── Section : Accessibilité ──────────────────────────────────────
            _SectionHeader(
              title: 'ACCESSIBILITÉ',
              sectionKey: 'access',
              closed: _closed.contains('access'),
              onTap: () => _toggle('access'),
            ),
            if (!_closed.contains('access'))
              _SettingsCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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

            const SizedBox(height: 20),

            // ── Section : Confidentialité ────────────────────────────────────
            _SectionHeader(
              title: 'CONFIDENTIALITÉ & DONNÉES',
              sectionKey: 'privacy',
              closed: _closed.contains('privacy'),
              onTap: () => _toggle('privacy'),
            ),
            if (!_closed.contains('privacy'))
              _SettingsCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    onTap: () => _showExportSheet(context, ref, user),
                  ),
                  _SettingsItem(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFFF6B6B),
                    label: 'Supprimer le compte',
                    onTap: () => _showDeleteDialog(context, ref),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // ── Section : Support ────────────────────────────────────────────
            _SectionHeader(
              title: 'SUPPORT',
              sectionKey: 'support',
              closed: _closed.contains('support'),
              onTap: () => _toggle('support'),
            ),
            if (!_closed.contains('support'))
              _SettingsCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    onTap: () => _showReportSheet(context, ref, user),
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

            const SizedBox(height: 32),

            // ── Déconnexion ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => _confirmSignOut(context, ref),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFF6B6B).withOpacity(.3)),
                  ),
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
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Langue picker ──────────────────────────────────────────────────────────
  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _LanguagePicker(),
    );
  }

  // ── Password change ────────────────────────────────────────────────────────
  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _PasswordSheet(),
    );
  }

  // ── Export données ─────────────────────────────────────────────────────────
  void _showExportSheet(BuildContext context, WidgetRef ref, AppUser? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExportSheet(user: user),
    );
  }

  // ── Supprimer le compte ────────────────────────────────────────────────────
  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
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
              await _submitDeleteRequest(context, ref);
            },
            child: const Text('Soumettre la demande',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDeleteRequest(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authSessionProvider);
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
      _showSnack(context, 'Erreur lors de l\'envoi de la demande.', color: const Color(0xFFFF6B6B));
    }
  }

  // ── Signaler un problème ───────────────────────────────────────────────────
  void _showReportSheet(BuildContext context, WidgetRef ref, AppUser? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportSheet(user: user),
    );
  }

  // ── À propos ───────────────────────────────────────────────────────────────
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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

  // ── Déconnexion avec confirmation ──────────────────────────────────────────
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void _showSnack(BuildContext context, String msg, {required Color color}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
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
// Password change bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();
  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _newCtrl    = TextEditingController();
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

          // Nouveau mot de passe
          _PwdField(
            controller: _newCtrl,
            label: 'Nouveau mot de passe',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 12),

          // Confirmer
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
                      child: CircularProgressIndicator(
                          color: _white, strokeWidth: 2))
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
                  'Ces données sont stockées de façon sécurisée sur nos serveurs Supabase. '
                  'Utilisez le bouton Copier pour en garder une trace locale.',
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

          // Type selector
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _types.map((t) {
              final selected = _type == t;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
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
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500)),
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
                      child: CircularProgressIndicator(
                          color: _white, strokeWidth: 2))
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
// Section header repliable
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String sectionKey;
  final bool closed;
  final VoidCallback onTap;
  const _SectionHeader({
    required this.title,
    required this.sectionKey,
    required this.closed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ov = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Row(children: [
          Text(title,
              style: TextStyle(
                  color: ov.withOpacity(.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const Spacer(),
          Icon(
            closed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
            size: 16,
            color: ov.withOpacity(.5),
          ),
        ]),
      ),
    );
  }
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
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))
        ],
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
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14, fontWeight: FontWeight.w500))),
            if (trailing != null) ...[
              Text(trailing!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Item Toggle — stateless, driven by parent provider
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
                fontSize: 14, fontWeight: FontWeight.w500))),
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
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14, fontWeight: FontWeight.w500)),
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
// Accent colour picker
// ─────────────────────────────────────────────────────────────────────────────
class _AccentPicker extends StatelessWidget {
  final Color current;
  final ValueChanged<Color> onPick;
  const _AccentPicker({required this.current, required this.onPick});

  static const _presets = [
    Color(0xFF8B1A00),
    Color(0xFFE65100),
    Color(0xFFB8860B),
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFF6A0DAD),
    Color(0xFF00695C),
    Color(0xFFAD1457),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: current.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.color_lens_outlined, size: 18, color: current),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Couleur accent',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _presets.map((c) {
                  final sel = c.value == current.value;
                  return GestureDetector(
                    onTap: () => onPick(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? cs.onSurface : Colors.transparent,
                          width: sel ? 2.5 : 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withOpacity(.45),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: sel
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
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
// Hex pattern painter
// ─────────────────────────────────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  final double opacity;
  const _HexPainter({this.opacity = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    const r = 18.0;
    final dx = r * math.sqrt(3);
    final dy = r * 1.5;
    for (double y = -r; y < size.height + r * 2; y += dy) {
      for (double x = -dx; x < size.width + dx; x += dx) {
        final off = ((y / dy).floor() % 2 == 0) ? 0.0 : dx / 2;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final p = Offset(x + off + r * math.cos(a), y + r * math.sin(a));
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) => old.opacity != opacity;
}
