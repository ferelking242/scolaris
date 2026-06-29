import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _orange = ScolarisPalette.orange;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Data ──────────────────────────────────────────────────────────────────────
class _Badge {
  final String emoji;
  final String titre;
  final String description;
  final Color color;
  final bool obtenu;
  final String? dateObtention;
  const _Badge({
    required this.emoji, required this.titre, required this.description,
    required this.color, required this.obtenu, this.dateObtention,
  });
}

class _BonPoint {
  final String motif;
  final String matiere;
  final String date;
  final int etoiles;
  final Color color;
  const _BonPoint({
    required this.motif, required this.matiere, required this.date,
    required this.etoiles, required this.color,
  });
}

const _badges = [
  _Badge(emoji: '🏆', titre: 'Tableau d\'honneur', description: 'Classé 1er du trimestre', color: _gold, obtenu: true, dateObtention: 'Trim. 2'),
  _Badge(emoji: '📚', titre: 'Grand lecteur', description: '10 livres lus ce trimestre', color: _terra, obtenu: true, dateObtention: 'Mai 2026'),
  _Badge(emoji: '🧮', titre: 'As des maths', description: 'Moyenne > 8/10 en calcul', color: Color(0xFF0891B2), obtenu: true, dateObtention: 'Avr. 2026'),
  _Badge(emoji: '✍️', titre: 'Belle écriture', description: 'Récompensé pour l\'écriture', color: Color(0xFF6D28D9), obtenu: true, dateObtention: 'Mar. 2026'),
  _Badge(emoji: '🌟', titre: 'Super présence', description: '30 jours sans absence', color: _green, obtenu: false),
  _Badge(emoji: '🎨', titre: 'Artiste du mois', description: 'Meilleur dessin de la classe', color: Color(0xFFDB2777), obtenu: false),
  _Badge(emoji: '⚽', titre: 'Champion sport', description: 'Meilleur en EPS', color: Color(0xFF059669), obtenu: false),
  _Badge(emoji: '🔬', titre: 'Jeune scientifique', description: 'Excellence en sciences', color: Color(0xFF0891B2), obtenu: false),
];

const _bonsPoints = [
  _BonPoint(motif: 'Excellent devoir de calcul', matiere: 'Calcul', date: 'Hier', etoiles: 3, color: _gold),
  _BonPoint(motif: 'Belle lecture à voix haute', matiere: 'Lecture', date: 'Lun 23 Jun', etoiles: 2, color: _terra),
  _BonPoint(motif: 'Aide aux camarades', matiere: 'Conduite', date: 'Ven 20 Jun', etoiles: 1, color: _green),
  _BonPoint(motif: 'Dessin réussi', matiere: 'Dessin', date: 'Mer 18 Jun', etoiles: 2, color: Color(0xFFDB2777)),
  _BonPoint(motif: 'Récitation parfaite', matiere: 'Français', date: 'Lun 16 Jun', etoiles: 3, color: Color(0xFF6D28D9)),
  _BonPoint(motif: 'Bonne participation', matiere: 'Sciences', date: 'Ven 13 Jun', etoiles: 1, color: Color(0xFF0891B2)),
];

int get _totalEtoiles => _bonsPoints.fold(0, (s, b) => s + b.etoiles);
int get _badgesObtenus => _badges.where((b) => b.obtenu).length;

// ── Page principale ───────────────────────────────────────────────────────────
class CarnetRecompensesPage extends StatefulWidget {
  const CarnetRecompensesPage({super.key});
  @override
  State<CarnetRecompensesPage> createState() => _CarnetRecompensesPageState();
}

class _CarnetRecompensesPageState extends State<CarnetRecompensesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Carnet de récompenses ⭐',
      subtitle: 'Tes bons points et médailles',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Hero stats ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0500), _terra],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: _terra.withOpacity(.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            // Étoiles animées
            _StarDisplay(count: _totalEtoiles),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mes étoiles', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('$_totalEtoiles ⭐', style: const TextStyle(
                  color: _white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$_badgesObtenus badges', style: const TextStyle(
                      color: _ink, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${_bonsPoints.length} bons points', style: const TextStyle(
                      color: _white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Tabs ─────────────────────────────────────────────────────────────
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: _border.withOpacity(.3),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _terra,
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: const [Tab(text: '🏅 Mes badges'), Tab(text: '⭐ Bons points')],
          ),
        ),
        const SizedBox(height: 14),

        if (_tab.index == 0) _buildBadges()
        else _buildBonsPoints(),
      ]),
    );
  }

  Widget _buildBadges() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: _badges.map((b) => _BadgeCard(badge: b)).toList(),
    );
  }

  Widget _buildBonsPoints() => Column(
    children: _bonsPoints.map((bp) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _BonPointCard(bp: bp),
    )).toList(),
  );
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
        })..insert(0, const Positioned.fill(child: Center(child: Text('⭐', style: TextStyle(fontSize: 28))))),
      ),
    );
  }
}

// ── Carte badge ───────────────────────────────────────────────────────────────
class _BadgeCard extends StatelessWidget {
  final _Badge badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: badge.obtenu ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: badge.obtenu ? badge.color.withOpacity(.08) : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: badge.obtenu ? badge.color.withOpacity(.3) : _border,
              width: badge.obtenu ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(badge.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(badge.titre, style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800,
              color: badge.obtenu ? _ink : _muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(badge.description, style: const TextStyle(
              fontSize: 10, color: _muted, height: 1.3),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (badge.obtenu && badge.dateObtention != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badge.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge.dateObtention!, style: const TextStyle(
                  color: _white, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ),
          ] else if (!badge.obtenu) ...[
            const SizedBox(height: 6),
            const Icon(Icons.lock_rounded, size: 14, color: _muted),
          ],
        ]),
      ),
    );
  }
}

// ── Carte bon point ───────────────────────────────────────────────────────────
class _BonPointCard extends StatelessWidget {
  final _BonPoint bp;
  const _BonPointCard({required this.bp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: bp.color.withOpacity(.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(
            List.generate(bp.etoiles, (_) => '⭐').join(),
            style: TextStyle(fontSize: bp.etoiles == 1 ? 18 : bp.etoiles == 2 ? 14 : 11),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bp.motif, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bp.color.withOpacity(.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(bp.matiere, style: TextStyle(
                  fontSize: 10, color: bp.color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text(bp.date, style: const TextStyle(fontSize: 10.5, color: _muted)),
          ]),
        ])),
        Row(children: List.generate(3, (i) => Icon(
          i < bp.etoiles ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < bp.etoiles ? _gold : _border,
          size: 18,
        ))),
      ]),
    );
  }
}
