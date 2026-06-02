import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/mock_data.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;
const _green = ScolarisPalette.forestGreen;

class CourseDetailPage extends StatefulWidget {
  final MockCourse course;
  const CourseDetailPage({super.key, required this.course});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late final TabController _tab;

  static const _tabs = ['Programme', 'Objectifs', 'Planning', 'Ressources'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _loading = false); });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    return Scaffold(
      backgroundColor: const Color(0xFFF5EEE6),
      body: Column(children: [
        // ── Hero header ──────────────────────────────────────────────
        _CourseHero(course: c),

        // ── Tabs ────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
            labelColor: c.color,
            unselectedLabelColor: muted,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            indicatorColor: c.color,
            indicatorWeight: 3,
          ),
        ),

        // ── Tab content ──────────────────────────────────────────────
        Expanded(
          child: Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(
              baseColor: Color(0xFFDDD6CE),
              highlightColor: Color(0xFFEFEAE3),
            ),
            child: TabBarView(
              controller: _tab,
              children: [
                _ProgrammeTab(course: c),
                _ObjectifsTab(course: c),
                _PlanningTab(course: c),
                _RessourcesTab(course: c),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Hero header
// ══════════════════════════════════════════════════════════════════════════
class _CourseHero extends StatelessWidget {
  final MockCourse course;
  const _CourseHero({required this.course});

  @override
  Widget build(BuildContext context) {
    final c = course.color;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(Colors.black, c, 0.7)!,
            c,
            c.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Back button
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Icon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.40), width: 1.5),
                ),
                child: Icon(course.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(course.name, style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person_outline_rounded, size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(course.teacher, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _HeroBadge(Icons.class_outlined, course.classe),
                  _HeroBadge(Icons.auto_stories_rounded, '${course.chapters} chapitres'),
                  _HeroBadge(Icons.schedule_rounded, '${course.hoursPerWeek}h / semaine'),
                ]),
              ])),
            ]),
          ),

          // Info importante
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.30)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(course.importantInfo,
                  style: const TextStyle(color: Colors.white, fontSize: 12))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroBadge(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.20),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.40)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Onglet Programme
// ══════════════════════════════════════════════════════════════════════════
class _ProgrammeTab extends StatelessWidget {
  final MockCourse course;
  const _ProgrammeTab({required this.course});

  List<(int, String, String)> get _chapters => List.generate(
    course.chapters,
    (i) => (
      i + 1,
      _chapterTitle(course.code, i),
      _chapterDesc(i),
    ),
  );

  static String _chapterTitle(String code, int i) {
    const titles = [
      'Introduction générale', 'Fondements théoriques', 'Méthodes et outils',
      'Applications pratiques', 'Études de cas', 'Approfondissement',
      'Exercices d\'intégration', 'Problèmes avancés', 'Révisions et synthèse',
      'Évaluation formative', 'Extensions et ouvertures', 'Projet final',
      'Bilan du semestre', 'Préparation aux examens', 'Annales commentées',
    ];
    return titles[i % titles.length];
  }

  static String _chapterDesc(int i) {
    const descs = [
      'Présentation du programme et des objectifs du cours.',
      'Concepts fondamentaux et vocabulaire de la matière.',
      'Outils pratiques et méthodologie de travail.',
      'Mise en application des connaissances acquises.',
      'Analyse d\'exemples concrets et discussion.',
      'Approfondissement des notions clés du chapitre.',
      'Série d\'exercices d\'intégration progressive.',
      'Problèmes complexes à résoudre en autonomie.',
      'Synthèse des apprentissages du trimestre.',
      'Évaluation des acquis par des exercices diagnostiques.',
    ];
    return descs[i % descs.length];
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _chapters;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final (num, title, desc) = chapters[i];
        final c = course.color;
        final done = i < (course.chapters * 0.4).floor();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: done ? c.withOpacity(0.30) : border),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: done ? c : const Color(0xFFF0E8DC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : Center(child: Text('$num',
                      style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                  fontSize: 13, color: ink, fontWeight: FontWeight.w700,
                  decoration: done ? TextDecoration.none : null)),
              const SizedBox(height: 3),
              Text(desc, style: const TextStyle(fontSize: 11.5, color: muted)),
            ])),
            if (done) Icon(Icons.lock_open_rounded, size: 14, color: c)
            else const Icon(Icons.lock_outlined, size: 14, color: muted),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Onglet Objectifs
// ══════════════════════════════════════════════════════════════════════════
class _ObjectifsTab extends StatelessWidget {
  final MockCourse course;
  const _ObjectifsTab({required this.course});

  @override
  Widget build(BuildContext context) {
    final c = course.color;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Objectifs pédagogiques
        _SectionBlock(
          icon: Icons.flag_rounded,
          title: 'Objectifs pédagogiques',
          color: c,
          child: Column(children: course.objectives.asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c, c.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: Text('${e.key + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value,
                    style: const TextStyle(fontSize: 13, color: ink, height: 1.4))),
              ]),
            ),
          ).toList()),
        ),
        const SizedBox(height: 14),

        // Description du cours
        _SectionBlock(
          icon: Icons.description_rounded,
          title: 'Description du cours',
          color: _terra,
          child: Text(course.description,
              style: const TextStyle(fontSize: 13, color: ink, height: 1.6)),
        ),
        const SizedBox(height: 14),

        // Informations professeur
        _SectionBlock(
          icon: Icons.person_rounded,
          title: 'Informations professeur',
          color: _green,
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_green, _green.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(
                course.teacher.replaceAll('M. ', '').replaceAll('Mme ', '').replaceAll('Ms. ', '').replaceAll('Dr. ', '')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              )),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.teacher, style: const TextStyle(
                  fontSize: 14, color: ink, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Enseignant · ${course.name}', style: const TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 12, color: muted),
                const SizedBox(width: 4),
                Text('${course.hoursPerWeek}h de cours / semaine',
                    style: const TextStyle(fontSize: 12, color: muted)),
              ]),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Onglet Planning
// ══════════════════════════════════════════════════════════════════════════
class _PlanningTab extends StatelessWidget {
  final MockCourse course;
  const _PlanningTab({required this.course});

  static const _months = [
    (month: 'Septembre', items: ['Chapitre 1–2 : Introduction', 'TP / Évaluation diagnostique']),
    (month: 'Octobre',   items: ['Chapitre 3–4 : Fondements', 'Devoir surveillé T1']),
    (month: 'Novembre',  items: ['Chapitre 5–6 : Applications', 'Révisions T1']),
    (month: 'Décembre',  items: ['Examens T1', 'Conseil de classe']),
    (month: 'Janvier',   items: ['Chapitre 7–8 : Approfondissement', 'Évaluation formative']),
    (month: 'Février',   items: ['Chapitre 9–10 : Exercices', 'Devoir surveillé T2']),
    (month: 'Mars',      items: ['Chapitre 11–12 : Synthèse', 'Révisions T2']),
    (month: 'Avril',     items: ['Examens T2', 'Conseil de classe']),
    (month: 'Mai',       items: ['Chapitre 13–14 : Projet', 'Évaluation de projet']),
    (month: 'Juin',      items: ['Examens finaux T3', 'Bilan annuel']),
  ];

  @override
  Widget build(BuildContext context) {
    final c = course.color;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _months.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = _months[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 6, height: double.infinity,
              decoration: BoxDecoration(
                color: c.withOpacity(0.70),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.month, style: TextStyle(
                  fontSize: 13, color: c, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final item in m.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 5, color: muted),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item,
                        style: const TextStyle(fontSize: 12, color: ink))),
                  ]),
                ),
            ])),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Onglet Ressources
// ══════════════════════════════════════════════════════════════════════════
class _RessourcesTab extends StatelessWidget {
  final MockCourse course;
  const _RessourcesTab({required this.course});

  static const _icons = [
    Icons.menu_book_rounded,
    Icons.folder_rounded,
    Icons.link_rounded,
    Icons.videocam_rounded,
    Icons.science_rounded,
    Icons.computer_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final c = course.color;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionBlock(
          icon: Icons.library_books_rounded,
          title: 'Ressources disponibles',
          color: c,
          child: Column(
            children: course.resources.asMap().entries.map((e) {
              final icon = _icons[e.key % _icons.length];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withOpacity(0.20)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: c, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value,
                      style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w600))),
                  Icon(Icons.open_in_new_rounded, size: 14, color: c.withOpacity(0.70)),
                ]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Emploi du temps associé
        _SectionBlock(
          icon: Icons.calendar_today_rounded,
          title: 'Emploi du temps associé',
          color: _terra,
          child: Column(
            children: MockData.schedule
                .where((s) => s.subject.toLowerCase().contains(
                    course.name.split(' ').first.toLowerCase()))
                .map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _terra.withOpacity(0.20)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: _terra),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${s.day} · ${s.time}',
                        style: const TextStyle(fontSize: 12.5, color: ink, fontWeight: FontWeight.w600))),
                    Text('Salle ${s.room}', style: const TextStyle(fontSize: 12, color: muted)),
                  ]),
                ))
                .toList(),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Bloc section générique
// ══════════════════════════════════════════════════════════════════════════
class _SectionBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  const _SectionBlock({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.70)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(
                fontSize: 13, color: ink, fontWeight: FontWeight.w800)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ]),
    );
  }
}
