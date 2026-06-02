import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'surface.dart';

const _terra  = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);
const _gold   = Color(0xFFC17F24);
const _green  = Color(0xFF1B5E20);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

/// Dashboard layout utilisé par tous les rôles (Enseignant, Finance, Surveillance, etc.)
class DashboardScaffold extends StatelessWidget {
  final List<DashStat> stats;
  final List<DashSection> sections;
  final List<ExploreCard>? explore;

  const DashboardScaffold({
    super.key,
    required this.stats,
    required this.sections,
    this.explore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PeriodBar(),
            const SizedBox(height: 16),
            _StatsGrid(stats: stats),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (ctx2, c2) {
              if (c2.maxWidth > 720 && sections.length > 1) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 182,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (_, i) => _SectionCard(section: sections[i]),
                );
              }
              return Column(children: [
                for (final s in sections) ...[
                  _SectionCard(section: s),
                  const SizedBox(height: 14),
                ],
              ]);
            }),
            if (explore != null && explore!.isNotEmpty) ...[
              _SectionLabel('Explorer la plateforme'),
              const SizedBox(height: 10),
              _ExploreGrid(cards: explore!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Period bar ────────────────────────────────────────────────────────────
class _PeriodBar extends StatefulWidget {
  @override
  State<_PeriodBar> createState() => _PeriodBarState();
}

class _PeriodBarState extends State<_PeriodBar> {
  int _sel = 0;
  final _chips = ["Aujourd'hui", '7 jours', '30 jours', 'Ce trimestre'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ScolarisSurface.card(radius: 8, borderColor: _border),
          child: Row(children: const [
            Icon(Icons.calendar_today_outlined, size: 13, color: _muted),
            SizedBox(width: 6),
            Text('Période', style: TextStyle(
                fontSize: 12, color: _ink, fontWeight: FontWeight.w500)),
            SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 14, color: _muted),
          ]),
        ),
        const SizedBox(width: 8),
        for (int i = 0; i < _chips.length; i++) ...[
          GestureDetector(
            onTap: () => setState(() => _sel = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: _sel == i
                  ? BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_terra, _orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _terra.withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
              child: Text(_chips[i],
                  style: TextStyle(
                      fontSize: 12,
                      color: _sel == i ? _white : _muted,
                      fontWeight: _sel == i ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
          if (i < _chips.length - 1) const SizedBox(width: 6),
        ],
      ]),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final List<DashStat> stats;
  const _StatsGrid({required this.stats});

  static const _colors = [_terra, _gold, _green, _orange];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 980 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 96,
        ),
        itemCount: stats.length,
        itemBuilder: (_, i) =>
            _StatCard(stat: stats[i], color: _colors[i % _colors.length]),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final DashStat stat;
  final Color color;
  const _StatCard({required this.stat, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ScolarisSurface.accent(color: color, radius: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(stat.icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(stat.label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w600))),
          ]),
          const Spacer(),
          Text(stat.value, style: TextStyle(
              fontSize: 24, color: color, fontWeight: FontWeight.w900)),
        ],
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
      decoration: ScolarisSurface.card(radius: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(section.title, style: const TextStyle(
                fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(section.count, style: const TextStyle(
                fontSize: 26, color: _terra, fontWeight: FontWeight.w900)),
          ])),
          if (section.actionLabel != null)
            _PrimaryBtn(label: section.actionLabel!, onTap: section.onAction ?? () {}),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: ScolarisSurface.inner(radius: 10),
          child: Center(child: Text(section.emptyText,
              style: const TextStyle(fontSize: 12.5, color: _muted))),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: dotColor.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
          const SizedBox(width: 6),
          Text(section.footerLabel, style: const TextStyle(
              fontSize: 11.5, color: _muted,
              fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const Spacer(),
          Text('Voir détails', style: TextStyle(
              fontSize: 11.5, color: _terra.withOpacity(0.8),
              fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 14, color: _muted),
        ]),
      ]),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34, padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_terra, _orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: _terra.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Text(label, style: const TextStyle(
            color: _white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
        fontSize: 14, color: _ink, fontWeight: FontWeight.w800));
  }
}

// ── Explore Grid ──────────────────────────────────────────────────────────
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
          mainAxisExtent: 90,
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
      decoration: ScolarisSurface.card(radius: 14),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.25)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(card.icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(card.title, style: const TextStyle(
                fontSize: 13, color: _ink, fontWeight: FontWeight.w700)),
            if (card.suggested) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                    color: _gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(99)),
                child: const Text('Suggéré', style: TextStyle(
                    fontSize: 9.5, color: _gold, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Text(card.description, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.35)),
        ])),
      ]),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────
class DashStat {
  final IconData icon;
  final String label;
  final String value;
  const DashStat({required this.icon, required this.label, required this.value});

  factory DashStat.tr({
    required IconData icon,
    required String labelKey,
    required String value,
  }) => DashStat(icon: icon, label: labelKey.tr(), value: value);
}

class DashSection {
  final String title;
  final String count;
  final String emptyText;
  final String footerLabel;
  final Color? dotColor;
  final String? actionLabel;
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
  final String title;
  final String description;
  final bool suggested;
  const ExploreCard({
    required this.icon,
    required this.title,
    required this.description,
    this.suggested = false,
  });
}
