import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/remote/supabase_db_source.dart';
import '../../domain/entities/user_entity.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/db_providers.dart';
import '../../presentation/providers/nav_providers.dart';
import '../pages/account_page.dart';
import '../widgets/subscription_alert_banner.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
// _terra/_orange/_gold retirés : la chrome sombre (sidebar/header/popups) suit
// désormais l'accent choisi dans Apparence (Theme.of(context).colorScheme.primary)
// plutôt qu'une couleur de marque figée.
const _bg      = Color(0xFFF5EEE6);
const _ink     = Color(0xFF1A0A00);
const _muted   = Color(0xFF7A5C44);
const _border  = Color(0xFFDDCCBB);
const _white   = Colors.white;

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
  bool _showSettings = false;

  List<DesktopNavItem> get _flatItems =>
      [for (final g in widget.groups) ...g.items];

  void _toggle() => setState(() {
    _mode = _mode == _SideMode.full ? _SideMode.icons : _SideMode.full;
  });
  void _openSettings() => setState(() { _showSettings = true; });
  void _closeOverlay() => setState(() { _showSettings = false; });

  double get _sideW => _mode == _SideMode.full ? 220.0 : 56.0;

  void _goToLabelKey(String labelKey) {
    final items = _flatItems;
    final idx = items.indexWhere((e) => e.labelKey == labelKey);
    if (idx >= 0) {
      setState(() {
        _flatIndex = idx;
        _showSettings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Intention de navigation émise par une page (ex. actions rapides du dashboard).
    ref.listen<String?>(navIntentProvider, (_, next) {
      if (next != null) {
        _goToLabelKey(next);
        ref.read(navIntentProvider.notifier).state = null;
      }
    });
    final _isDark = Theme.of(context).brightness == Brightness.dark;
    final _accent = Theme.of(context).colorScheme.primary;
    final _side1  = _isDark
        ? const Color(0xFF0D1117)
        : Color.lerp(Colors.black, _accent, .32)!;
    final _side2  = _isDark
        ? const Color(0xFF1C2128)
        : Color.lerp(Colors.black, _accent, .55)!;
    return Scaffold(
      backgroundColor: _side1,
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_side1, _side2],
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
                  onSelect: (i) => setState(() { _flatIndex = i; _showSettings = false; }),
                  onSettings: _openSettings,
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
                    onToggle: _toggle,
                    onSettings: _openSettings,
                    showingOverlay: _showSettings,
                    onCloseOverlay: _closeOverlay,
                  ),
                  const SubscriptionAlertBanner(),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22)),
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: _showSettings
                            ? const AccountPage()
                            : _flatItems[_flatIndex].page,
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
    final accent = Theme.of(context).colorScheme.primary;
    final accent2 = Color.lerp(accent, Colors.white, .18)!;
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
                        gradient: LinearGradient(
                          colors: [accent, accent2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: accent.withOpacity(.4),
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
                            gradient: LinearGradient(
                              colors: [accent, accent2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: accent.withOpacity(.35),
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
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
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
                                color: accent2.withOpacity(.75),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            _closedGroups.contains(g)
                                ? Icons.expand_more_rounded
                                : Icons.expand_less_rounded,
                            size: 13,
                            color: accent2.withOpacity(.6),
                          ),
                        ]),
                      ),
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
  final VoidCallback onToggle;
  final VoidCallback? onSettings;
  final bool showingOverlay;
  final VoidCallback? onCloseOverlay;

  const _Header({
    required this.title,
    required this.mode,
    required this.onToggle,
    this.onSettings,
    this.showingOverlay = false,
    this.onCloseOverlay,
  });

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final side1  = isDark
        ? const Color(0xFF0D1117)
        : Color.lerp(Colors.black, accent, .32)!;
    final side2  = isDark
        ? const Color(0xFF1C2128)
        : Color.lerp(Colors.black, accent, .55)!;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [side1, side2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: side1.withOpacity(.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // ── Toggle / Back button ──────────────────────────────────────
          _DarkBtn(
            icon: widget.showingOverlay
                ? Icons.arrow_back_rounded
                : (widget.mode == _SideMode.full ? Icons.menu_open_rounded : Icons.menu_rounded),
            tooltip: widget.showingOverlay
                ? 'common.back'.tr()
                : (widget.mode == _SideMode.full ? 'sidebar.collapse'.tr() : 'sidebar.expand'.tr()),
            onTap: widget.showingOverlay ? (widget.onCloseOverlay ?? () {}) : widget.onToggle,
          ),
          const SizedBox(width: 14),

          Container(width: 1, height: 20, color: _white.withOpacity(.12)),
          const SizedBox(width: 14),

          // ── Campus selector (uniquement si l'école a des filiales) ──────
          _BranchSelector(),

          const Spacer(),

          // ── Help icon ──────────────────────────────────────────────────
          CustomPopup(
            barrierColor: Colors.transparent,
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
            content: Material(
              type: MaterialType.transparency,
              child: _AccountPanel(
                user: user,
                onSettings: () {
                  // Le popup est empilé sur le Navigator le plus proche
                  // (CustomPopup, rootNavigator: false) — le fermer sur le
                  // root Navigator ciblait le mauvais stack et laissait le
                  // popup ouvert par-dessus l'écran Profil.
                  Navigator.of(context).maybePop();
                  widget.onSettings?.call();
                },
              ),
            ),
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

}

// ─────────────────────────────────────────────────────────────────────────────
// Campus selector — visible uniquement si l'école a ≥ 1 filiale
// ─────────────────────────────────────────────────────────────────────────────
class _BranchSelector extends ConsumerWidget {
  const _BranchSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final selected = ref.watch(selectedBranchProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return branchesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (branches) {
        if (branches.isEmpty) return const SizedBox.shrink();

        final label = selected?.name ?? 'Tous les campus';

        return Row(mainAxisSize: MainAxisSize.min, children: [
          CustomPopup(
            barrierColor: Colors.transparent,
            content: Material(
              type: MaterialType.transparency,
              child: _BranchPopup(branches: branches, selected: selected),
            ),
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
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.school_outlined, size: 13, color: accent),
                  const SizedBox(width: 7),
                  Text(label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _shTxt,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(width: 5),
                  Icon(Icons.unfold_more_rounded, size: 13, color: _shMuted),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 20, color: _white.withOpacity(.12)),
        ]);
      },
    );
  }
}

class _BranchPopup extends ConsumerWidget {
  final List<SbBranch> branches;
  final SbBranch? selected;
  const _BranchPopup({required this.branches, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pick(SbBranch? branch) {
      ref.read(selectedBranchProvider.notifier).state = branch;
      ref.invalidate(classesProvider);
      Navigator.of(context).maybePop();
    }

    final accent = Theme.of(context).colorScheme.primary;
    final items = <SbBranch?>[null, ...branches];

    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1200),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SÉLECTIONNER LE CENTRE',
                  style: TextStyle(
                    fontSize: 9, letterSpacing: 1.2,
                    color: accent.withOpacity(.7), fontWeight: FontWeight.w800,
                  )),
            ),
          ),
          for (final b in items)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => pick(b),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: b?.id == selected?.id ? accent : _shMuted.withOpacity(.4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b?.name ?? 'Tous les campus',
                        style: TextStyle(
                          fontSize: 13,
                          color: b?.id == selected?.id ? accent : _shTxt,
                          fontWeight: b?.id == selected?.id ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (b?.id == selected?.id)
                      Icon(Icons.check_rounded, size: 14, color: accent),
                  ]),
                ),
              ),
            ),
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

  const _AccountPanel({required this.user, this.onSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleName = switch (user?.role) {
      UserRole.staff   => 'Administration',
      UserRole.teacher => 'Enseignant',
      UserRole.student => 'Élève',
      UserRole.parent  => 'Parent',
      null             => '—',
    };
    final accent = Theme.of(context).colorScheme.primary;
    final accentDark = Color.lerp(accent, Colors.black, .25)!;
    final accentLight = Color.lerp(accent, Colors.white, .18)!;

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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentDark, accent, accentLight],
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
            icon: Icons.settings_outlined,
            label: 'Mon profil',
            // Le pop se fait déjà dans le callback onSettings passé par
            // _Header (sur le bon Navigator) — un 2e pop ici ciblait en plus
            // le root Navigator par erreur, sur un popup empilé ailleurs.
            onTap: () => onSettings?.call(),
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
    final accent = Theme.of(context).colorScheme.primary;
    final accentLight = Color.lerp(accent, Colors.white, .18)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accent, accentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(.35),
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
    final accent = Theme.of(context).colorScheme.primary;
    final bg = active
        ? accent
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
                        decoration: BoxDecoration(
                          color: _white.withOpacity(.9),
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
              tooltip: 'Mon profil', onTap: onSettings),
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
            label: 'Mon profil', onTap: onSettings),
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
    final accent = Theme.of(context).colorScheme.primary;
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
                    decoration: BoxDecoration(
                      color: accent,
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
