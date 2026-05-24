import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locales.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import 'account_page.dart';

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
const _shTxt  = Color(0xFFE8DDD0);

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
    final themeMode = ref.watch(themeControllerProvider).mode;
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

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Bannière + Avatar 3D ─────────────────────────────────────────
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
                    Positioned.fill(
                      child: CustomPaint(painter: _HexPainter()),
                    ),
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

                // Avatar 3D
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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

                // Réserve la hauteur du stack
                const SizedBox(height: 210),
              ],
            ),

            // ── Nom + email ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
              child: Row(
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
                            style: const TextStyle(
                                color: _muted, fontSize: 13)),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.person_outline_rounded,
                              size: 15, color: _terra),
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
                        MaterialPageRoute(
                            builder: (_) => const AccountPage())),
                  ),
                  _SettingsItem(
                    icon: Icons.lock_outline_rounded,
                    color: _orange,
                    label: 'Mot de passe & Sécurité',
                    onTap: () {},
                  ),
                  _SettingsItemToggle(
                    icon: Icons.notifications_outlined,
                    color: _gold,
                    label: 'Notifications push',
                    value: true,
                  ),
                  _SettingsItem(
                    icon: Icons.language_outlined,
                    color: _green,
                    label: 'Langue',
                    trailing: langName,
                    onTap: () => _showLanguagePicker(context, ref),
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
                    value: false,
                  ),
                  _SettingsItemToggle(
                    icon: Icons.contrast_rounded,
                    color: _orange,
                    label: 'Contraste élevé',
                    value: false,
                  ),
                  _SettingsItemToggle(
                    icon: Icons.animation_rounded,
                    color: _gold,
                    label: 'Réduire les animations',
                    value: false,
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
                    value: true,
                  ),
                  _SettingsItem(
                    icon: Icons.download_outlined,
                    color: _green,
                    label: 'Exporter mes données',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFFF6B6B),
                    label: 'Supprimer le compte',
                    onTap: () {},
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
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.bug_report_outlined,
                    color: _orange,
                    label: 'Signaler un problème',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.star_outline_rounded,
                    color: _gold,
                    label: 'Noter l\'application',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: Icons.info_outline_rounded,
                    color: _muted,
                    label: 'À propos de Scolaris',
                    trailing: 'v0.1.0',
                    onTap: () {},
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // ── Déconnexion ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => ref.read(signOutUseCaseProvider)(),
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
                      Icon(Icons.logout_rounded,
                          size: 18, color: Color(0xFFFF6B6B)),
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

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _LanguagePicker(),
    );
  }
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Row(children: [
          Text(title,
              style: TextStyle(
                  color: _muted.withOpacity(.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const Spacer(),
          Icon(
            closed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
            size: 16,
            color: _muted.withOpacity(.5),
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
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2))
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
                style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500))),
            if (trailing != null) ...[
              Text(trailing!,
                  style: TextStyle(
                      color: _muted.withOpacity(.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: _muted, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Item Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsItemToggle extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  const _SettingsItemToggle({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  @override
  State<_SettingsItemToggle> createState() => _SettingsItemToggleState();
}

class _SettingsItemToggleState extends State<_SettingsItemToggle> {
  late bool _v;
  @override
  void initState() { super.initState(); _v = widget.value; }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, size: 18, color: widget.color),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(widget.label,
            style: const TextStyle(
                color: _ink, fontSize: 14, fontWeight: FontWeight.w500))),
        Switch(
          value: _v,
          activeColor: _terra,
          onChanged: (v) => setState(() => _v = v),
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
                  textStyle: WidgetStateProperty.all(const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
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
