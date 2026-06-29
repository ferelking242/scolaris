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

// ── Data ──────────────────────────────────────────────────────────────────────
class _Annale {
  final String matiere;
  final String titre;
  final String annee;
  final String session;
  final Color color;
  final IconData icon;
  const _Annale({
    required this.matiere, required this.titre, required this.annee,
    required this.session, required this.color, required this.icon,
  });
}

const _annales = [
  _Annale(matiere: 'Mathématiques', titre: 'Analyse — Dérivées et intégrales', annee: '2023', session: 'Normale', color: _terra, icon: Icons.calculate_rounded),
  _Annale(matiere: 'Mathématiques', titre: 'Algèbre — Nombres complexes', annee: '2023', session: 'Rattrapage', color: _terra, icon: Icons.calculate_rounded),
  _Annale(matiere: 'Mathématiques', titre: 'Probabilités et statistiques', annee: '2022', session: 'Normale', color: _terra, icon: Icons.calculate_rounded),
  _Annale(matiere: 'Sciences Physiques', titre: 'Mécanique — Chute libre et projectile', annee: '2023', session: 'Normale', color: _green, icon: Icons.science_rounded),
  _Annale(matiere: 'Sciences Physiques', titre: 'Électricité — Circuits RC et RL', annee: '2022', session: 'Normale', color: _green, icon: Icons.science_rounded),
  _Annale(matiere: 'Chimie', titre: 'Réactions d\'oxydo-réduction', annee: '2023', session: 'Normale', color: Color(0xFF059669), icon: Icons.biotech_rounded),
  _Annale(matiere: 'Algorithmique', titre: 'Algorithmes de tri et complexité', annee: '2023', session: 'Normale', color: Color(0xFF6D28D9), icon: Icons.code_rounded),
  _Annale(matiere: 'Français', titre: 'Dissertation littéraire — Négritude', annee: '2023', session: 'Normale', color: _gold, icon: Icons.menu_book_rounded),
  _Annale(matiere: 'Philosophie', titre: 'La liberté et la responsabilité', annee: '2022', session: 'Normale', color: Color(0xFFDB2777), icon: Icons.psychology_rounded),
];

class _Fiche {
  final String matiere;
  final String titre;
  final int chapitres;
  final Color color;
  final IconData icon;
  final double progression;
  const _Fiche({
    required this.matiere, required this.titre, required this.chapitres,
    required this.color, required this.icon, required this.progression,
  });
}

const _fiches = [
  _Fiche(matiere: 'Mathématiques', titre: 'Fonctions, dérivées, intégrales', chapitres: 5, color: _terra, icon: Icons.calculate_rounded, progression: 0.65),
  _Fiche(matiere: 'Physique', titre: 'Mécanique du point matériel', chapitres: 4, color: _green, icon: Icons.science_rounded, progression: 0.40),
  _Fiche(matiere: 'Chimie', titre: 'Cinétique et équilibres chimiques', chapitres: 3, color: Color(0xFF059669), icon: Icons.biotech_rounded, progression: 0.20),
  _Fiche(matiere: 'Algo', titre: 'Algorithmes et structures de données', chapitres: 6, color: Color(0xFF6D28D9), icon: Icons.code_rounded, progression: 0.80),
  _Fiche(matiere: 'Français', titre: 'Littérature africaine francophone', chapitres: 4, color: _gold, icon: Icons.menu_book_rounded, progression: 0.50),
];

final _matieresFiltres = ['Toutes', ..._annales.map((a) => a.matiere).toSet().toList()];

// ── Page principale ───────────────────────────────────────────────────────────
class PrepaBacPage extends StatefulWidget {
  const PrepaBacPage({super.key});
  @override
  State<PrepaBacPage> createState() => _PrepaBacPageState();
}

class _PrepaBacPageState extends State<PrepaBacPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _filtre = 'Toutes';

  // Compte à rebours jusqu'au Bac (fictif)
  static final DateTime _dateBac = DateTime(2026, 7, 20);
  int get _jours => _dateBac.difference(DateTime.now()).inDays.clamp(0, 999);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  List<_Annale> get _filtredAnnales => _annales
      .where((a) => _filtre == 'Toutes' || a.matiere == _filtre)
      .toList();

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Prépa-Bac',
      subtitle: 'Annales, fiches & planning',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Compte à rebours ────────────────────────────────────────────────
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
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _white.withOpacity(.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _white.withOpacity(.2)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$_jours', style: const TextStyle(
                    color: _white, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
                const Text('jours', style: TextStyle(color: Colors.white60, fontSize: 9)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bac National 2026',
                  style: TextStyle(color: _white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('20 juillet 2026 — Terminale EMI',
                  style: TextStyle(color: _white.withOpacity(.7), fontSize: 12)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (1 - _jours / 365).clamp(0.0, 1.0),
                  backgroundColor: _white.withOpacity(.2),
                  valueColor: const AlwaysStoppedAnimation(_gold),
                  minHeight: 5,
                ),
              ),
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
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [Tab(text: 'Annales'), Tab(text: 'Fiches'), Tab(text: 'Planning')],
          ),
        ),
        const SizedBox(height: 14),

        // ── Contenu par onglet ─────────────────────────────────────────────
        if (_tab.index == 0) _buildAnnales()
        else if (_tab.index == 1) _buildFiches()
        else _buildPlanning(),
      ]),
    );
  }

  Widget _buildAnnales() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Filtres
      SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _matieresFiltres.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final m = _matieresFiltres[i];
            final sel = m == _filtre;
            return GestureDetector(
              onTap: () => setState(() => _filtre = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? _terra : _white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _terra : _border),
                ),
                child: Text(m, style: TextStyle(
                    color: sel ? _white : _muted,
                    fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      ..._filtredAnnales.map((a) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _AnnaleCard(annale: a),
      )),
    ]);
  }

  Widget _buildFiches() => Column(
    children: _fiches.map((f) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _FicheCard(fiche: f),
    )).toList(),
  );

  Widget _buildPlanning() {
    final semaines = [
      (s: 'Semaine 1', focus: 'Mathématiques — Révisions chapitres 1-3', fait: true),
      (s: 'Semaine 2', focus: 'Physique — Mécanique + Électricité', fait: true),
      (s: 'Semaine 3', focus: 'Chimie + Algorithmique', fait: false),
      (s: 'Semaine 4', focus: 'Français + Philosophie', fait: false),
      (s: 'Semaine 5', focus: 'Annales Maths 2021-2023', fait: false),
      (s: 'Semaine 6', focus: 'Annales Sciences + Révisions finales', fait: false),
    ];
    return Column(children: semaines.map((w) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: w.fait ? _green.withOpacity(.3) : _border),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: w.fait ? _green : _border.withOpacity(.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              w.fait ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
              color: _white, size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.s, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: w.fait ? _green : _muted)),
            const SizedBox(height: 2),
            Text(w.focus, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w600)),
          ])),
          if (w.fait) const Icon(Icons.check_circle_rounded, color: _green, size: 18),
        ]),
      ),
    )).toList());
  }
}

// ── Carte annale ──────────────────────────────────────────────────────────────
class _AnnaleCard extends StatelessWidget {
  final _Annale annale;
  const _AnnaleCard({required this.annale});
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
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: annale.color.withOpacity(.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(annale.icon, color: annale.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(annale.titre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 3),
          Row(children: [
            Text(annale.matiere, style: TextStyle(fontSize: 11, color: annale.color, fontWeight: FontWeight.w600)),
            const Text(' · ', style: TextStyle(color: _muted)),
            Text('${annale.annee} — ${annale.session}',
                style: const TextStyle(fontSize: 11, color: _muted)),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _terra.withOpacity(.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.download_rounded, size: 13, color: _terra),
            SizedBox(width: 4),
            Text('PDF', style: TextStyle(fontSize: 11, color: _terra, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

// ── Carte fiche ───────────────────────────────────────────────────────────────
class _FicheCard extends StatelessWidget {
  final _Fiche fiche;
  const _FicheCard({required this.fiche});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: fiche.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(fiche.icon, color: fiche.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fiche.titre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            Text('${fiche.chapitres} chapitres', style: const TextStyle(fontSize: 11, color: _muted)),
          ])),
          Text('${(fiche.progression * 100).round()} %',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fiche.color)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fiche.progression,
            backgroundColor: _border.withOpacity(.5),
            valueColor: AlwaysStoppedAnimation(fiche.color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}
