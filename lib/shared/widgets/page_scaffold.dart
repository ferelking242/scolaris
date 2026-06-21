import 'package:flutter/material.dart';

  // ── Palette constants (light-mode fallbacks, widgets must use colorScheme) ──
  const ink      = Color(0xFF1A0A00);
  const muted    = Color(0xFF7A5C44);
  const border   = Color(0xFFDDCCBB);
  const cardBg   = Colors.white;
  const pageBg   = Color(0xFFF5EEE6);
  const subtleBg = Color(0xFFF0E8DC);

  const _terra  = Color(0xFF8B1A00);
  const _orange = Color(0xFFD4540A);
  const _gold   = Color(0xFFC17F24);

  // ─────────────────────────────────────────────────────────────────────────────
  // CollapsingPageScaffold  ← effet iOS Large Title sur toutes les pages
  // ─────────────────────────────────────────────────────────────────────────────

  /// Scaffold avec header rétractable façon iOS Large Title.
  /// Remplace l'ancien Container+SingleChildScrollView.
  class CollapsingPageScaffold extends StatelessWidget {
    final String title;
    final String? subtitle;
    final List<Widget> actions;
    final Widget child;

    const CollapsingPageScaffold({
      super.key,
      required this.title,
      this.subtitle,
      this.actions = const [],
      required this.child,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;

      return ColoredBox(
        color: cs.surface,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              expandedHeight: subtitle != null ? 102 : 88,
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0.8,
              shadowColor: cs.shadow.withOpacity(0.12),
              actions: actions.isEmpty
                  ? null
                  : [...actions, const SizedBox(width: 8)],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.only(left: 20, bottom: 14, right: 16),
                expandedTitleScale: 1.85,
                collapseMode: CollapseMode.pin,
                title: Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                background: Container(color: cs.surface),
              ),
              bottom: subtitle != null
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(
                          height: 1,
                          color: cs.outlineVariant.withOpacity(0.35)),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PageScaffold — wrapper mince au-dessus de CollapsingPageScaffold
  // ─────────────────────────────────────────────────────────────────────────────
  class PageScaffold extends StatelessWidget {
    final String title;
    final String? subtitle;
    final List<Widget> actions;
    final Widget child;
    const PageScaffold({
      super.key,
      required this.title,
      this.subtitle,
      this.actions = const [],
      required this.child,
    });

    @override
    Widget build(BuildContext context) => CollapsingPageScaffold(
          title: title,
          subtitle: subtitle,
          actions: actions,
          child: child,
        );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DataPanel — card informative thème-aware
  // ─────────────────────────────────────────────────────────────────────────────
  class DataPanel extends StatelessWidget {
    final String? title;
    final List<Widget> headerActions;
    final Widget child;
    final EdgeInsetsGeometry padding;
    const DataPanel({
      super.key,
      this.title,
      this.headerActions = const [],
      required this.child,
      this.padding = const EdgeInsets.all(16),
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
                color: cs.shadow.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(title!,
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2)),
                    const Spacer(),
                    ...headerActions,
                  ]),
                ),
              child,
            ],
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // StatusPill — thème-aware (s'adapte light/dark)
  // ─────────────────────────────────────────────────────────────────────────────
  class StatusPill extends StatelessWidget {
    final String label;
    final Color? _fixedColor;
    final Color? _fixedBg;
    final bool _isNeutral;

    const StatusPill._({
      super.key,
      required this.label,
      Color? color,
      Color? bg,
      bool neutral = false,
    })  : _fixedColor = color,
          _fixedBg = bg,
          _isNeutral = neutral;

    factory StatusPill({
      Key? key,
      required String label,
      required Color color,
      Color? bg,
    }) =>
        StatusPill._(key: key, label: label, color: color, bg: bg);

    factory StatusPill.success(String label) => StatusPill._(
          label: label,
          color: const Color(0xFF1B5E20),
          bg: const Color(0xFFE8F5E9),
        );
    factory StatusPill.warning(String label) => StatusPill._(
          label: label,
          color: const Color(0xFFD4540A),
          bg: const Color(0xFFFFF3E0),
        );
    factory StatusPill.danger(String label) => StatusPill._(
          label: label,
          color: const Color(0xFF8B1A00),
          bg: const Color(0xFFFCE4EC),
        );
    factory StatusPill.info(String label) => StatusPill._(
          label: label,
          color: const Color(0xFFC17F24),
          bg: const Color(0xFFFFF8E1),
        );
    // Neutre : 100% thème-aware
    factory StatusPill.neutral(String label) =>
        StatusPill._(label: label, neutral: true);

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final Color effectiveColor;
      final Color effectiveBg;

      if (_isNeutral) {
        effectiveColor = cs.onSurfaceVariant;
        effectiveBg    = cs.surfaceContainerHigh;
      } else {
        effectiveColor = _fixedColor!;
        // bg sémantiques (success/warning/danger/info) : on assombrit en dark
        if (isDark && _fixedBg != null) {
          effectiveBg = _fixedBg!.withOpacity(0.2);
        } else {
          effectiveBg = _fixedBg ?? cs.surfaceContainerHigh;
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: effectiveBg, borderRadius: BorderRadius.circular(99)),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 10.5, color: effectiveColor, fontWeight: FontWeight.w700),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SearchInput — thème-aware
  // ─────────────────────────────────────────────────────────────────────────────
  class SearchInput extends StatelessWidget {
    final String hint;
    final ValueChanged<String>? onChanged;
    const SearchInput({super.key, this.hint = 'Rechercher…', this.onChanged});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        width: 220,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(children: [
          Icon(Icons.search_rounded, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(fontSize: 12.5, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ]),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ActionButton — thème-aware
  // ─────────────────────────────────────────────────────────────────────────────
  class ActionButton extends StatelessWidget {
    final String label;
    final IconData? icon;
    final VoidCallback? onTap;
    final bool primary;
    const ActionButton({
      super.key,
      required this.label,
      this.icon,
      this.onTap,
      this.primary = false,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: primary ? cs.primary : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(9),
              border:
                  primary ? null : Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 13,
                    color: primary ? cs.onPrimary : cs.onSurface),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      color: primary ? cs.onPrimary : cs.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // EmptyState — thème-aware
  // ─────────────────────────────────────────────────────────────────────────────
  class EmptyState extends StatelessWidget {
    final IconData icon;
    final String title;
    final String description;
    const EmptyState({
      super.key,
      required this.icon,
      required this.title,
      required this.description,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Icon(icon, color: cs.onSurfaceVariant, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DataTablePanel — thème-aware
  // ─────────────────────────────────────────────────────────────────────────────
  class DataTablePanel extends StatelessWidget {
    final List<String> columns;
    final List<List<Widget>> rows;
    final List<int>? flex;
    const DataTablePanel({
      super.key,
      required this.columns,
      required this.rows,
      this.flex,
    });

    int _flex(int i) =>
        flex == null || i >= flex!.length ? 1 : flex![i];

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: cs.surfaceContainerHigh,
              child: Row(children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    flex: _flex(i),
                    child: Text(columns[i].toUpperCase(),
                        style: TextStyle(
                            fontSize: 10.5,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ),
              ]),
            ),
            for (var r = 0; r < rows.length; r++)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.3))),
                  color: r.isEven
                      ? cs.surface
                      : cs.surfaceContainerLowest,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var c = 0; c < rows[r].length; c++)
                      Expanded(flex: _flex(c), child: rows[r][c]),
                  ],
                ),
              ),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Avatar
  // ─────────────────────────────────────────────────────────────────────────────
  class Avatar extends StatelessWidget {
    final String name;
    final Color? color;
    final double size;
    const Avatar({super.key, required this.name, this.color, this.size = 28});

    @override
    Widget build(BuildContext context) {
      final initial =
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
      final c = color ??
          _palette[
              name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.withOpacity(.6), c],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size / 3.5),
        ),
        alignment: Alignment.center,
        child: Text(initial,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * .42)),
      );
    }

    static const _palette = [
      Color(0xFF8B1A00),
      Color(0xFFD4540A),
      Color(0xFFC17F24),
      Color(0xFF1B5E20),
      Color(0xFF5D4037),
      Color(0xFF3E1A00),
    ];
  }
  