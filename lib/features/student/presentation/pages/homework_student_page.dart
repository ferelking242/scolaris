import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

class _StudentHW {
  final String matiere;
  final String titre;
  final String enseignant;
  final DateTime echeance;
  bool done;
  final double? note;
  _StudentHW({
    required this.matiere,
    required this.titre,
    required this.enseignant,
    required this.echeance,
    this.done = false,
    this.note,
  });
}

// Devoirs EMI — Ferel Ondongo (Terminale EMI)
final _mockStudentHW = <_StudentHW>[
  _StudentHW(
    matiere: 'Mathématiques',
    titre: 'Intégrales — Exercices 8.4 à 8.7',
    enseignant: 'M. Ngakosso Jean-Pierre',
    echeance: DateTime.now().add(const Duration(hours: 20)),
  ),
  _StudentHW(
    matiere: 'Électronique',
    titre: 'Rapport TP — Circuits RLC (résonance)',
    enseignant: 'M. Kimbembi Rodrigue',
    echeance: DateTime.now().add(const Duration(days: 2)),
  ),
  _StudentHW(
    matiere: 'Algorithmique',
    titre: 'Programme Python — Tri rapide (Quicksort)',
    enseignant: 'M. Mabika Jean-Claude',
    echeance: DateTime.now().add(const Duration(days: 3)),
  ),
  _StudentHW(
    matiere: 'Sciences Physiques',
    titre: 'Compte-rendu — Lois de Kirchhoff',
    enseignant: 'M. Massamba Boris',
    echeance: DateTime.now().add(const Duration(days: 5)),
  ),
  _StudentHW(
    matiere: 'Chimie',
    titre: 'Exercices — Cinétique chimique ch.6',
    enseignant: 'M. Bouya Jean',
    echeance: DateTime.now().subtract(const Duration(days: 1)),
    done: false,
  ),
  _StudentHW(
    matiere: 'Philosophie',
    titre: 'Dissertation — Science et liberté',
    enseignant: 'M. Ngandzali Théophile',
    echeance: DateTime.now().add(const Duration(days: 10)),
  ),
  _StudentHW(
    matiere: 'Mathématiques',
    titre: 'Contrôle — Fonctions logarithmiques',
    enseignant: 'M. Ngakosso Jean-Pierre',
    echeance: DateTime.now().subtract(const Duration(days: 5)),
    note: 17.5,
    done: true,
  ),
  _StudentHW(
    matiere: 'Anglais',
    titre: 'Essay — "Technology and the future"',
    enseignant: 'Mme Banzouzi Pauline',
    echeance: DateTime.now().subtract(const Duration(days: 8)),
    note: 16.0,
    done: true,
  ),
  _StudentHW(
    matiere: 'Algorithmique',
    titre: 'Projet — Gestionnaire de notes en Python',
    enseignant: 'M. Mabika Jean-Claude',
    echeance: DateTime.now().subtract(const Duration(days: 12)),
    note: 19.0,
    done: true,
  ),
];

// ──────────────────────────────────────────────────────────────────────────────
class HomeworkStudentPage extends StatefulWidget {
  const HomeworkStudentPage({super.key});
  @override
  State<HomeworkStudentPage> createState() => _HomeworkStudentPageState();
}

class _HomeworkStudentPageState extends State<HomeworkStudentPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final List<_StudentHW> _hws = _mockStudentHW;

  List<_StudentHW> get _aRendre => _hws.where((h) =>
      !h.done && h.note == null &&
      h.echeance.isAfter(DateTime.now())).toList()
    ..sort((a, b) => a.echeance.compareTo(b.echeance));

  List<_StudentHW> get _enRetard => _hws.where((h) =>
      !h.done && h.echeance.isBefore(DateTime.now())).toList();

  List<_StudentHW> get _rendus => _hws.where((h) => h.done).toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(children: [
        _Header(tab: _tab,
            total: _hws.length,
            aRendre: _aRendre.length,
            retard: _enRetard.length),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            // À rendre
            _ListTab(
              hws: [..._enRetard, ..._aRendre],
              emptyMsg: 'Aucun devoir en attente 🎉',
              onToggle: (h) => setState(() => h.done = !h.done),
              showOverdue: true,
            ),
            // Rendu
            _ListTab(
              hws: _rendus,
              emptyMsg: 'Aucun devoir rendu pour l\'instant.',
              onToggle: (h) => setState(() => h.done = !h.done),
              showOverdue: false,
            ),
            // Corrigé
            _ListTab(
              hws: _hws.where((h) => h.note != null).toList(),
              emptyMsg: 'Pas encore de copies corrigées.',
              onToggle: null,
              showOverdue: false,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final TabController tab;
  final int total;
  final int aRendre;
  final int retard;
  const _Header({
    required this.tab,
    required this.total,
    required this.aRendre,
    required this.retard,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A0A00), _terra]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(child: Icon(Icons.assignment_turned_in_rounded, color: _white, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mes Devoirs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              Text('$total devoirs · $retard en retard',
                  style: TextStyle(fontSize: 12,
                      color: retard > 0 ? _terra : _muted)),
            ])),
            if (retard > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _terra, borderRadius: BorderRadius.circular(20)),
              child: Text('$retard retard${retard > 1 ? 's' : ''}',
                  style: const TextStyle(color: _white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        TabBar(
          controller: tab,
          labelColor: _terra,
          unselectedLabelColor: _muted,
          indicatorColor: _terra,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
          tabs: const [
            Tab(text: 'À rendre'),
            Tab(text: 'Rendu'),
            Tab(text: 'Corrigé'),
          ],
        ),
      ]),
    );
  }
}

class _ListTab extends StatelessWidget {
  final List<_StudentHW> hws;
  final String emptyMsg;
  final void Function(_StudentHW)? onToggle;
  final bool showOverdue;
  const _ListTab({
    required this.hws,
    required this.emptyMsg,
    required this.onToggle,
    required this.showOverdue,
  });
  @override
  Widget build(BuildContext context) {
    if (hws.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded, size: 56, color: _green.withOpacity(.4)),
        const SizedBox(height: 12),
        Text(emptyMsg, style: const TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w600)),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: hws.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _HWStudentCard(
          hw: hws[i], onToggle: onToggle, showOverdue: showOverdue),
    );
  }
}

class _HWStudentCard extends StatelessWidget {
  final _StudentHW hw;
  final void Function(_StudentHW)? onToggle;
  final bool showOverdue;
  const _HWStudentCard({
    required this.hw,
    required this.onToggle,
    required this.showOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = hw.echeance.difference(now).inDays;
    final overdue = hw.echeance.isBefore(now) && !hw.done;
    final today = !overdue && daysLeft == 0;

    final Color cardColor;
    if (overdue && showOverdue) {
      cardColor = _terra.withOpacity(.06);
    } else if (today) {
      cardColor = _orange.withOpacity(.06);
    } else {
      cardColor = _white;
    }

    final Color borderColor;
    if (overdue && showOverdue) {
      borderColor = _terra.withOpacity(.25);
    } else if (today) {
      borderColor = _orange.withOpacity(.25);
    } else {
      borderColor = _border;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (onToggle != null)
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: GestureDetector(
                onTap: () => onToggle!(hw),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: hw.done ? _green : Colors.transparent,
                    border: Border.all(
                        color: hw.done ? _green : _border, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: hw.done
                      ? const Icon(Icons.check_rounded, size: 14, color: _white)
                      : null,
                ),
              ),
            ),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _terra.withOpacity(.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(hw.matiere, style: const TextStyle(
                      color: _terra, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                if (hw.note != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${hw.note!.toStringAsFixed(1)}/20',
                      style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                if (overdue && showOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _terra, borderRadius: BorderRadius.circular(6)),
                    child: const Text('En retard', style: TextStyle(
                        color: _white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                  )
                else if (today)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: _orange, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Aujourd\'hui', style: TextStyle(
                        color: _white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                  )
                else if (!hw.done && daysLeft > 0)
                  Text('J-$daysLeft', style: TextStyle(color: _muted, fontSize: 11)),
              ]),
              const SizedBox(height: 6),
              Text(hw.titre, style: TextStyle(
                  color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700,
                  decoration: hw.done ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 12, color: _muted),
                const SizedBox(width: 3),
                Text(hw.enseignant, style: const TextStyle(color: _muted, fontSize: 11.5)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 11, color: _muted),
                const SizedBox(width: 3),
                Text(
                  '${hw.echeance.day.toString().padLeft(2,'0')}/${hw.echeance.month.toString().padLeft(2,'0')}/${hw.echeance.year}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}
