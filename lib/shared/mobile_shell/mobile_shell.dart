import 'dart:math' as math;
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/db_providers.dart';
import '../../presentation/providers/nav_providers.dart';
import '../pages/account_page.dart';
import '../widgets/responsive_role_shell.dart';
import '../widgets/subscription_alert_banner.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
// _terra/_orange/_gold/_menuBg1/_menuBg2 retirés : la chrome sombre (header,
// sidebar, avatar, badges) suit désormais l'accent choisi dans Apparence
// (Theme.of(context).colorScheme.primary) plutôt qu'une couleur figée.
const _white     = Colors.white;
const _menuTxt   = Color(0xFFE8DDD0);

const _kEdgeZone = 28.0;

class MobileShell extends ConsumerStatefulWidget {
  final List<RoleNavEntry> dockEntries;
  final List<RoleNavEntry> drawerEntries;
  final UserRole role;
  final String title;
  const MobileShell({
    super.key,
    required this.dockEntries,
    required this.drawerEntries,
    required this.role,
    required this.title,
  });

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell>
    with SingleTickerProviderStateMixin {
  // Par labelKey, pas par index brut : drawerEntries est filtré par
  // modules/permissions et peut se réorganiser (ex. install d'un module
  // depuis la page « Modules »), ce qui décalerait un int vers une autre page.
  String? _currentLabelKey;

  int _indexFor(List<RoleNavEntry> entries) {
    if (_currentLabelKey == null) return 0;
    final idx = entries.indexWhere((e) => e.labelKey == _currentLabelKey);
    return idx >= 0 ? idx : 0;
  }

  late final AnimationController _menuCtrl;
  late final Animation<double>   _menuAnim;

  bool   _edgeDrag       = false;
  double _dragStartX     = 0;
  double _dragProgressX  = 0;
  bool   _showEdgeBubble = false;

  double _scale  = 1;
  double _xShift = 0;
  double _yShift = 0;
  double _radius = 0;

  bool get _menuOpen => _menuCtrl.value > 0.01;

  @override
  void initState() {
    super.initState();
    _menuCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _menuAnim = CurvedAnimation(
        parent: _menuCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
    _menuCtrl.addListener(_onAnim);
  }

  void _onAnim() {
    final t = _menuAnim.value;
    setState(() {
      _scale  = 1 - 0.12 * t;
      _xShift = 0.68 * t;
      _yShift = 0.095 * t;
      _radius = 28 * t;
    });
  }

  @override
  void dispose() {
    _menuCtrl.removeListener(_onAnim);
    _menuCtrl.dispose();
    super.dispose();
  }

  void _openMenu()   => _menuCtrl.animateTo(1);
  void _closeMenu()  => _menuCtrl.animateTo(0);
  void _toggleMenu() => _menuOpen ? _closeMenu() : _openMenu();

  void _navigateTo(String labelKey) {
    if (widget.drawerEntries.any((e) => e.labelKey == labelKey)) {
      setState(() => _currentLabelKey = labelKey);
    }
  }

  void _onDragStart(DragStartDetails d) {
    _dragStartX = d.localPosition.dx;
    _edgeDrag   = !_menuOpen && _dragStartX < _kEdgeZone;
    if (_edgeDrag) setState(() { _showEdgeBubble = true; _dragProgressX = 0; });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.delta.dx;
    if (_edgeDrag) {
      _dragProgressX += delta;
      _menuCtrl.value = (_dragProgressX / 220).clamp(0.0, 1.0);
    } else if (_menuOpen && delta < 0) {
      _menuCtrl.value = (_menuCtrl.value + delta / 260).clamp(0.0, 1.0);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _showEdgeBubble = false);
    final vel = d.primaryVelocity ?? 0;
    if (_edgeDrag) {
      _edgeDrag = false;
      (_menuCtrl.value > 0.42 || vel > 500) ? _openMenu() : _closeMenu();
    } else if (_menuOpen) {
      (_menuCtrl.value < 0.55 || vel < -500) ? _closeMenu() : _openMenu();
    }
  }

  void _openAccount() {
    if (_menuOpen) _closeMenu();
    // Pas de _FullPage ici : AccountPage a son propre bandeau avec bouton
    // retour (photo, nom, rôle) — l'envelopper doublait le bouton retour.
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AccountPage()));
  }

  @override
  Widget build(BuildContext context) {
    // Intention de navigation émise par une page (ex. actions rapides du dashboard).
    ref.listen<String?>(navIntentProvider, (_, next) {
      if (next != null) {
        _navigateTo(next);
        ref.read(navIntentProvider.notifier).state = null;
      }
    });
    final pageIndex = _indexFor(widget.drawerEntries);
    final size = MediaQuery.sizeOf(context);
    final user = ref.watch(authSessionProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final menuBg1 = Color.lerp(Colors.black, accent, .32)!;

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: menuBg1,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1 ─ Sidebar panel
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SidebarPanel(
                  entries: widget.drawerEntries,
                  user: user,
                  onSelect: (key) { _closeMenu(); _navigateTo(key); },
                  onAccount: _openAccount,
                  onClose: _closeMenu,
                  opacity: _menuCtrl.value,
                  width: size.width,
                  role: widget.role,
                ),
              ),
            ),

            // 2 ─ Main card with shadow
            Transform(
              transform: Matrix4.identity()
                ..translate(size.width * _xShift, size.height * _yShift)
                ..scale(_scale),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _menuOpen ? 0.45 : 0.12),
                      blurRadius: _menuOpen ? 40 : 10,
                      offset: Offset(_menuOpen ? -6 : 0, 0),
                    ),
                    if (_menuOpen) ...[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 80,
                        spreadRadius: -4,
                        offset: const Offset(-2, 28),
                      ),
                      BoxShadow(
                        color: accent.withValues(alpha: 0.12),
                        blurRadius: 60,
                        spreadRadius: -8,
                        offset: const Offset(0, 40),
                      ),
                    ],
                  ],
                ),
                child: GestureDetector(
                  onTap: _menuOpen ? _closeMenu : null,
                  behavior: HitTestBehavior.translucent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius),
                    child: Stack(children: [
                      Scaffold(
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      body: SafeArea(
                        bottom: true,
                        child: Column(children: [
                          _SmartHeader(
                            title: widget.title,
                            user: user,
                            onMenu: _toggleMenu,
                            onAccount: _openAccount,
                            pageIndex: pageIndex,
                            entries: widget.drawerEntries,
                            showTabBar: ref.watch(settingsProvider).afficherBarreOnglets,
                            onTabTap: (i) {
                              if (_menuOpen) _closeMenu();
                              setState(() => _currentLabelKey = widget.drawerEntries[i].labelKey);
                            },
                          ),
                          // Réservée à l'admin (staff) : seul lui paie et peut
                          // agir sur l'abonnement de l'école.
                          if (widget.role == UserRole.staff)
                            const SubscriptionAlertBanner(),
                          Expanded(
                            child: KeyedSubtree(
                              key: ValueKey(pageIndex),
                              child: widget.drawerEntries[pageIndex].page,
                            ),
                          ),
                        ]),
                      ),
                    ),
                      // Overlay: bloque toute interaction quand le menu est ouvert
                      if (_menuOpen)
                        Positioned.fill(
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) => _closeMenu(),
                          ),
                        ),
                  ]),
                ),
              ),
            ),
          ),

            // 3 ─ Edge bubble
            if (_showEdgeBubble || (_menuCtrl.value > 0 && _menuCtrl.value < 0.15))
              Positioned(
                left: 4 + _menuCtrl.value * 12,
                top: size.height * 0.5 - 22,
                child: _EdgeBubble(progress: _menuCtrl.value),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Smart Header ─────────────────────────────────────────────────────────
class _SmartHeader extends StatelessWidget {
  final String title;
  final AppUser? user;
  final VoidCallback onMenu;
  final VoidCallback onAccount;
  final int pageIndex;
  final List<RoleNavEntry> entries;
  final ValueChanged<int> onTabTap;

  final bool showTabBar;
  const _SmartHeader({
    required this.title, required this.user,
    required this.onMenu,
    required this.onAccount,
    required this.pageIndex, required this.entries,
    required this.onTabTap, required this.showTabBar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surfColor = cs.surface;
    final onSurf    = cs.onSurface;
    final mutedClr  = cs.onSurface.withValues(alpha: .5);
    final accent    = cs.primary;
    final accentLight = Color.lerp(accent, Colors.white, .18)!;

    final initials = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top bar — frosted glass ──────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 56,
              color: surfColor.withValues(alpha: 0.88),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                _HeaderBtn(onTap: onMenu, child: _HamburgerIcon(color: onSurf)),
                Image.asset('assets/images/logo_transparent.png', width: 28, height: 28,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo.png', width: 28, height: 28,
                      errorBuilder: (_, __, ___) =>
                        Icon(Icons.school_rounded, size: 26, color: accent),
                    )),
                const SizedBox(width: 7),
                Text(AppConfig.appName,
                    style: TextStyle(fontSize: 14, color: onSurf,
                        fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                  onTap: onAccount,
                  child: Container(
                    width: 32, height: 32,
                    margin: const EdgeInsets.only(left: 2, right: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accentLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                          color: accent.withValues(alpha: .3),
                          blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Center(child: Text(initials,
                        style: const TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w800))),
                  ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        // Divider under header
        Container(height: 1, color: cs.outline.withValues(alpha: .15)),

        // ── Tab nav bar (optionnel) ───────────────────────────────────────
        if (showTabBar) ...[
          Container(
            color: surfColor,
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                final e   = entries[i];
                final sel = i == pageIndex;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                  onTap: () => onTabTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel ? accent : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(sel ? (e.activeIcon ?? e.icon) : e.icon,
                          size: 15, color: sel ? Colors.white : mutedClr),
                      const SizedBox(width: 6),
                      Text(e.labelKey.tr(),
                          style: TextStyle(
                              color: sel ? Colors.white : mutedClr,
                              fontSize: 12.5,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  ),
                  ),
                );
              },
            ),
          ),
          Container(height: 1, color: cs.outline.withValues(alpha: .2)),
        ],
      ],
    );
  }
}

class _HamburgerIcon extends StatelessWidget {
  final Color color;
  const _HamburgerIcon({required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 20, height: 2, color: color),
        const SizedBox(height: 4),
        Container(width: 14, height: 2, color: color),
        const SizedBox(height: 4),
        Container(width: 17, height: 2, color: color),
      ],
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HeaderBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}

class _EdgeBubble extends StatelessWidget {
  final double progress;
  const _EdgeBubble({required this.progress});
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: (1 - progress * 6).clamp(0.0, 1.0),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .85),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(
              color: Color(0x33000000), blurRadius: 12, offset: Offset(2, 2))],
        ),
        child: const Center(
            child: Icon(Icons.chevron_right_rounded, size: 26, color: _white)),
      ),
    );
  }
}

// ─── Sidebar Panel — African dark brown theme ─────────────────────────────
class _SidebarPanel extends StatefulWidget {
  final List<RoleNavEntry> entries;
  final AppUser? user;
  final ValueChanged<String> onSelect;
  final VoidCallback onAccount;
  final VoidCallback onClose;
  final double opacity;
  final double width;
  final UserRole role;

  const _SidebarPanel({
    required this.entries, required this.user,
    required this.onSelect,
    required this.onAccount, required this.onClose,
    required this.opacity, required this.width,
    required this.role,
  });

  @override
  State<_SidebarPanel> createState() => _SidebarPanelState();
}

String _schoolInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final words = name.trim().split(RegExp(r'\s+'));
  return words.map((w) => w[0]).take(2).join().toUpperCase();
}

class _SidebarPanelState extends State<_SidebarPanel> {
  String _activeKey = '';
  bool   _accountExpanded = false;
  final Set<String> _collapsedSections = {};

  @override
  void initState() {
    super.initState();
    if (widget.entries.isNotEmpty) _activeKey = widget.entries.first.labelKey;
  }

  List<_NavGroup> get _groups {
    final entries = widget.entries;
    if (entries.isEmpty) return [];
    // Group entries into sections of up to 4
    final main   = entries.take(math.min(4, entries.length)).toList();
    final rest   = entries.skip(main.length).toList();
    return [
      _NavGroup(labelKey: 'nav.main',    entries: main),
      if (rest.isNotEmpty)
        _NavGroup(labelKey: 'nav.other', entries: rest),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initials = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final accentLight = Color.lerp(accent, Colors.white, .18)!;
    final menuBg1 = Color.lerp(Colors.black, accent, .32)!;
    final menuBg2 = Color.lerp(Colors.black, accent, .55)!;

    return SizedBox(
      width: widget.width,
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0D1117), const Color(0xFF1C2128)]
                  : [menuBg1, menuBg2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            // Subtle African pattern background
            CustomPaint(
              painter: _SidebarPatternPainter(
                isDark: isDark,
                accent: accent,
              ),
              child: const SizedBox.expand(),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top: account switcher + X ─────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 4, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row: avatar + info + chevron + X
                        Row(children: [
                          // Avatar
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                            onTap: widget.onAccount,
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _white.withValues(alpha: .12),
                                border: Border.all(color: accentLight.withValues(alpha: .4), width: 1.5),
                              ),
                              child: Center(child: Text(initials,
                                  style: const TextStyle(color: _white,
                                      fontWeight: FontWeight.w800, fontSize: 16))),
                            ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Name + role — largeur fixe pour que chevron+X restent collés
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 138),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                              onTap: widget.onAccount,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  user?.fullName ?? 'Utilisateur',
                                  style: const TextStyle(color: _white,
                                      fontSize: 14, fontWeight: FontWeight.w700),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  (widget.user?.role.name ?? 'user').toUpperCase(),
                                  style: TextStyle(color: accentLight.withValues(alpha: .8),
                                      fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.1),
                                ),
                              ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Chevron « écoles » — réservé aux profs rattachés à ≥ 2 écoles.
                          if (widget.role == UserRole.teacher)
                            Consumer(builder: (context, ref, _) {
                              final memberships =
                                  ref.watch(myMembershipsProvider).valueOrNull ?? const [];
                              if (memberships.length < 2) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _accountExpanded = !_accountExpanded),
                                    child: AnimatedRotation(
                                      turns: _accountExpanded ? 0.5 : 0,
                                      duration: const Duration(milliseconds: 220),
                                      child: Icon(Icons.apartment_rounded,
                                          color: accentLight.withValues(alpha: .85), size: 19),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(width: 6),
                          // X close
                          Material(
                            color: _white.withValues(alpha: .14),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onClose,
                              child: const SizedBox(
                                width: 38, height: 38,
                                child: Icon(Icons.close_rounded, color: _white, size: 19),
                              ),
                            ),
                          ),
                        ]),

                        // ── Sélecteur d'école expandable — profs multi-écoles ──
                        if (widget.role == UserRole.teacher)
                          Consumer(builder: (context, ref, _) {
                            final memberships =
                                ref.watch(myMembershipsProvider).valueOrNull ?? const [];
                            final activeId = ref.watch(currentSchoolIdProvider);
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child: _accountExpanded && memberships.length >= 2
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _white.withValues(alpha: .06),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: _white.withValues(alpha: .08)),
                                        ),
                                        child: Column(children: [
                                          for (int i = 0; i < memberships.length; i++) ...[
                                            if (i > 0)
                                              Container(height: .5, color: _white.withValues(alpha: .08)),
                                            _AccountTile(
                                              initials: _schoolInitials(memberships[i].schoolName),
                                              name: memberships[i].schoolName ?? 'École',
                                              role: 'école',
                                              isActive: memberships[i].schoolId == activeId,
                                              onTap: () {
                                                ref.read(activeSchoolIdProvider.notifier).state =
                                                    memberships[i].schoolId;
                                                setState(() => _accountExpanded = false);
                                              },
                                            ),
                                          ],
                                        ]),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            );
                          }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                Container(height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: _white.withValues(alpha: .08)),
                const SizedBox(height: 8),

                // ── Nav groups ─────────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      for (final group in _groups) ...[
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                          onTap: () => setState(() {
                            if (_collapsedSections.contains(group.labelKey)) {
                              _collapsedSections.remove(group.labelKey);
                            } else {
                              _collapsedSections.add(group.labelKey);
                            }
                          }),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                            child: Row(children: [
                              Icon(
                                group.labelKey == 'nav.main'
                                    ? Icons.grid_view_rounded
                                    : Icons.more_horiz_rounded,
                                size: 11,
                                color: accentLight.withValues(alpha: .55),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                group.labelKey.tr().toUpperCase(),
                                style: TextStyle(
                                    color: accentLight.withValues(alpha: .6),
                                    fontSize: 9, fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5),
                              ),
                              const Spacer(),
                              AnimatedRotation(
                                turns: _collapsedSections.contains(group.labelKey) ? 0 : 0.5,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(Icons.expand_less_rounded,
                                    size: 12, color: accentLight.withValues(alpha: .4)),
                              ),
                            ]),
                          ),
                          ),
                        ),
                        if (!_collapsedSections.contains(group.labelKey))
                          for (int i = 0; i < group.entries.length; i++)
                            _SidebarItem(
                              entry: group.entries[i],
                              selected: group.entries[i].labelKey == _activeKey,
                              index: i,
                              opacity: widget.opacity,
                              onTap: () {
                                setState(() => _activeKey = group.entries[i].labelKey);
                                widget.onSelect(group.entries[i].labelKey);
                              },
                            ),
                      ],
                    ],
                  ),
                ),

                // ── App branding footer ────────────────────────────────
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(children: [
                      Image.asset('assets/images/logo_transparent.png',
                          width: 22, height: 22,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.school_rounded, size: 20, color: accentLight)),
                      const SizedBox(width: 8),
                      Text(AppConfig.appName,
                          style: TextStyle(color: _white.withValues(alpha: .5),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('v${AppConfig.appVersion}',
                          style: TextStyle(color: _white.withValues(alpha: .25), fontSize: 10)),
                    ]),
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Account tile for switcher ─────────────────────────────────────────────
class _AccountTile extends StatelessWidget {
  final String initials, name, role;
  final bool isActive;
  final VoidCallback onTap;
  const _AccountTile({
    required this.initials, required this.name,
    required this.role, required this.isActive, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: .1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? accent.withValues(alpha: .25) : _white.withValues(alpha: .10),
                border: isActive ? Border.all(color: accent.withValues(alpha: .5)) : null,
              ),
              child: Center(child: Text(initials,
                  style: TextStyle(
                      color: isActive ? accent : _white.withValues(alpha: .7),
                      fontSize: 12, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(
                  color: isActive ? _white : _white.withValues(alpha: .8),
                  fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              Text(role.toUpperCase(), style: TextStyle(
                  color: accent.withValues(alpha: .6), fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            ])),
            if (isActive)
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }
}

class _NavGroup {
  final String labelKey;
  final List<RoleNavEntry> entries;
  const _NavGroup({required this.labelKey, required this.entries});
}

// ── Sidebar Item ─────────────────────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final RoleNavEntry entry;
  final bool selected;
  final int index;
  final double opacity;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.entry, required this.selected,
    required this.index, required this.opacity, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedSlide(
      offset: Offset(-(1 - opacity.clamp(0.0, 1.0)) * 0.35, 0),
      duration: Duration(milliseconds: 180 + index * 35),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: opacity.clamp(0.0, 1.0),
        duration: Duration(milliseconds: 180 + index * 35),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              splashColor: accent.withValues(alpha: .1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: selected ? _white.withValues(alpha: .10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: accent.withValues(alpha: .2)) : null,
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: .2)
                          : _white.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entry.icon, size: 18,
                        color: selected ? accent : _menuTxt.withValues(alpha: .7)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(entry.labelKey.tr(),
                        style: TextStyle(
                          color: selected ? _white : _menuTxt.withValues(alpha: .8),
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ),
                  if (selected)
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sidebar background pattern ────────────────────────────────────────────
class _SidebarPatternPainter extends CustomPainter {
  final bool isDark;
  final Color accent;
  const _SidebarPatternPainter({this.isDark = false, this.accent = ScolarisPalette.gold});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark mode: vivid pattern with accent fill + outline; light mode: subtle outline
    final strokePaint = Paint()
      ..color = accent.withValues(alpha: isDark ? .22 : .05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.6 : 1.2;
    final fillPaint = isDark
        ? (Paint()
          ..color = accent.withValues(alpha: .07)
          ..style = PaintingStyle.fill)
        : null;

    const sp = 44.0;
    final cols = (size.width / sp).ceil() + 1;
    final rows = (size.height / sp).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * sp + (r.isEven ? sp * 0.5 : 0);
        final cy = r * sp * 0.866;
        final o = Offset(cx, cy);
        if (fillPaint != null) _diamond(canvas, o, 9, fillPaint);
        _diamond(canvas, o, 9, strokePaint);
      }
    }
    // Extra concentric diamond ring in the centre for visual interest
    if (isDark) {
      final cx = size.width * 0.5;
      final cy = size.height * 0.42;
      final ringPaint = Paint()
        ..color = accent.withValues(alpha: .10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (final r in [28.0, 46.0, 64.0]) {
        _diamond(canvas, Offset(cx, cy), r, ringPaint);
      }
    }
  }

  void _diamond(Canvas canvas, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r * 0.7, o.dy)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r * 0.7, o.dy)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_SidebarPatternPainter old) =>
      old.isDark != isDark || old.accent != accent;
}
