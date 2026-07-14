import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import 'bulletin_pdf.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);
const _orange = Color(0xFFD4540A);

// ── Le calcul du bulletin vit dans core/bulletin/bulletin_math.dart ─────────
//  Il y était autrefois ici, en double, et en FAUX : une moyenne arithmétique
//  de toutes les notes, quand le bulletin congolais pondère la composition.
//  Deux calculs pour une même moyenne, c'est la liste qui affiche 12,00 et le
//  bulletin 12,17. Il n'en reste qu'un, et il est testé.

/// La couleur d'une mention. Le libellé, lui, vient de [mentionOf] — une seule
/// source, partagée avec le bulletin et le PDF.
Color _mentionColor(double moy) {
  if (moy >= 16) return _green;
  if (moy >= 14) return const Color(0xFF0EA5E9);
  if (moy >= 12) return _gold;
  if (moy >= 10) return _orange;
  return _terra;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE — Notes & Bulletins (supervision admin sur toutes les classes)
// ─────────────────────────────────────────────────────────────────────────────
class AdminGradesPage extends ConsumerStatefulWidget {
  const AdminGradesPage({super.key});
  @override
  ConsumerState<AdminGradesPage> createState() => _AdminGradesPageState();
}

class _AdminGradesPageState extends ConsumerState<AdminGradesPage> {
  String? _classId;
  // Null tant que l'école n'est pas chargée : trimestres ou semestres, c'est
  // elle qui décide (cf. SchoolFormat).
  String? _selectedPeriod;
  SbStudent? _bulletinStudent; // fiche bulletin inline (null = liste)

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(schoolFormatProvider);
    final period = _selectedPeriod ?? fmt.periods.first;
    final classesAsync = ref.watch(classesProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
          title: 'Notes & Bulletins',
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => PageScaffold(
          title: 'Notes & Bulletins',
          child: Center(child: Text('Erreur : $e'))),
      data: (classes) {
        if (classes.isNotEmpty && _classId == null) _classId = classes.first.id;
        final selected = classes.isEmpty
            ? null
            : classes.firstWhere((c) => c.id == _classId,
                orElse: () => classes.first);

        // Bulletin inline : remplace la liste par la fiche de l'élève.
        if (_bulletinStudent != null) {
          return _StudentBulletinPage(
            student: _bulletinStudent!,
            className: selected?.name ?? '',
            classId: selected?.id ?? '',
            period: period,
            onBack: () => setState(() => _bulletinStudent = null),
          );
        }

        return PageScaffold(
          title: 'Notes & Bulletins',
          subtitle: 'Consulter les moyennes et bulletins de toutes les classes',
          child: classes.isEmpty
              ? const _Empty(
                  icon: Icons.class_outlined,
                  text: 'Aucune classe. Créez des classes pour suivre les notes.')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _ClassChips(
                    classes: classes,
                    selectedId: _classId,
                    onChanged: (id) => setState(() => _classId = id),
                  ),
                  const SizedBox(height: 12),
                  _PeriodChips(
                    value: period,
                    periods: fmt.periods,
                    labelOf: fmt.periodLabel,
                    onChanged: (p) => setState(() => _selectedPeriod = p),
                  ),
                  const SizedBox(height: 14),
                  if (selected != null)
                    _ClassGradesPanel(
                      key: ValueKey('${selected.id}|$period'),
                      classObj: selected,
                      period: period,
                      onOpen: (s) => setState(() => _bulletinStudent = s),
                    ),
                ]),
        );
      },
    );
  }
}

// ── Tableau des moyennes de la classe ────────────────────────────────────────
class _ClassGradesPanel extends ConsumerWidget {
  final SbClass classObj;
  final String period;
  final void Function(SbStudent) onOpen;
  const _ClassGradesPanel(
      {super.key,
      required this.classObj,
      required this.period,
      required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsByClassProvider(classObj.name));
    // Le MÊME calcul que le bulletin. Deux moyennes qui ne se parlent pas, c'est
    // la liste qui dit 12,00 et le bulletin 12,17 — et un parent qui appelle.
    final bulletinsAsync =
        ref.watch(classBulletinsProvider('${classObj.id}|$period'));

    if (studentsAsync.isLoading || bulletinsAsync.isLoading) {
      return const DataPanel(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final students = studentsAsync.valueOrNull ?? const <SbStudent>[];
    final bulletins = bulletinsAsync.valueOrNull ?? const <String, Bulletin>{};

    if (students.isEmpty) {
      return const _Empty(
          icon: Icons.group_off_rounded,
          text: 'Aucun élève dans cette classe.');
    }

    // Le rang vient du calcul, pas de la position dans la liste : deux élèves
    // ex æquo portent le même rang.
    final sorted = [...students]..sort((a, b) {
        final ba = bulletins[a.id], bb = bulletins[b.id];
        final avgA = (ba == null || ba.isEmpty) ? -1.0 : ba.average;
        final avgB = (bb == null || bb.isEmpty) ? -1.0 : bb.average;
        return avgB.compareTo(avgA);
      });

    final noted =
        students.where((s) => !(bulletins[s.id]?.isEmpty ?? true)).length;

    return DataPanel(
      title: '${classObj.name} — $noted/${students.length} élève(s) noté(s)',
      child: DataTablePanel(
        columns: const ['Rang', 'Élève', 'Moy. générale', 'Mention', ''],
        flex: const [1, 4, 2, 3, 1],
        rows: [
          for (final s in sorted) _row(context, s, bulletins[s.id]),
        ],
      ),
    );
  }

  List<Widget> _row(BuildContext context, SbStudent s, Bulletin? b) {
    final hasGrades = b != null && !b.isEmpty;
    final avg = hasGrades ? b.average : 0.0;
    final c = _mentionColor(avg);
    return [
      Text(hasGrades ? '${b.rank}' : '—',
          style: TextStyle(
              fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
      Row(children: [
        Avatar(name: s.fullName, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(s.fullName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.cInk, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ]),
      hasGrades
          ? Text(avg.toStringAsFixed(2).replaceAll('.', ','),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c))
          : Text('—', style: TextStyle(fontSize: 13, color: context.cMuted)),
      hasGrades
          ? Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(b.mention,
                    style: TextStyle(
                        fontSize: 11, color: c, fontWeight: FontWeight.w700)),
              ),
            )
          : Text('Pas de notes',
              style: TextStyle(fontSize: 11, color: context.cMuted)),
      IconButton(
        icon: Icon(Icons.chevron_right_rounded, size: 20, color: context.cMuted),
        tooltip: 'Voir le bulletin',
        onPressed: () => onOpen(s),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulletin détaillé d'un élève (admin) — réutilise le calcul + impression PDF
// ─────────────────────────────────────────────────────────────────────────────
class _StudentBulletinPage extends ConsumerWidget {
  final SbStudent student;
  final String className;
  final String classId;
  final String period;
  final VoidCallback onBack;
  const _StudentBulletinPage({
    required this.student,
    required this.className,
    required this.classId,
    required this.period,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodLabel = ref.watch(schoolFormatProvider).periodLabel(period);
    final school = ref.watch(schoolProvider).valueOrNull;
    final rules = BulletinRules.fromSchool(school);
    // Les bulletins de TOUTE la classe : sans les autres, cet élève n'a ni rang,
    // ni moyenne de classe, ni premier, ni dernier.
    final bulletinsAsync =
        ref.watch(classBulletinsProvider('$classId|$period'));

    return PageScaffold(
      title: 'Bulletin',
      subtitle: '${student.fullName} · $className · $periodLabel',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(label: 'Retour aux notes', onTap: onBack),
        const SizedBox(height: 14),
        bulletinsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
          ),
          data: (all) {
            final b = all[student.id];

            if (b == null || b.isEmpty) {
              return Column(children: [
                _InfoCard(
                  name: student.fullName,
                  classe: className,
                  matricule: student.matricule,
                  periodLabel: periodLabel,
                ),
                const SizedBox(height: 14),
                const _Empty(
                    icon: Icons.receipt_long_outlined,
                    text: 'Aucune note saisie pour cette période.'),
              ]);
            }

            return Column(children: [
              _InfoCard(
                name: student.fullName,
                classe: className,
                matricule: student.matricule,
                periodLabel: periodLabel,
              ),
              const SizedBox(height: 14),
              _BulletinTable(bulletin: b, rules: rules),
              const SizedBox(height: 14),
              _CouncilCard(bulletin: b),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // Impression DIRECTE : `printing` ouvre la boîte de dialogue
                  // du système. Pas d'export-puis-ouvrir — le bulletin part à
                  // l'imprimante, ou se sauvegarde en PDF, au choix.
                  onPressed: () => printBulletin(
                    school: school,
                    student: student,
                    className: className,
                    periodLabel: periodLabel,
                    bulletin: b,
                    rules: rules,
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Imprimer le bulletin',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _terra,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ]);
          },
        ),
      ]),
    );
  }
}

/// Le tableau du bulletin — celui du papier : le détail des devoirs, la M.C, la
/// composition, le coefficient, le total, la moyenne, le rang, l'observation.
///
/// L'ancien n'affichait qu'une moyenne par matière. Le parent ne pouvait pas
/// voir d'où elle venait — et le prof ne pouvait pas la vérifier.
class _BulletinTable extends StatelessWidget {
  final Bulletin bulletin;
  final BulletinRules rules;
  const _BulletinTable({required this.bulletin, required this.rules});

  static String _n(double? v) =>
      v == null ? '—' : v.toStringAsFixed(2).replaceAll('.', ',');
  static String _rg(int? r) => r == null ? '—' : (r == 1 ? '1er' : '${r}e');

  @override
  Widget build(BuildContext context) {
    final labels = rules.devoirLabels;
    return DataPanel(
      title: 'Notes de la période',
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 42,
          columnSpacing: 18,
          headingTextStyle: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: context.cMuted),
          dataTextStyle: TextStyle(fontSize: 12.5, color: context.cInk),
          columns: [
            const DataColumn(label: Text('Matière')),
            for (final l in labels) DataColumn(label: Text(l), numeric: true),
            const DataColumn(label: Text('M.C'), numeric: true),
            const DataColumn(label: Text('Compo'), numeric: true),
            const DataColumn(label: Text('Coef.'), numeric: true),
            const DataColumn(label: Text('Total'), numeric: true),
            const DataColumn(label: Text('Moy.'), numeric: true),
            const DataColumn(label: Text('RG'), numeric: true),
            const DataColumn(label: Text('Observations')),
          ],
          rows: [
            for (final l in bulletin.lines)
              DataRow(cells: [
                DataCell(Text(l.subject,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                for (final d in l.devoirs) DataCell(Text(_n(d))),
                DataCell(Text(_n(l.mc))),
                DataCell(Text(_n(l.compo))),
                DataCell(Text('${l.coef}')),
                DataCell(Text(_n(l.total))),
                DataCell(Text(_n(l.average),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: (l.average ?? 0) >= 10 ? _green : _terra))),
                DataCell(Text(_rg(l.rank))),
                DataCell(Text(l.appreciation,
                    style: TextStyle(fontSize: 12, color: context.cMuted))),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Le pavé du conseil de classe : ce qui décide du passage en classe supérieure.
class _CouncilCard extends StatelessWidget {
  final Bulletin bulletin;
  const _CouncilCard({required this.bulletin});

  static String _n(double? v) =>
      v == null ? '—' : v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final b = bulletin;
    final ok = b.average >= 10;

    Widget stat(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: TextStyle(fontSize: 12.5, color: context.cMuted)),
            Text(v,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.cInk)),
          ]),
        );

    return DataPanel(
      title: 'Conseil de classe',
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          SizedBox(
            width: 240,
            child: Column(children: [
              stat('Moyenne générale', '${_n(b.average)} / 20'),
              stat('Total / Coef.', '${_n(b.totalPoints)} / ${b.totalCoef}'),
              stat('Rang', '${b.rank ?? '—'} sur ${b.classSize}'),
            ]),
          ),
          SizedBox(
            width: 240,
            child: Column(children: [
              stat('Moyenne de la classe', _n(b.classAverage)),
              stat('Premier', _n(b.bestAverage)),
              stat('Dernier', _n(b.worstAverage)),
            ]),
          ),
          SizedBox(
            width: 240,
            child: Column(children: [
              stat('Absences', '${b.absences}'),
              stat('Retards', '${b.lates}'),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: (ok ? _green : _terra).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (ok ? _green : _terra).withValues(alpha: .3)),
            ),
            child: Column(children: [
              Text(b.decision,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ok ? _green : _terra)),
              const SizedBox(height: 2),
              Text('Mention : ${b.mention}',
                  style: TextStyle(fontSize: 12, color: context.cMuted)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Sous-widgets ─────────────────────────────────────────────────────────────
class _ClassChips extends StatelessWidget {
  final List<SbClass> classes;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  const _ClassChips(
      {required this.classes, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final c in classes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: selectedId == c.id,
                onSelected: (_) => onChanged(c.id),
                selectedColor: _terra.withValues(alpha: .12),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selectedId == c.id ? _terra : muted,
                  fontWeight:
                      selectedId == c.id ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
        ]),
      );
}

// Les périodes viennent de l'école : trimestres au lycée, semestres à
// l'université. Cf. SchoolFormat.
class _PeriodChips extends StatelessWidget {
  final String value;
  final List<String> periods;
  final String Function(String) labelOf;
  final ValueChanged<String> onChanged;
  const _PeriodChips({
    required this.value,
    required this.periods,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final p in periods)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(labelOf(p)),
            selected: value == p,
            onSelected: (_) => onChanged(p),
            selectedColor: _green.withValues(alpha: .12),
            labelStyle: TextStyle(
              fontSize: 12,
              color: value == p ? _green : muted,
              fontWeight: value == p ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  final String name;
  final String classe;
  final String? matricule;
  final String periodLabel;
  const _InfoCard(
      {required this.name,
      required this.classe,
      this.matricule,
      required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Avatar(name: name, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    color: context.cInk, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('$classe · $periodLabel',
                style: TextStyle(color: context.cMuted, fontSize: 11.5)),
            const SizedBox(height: 2),
            Text('Matricule : ${matricule ?? '—'}',
                style: TextStyle(color: context.cMuted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: context.cBorder),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.cMuted)),
        ]),
      );
}
