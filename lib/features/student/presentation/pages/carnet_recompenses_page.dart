import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

// Neutres (texte/fond/bordure) : jamais figés → `context.c*` (page_scaffold).
// Ces deux-là sont du texte posé sur un fond de marque coloré : ils restent
// constants, valables en clair comme en sombre.
const _white  = Colors.white;        // sur terracotta / couleur de badge
const _onGold = Color(0xFF1A0A00);   // sur la pastille or

/// Couleur d'un badge — dérivée de sa clé, faute de colonne `color` en base.
/// (Une couleur n'est pas une donnée d'école : c'est de la présentation.)
Color _badgeColor(String key) {
  const palette = [
    _gold, _terra, Color(0xFF0891B2), Color(0xFF6D28D9),
    _green, Color(0xFFDB2777), Color(0xFF059669), Color(0xFFD4540A),
  ];
  if (key.isEmpty) return _gold;
  return palette[key.codeUnits.fold(0, (a, b) => a + b) % palette.length];
}

// ══════════════════════════════════════════════════════════════════════════
// Carnet de récompenses — bons points et badges d'un élève.
//
// `studentId` null = l'élève connecté (vue élève).
// `studentId` renseigné = vue parent sur un de ses enfants.
// ══════════════════════════════════════════════════════════════════════════
class CarnetRecompensesPage extends ConsumerStatefulWidget {
  final String? studentId;
  final String? title;
  const CarnetRecompensesPage({super.key, this.studentId, this.title});

  @override
  ConsumerState<CarnetRecompensesPage> createState() =>
      _CarnetRecompensesPageState();
}

class _CarnetRecompensesPageState extends ConsumerState<CarnetRecompensesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final sid     = widget.studentId ?? session?.id;
    final heading = widget.title ?? 'Carnet de récompenses ⭐';

    if (sid == null) {
      return PageScaffold(title: heading, child: const SizedBox());
    }

    final pointsAsync = ref.watch(meritPointsForStudentProvider(sid));
    final badgesAsync = ref.watch(badgesForStudentProvider(sid));

    final points = pointsAsync.valueOrNull ?? const <SbMeritPoint>[];
    final badges = badgesAsync.valueOrNull ?? const <SbBadge>[];
    final loading = pointsAsync.isLoading || badgesAsync.isLoading;

    final totalEtoiles = points.fold<int>(0, (s, p) => s + p.stars);
    final obtenus = badges.where((b) => b.earned).length;

    if (pointsAsync.hasError) {
      return PageScaffold(
        title: heading,
        child: Center(child: Text('Erreur : ${pointsAsync.error}',
            style: TextStyle(color: context.cMuted))),
      );
    }

    return PageScaffold(
      title: heading,
      subtitle: loading
          ? 'Chargement…'
          : totalEtoiles == 0 && obtenus == 0
              ? 'Aucune récompense pour l\'instant'
              : '$totalEtoiles étoile(s) · $obtenus badge(s)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Bandeau étoiles ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0500), _terra],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: _terra.withOpacity(.3),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            _StarDisplay(count: totalEtoiles),
            const SizedBox(width: 20),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mes étoiles',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('$totalEtoiles ⭐', style: const TextStyle(
                  color: _white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$obtenus badge(s)', style: const TextStyle(
                      color: _onGold, fontSize: 11,
                      fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${points.length} bon(s) point(s)',
                      style: const TextStyle(color: _white, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Onglets ────────────────────────────────────────────────────────
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: context.cSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: context.cCard,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 4)
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _terra,
            unselectedLabelColor: context.cMuted,
            labelStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: '🏅 Badges'),
              Tab(text: '⭐ Bons points'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (loading)
          const Center(child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: CircularProgressIndicator(),
          ))
        else if (_tab.index == 0)
          _buildBadges(badges)
        else
          _buildPoints(points),
      ]),
    );
  }

  Widget _buildBadges(List<SbBadge> badges) {
    if (badges.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Aucun badge',
        description:
            'L\'école n\'a pas encore défini de badges à décrocher.',
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: badges.map((b) => _BadgeCard(badge: b)).toList(),
    );
  }

  Widget _buildPoints(List<SbMeritPoint> points) {
    if (points.isEmpty) {
      return const EmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Aucun bon point',
        description:
            'Les bons points attribués par l\'enseignant apparaîtront ici.',
      );
    }
    return Column(
      children: points
          .map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PointCard(point: p),
              ))
          .toList(),
    );
  }
}

// ── Affichage étoiles ─────────────────────────────────────────────────────────
class _StarDisplay extends StatelessWidget {
  final int count;
  const _StarDisplay({required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60, height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(math.min(count, 5), (i) {
          final angle = (i / 5) * 2 * math.pi;
          return Positioned(
            left: 22 + 18 * math.cos(angle),
            top: 22 + 18 * math.sin(angle),
            child: const Text('⭐', style: TextStyle(fontSize: 14)),
          );
        })
          ..insert(
              0,
              const Positioned.fill(
                  child: Center(
                      child: Text('⭐', style: TextStyle(fontSize: 28))))),
      ),
    );
  }
}

// ── Carte badge ───────────────────────────────────────────────────────────────
class _BadgeCard extends StatelessWidget {
  final SbBadge badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor(badge.key);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: badge.earned ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: badge.earned ? color.withOpacity(.10) : context.cCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: badge.earned ? color.withOpacity(.3) : context.cBorder,
              width: badge.earned ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(badge.emoji ?? '🏅', style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(badge.title,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800,
                  color: badge.earned ? context.cInk : context.cMuted),
              textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (badge.description != null) ...[
            const SizedBox(height: 4),
            Text(badge.description!,
                style: TextStyle(
                    fontSize: 10, color: context.cMuted, height: 1.3),
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (badge.earned) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_fmt(badge.earnedAt),
                  style: const TextStyle(color: _white, fontSize: 9.5,
                      fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Icon(Icons.lock_rounded, size: 14, color: context.cMuted),
          ],
        ]),
      ),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return 'Obtenu';
    const mois = ['janv.','févr.','mars','avr.','mai','juin','juil.','août',
                  'sept.','oct.','nov.','déc.'];
    return '${mois[d.month - 1]} ${d.year}';
  }
}

// ── Carte bon point ───────────────────────────────────────────────────────────
class _PointCard extends StatelessWidget {
  final SbMeritPoint point;
  const _PointCard({required this.point});

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor(point.subject ?? '');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(
            List.generate(point.stars, (_) => '⭐').join(),
            style: TextStyle(
                fontSize: point.stars == 1 ? 18 : point.stars == 2 ? 14 : 11),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(point.reason, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: context.cInk)),
          const SizedBox(height: 3),
          Row(children: [
            if (point.subject != null && point.subject!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(point.subject!, style: TextStyle(
                    fontSize: 10, color: color,
                    fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(
                [
                  _fmt(point.awardedAt),
                  if (point.awardedByName != null) point.awardedByName!,
                ].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 10.5, color: context.cMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        Row(children: List.generate(3, (i) => Icon(
          i < point.stars
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          color: i < point.stars ? _gold : context.cBorder,
          size: 18,
        ))),
      ]),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    const mois = ['janv.','févr.','mars','avr.','mai','juin','juil.','août',
                  'sept.','oct.','nov.','déc.'];
    return '${d.day} ${mois[d.month - 1]}';
  }
}
