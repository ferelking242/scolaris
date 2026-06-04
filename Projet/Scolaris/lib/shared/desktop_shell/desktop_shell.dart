import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/theme_controller.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import '../pages/notifications_page.dart';
import '../pages/settings_page.dart';
import '../../core/services/shell_navigator.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg      = Color(0xFFF5EEE6);
const _terra   = Color(0xFF8B1A00);
const _orange  = Color(0xFFD4540A);
const _gold    = Color(0xFFC17F24);
const _ink     = Color(0xFF1A0A00);
const _muted   = Color(0xFF7A5C44);
const _border  = Color(0xFFDDCCBB);
const _white   = Colors.white;

// Unified dark shell — sidebar + header share this palette
const _sh1     = Color(0xFF1A0A00);
const _sh2     = Color(0xFF3E1A00);
const _shTxt   = Color(0xFFE8DDD0);
const _shMuted = Color(0xFFB89880);

// ── 2 sidebar modes (hidden supprimé) ────────────────────────────────────────
enum _SideMode { full, icons }

// ─────────────────────────────────────────────────────────────────────────────
// Public data classes
// ─────────────────────────────────────────────────────────────────────────────
class DesktopNavGroup {
  final String labelKey;
  final List<DesktopNavItem> items;
  const DesktopNavGroup({required this.labelKey, required this.items});
}

class DesktopNavItem {
  final IconData icon;
  final String labelKey;
  final Widget page;
  const DesktopNavItem({
    required this.icon,
    required this.labelKey,
    required this.page,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell
// ─────────────────────────────────────────────────────────────────────────────
class DesktopShell extends ConsumerStatefulWidget {
  final List<DesktopNavGroup> groups;
  final UserRole role;
  final String title;

  const DesktopShell({
    super.key,
    required this.groups,
    required this.role,
    required this.title,
  });

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _flatIndex = 0;
  _SideMode _mode = _SideMode.icons;
  String _selectedSchool = 'Pointe-Noire';

  List<DesktopNavItem> get _flatItems =>
      [for (final g in widget.groups) ...g.items];

  void _toggle() => setState(() {
    _mode = _mode == _SideMode.full ? _SideMode.icons : _SideMode.full;
  });

  double get _sideW => _mode == _SideMode.full ? 220.0 : 56.0;

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(shellNavProvider, (_, labelKey) {
      if (labelKey == null) return;
      final i = _flatItems.indexWhere((it) => it.labelKey == labelKey);
      if (i >= 0) setState(() => _flatIndex = i);
      ref.read(shellNavProvider.notifier).state = null;
    });
    return Scaffold(
      backgroundColor: _sh1,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Animated sidebar ─────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeInOut,
              width: _sideW,
              child: Stack(children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_sh1, _sh2],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _HexPainter()),
                ),
                _Sidebar(
                  groups: widget.groups,
                  collapsed: _mode == _SideMode.icons,
                  currentIndex: _flatIndex,
                  onSelect: (i) => setState(() => _flatIndex = i),
                  onSettings: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const Scaffold(body: SettingsPage()))),
                  onHelp: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: const _HelpPanel(),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Main column: header + content ────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: widget.title,
                    mode: _mode,
                    selectedSchool: _selectedSchool,
                    onToggle: _toggle,
                    onSchoolChange: (s) => setState(() => _selectedSchool = s),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22)),
                      child: Container(
                        color: _bg,
                        child: _flatItems[_flatIndex].page,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar  — logo en haut + nav items avec sections repliables
// ─────────────────────────────────────────────────────────────────────────────
class _Sidebar extends StatefulWidget {
  final List<DesktopNavGroup> groups;
  final bool collapsed;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;

  const _Sidebar({
    required this.groups,
    required this.collapsed,
    required this.currentIndex,
    required this.onSelect,
    this.onSettings,
    this.onHelp,
  });

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final Set<int> _closedGroups = {};

  int _flat(int gIdx, int iIdx) {
    int f = 0;
    for (var i = 0; i < gIdx; i++) f += widget.groups[i].items.length;
    return f + iIdx;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Logo Scolaris ──────────────────────────────────────────────────
        SizedBox(
          height: 72,
          child: Center(
            child: widget.collapsed
                ? Image.asset(
                    'assets/images/logo_transparent.png',
                    width: 38, height: 38,
                    errorBuilder: (_, __, ___) => Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_terra, Color(0xFFD4540A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: _terra.withOpacity(.4),
                            blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: const Center(child: Text('S',
                          style: TextStyle(color: _white,
                              fontWeight: FontWeight.w900, fontSize: 18))),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo_transparent.png',
                        width: 36, height: 36,
                        errorBuilder: (_, __, ___) => Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_terra, Color(0xFFD4540A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: _terra.withOpacity(.35),
                                blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: const Center(child: Text('S',
                              style: TextStyle(color: _white,
                                  fontWeight: FontWeight.w900, fontSize: 17))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Scolaris',
                          style: TextStyle(
                            color: _shTxt,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          )),
                    ],
                  ),
          ),
        ),
        Container(height: 1, color: _white.withOpacity(.07)),

        // ── Nav groups ────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
                horizontal: widget.collapsed ? 6 : 8, vertical: 6),
            children: [
              for (var g = 0; g < widget.groups.length; g++) ...[
                // Group header (repliable)
                if (!widget.collapsed)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_closedGroups.contains(g)) {
                        _closedGroups.remove(g);
                      } else {
                        _closedGroups.add(g);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 8, 6),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            widget.groups[g].labelKey.tr().toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              color: _gold.withOpacity(.65),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          _closedGroups.contains(g)
                              ? Icons.expand_more_rounded
                              : Icons.expand_less_rounded,
                          size: 13,
                          color: _gold.withOpacity(.5),
                        ),
                      ]),
                    ),
                  )
                else
                  const SizedBox(height: 10),

                // Items (shown unless group collapsed)
                if (widget.collapsed || !_closedGroups.contains(g))
                  ...List.generate(widget.groups[g].items.length, (i) {
                    final idx = _flat(g, i);
                    final it = widget.groups[g].items[i];
                    return _SideItem(
                      icon: it.icon,
                      labelKey: it.labelKey,
                      selected: idx == widget.currentIndex,
                      collapsed: widget.collapsed,
                      onTap: () => widget.onSelect(idx),
                    );
                  }),
              ],
            ],
          ),
        ),

        // ── Footer (Settings + Help) ──────────────────────────────────────
        Container(height: 1, color: _white.withOpacity(.07)),
        _SidebarFooter(
          collapsed: widget.collapsed,
          onSettings: widget.onSettings,
          onHelp: widget.onHelp,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — dark, même fond que sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends ConsumerStatefulWidget {
  final String title;
  final _SideMode mode;
  final String selectedSchool;
  final VoidCallback onToggle;
  final ValueChanged<String> onSchoolChange;

  const _Header({
    required this.title,
    required this.mode,
    required this.selectedSchool,
    required this.onToggle,
    required this.onSchoolChange,
  });

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;

  static const _schools = ['EAD', 'Pointe-Noire', 'Brazzaville'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_sh1, _sh2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _sh1.withOpacity(.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // ── Toggle sidebar button ──────────────────────────────────────
          _DarkBtn(
            icon: widget.mode == _SideMode.full
                ? Icons.menu_open_rounded
                : Icons.menu_rounded,
            tooltip: widget.mode == _SideMode.full ? 'Réduire' : 'Étendre',
            onTap: widget.onToggle,
          ),
          const SizedBox(width: 14),

          Container(width: 1, height: 20, color: _white.withOpacity(.12)),
          const SizedBox(width: 14),

          // ── School selector ────────────────────────────────────────────
          CustomPopup(
            barrierColor: Colors.transparent,
            backgroundColor: const Color(0xFF1E0C00),
            content: Material(type: MaterialType.transparency,
                child: _buildSchoolPopup(context)),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _white.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _white.withOpacity(.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_outlined, size: 13, color: _gold),
                    const SizedBox(width: 7),
                    Text(
                      widget.selectedSchool,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _shTxt,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.unfold_more_rounded, size: 13, color: _shMuted),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),
          Container(width: 1, height: 20, color: _white.withOpacity(.12)),
          const SizedBox(width: 14),

          // ── Search bar ─────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _searchActive ? 280 : 220,
            height: 34,
            decoration: BoxDecoration(
              color: _white.withOpacity(_searchActive ? .12 : .07),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _searchActive
                    ? _gold.withOpacity(.4)
                    : _white.withOpacity(.1),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.search_rounded, size: 15, color: _shMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onTap: () => setState(() => _searchActive = true),
                    onTapOutside: (_) {
                      _searchFocus.unfocus();
                      setState(() => _searchActive = false);
                    },
                    style: const TextStyle(fontSize: 12.5, color: _shTxt),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Rechercher élèves, classes…',
                      hintStyle: TextStyle(
                          fontSize: 12.5, color: _shMuted.withOpacity(.7)),
                      isCollapsed: true,
                    ),
                  ),
                ),
                if (!_searchActive)
                  GestureDetector(
                    onTap: () {
                      _searchFocus.requestFocus();
                      setState(() => _searchActive = true);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _white.withOpacity(.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('⌘K',
                          style: TextStyle(
                              fontSize: 10,
                              color: _shMuted.withOpacity(.8))),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                      setState(() => _searchActive = false);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: _shMuted),
                    ),
                  ),
              ],
            ),
          ),

          const Spacer(),

          // ── Notification icon ──────────────────────────────────────────
          CustomPopup(
            barrierColor: Colors.transparent,
            backgroundColor: const Color(0xFF1E0C00),
            content: Material(
              type: MaterialType.transparency,
              child: _NotifPanel(
                onViewAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: NotificationsPage(),
                      )),
                ),
              ),
            ),
            child: const _DarkBadgeBtn(
              icon: Icons.notifications_outlined,
              badge: true,
              tooltip: 'Notifications',
            ),
          ),
          const SizedBox(width: 4),

          // ── Help icon ──────────────────────────────────────────────────
          CustomPopup(
            barrierColor: Colors.transparent,
            backgroundColor: const Color(0xFF1E0C00),
            content: Material(
                type: MaterialType.transparency,
                child: const _HelpPanel()),
            child: const _DarkBadgeBtn(
              icon: Icons.help_outline_rounded,
              tooltip: 'Aide',
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 20, color: _white.withOpacity(.12)),
          const SizedBox(width: 12),

          // ── Account popup ──────────────────────────────────────────────
          CustomPopup(
            barrierColor: Colors.transparent,
            backgroundColor: const Color(0xFF1E0C00),
            content: Material(
              type: MaterialType.transparency,
              child: _AccountPanel(
              user: user,
              onSettings: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const Scaffold(body: SettingsPage())),
              ),
              onNotifs: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: NotificationsPage(),
                    )),
              ),
            )),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Avatar3D(user: user, size: 32),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: _shMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolPopup(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1200),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SÉLECTIONNER LE CENTRE',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  color: _gold.withOpacity(.7),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          ..._schools.map((s) {
            final sel = s == widget.selectedSchool;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  widget.onSchoolChange(s);
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? _gold : _shMuted.withOpacity(.4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s,
                          style: TextStyle(
                            fontSize: 13,
                            color: sel ? _gold : _shTxt,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500,
                          )),
                    ),
                    if (sel)
                      const Icon(Icons.check_rounded,
                          size: 14, color: _gold),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account panel popup — bannière + avatar 3D bien visible
// ─────────────────────────────────────────────────────────────────────────────
class _AccountPanel extends ConsumerWidget {
  final AppUser? user;
  final VoidCallback? onSettings;
  final VoidCallback? onNotifs;

  const _AccountPanel({required this.user, this.onSettings, this.onNotifs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleName = switch (user?.role) {
      UserRole.staff   => 'Administration',
      UserRole.teacher => 'Enseignant',
      UserRole.student => 'Élève',
      UserRole.parent  => 'Parent',
      null             => '—',
    };

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF1E0C00),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.55),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Bannière terracotta ──────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B1200), _terra, _orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _HexPainter(opacity: 0.1)),
                  ),
                  // Avatar positionné sur le bas de la bannière
                  Positioned(
                    bottom: -24,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF1E0C00), width: 3),
                      ),
                      child: _Avatar3D(user: user, size: 48),
                    ),
                  ),
                  // Badge rôle en haut à droite
                  Positioned(
                    top: 12, right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _white.withOpacity(.2)),
                      ),
                      child: Text(
                        roleName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: _white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Nom + email (avec offset pour l'avatar) ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '—',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _shTxt,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style:
                            TextStyle(fontSize: 11.5, color: _shMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: _white.withOpacity(.07)),

          // ── Menu items ───────────────────────────────────────────────────
          _PanelItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _terra,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('3',
                  style: TextStyle(
                      fontSize: 10,
                      color: _white,
                      fontWeight: FontWeight.w700)),
            ),
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              onNotifs?.call();
            },
          ),
          _PanelItem(
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              onSettings?.call();
            },
          ),
          _PanelItem(
            icon: Icons.brightness_6_outlined,
            label: 'Changer le thème',
            onTap: () {
              ref.read(themeControllerProvider.notifier).toggleBrightness();
            },
          ),
          Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: _white.withOpacity(.07)),
          _PanelItem(
            icon: Icons.logout_rounded,
            label: 'Se déconnecter',
            danger: true,
            onTap: () => ref.read(signOutUseCaseProvider)(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PanelItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool danger;

  const _PanelItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  @override
  State<_PanelItem> createState() => _PanelItemState();
}

class _PanelItemState extends State<_PanelItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? const Color(0xFFFF6B6B) : _shTxt;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        color: _hover
            ? _white.withOpacity(.05)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Icon(widget.icon,
                    size: 17, color: color.withOpacity(.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification panel
// ─────────────────────────────────────────────────────────────────────────────
class _NotifPanel extends StatelessWidget {
  final VoidCallback? onViewAll;

  static const _notifs = [
    ('Nouvelle inscription', 'Amara Diallo – Terminale A', '2 min',
        Icons.person_add_outlined),
    ('Résultats publiés', 'Semestre 1 – Classe 4ème B', '1 h',
        Icons.grade_outlined),
    ('Paiement reçu', '85 000 XAF – Frais scolaires', '3 h',
        Icons.payments_outlined),
  ];

  const _NotifPanel({this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      decoration: BoxDecoration(
        color: const Color(0xFF1E0C00),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Text('Notifications',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _shTxt)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _terra,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('3',
                      style: TextStyle(
                          fontSize: 10,
                          color: _white,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _white.withOpacity(.07)),
          ..._notifs.map((n) => _NotifItem(
                icon: n.$4,
                title: n.$1,
                subtitle: n.$2,
                time: n.$3,
              )),
          Container(height: 1, color: _white.withOpacity(.07)),
          // Bouton "Voir toutes" fonctionnel
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                onViewAll?.call();
              },
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Voir toutes les notifications',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: _gold,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 13, color: _gold),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _NotifItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _terra.withOpacity(.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Icon(icon, size: 16, color: _orange),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _shTxt)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: _shMuted.withOpacity(.8))),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(time,
              style: TextStyle(
                  fontSize: 10, color: _shMuted.withOpacity(.6))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help panel
// ─────────────────────────────────────────────────────────────────────────────
class _HelpPanel extends StatelessWidget {
  static const _topics = [
    (Icons.book_outlined, 'Documentation'),
    (Icons.video_library_outlined, 'Tutoriels vidéo'),
    (Icons.support_agent_outlined, 'Support technique'),
    (Icons.keyboard_outlined, 'Raccourcis clavier'),
  ];

  const _HelpPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1E0C00),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Centre d\'aide',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _shTxt)),
            ),
          ),
          Container(height: 1, color: _white.withOpacity(.07)),
          ..._topics.map((t) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        Icon(t.$1, size: 16, color: _shMuted),
                        const SizedBox(width: 10),
                        Text(t.$2,
                            style: const TextStyle(
                                fontSize: 13, color: _shTxt)),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D avatar widget — DiceBear bottts-neutral
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar3D extends StatelessWidget {
  final AppUser? user;
  final double size;
  const _Avatar3D({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final seed = (user?.fullName ?? 'user').replaceAll(' ', '+');
    final url =
        'https://api.dicebear.com/7.x/bottts-neutral/png?seed=$seed&size=128&backgroundColor=transparent';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_terra, _orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _terra.withOpacity(.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              _initials,
              style: TextStyle(
                color: _white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.35,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _initials {
    final name = user?.fullName ?? '?';
    return name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar nav item
// ─────────────────────────────────────────────────────────────────────────────
class _SideItem extends StatefulWidget {
  final IconData icon;
  final String labelKey;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SideItem({
    required this.icon,
    required this.labelKey,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final cs = Theme.of(context).colorScheme;
    final bg = active
        ? cs.primary
        : _hover
            ? _white.withOpacity(.08)
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: widget.collapsed ? widget.labelKey.tr() : '',
            preferBelow: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              height: 34,
              padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisAlignment: widget.collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(widget.icon,
                      size: widget.collapsed ? 20 : 17,
                      color: active ? _white : _shMuted),
                  if (!widget.collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.labelKey.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: active ? _white : _shTxt,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (active)
                      Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(
                          color: _gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar footer — Paramètres + Aide
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarFooter extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;
  const _SidebarFooter({
    required this.collapsed,
    this.onSettings,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          _FooterIconBtn(icon: Icons.settings_outlined,
              tooltip: 'Paramètres', onTap: onSettings),
          const SizedBox(height: 4),
          _FooterIconBtn(icon: Icons.help_outline_rounded,
              tooltip: 'Aide & Support', onTap: onHelp),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      child: Column(children: [
        _FooterRow(icon: Icons.settings_outlined,
            label: 'Paramètres', onTap: onSettings),
        const SizedBox(height: 4),
        _FooterRow(icon: Icons.help_outline_rounded,
            label: 'Aide & Support', onTap: onHelp),
      ]),
    );
  }
}

class _FooterRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _FooterRow({required this.icon, required this.label, this.onTap});
  @override
  State<_FooterRow> createState() => _FooterRowState();
}

class _FooterRowState extends State<_FooterRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover ? _white.withOpacity(.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(children: [
            Icon(widget.icon, size: 17, color: _shMuted),
            const SizedBox(width: 10),
            Text(widget.label, style: const TextStyle(
                fontSize: 12.5, color: _shMuted, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _FooterIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _FooterIconBtn(
      {required this.icon, required this.tooltip, this.onTap});
  @override
  State<_FooterIconBtn> createState() => _FooterIconBtnState();
}

class _FooterIconBtnState extends State<_FooterIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 40, height: 36,
            decoration: BoxDecoration(
              color: _hover ? _white.withOpacity(.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
                child: Icon(widget.icon, size: 20, color: _shMuted)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark header icon buttons
// ─────────────────────────────────────────────────────────────────────────────
class _DarkBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _DarkBtn(
      {required this.icon, required this.onTap, this.tooltip = ''});

  @override
  State<_DarkBtn> createState() => _DarkBtnState();
}

class _DarkBtnState extends State<_DarkBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _hover
                  ? _white.withOpacity(.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Icon(widget.icon, size: 20, color: _shTxt),
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkBadgeBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool badge;
  const _DarkBadgeBtn(
      {required this.icon, this.tooltip = '', this.badge = false});

  @override
  State<_DarkBadgeBtn> createState() => _DarkBadgeBtnState();
}

class _DarkBadgeBtnState extends State<_DarkBadgeBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _hover
                ? _white.withOpacity(.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(widget.icon, size: 22, color: _shTxt),
              if (widget.badge)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: _terra,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
        _hex(canvas, paint, Offset(x + off, y), r);
      }
    }
  }

  void _hex(Canvas canvas, Paint paint, Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) => old.opacity != opacity;
}
