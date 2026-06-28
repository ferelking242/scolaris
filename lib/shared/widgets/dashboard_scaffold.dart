import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

// ── Palette shadcn zinc ───────────────────────────────────────────────────
const _terra  = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);
const _gold   = Color(0xFFC17F24);
const _green  = Color(0xFF1B5E20);
const _ink    = Color(0xFF1A0A00);
const _white  = Colors.white;

const _zinc100 = Color(0xFFF4F4F5);
const _zinc200 = Color(0xFFE4E4E7);
const _zinc400 = Color(0xFFA1A1AA);
const _zinc700 = Color(0xFF3F3F46);
const _zinc900 = Color(0xFF18181B);

/// Dashboard layout utilisé par tous les rôles (Enseignant, Finance, Surveillance…).
///
/// Passer [loading] = true pour activer les shimmer skeletons sur les éléments
/// dynamiques (stats, sections). Le reste s'affiche normalement.
class DashboardScaffold extends StatelessWidget {
  final List<DashStat>    stats;
  final List<DashSection> sections;
  final List<ExploreCard>? explore;
  final bool              loading;

  const DashboardScaffold({
    super.key,
    required this.stats,
    required this.sections,
    this.explore,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _zinc100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sélecteur de période ───────────────────────────────────────
            const _PeriodChips(),
            const SizedBox(height: 20),

            // ── Grille de stats (shimmer si loading) ───────────────────────
            _StatsGrid(stats: stats, loading: loading),
            const SizedBox(height: 20),

            // ── Sections (une colonne ou grille 2×) ───────────────────────
            Skeletonizer(
              enabled: loading,
              effect: const ShimmerEffect(
                baseColor: Color(0xFFE4E4E7),
                highlightColor: Color(0xFFFAFAFA),
                duration: Duration(milliseconds: 1400),
              ),
              child: LayoutBuilder(builder: (ctx2, c2) {
                final wide = c2.maxWidth > 720 && sections.length > 1;
                if (wide) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 178,
                    ),
                    itemCount: sections.length,
                    itemBuilder: (_, i) =>
                        _SectionCard(section: sections[i]),
                  );
                }
                return Column(children: [
                  for (final s in sections) ...[
                    _SectionCard(section: s),
                    const SizedBox(height: 12),
                  ],
                ]);
              }),
            ),

            // ── Explorer la plateforme ────────────────────────────────────
            if (explore != null && explore!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const _SectionHeader('Explorer la plateforme'),
              const SizedBox(height: 12),
              _ExploreGrid(cards: explore!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur de période ──────────────────────────────────────────────────
class _PeriodChips extends StatefulWidget {
  const _PeriodChips();
  @override
  State<_PeriodChips> createState() => _PeriodChipsState();
}

class _PeriodChipsState extends State<_PeriodChips> {
  int _sel = 0;
  final _chips = ["Aujourd'hui", '7 jours', '30 jours', 'Trimestre'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (int i = 0; i < _chips.length; i++) ...[
          GestureDetector(
            onTap: () => setState(() => _sel = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 33,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:  _sel == i ? _zinc900 : _white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _sel == i ? _zinc900 : _zinc200,
                ),
                boxShadow: _sel == i
                    ? [BoxShadow(
                        color: Colors.black.withOpacity(.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3))]
                    : [],
              ),
              child: Text(_chips[i],
                  style: TextStyle(
                      fontSize: 12.5,
                      color: _sel == i ? _white : _zinc700,
                      fontWeight:
                          _sel == i ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
          if (i < _chips.length - 1) const SizedBox(width: 6),
        ],
      ]),
    );
  }
}

// ── Grille de statistiques ────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final List<DashStat> stats;
  final bool loading;
  const _StatsGrid({required this.stats, required this.loading});

  static const _accent = [_terra, _gold, _green, _orange];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 980 ? 4 : 2;
      final count = loading ? 4 : stats.length;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 110,
        ),
        itemCount: count,
        itemBuilder: (_, i) {
          final color = _accent[i % _accent.length];
          if (loading) return _StatCardSkeleton(color: color);
          return _StatCard(stat: stats[i], color: color);
        },
      );
    });
  }
}

// Carte de stat — shadcn style (blanc, bordure, icône top-right, nombre animé)
class _StatCard extends StatelessWidget {
  final DashStat stat;
  final Color color;
  const _StatCard({required this.stat, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _zinc200, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Stack(children: [
        // Icône en haut à droite
        Positioned(
          top: 0, right: 0,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stat.icon, size: 15, color: color),
          ),
        ),
        // Valeur + label en bas à gauche
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Spacer(),
            // Animation du compteur au chargement
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, t, __) {
                final num = int.tryParse(
                    stat.value.replaceAll(RegExp(r'[^0-9]'), ''));
                if (num == null) {
                  return Text(stat.value,
                      style: TextStyle(
                          fontSize: 28,
                          color: color,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5));
                }
                return Text(
                  (num * t).round().toString(),
                  style: TextStyle(
                      fontSize: 28,
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: _zinc400,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ]),
    );
  }
}

// Skeleton shimmer d'une carte stat
class _StatCardSkeleton extends StatelessWidget {
  final Color color;
  const _StatCardSkeleton({required this.color});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: Color(0xFFE4E4E7),
        highlightColor: Color(0xFFFAFAFA),
        duration: Duration(milliseconds: 1400),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _zinc200, width: 1.0),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _zinc200,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 52, height: 24,
              decoration: BoxDecoration(
                color: _zinc200,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 80, height: 11,
              decoration: BoxDecoration(
                color: _zinc200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final DashSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final dotColor = section.dotColor ?? _green;
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zinc200, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── En-tête : titre + nombre + bouton action ─────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(section.title,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: _zinc400,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .2)),
              const SizedBox(height: 2),
              Text(section.count,
                  style: const TextStyle(
                      fontSize: 28,
                      color: _terra,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5)),
            ]),
          ),
          if (section.actionLabel != null)
            _ActionChip(
                label: section.actionLabel!,
                onTap: section.onAction ?? () {}),
        ]),
        const SizedBox(height: 10),

        // ── Zone contenu (texte vide ou données) ─────────────────────────
        Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _zinc100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _zinc200, width: 1),
          ),
          child: Text(section.emptyText,
              style: const TextStyle(fontSize: 12, color: _zinc400)),
        ),
        const Spacer(),

        // ── Footer ────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: dotColor.withOpacity(.4), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(section.footerLabel,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: _zinc400,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4)),
          const Spacer(),
          Text('Voir tout',
              style: const TextStyle(
                  fontSize: 11.5, color: _terra, fontWeight: FontWeight.w600)),
          const SizedBox(width: 3),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 10, color: _terra.withOpacity(.8)),
        ]),
      ]),
    );
  }
}

// Mini bouton action — style shadcn solid (noir)
class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _zinc900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: _white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 15, color: _zinc900, fontWeight: FontWeight.w800));
}

// ── Explore Grid ───────────────────────────────────────────────────────────
class _ExploreGrid extends StatelessWidget {
  final List<ExploreCard> cards;
  const _ExploreGrid({required this.cards});

  static const _colors = [_terra, _gold, _green, _orange];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 720 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 88,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) =>
            _ExploreItem(card: cards[i], color: _colors[i % _colors.length]),
      );
    });
  }
}

class _ExploreItem extends StatelessWidget {
  final ExploreCard card;
  final Color color;
  const _ExploreItem({required this.card, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _zinc200, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(card.icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Flexible(
                  child: Text(card.title,
                      style: const TextStyle(
                          fontSize: 13,
                          color: _zinc900,
                          fontWeight: FontWeight.w700)),
                ),
                if (card.suggested) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _gold.withOpacity(.12),
                        borderRadius: BorderRadius.circular(99)),
                    child: const Text('Suggéré',
                        style: TextStyle(
                            fontSize: 9,
                            color: _gold,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(card.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: _zinc400, height: 1.35)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────
class DashStat {
  final IconData icon;
  final String   label;
  final String   value;
  const DashStat(
      {required this.icon, required this.label, required this.value});

  factory DashStat.tr({
    required IconData icon,
    required String   labelKey,
    required String   value,
  }) =>
      DashStat(icon: icon, label: labelKey.tr(), value: value);
}

class DashSection {
  final String     title;
  final String     count;
  final String     emptyText;
  final String     footerLabel;
  final Color?     dotColor;
  final String?    actionLabel;
  final VoidCallback? onAction;
  const DashSection({
    required this.title,
    required this.count,
    required this.emptyText,
    required this.footerLabel,
    this.dotColor,
    this.actionLabel,
    this.onAction,
  });
}

class ExploreCard {
  final IconData icon;
  final String   title;
  final String   description;
  final bool     suggested;
  const ExploreCard({
    required this.icon,
    required this.title,
    required this.description,
    this.suggested = false,
  });
}
