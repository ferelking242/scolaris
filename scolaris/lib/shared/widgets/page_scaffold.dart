import 'package:flutter/material.dart';

// ── Scolaris African palette for all shared pages ─────────────────────────
// Neutres FIGÉS (thème clair uniquement). Conservés pour compatibilité, mais
// à remplacer progressivement par l'extension `context.c*` ci-dessous, qui
// s'adapte automatiquement au mode clair/sombre. Ne plus en ajouter.
const ink = Color(0xFF1A0A00);
const muted = Color(0xFF7A5C44);
const border = Color(0xFFDDCCBB);
const cardBg = Colors.white;
const pageBg = Color(0xFFF5EEE6);
const subtleBg = Color(0xFFF0E8DC);

/// Neutres DÉRIVÉS DU THÈME — équivalents adaptatifs des constantes ci-dessus.
/// `context.cInk` remplace `ink`, `context.cMuted` remplace `muted`, etc.
/// Les accents de marque (terracotta, or, vert) restent des constantes.
extension ScolarisThemeColors on BuildContext {
  ColorScheme get _cs => Theme.of(this).colorScheme;
  Color get cInk => _cs.onSurface; // ← ink
  Color get cMuted => _cs.onSurfaceVariant; // ← muted
  Color get cBorder => _cs.outlineVariant; // ← border
  Color get cCard => _cs.surface; // ← cardBg
  Color get cPage => Theme.of(this).scaffoldBackgroundColor; // ← pageBg
  Color get cSubtle => _cs.surfaceContainerHigh; // ← subtleBg
}

const _terra = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);
const _gold = Color(0xFFC17F24);

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
  Widget build(BuildContext context) {
    // Une page atteinte par `Navigator.push` (la fiche d'un enfant, et tout ce
    // qu'on ouvre depuis elle) doit pouvoir se refermer. Les destinations du
    // menu, elles, n'ont rien à dépiler : le bouton ne s'affiche pas.
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      // Une page poussée n'a pas de Scaffold : sans SafeArea, son contenu passe
      // sous la barre d'état. Dans le shell, la marge est déjà gérée → top:false.
      child: SafeArea(
        top: canPop,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (canPop) ...[
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Theme.of(context).colorScheme.onSurface,
                      tooltip: 'Retour',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(.55))),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              const SizedBox(height: 4),
              Container(
                  height: 2,
                  width: 32,
                  decoration: BoxDecoration(
                      color: _terra, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête riche pour les pages de détail ouvertes en route isolée.
///
/// Règle le double défaut des anciennes pages : un `AppBar` quasi vide (pas de
/// bouton retour visible) + un titre redondant rendu par `PageScaffold`.
/// Ici : un seul bandeau dégradé terracotta avec bouton retour clair, badge
/// d'icône, titre, sous-titre et actions optionnelles.
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  /// Actions placées sous le titre (ex. bouton « Générer »).
  final List<Widget> actions;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(12, topInset + 10, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_terra, _orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Color(0x338B1A00), blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Bouton retour — affordance claire (pastille translucide).
            _HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Retour',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .85),
                            fontSize: 12.5,
                            height: 1.3)),
                  ],
                ],
              ),
            ),
          ]),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: [
              for (final a in actions) ...[a, const SizedBox(width: 8)],
            ]),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconButton(
      {required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Bouton d'action posé sur le bandeau dégradé (fond clair translucide).
class HeaderActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  /// `true` = bouton plein blanc (action principale), sinon contour translucide.
  final bool filled;
  const HeaderActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.filled = false,
  });
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: filled ? Colors.white : Colors.white.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: filled
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: .35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: filled ? _terra : Colors.white),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: filled ? _terra : Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Lien de retour discret (pastille) à poser en haut du `child` d'un
/// `PageScaffold` ouvert en route. Par défaut, `Navigator.maybePop`.
class BackLinkRow extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const BackLinkRow({super.key, this.label = 'Retour', this.onTap});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded, size: 15, color: context.cMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.cMuted,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

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
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _terra,
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
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.bg,
  });

  factory StatusPill.success(String label) => StatusPill(
      label: label,
      color: const Color(0xFF1B5E20),
      bg: const Color(0xFFE8F5E9));
  factory StatusPill.warning(String label) => StatusPill(
      label: label,
      color: const Color(0xFFD4540A),
      bg: const Color(0xFFFFF3E0));
  factory StatusPill.danger(String label) => StatusPill(
      label: label,
      color: const Color(0xFF8B1A00),
      bg: const Color(0xFFFCE4EC));
  factory StatusPill.info(String label) => StatusPill(
      label: label,
      color: const Color(0xFFC17F24),
      bg: const Color(0xFFFFF8E1));
  factory StatusPill.neutral(String label) =>
      StatusPill(label: label, color: muted, bg: subtleBg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? subtleBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class SearchInput extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  const SearchInput({super.key, this.hint = 'Rechercher…', this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 15, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12.5, color: ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12.5, color: muted),
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
    final fgColor = primary ? Colors.white : cs.onSurface;
    final bgColor = primary ? _terra : cs.surfaceContainerHigh;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9),
            border: primary ? null : Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fgColor),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: subtleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: muted, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 13, color: ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}

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

  int _flex(int i) => flex == null || i >= flex!.length ? 1 : flex![i];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg =
        isDark ? cs.surfaceContainerHighest : cs.surfaceContainerLow;
    final rowEvenBg = cs.surfaceContainer;
    final rowOddBg =
        isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest;
    final divider = cs.outlineVariant;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: headerBg,
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
          // Rows
          for (var r = 0; r < rows.length; r++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: divider, width: 0.6)),
                color: r.isEven ? rowEvenBg : rowOddBg,
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

class Avatar extends StatelessWidget {
  final String name;
  final Color? color;
  final double size;
  const Avatar({super.key, required this.name, this.color, this.size = 28});
  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
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
