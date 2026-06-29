import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

// ── Shared skeleton atoms ─────────────────────────────────────────────────────

/// Skeleton d'une liste de cards simples (ex. notes, devoirs, présences).
class ScolSkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  const ScolSkeletonList({super.key, this.count = 6, this.itemHeight = 72});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => _FakeListTile(height: itemHeight, cs: cs),
      ),
    );
  }
}

class _FakeListTile extends StatelessWidget {
  final double height;
  final ColorScheme cs;
  const _FakeListTile({required this.height, required this.cs});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 13, width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10, width: 130,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
}

/// Skeleton d'une grille de cartes (ex. cours, matières).
class ScolSkeletonGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final double itemHeight;
  const ScolSkeletonGrid({
    super.key,
    this.count = 4,
    this.crossAxisCount = 2,
    this.itemHeight = 152,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // fake stats row
          Row(children: List.generate(4, (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
              height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 28, height: 12,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ]),
            ),
          ))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: itemHeight,
            ),
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 13, width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10, width: 80,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Skeleton pour une page avec un header hero coloré + contenu liste.
class ScolSkeletonHero extends StatelessWidget {
  final Color color;
  final int listCount;
  const ScolSkeletonHero({super.key, required this.color, this.listCount = 5});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: Column(children: [
        // hero
        Container(
          color: color.withValues(alpha: .3),
          height: 160,
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 18, width: 160, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(5))),
              const SizedBox(height: 8),
              Container(height: 12, width: 100, decoration: BoxDecoration(color: cs.outlineVariant.withValues(alpha: .6), borderRadius: BorderRadius.circular(4))),
            ])),
          ]),
        ),
        // list
        Expanded(child: ScolSkeletonList(count: listCount, itemHeight: 68)),
      ]),
    );
  }
}

/// Skeleton simple plein écran (centré, 3 lignes).
class ScolSkeletonCentered extends StatelessWidget {
  const ScolSkeletonCentered({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 24),
          for (int i = 0; i < 5; i++) ...[
            Container(
              height: 68,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
