import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/services/print_service.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

// ── Modèle bulletin (calculé) ─────────────────────────────────────────────────
class _BulletinRow {
  final String matiere;
  final int coef;
  final double moyenne;
  final String appreciation;
  const _BulletinRow({
    required this.matiere,
    required this.coef,
    required this.moyenne,
    required this.appreciation,
  });
}

String _mention(double moy) {
  if (moy >= 16) return 'Très Bien';
  if (moy >= 14) return 'Bien';
  if (moy >= 12) return 'Assez Bien';
  if (moy >= 10) return 'Passable';
  return 'Insuffisant';
}

Color _mentionColor(double moy) {
  if (moy >= 16) return ScolarisPalette.forestGreen;
  if (moy >= 14) return const Color(0xFF0EA5E9);
  if (moy >= 12) return ScolarisPalette.gold;
  if (moy >= 10) return ScolarisPalette.orange;
  return ScolarisPalette.terracotta;
}

String _autoAppreciation(double avg) {
  if (avg >= 16) return 'Excellent travail, continuez sur cette lancée';
  if (avg >= 14) return 'Très bon résultat ce semestre';
  if (avg >= 12) return 'Bon niveau, peut encore progresser';
  if (avg >= 10) return 'Résultat passable, des efforts sont nécessaires';
  return 'Résultat insuffisant, un travail important est requis';
}

// ── Page ──────────────────────────────────────────────────────────────────────
class BulletinPage extends ConsumerStatefulWidget {
  const BulletinPage({super.key});
  @override
  ConsumerState<BulletinPage> createState() => _BulletinPageState();
}

class _BulletinPageState extends ConsumerState<BulletinPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  // Système congolais : 3 trimestres (les notes portent period 'T1'|'T2'|'T3').
  String get _period => 'T${_tab.index + 1}';
  String get _periodLabel => switch (_tab.index) {
        0 => '1er trimestre',
        1 => '2e trimestre',
        _ => '3e trimestre',
      };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Calcul des lignes du bulletin ─────────────────────────────────────────
  List<_BulletinRow> _buildRows(
      List<SbGrade> allGrades, List<SbSubject> subjects) {
    // Garder seulement les notes du semestre actif
    final periodGrades =
        allGrades.where((g) => g.period == _period).toList();

    // Grouper par matière
    final Map<String, List<SbGrade>> bySubject = {};
    for (final g in periodGrades) {
      if (g.subjectId == null) continue;
      (bySubject[g.subjectId!] ??= []).add(g);
    }

    final rows = <_BulletinRow>[];
    for (final subj in subjects) {
      final grades = bySubject[subj.id];
      if (grades == null || grades.isEmpty) continue;
      final avg =
          grades.fold(0.0, (s, g) => s + g.outOf20) / grades.length;
      final comment = grades
          .where((g) => g.comment != null && g.comment!.isNotEmpty)
          .lastOrNull
          ?.comment;
      rows.add(_BulletinRow(
        matiere: subj.name,
        coef: subj.coefficient,
        moyenne: avg,
        appreciation: comment ?? _autoAppreciation(avg),
      ));
    }
    return rows;
  }

  double _generalAvg(List<_BulletinRow> rows) {
    if (rows.isEmpty) return 0;
    final totalPts =
        rows.fold(0.0, (s, r) => s + r.moyenne * r.coef);
    final totalCoef = rows.fold(0, (s, r) => s + r.coef);
    return totalCoef > 0 ? totalPts / totalCoef : 0;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final studentAsync = ref.watch(myStudentProfileProvider);
    final schoolAsync  = ref.watch(schoolProvider);
    final gradesAsync = session != null
        ? ref.watch(gradesForStudentProvider(session.id))
        : const AsyncValue<List<SbGrade>>.data([]);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Container(
      color: _bg,
      child: Column(children: [
        // ── Header + onglets ────────────────────────────────────────────
        _BulletinHeader(
          tab: _tab,
          schoolName: schoolAsync.valueOrNull?.name,
          studentClass: studentAsync.valueOrNull?.classe,
        ),
        Expanded(
          child: subjectsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Erreur matières : $e')),
            data: (subjects) => gradesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Erreur notes : $e')),
              data: (allGrades) {
                final rows = _buildRows(allGrades, subjects);
                final avg = _generalAvg(rows);
                final student = studentAsync.valueOrNull;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    // Info élève
                    _StudentInfoCard(
                      name: session?.fullName ?? 'Élève',
                      classe: student?.classe,
                      matricule: student?.matricule,
                      periodLabel: _periodLabel,
                    ),
                    const SizedBox(height: 14),

                    if (rows.isEmpty)
                      const _EmptyBulletin()
                    else ...[
                      _GradesTable(rows: rows),
                      const SizedBox(height: 14),
                      _SummaryCard(
                        moyenne: avg,
                        mention: _mention(avg),
                        mColor: _mentionColor(avg),
                        periodLabel: _periodLabel,
                      ),
                      const SizedBox(height: 14),
                      _CouncilCard(moyenne: avg),
                      const SizedBox(height: 14),
                      _PrintBtn(
                        studentName: session?.fullName ?? '',
                        schoolName: schoolAsync.valueOrNull?.name ?? 'École',
                        rows: rows,
                        avg: avg,
                        period: _period,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ]),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Header + tabs ─────────────────────────────────────────────────────────────
class _BulletinHeader extends StatelessWidget {
  final TabController tab;
  final String? schoolName;
  final String? studentClass;
  const _BulletinHeader(
      {required this.tab, this.schoolName, this.studentClass});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1A0A00), Color(0xFF8B1A00)]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(
                  child: Icon(Icons.receipt_long_rounded,
                      color: _white, size: 20)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bulletins Scolaires',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
              Text(
                  [
                    if (schoolName != null) schoolName!,
                    if (studentClass != null) studentClass!,
                  ].join(' · '),
                  style:
                      const TextStyle(fontSize: 12, color: _muted)),
            ]),
          ]),
        ),
        TabBar(
          controller: tab,
          labelColor: _terra,
          unselectedLabelColor: _muted,
          indicatorColor: _terra,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Trim. 1'),
            Tab(text: 'Trim. 2'),
            Tab(text: 'Trim. 3'),
          ],
        ),
      ]),
    );
  }
}

// ── Student info card ─────────────────────────────────────────────────────────
class _StudentInfoCard extends StatelessWidget {
  final String name;
  final String? classe;
  final String? matricule;
  final String periodLabel;
  const _StudentInfoCard(
      {required this.name,
      this.classe,
      this.matricule,
      required this.periodLabel});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1A0A00), _terra]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_initials,
                  style: const TextStyle(
                      color: _white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  Text(
                    [
                      if (classe != null) classe!,
                      periodLabel,
                    ].join(' · '),
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ]),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(children: [
          _InfoPill('N° Matricule', matricule ?? '—'),
          const SizedBox(width: 10),
          _InfoPill('Classe', classe ?? '—'),
        ]),
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  const _InfoPill(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    color: _muted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: _ink,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

// ── Tableau des notes ─────────────────────────────────────────────────────────
class _GradesTable extends StatelessWidget {
  final List<_BulletinRow> rows;
  const _GradesTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    // Moyenne générale pondérée
    final totalPts = rows.fold(0.0, (s, r) => s + r.moyenne * r.coef);
    final totalCoef = rows.fold(0, (s, r) => s + r.coef);
    final generalAvg = totalCoef > 0 ? totalPts / totalCoef : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: _ink,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: const Row(children: [
                Expanded(
                    flex: 5,
                    child: Text('Matière',
                        style: TextStyle(
                            color: _white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 1,
                    child: Text('Coef',
                        style: TextStyle(
                            color: _white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Note/20',
                        style: TextStyle(
                            color: _white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center)),
              ]),
            ),
            // Lignes
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              final isEven = i % 2 == 0;
              return Container(
                color: isEven
                    ? _bg.withValues(alpha: .5)
                    : _white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            flex: 5,
                            child: Text(r.matiere,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                        Expanded(
                            flex: 1,
                            child: Center(
                                child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                  color: _terra.withValues(alpha: .1),
                                  shape: BoxShape.circle),
                              child: Center(
                                  child: Text('${r.coef}',
                                      style: const TextStyle(
                                          color: _terra,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800))),
                            ))),
                        Expanded(
                            flex: 2,
                            child: Center(
                                child: Text(
                              r.moyenne.toStringAsFixed(1),
                              style: TextStyle(
                                  color: r.moyenne >= 14
                                      ? _green
                                      : r.moyenne >= 10
                                          ? _orange
                                          : _terra,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800),
                            ))),
                      ]),
                      const SizedBox(height: 3),
                      Text(r.appreciation,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: _muted.withValues(alpha: .8),
                              fontStyle: FontStyle.italic)),
                    ]),
              );
            }),
            const Divider(height: 1),
            // Ligne total
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: .04),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(13)),
              ),
              child: Row(children: [
                const Expanded(
                    flex: 5,
                    child: Text('Moyenne Générale',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800))),
                Expanded(
                    flex: 1,
                    child: Center(
                        child: Text('$totalCoef',
                            style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)))),
                Expanded(
                    flex: 2,
                    child: Center(
                        child: Text(generalAvg.toStringAsFixed(2),
                            style: const TextStyle(
                                color: _terra,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)))),
              ]),
            ),
          ]),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double moyenne;
  final String mention;
  final Color mColor;
  final String periodLabel;
  const _SummaryCard(
      {required this.moyenne,
      required this.mention,
      required this.mColor,
      required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mColor.withValues(alpha: .08),
            mColor.withValues(alpha: .02)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mColor.withValues(alpha: .2)),
      ),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: mColor.withValues(alpha: .15),
              shape: BoxShape.circle),
          child: Center(
              child: Text(moyenne.toStringAsFixed(2),
                  style: TextStyle(
                      color: mColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mention : $mention',
              style: TextStyle(
                  color: mColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(periodLabel,
              style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyenne / 20,
              backgroundColor: mColor.withValues(alpha: .1),
              valueColor: AlwaysStoppedAnimation<Color>(mColor),
              minHeight: 5,
            ),
          ),
        ])),
      ]),
    );
  }
}

// ── Council card ──────────────────────────────────────────────────────────────
class _CouncilCard extends StatelessWidget {
  final double moyenne;
  const _CouncilCard({required this.moyenne});

  String get _text {
    if (moyenne >= 16) {
      return 'Excellent trimestre. L\'élève fait preuve d\'une grande rigueur et d\'un investissement remarquable. Encouragé(e) à maintenir ce niveau.';
    }
    if (moyenne >= 14) {
      return 'Très bon trimestre. Des résultats solides qui témoignent d\'un travail sérieux. Peut encore progresser sur certaines matières.';
    }
    if (moyenne >= 12) {
      return 'Bon trimestre dans l\'ensemble. Des efforts supplémentaires permettraient d\'atteindre l\'excellence.';
    }
    if (moyenne >= 10) {
      return 'Résultats passables. Des lacunes sont à combler. Un travail régulier et soutenu est indispensable pour le prochain trimestre.';
    }
    return 'Résultats insuffisants. Un soutien scolaire est fortement recommandé. L\'élève doit impérativement améliorer ses résultats.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.groups_2_rounded, size: 18, color: _gold),
          const SizedBox(width: 8),
          const Text('Appréciation du Conseil de Classe',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _ink)),
        ]),
        const SizedBox(height: 10),
        Text(_text,
            style: const TextStyle(
                color: _muted,
                fontSize: 12.5,
                height: 1.6,
                fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyBulletin extends StatelessWidget {
  const _EmptyBulletin();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFDDCCBB)),
          SizedBox(height: 12),
          Text('Aucune note pour ce semestre',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _ink)),
          SizedBox(height: 6),
          Text(
              'Les notes saisies par vos enseignants\napparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _muted, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Bouton impression ─────────────────────────────────────────────────────────
class _PrintBtn extends StatelessWidget {
  final String studentName;
  final String schoolName;
  final List<_BulletinRow> rows;
  final double avg;
  final String period;

  const _PrintBtn({
    required this.studentName,
    required this.schoolName,
    required this.rows,
    required this.avg,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => PrintService.printBulletin(
          studentName: studentName,
          schoolName: schoolName,
          period: switch (period) {
            'T1' => '1er trimestre',
            'T2' => '2e trimestre',
            _ => '3e trimestre',
          },
          rows: rows
              .map((r) => {
                    'subject': r.matiere,
                    'coef': r.coef,
                    'grade': r.moyenne,
                    'appreciation': r.appreciation,
                  })
              .toList(),
          average: avg,
          mention: _mention(avg),
        ),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Télécharger le bulletin (PDF)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _terra,
          side: const BorderSide(color: _terra),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
