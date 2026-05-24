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

// ── Modèles ───────────────────────────────────────────────────────────────────
class _SubjectStat {
  final String matiere;
  final double moyenne;
  final double min;
  final double max;
  const _SubjectStat({
    required this.matiere,
    required this.moyenne,
    required this.min,
    required this.max,
  });
}

class _StudentStat {
  final String name;
  final double moyenne;
  const _StudentStat({required this.name, required this.moyenne});
}

class _ClassData {
  final String name;
  final int effectif;
  final double moyenne;
  final double presence;
  final double reussite;
  final List<_SubjectStat> subjects;
  final List<_StudentStat> topStudents;
  final List<_StudentStat> lowStudents;
  const _ClassData({
    required this.name,
    required this.effectif,
    required this.moyenne,
    required this.presence,
    required this.reussite,
    required this.subjects,
    required this.topStudents,
    required this.lowStudents,
  });
}

const _data = <String, _ClassData>{
  'Tle C': _ClassData(
    name: 'Tle C',
    effectif: 32,
    moyenne: 13.8,
    presence: .94,
    reussite: .88,
    subjects: [
      _SubjectStat(matiere: 'EPS',               moyenne: 16.2, min: 12.0, max: 20.0),
      _SubjectStat(matiere: 'Mathématiques',      moyenne: 15.5, min: 8.5,  max: 19.5),
      _SubjectStat(matiere: 'Sciences Physiques', moyenne: 14.2, min: 7.0,  max: 19.0),
      _SubjectStat(matiere: 'SVT',               moyenne: 13.8, min: 9.0,  max: 18.5),
      _SubjectStat(matiere: 'Philosophie',        moyenne: 13.5, min: 8.0,  max: 18.0),
      _SubjectStat(matiere: 'Histoire-Géo',       moyenne: 13.0, min: 7.5,  max: 18.0),
      _SubjectStat(matiere: 'Français',           moyenne: 12.5, min: 7.0,  max: 17.5),
      _SubjectStat(matiere: 'Anglais',            moyenne: 10.8, min: 5.5,  max: 17.0),
    ],
    topStudents: [
      _StudentStat(name: 'Junior Mafoua',      moyenne: 16.4),
      _StudentStat(name: 'Stéphanie Loemba',   moyenne: 16.1),
      _StudentStat(name: 'Roméo Nsianganga',   moyenne: 15.9),
    ],
    lowStudents: [
      _StudentStat(name: 'Régis Bouboutou',    moyenne: 8.9),
      _StudentStat(name: 'Martial Loemba-Bita',moyenne: 9.4),
    ],
  ),
  '1ère C': _ClassData(
    name: '1ère C',
    effectif: 30,
    moyenne: 12.6,
    presence: .91,
    reussite: .80,
    subjects: [
      _SubjectStat(matiere: 'Mathématiques',     moyenne: 13.0, min: 6.0,  max: 18.5),
      _SubjectStat(matiere: 'Sciences Physiques',moyenne: 12.8, min: 5.5,  max: 18.0),
      _SubjectStat(matiere: 'SVT',              moyenne: 13.2, min: 7.0,  max: 18.0),
      _SubjectStat(matiere: 'Français',          moyenne: 12.0, min: 6.0,  max: 17.0),
      _SubjectStat(matiere: 'Anglais',           moyenne: 11.0, min: 5.0,  max: 16.5),
    ],
    topStudents: [
      _StudentStat(name: 'Cynthia Ngakosso',   moyenne: 15.9),
      _StudentStat(name: 'Franck Mbemba',      moyenne: 14.7),
    ],
    lowStudents: [
      _StudentStat(name: 'Prince Yombi',       moyenne: 8.1),
    ],
  ),
  '2nde A': _ClassData(
    name: '2nde A',
    effectif: 28,
    moyenne: 11.8,
    presence: .89,
    reussite: .71,
    subjects: [
      _SubjectStat(matiere: 'Mathématiques',     moyenne: 11.5, min: 4.5,  max: 17.0),
      _SubjectStat(matiere: 'Français',          moyenne: 12.2, min: 5.0,  max: 17.5),
      _SubjectStat(matiere: 'Sciences Physiques',moyenne: 10.8, min: 4.0,  max: 16.5),
    ],
    topStudents: [
      _StudentStat(name: 'Gloire Mabika',      moyenne: 14.8),
    ],
    lowStudents: [
      _StudentStat(name: 'Boris Nzoungou',     moyenne: 7.2),
      _StudentStat(name: 'Christa Balossa',    moyenne: 7.9),
    ],
  ),
};

// ── Page ──────────────────────────────────────────────────────────────────────
class ClassStatsPage extends StatefulWidget {
  const ClassStatsPage({super.key});
  @override
  State<ClassStatsPage> createState() => _ClassStatsPageState();
}

class _ClassStatsPageState extends State<ClassStatsPage> {
  String _selectedClass = 'Tle C';

  @override
  Widget build(BuildContext context) {
    final d = _data[_selectedClass]!;
    return Container(
      color: _bg,
      child: Column(children: [
        _TopBar(
          selectedClass: _selectedClass,
          classes: _data.keys.toList(),
          onSelect: (c) => setState(() => _selectedClass = c),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _KpiRow(data: d),
              const SizedBox(height: 14),
              _SubjectBarsCard(subjects: d.subjects),
              const SizedBox(height: 14),
              _RankingCard(title: 'Top élèves', students: d.topStudents, isTop: true),
              const SizedBox(height: 10),
              _RankingCard(title: 'En difficulté', students: d.lowStudents, isTop: false),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String selectedClass;
  final List<String> classes;
  final ValueChanged<String> onSelect;
  const _TopBar({
    required this.selectedClass,
    required this.classes,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: _white,
          border: Border(bottom: BorderSide(color: _border))),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A0A00), Color(0xFF2D6A4F)]),
            borderRadius: BorderRadius.circular(11)),
          child: const Center(child: Icon(Icons.bar_chart_rounded, color: _white, size: 20))),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Statistiques de Classe',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          Text('Analyse des performances — semestre 2',
              style: TextStyle(fontSize: 12, color: _muted)),
        ])),
        DropdownButton<String>(
          value: selectedClass,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          items: classes.map((c) =>
              DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => onSelect(v!),
        ),
      ]),
    );
  }
}

// ── KPI row ────────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final _ClassData data;
  const _KpiRow({required this.data});
  @override
  Widget build(BuildContext context) {
    final kpis = [
      (data.moyenne.toStringAsFixed(1), 'Moyenne', _terra, Icons.grade_rounded),
      ('${(data.presence * 100).toInt()}%', 'Présence', _green, Icons.how_to_reg_rounded),
      ('${(data.reussite * 100).toInt()}%', 'Réussite', _orange, Icons.check_circle_rounded),
      ('${data.effectif}', 'Élèves', _gold, Icons.groups_rounded),
    ];
    return Row(children: kpis.asMap().entries.map((e) {
      final isLast = e.key == kpis.length - 1;
      final kpi = e.value;
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            Icon(kpi.$4, size: 20, color: kpi.$3),
            const SizedBox(height: 6),
            Text(kpi.$1, style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: kpi.$3)),
            Text(kpi.$2, style: const TextStyle(
                fontSize: 10.5, color: _muted, fontWeight: FontWeight.w500)),
          ]),
        ),
      ));
    }).toList());
  }
}

// ── Subject bars ───────────────────────────────────────────────────────────────
class _SubjectBarsCard extends StatelessWidget {
  final List<_SubjectStat> subjects;
  const _SubjectBarsCard({required this.subjects});
  @override
  Widget build(BuildContext context) {
    final sorted = [...subjects]..sort((a, b) => b.moyenne.compareTo(a.moyenne));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Moyennes par matière',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 14),
        ...sorted.map((s) {
          final pct = s.moyenne / 20;
          final color = s.moyenne >= 14 ? _green :
              s.moyenne >= 12 ? _orange : _terra;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.matiere, style: const TextStyle(
                    fontSize: 12.5, color: _ink, fontWeight: FontWeight.w600))),
                Text(s.moyenne.toStringAsFixed(1),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                Text('/20', style: TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(width: 8),
                Text('(${s.min.toStringAsFixed(1)}–${s.max.toStringAsFixed(1)})',
                    style: TextStyle(fontSize: 10, color: _muted.withOpacity(.7))),
              ]),
              const SizedBox(height: 5),
              Stack(children: [
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Ranking card ───────────────────────────────────────────────────────────────
class _RankingCard extends StatelessWidget {
  final String title;
  final List<_StudentStat> students;
  final bool isTop;
  const _RankingCard({required this.title, required this.students, required this.isTop});
  @override
  Widget build(BuildContext context) {
    final color = isTop ? _green : _terra;
    final icon  = isTop ? Icons.emoji_events_rounded : Icons.warning_amber_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(title, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 10),
        ...students.asMap().entries.map((e) {
          final rank = e.key + 1;
          final s = e.value;
          final moy = s.moyenne;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: color.withOpacity(.1), shape: BoxShape.circle),
                child: Center(child: Text('$rank', style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s.name, style: const TextStyle(
                  color: _ink, fontSize: 13, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
                child: Text(moy.toStringAsFixed(2), style: TextStyle(
                    color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
