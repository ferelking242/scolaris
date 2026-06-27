import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import '../pages/account_page.dart';
import '../pages/notifications_page.dart';
import '../pages/search_page.dart';
import '../widgets/responsive_role_shell.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _pageBg    = Color(0xFFF5EEE6);
const _white     = Colors.white;
const _ink       = Color(0xFF1A0A00);
const _muted     = Color(0xFF7A5C44);
const _terra     = ScolarisPalette.terracotta;
const _orange    = ScolarisPalette.orange;
const _gold      = ScolarisPalette.gold;
const _menuAcc   = ScolarisPalette.gold;

// African sidebar background — dark terracotta/brown, NOT green
const _menuBg1   = Color(0xFF1A0A00);
const _menuBg2   = Color(0xFF3E1A00);
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
  int _pageIndex = 0;

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
    final idx = widget.drawerEntries.indexWhere((e) => e.labelKey == labelKey);
    if (idx >= 0) setState(() => _pageIndex = idx);
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

  void _openNotifications() {
    if (_menuOpen) _closeMenu();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _FullPage(
            title: 'Notifications', child: NotificationsPage())));
  }

  void _openSearch() {
    if (_menuOpen) _closeMenu();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _FullPage(
            title: 'Recherche', child: SearchPage())));
  }

  void _openAccount() {
    if (_menuOpen) _closeMenu();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _FullPage(
            title: 'Mon compte', child: AccountPage())));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final user = ref.watch(authSessionProvider);

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: _menuBg1,
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
                  onSignOut: () async {
                    try {
                      await ref.read(signOutUseCaseProvider)();
                    } finally {
                      if (context.mounted) context.go('/login');
                    }
                  },
                  onAccount: _openAccount,
                  onClose: _closeMenu,
                  opacity: _menuCtrl.value,
                  width: size.width * 0.72,
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
                  boxShadow: _menuOpen ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.38),
                      blurRadius: 40,
                      offset: const Offset(-6, 0),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 80,
                      spreadRadius: -4,
                      offset: const Offset(-2, 28),
                    ),
                    BoxShadow(
                      color: _terra.withOpacity(0.08),
                      blurRadius: 60,
                      spreadRadius: -8,
                      offset: const Offset(0, 40),
                    ),
                  ] : [],
                ),
                child: GestureDetector(
                  onTap: _menuOpen ? _closeMenu : null,
                  behavior: HitTestBehavior.translucent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius),
                    child: Stack(children: [
                      Scaffold(
                      backgroundColor: _pageBg,
                      body: SafeArea(
                        bottom: true,
                        child: Column(children: [
                          _SmartHeader(
                            title: widget.title,
                            user: user,
                            onMenu: _toggleMenu,
                            onSearch: _openSearch,
                            onNotifications: _openNotifications,
                            onAccount: _openAccount,
                            pageIndex: _pageIndex,
                            entries: widget.drawerEntries,
                            showTabBar: ref.watch(settingsProvider).afficherBarreOnglets,
                            onTabTap: (i) {
                              if (_menuOpen) _closeMenu();
                              setState(() => _pageIndex = i);
                            },
                          ),
                          Expanded(
                            child: KeyedSubtree(
                              key: ValueKey(_pageIndex),
                              child: widget.drawerEntries[_pageIndex].page,
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

// ─── Full Page Wrapper ────────────────────────────────────────────────────
class _FullPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _FullPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(children: [
          Container(
            decoration: const BoxDecoration(
              color: _white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEE2D2), width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(children: [
              Material(
                color: const Color(0xFFF5EEE6),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  splashColor: _terra.withOpacity(.12),
                  child: const SizedBox(
                    width: 40, height: 40,
                    child: Icon(Icons.arrow_back_rounded, color: _ink, size: 21),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: _ink, fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ]),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

// ─── Smart Header ─────────────────────────────────────────────────────────
class _SmartHeader extends StatelessWidget {
  final String title;
  final AppUser? user;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onAccount;
  final int pageIndex;
  final List<RoleNavEntry> entries;
  final ValueChanged<int> onTabTap;

  final bool showTabBar;
  const _SmartHeader({
    required this.title, required this.user,
    required this.onMenu, required this.onSearch,
    required this.onNotifications, required this.onAccount,
    required this.pageIndex, required this.entries,
    required this.onTabTap, required this.showTabBar,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top bar ──────────────────────────────────────────────────────
        Container(
          height: 60,
          decoration: const BoxDecoration(
            color: _white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFEEE2D2), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            // Menu (ripple natif)
            _HeaderBtn(
              onTap: onMenu,
              tooltip: 'Menu',
              child: const Icon(Icons.menu_rounded, size: 24, color: _ink),
            ),
            const SizedBox(width: 2),
            // Logo branded tile
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_terra, _orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: _terra.withOpacity(.28),
                    blurRadius: 7, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset('assets/images/logo_transparent.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.school_rounded,
                                size: 18, color: _white),
                          ),
                        )),
              ),
            ),
            const SizedBox(width: 9),
            Text(AppConfig.appName,
                style: const TextStyle(fontSize: 16, color: _ink,
                    fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            const Spacer(),
            _HeaderBtn(
              onTap: onSearch,
              tooltip: 'Rechercher',
              child: const Icon(Icons.search_rounded, size: 22, color: _ink),
            ),
            _HeaderBtn(
              onTap: onNotifications,
              tooltip: 'Notifications',
              child: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_none_rounded, size: 23, color: _ink),
                Positioned(top: 0, right: 0,
                  child: Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: _white, width: 1.5),
                      ))),
              ]),
            ),
            const SizedBox(width: 4),
            // Account avatar button
            GestureDetector(
              onTap: onAccount,
              child: Container(
                width: 34, height: 34,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_terra, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: _terra.withOpacity(.32),
                      blurRadius: 7, offset: const Offset(0, 2))],
                ),
                child: Center(child: Text(initials,
                    style: const TextStyle(color: _white, fontSize: 12,
                        fontWeight: FontWeight.w800))),
              ),
            ),
          ]),
        ),

        // ── Tab nav bar (optionnel) ───────────────────────────────────────
        if (showTabBar) ...[
          Container(
            color: _white,
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                final e   = entries[i];
                final sel = i == pageIndex;
                return GestureDetector(
                  onTap: () => onTabTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel ? _terra : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(sel ? (e.activeIcon ?? e.icon) : e.icon,
                          size: 15, color: sel ? _white : _muted),
                      const SizedBox(width: 6),
                      Text(e.labelKey.tr(),
                          style: TextStyle(
                              color: sel ? _white : _muted,
                              fontSize: 12.5,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  ),
                );
              },
            ),
          ),
          Container(height: 1, color: const Color(0xFFEEE5D8)),
        ],
      ],
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;
  const _HeaderBtn({required this.child, required this.onTap, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: _terra.withOpacity(.12),
        highlightColor: _terra.withOpacity(.06),
        child: SizedBox(width: 42, height: 42, child: Center(child: child)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _EdgeBubble extends StatelessWidget {
  final double progress;
  const _EdgeBubble({required this.progress});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (1 - progress * 6).clamp(0.0, 1.0),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _terra.withOpacity(.85),
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
  final VoidCallback onSignOut;
  final VoidCallback onAccount;
  final VoidCallback onClose;
  final double opacity;
  final double width;
  final UserRole role;

  const _SidebarPanel({
    required this.entries, required this.user,
    required this.onSelect, required this.onSignOut,
    required this.onAccount, required this.onClose,
    required this.opacity, required this.width,
    required this.role,
  });

  @override
  State<_SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends State<_SidebarPanel> {
  String _activeKey = '';
  bool   _accountExpanded = false;

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

    return SizedBox(
      width: widget.width,
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_menuBg1, _menuBg2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            // Subtle African pattern background
            CustomPaint(painter: _SidebarPatternPainter(), child: const SizedBox.expand()),

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
                          GestureDetector(
                            onTap: widget.onAccount,
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _white.withOpacity(.12),
                                border: Border.all(color: _gold.withOpacity(.4), width: 1.5),
                              ),
                              child: Center(child: Text(initials,
                                  style: const TextStyle(color: _white,
                                      fontWeight: FontWeight.w800, fontSize: 16))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Name + role
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _accountExpanded = !_accountExpanded),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  user?.fullName ?? 'Utilisateur',
                                  style: const TextStyle(color: _white,
                                      fontSize: 14, fontWeight: FontWeight.w700),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  (widget.user?.role.name ?? 'user').toUpperCase(),
                                  style: TextStyle(color: _gold.withOpacity(.8),
                                      fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.1),
                                ),
                              ]),
                            ),
                          ),
                          // Chevron pour déplie comptes
                          GestureDetector(
                            onTap: () => setState(() => _accountExpanded = !_accountExpanded),
                            child: AnimatedRotation(
                              turns: _accountExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: Icon(Icons.expand_more_rounded,
                                  color: _white.withOpacity(.7), size: 20),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // X close
                          Material(
                            color: _white.withOpacity(.14),
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

                        // ── Compte switcher expandable ──────────────────
                        AnimatedSize(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: _accountExpanded
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _white.withOpacity(.06),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _white.withOpacity(.08)),
                                    ),
                                    child: Column(children: [
                                      _AccountTile(
                                        initials: 'AD',
                                        name: 'Admin École',
                                        role: 'admin',
                                        isActive: false,
                                        onTap: () {},
                                      ),
                                      Container(height: .5, color: _white.withOpacity(.08)),
                                      _AccountTile(
                                        initials: 'PR',
                                        name: 'Prof. Martin',
                                        role: 'teacher',
                                        isActive: false,
                                        onTap: () {},
                                      ),
                                      Container(height: .5, color: _white.withOpacity(.08)),
                                      // Ajouter un compte
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: const BorderRadius.vertical(
                                              bottom: Radius.circular(14)),
                                          onTap: () {},
                                          splashColor: _gold.withOpacity(.1),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                            child: Row(children: [
                                              Container(
                                                width: 34, height: 34,
                                                decoration: BoxDecoration(
                                                  color: _gold.withOpacity(.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: _gold.withOpacity(.3),
                                                      style: BorderStyle.solid),
                                                ),
                                                child: const Icon(Icons.add_rounded,
                                                    color: _gold, size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text('Ajouter un compte',
                                                  style: TextStyle(
                                                      color: _gold,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600)),
                                            ]),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                Container(height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: _white.withOpacity(.08)),
                const SizedBox(height: 8),

                // ── Nav groups ─────────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      for (final group in _groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                          child: Text(
                            group.labelKey == 'nav.main' ? 'NAVIGATION' : 'PLUS',
                            style: TextStyle(
                                color: _gold.withOpacity(.6),
                                fontSize: 9, fontWeight: FontWeight.w800,
                                letterSpacing: 1.5),
                          ),
                        ),
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

                      // ── Logout as last item ─────────────────────────
                      const SizedBox(height: 8),
                      Container(height: 1, color: _white.withOpacity(.06),
                          margin: const EdgeInsets.symmetric(horizontal: 4)),
                      const SizedBox(height: 8),
                      _SidebarLogoutItem(onTap: widget.onSignOut),
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
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.school_rounded, size: 20, color: _gold)),
                      const SizedBox(width: 8),
                      Text(AppConfig.appName,
                          style: TextStyle(color: _white.withOpacity(.5),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('v${AppConfig.appVersion}',
                          style: TextStyle(color: _white.withOpacity(.25), fontSize: 10)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _gold.withOpacity(.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? _gold.withOpacity(.25) : _white.withOpacity(.10),
                border: isActive ? Border.all(color: _gold.withOpacity(.5)) : null,
              ),
              child: Center(child: Text(initials,
                  style: TextStyle(
                      color: isActive ? _gold : _white.withOpacity(.7),
                      fontSize: 12, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(
                  color: isActive ? _white : _white.withOpacity(.8),
                  fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              Text(role.toUpperCase(), style: TextStyle(
                  color: _gold.withOpacity(.6), fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            ])),
            if (isActive)
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
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
              splashColor: _gold.withOpacity(.1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: selected ? _white.withOpacity(.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: _gold.withOpacity(.2)) : null,
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? _gold.withOpacity(.2)
                          : _white.withOpacity(.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entry.icon, size: 18,
                        color: selected ? _gold : _menuTxt.withOpacity(.7)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(entry.labelKey.tr(),
                        style: TextStyle(
                          color: selected ? _white : _menuTxt.withOpacity(.8),
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ),
                  if (selected)
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: _gold, shape: BoxShape.circle),
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

class _SidebarLogoutItem extends StatelessWidget {
  final VoidCallback onTap;
  const _SidebarLogoutItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: ScolarisPalette.terracotta.withOpacity(.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, size: 18,
                  color: ScolarisPalette.terracotta),
            ),
            const SizedBox(width: 14),
            Text('common.logout'.tr(),
                style: TextStyle(
                    color: ScolarisPalette.terracotta.withOpacity(.9),
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ── Sidebar background pattern ────────────────────────────────────────────
class _SidebarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ScolarisPalette.gold.withOpacity(.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const sp = 48.0;
    final cols = (size.width / sp).ceil() + 1;
    final rows = (size.height / sp).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * sp + (r.isEven ? sp * 0.5 : 0);
        final cy = r * sp * 0.866;
        _diamond(canvas, Offset(cx, cy), 8, p);
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
  bool shouldRepaint(_) => false;
}
