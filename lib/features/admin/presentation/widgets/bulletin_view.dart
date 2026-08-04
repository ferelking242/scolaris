import 'package:flutter/material.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../pages/bulletin_pdf.dart';

/// La vue d'un bulletin — le tableau des matières + le conseil de classe +
/// l'impression.
///
/// **Partagée** entre les deux pages qui montrent un bulletin :
///  • « Notes & Bulletins » — le bulletin *vivant*, recalculé à l'ouverture ;
///  • « Bulletins » (génération) — le bulletin *figé*, relu depuis l'archive.
///
/// Une seule vue, parce qu'un bulletin doit se ressembler partout : c'est le
/// même document, qu'on le prévisualise ou qu'on le ressorte du classeur. Deux
/// rendus divergeraient tôt ou tard.
class BulletinView extends StatelessWidget {
  final SbSchool? school;
  final SbStudent student;
  final String className;
  final String periodLabel;
  final Bulletin bulletin;
  final BulletinRules rules;

  /// « Figé » = ce bulletin vient d'une génération archivée, pas d'un calcul en
  /// direct. On le signale : le rang et la moyenne de la classe sont ceux du
  /// jour de la génération, pas d'aujourd'hui.
  final bool frozen;

  /// Ne servent qu'au modèle DÉTAILLÉ (synthèse annuelle à l'impression) —
  /// `null` : le bloc annuel ne s'affichera simplement pas.
  final String? classId;
  final String? academicYear;
  final String? periodCode;

  const BulletinView({
    super.key,
    required this.school,
    required this.student,
    required this.className,
    required this.periodLabel,
    required this.bulletin,
    required this.rules,
    this.frozen = false,
    this.classId,
    this.academicYear,
    this.periodCode,
  });

  static const _terra = Color(0xFF8B1A00);
  static const _green = Color(0xFF2D6A4F);

  /// Barème d'AFFICHAGE du bulletin = celui du CYCLE de la classe (résolu depuis
  /// l'école). Le calcul interne reste sur 20 (rang, mention, décision) ; on ne
  /// convertit qu'à l'affichage. `_k` = facteur d'échelle (0,5 pour /10, 5 pour
  /// /100, 1 pour /20 → aucune conversion).
  double get _maxScore =>
      school?.formatForCycle(SchoolLevel.fromClassName(className)?.name)
          .maxScore ??
      20;
  double get _k => _maxScore / 20;

  /// Une NOTE, ramenée du calcul interne (/20) au barème du cycle pour l'écran.
  String _n(double? v) =>
      v == null ? '—' : (v * _k).toStringAsFixed(2).replaceAll('.', ',');
  static String _rg(int? r) => r == null ? '—' : (r == 1 ? '1er' : '${r}e');

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _table(context),
      const SizedBox(height: 14),
      _council(context),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          // Impression DIRECTE : `printing` ouvre la boîte de dialogue du
          // système. Pas d'export-puis-ouvrir.
          onPressed: () => printBulletin(
            school: school,
            student: student,
            className: className,
            periodLabel: periodLabel,
            bulletin: bulletin,
            rules: rules,
            classId: classId,
            academicYear: academicYear,
            periodCode: periodCode,
          ),
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('Imprimer le bulletin',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: _terra,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ]);
  }

  Widget _table(BuildContext context) {
    final labels = rules.devoirLabels;
    return DataPanel(
      title: 'Notes de la période',
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          headingRowColor: WidgetStateProperty.all(context.cSubtle),
          dataRowMinHeight: 38,
          dataRowMaxHeight: 44,
          columnSpacing: 20,
          horizontalMargin: 16,
          dividerThickness: 0.6,
          headingTextStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.cMuted,
              letterSpacing: .3),
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
            for (var i = 0; i < bulletin.lines.length; i++)
              _row(context, bulletin.lines[i], zebra: i.isOdd),
          ],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, BulletinLine l, {required bool zebra}) {
    return DataRow(
      color: zebra
          ? WidgetStateProperty.all(context.cSubtle.withValues(alpha: .5))
          : null,
      cells: [
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
      ],
    );
  }

  Widget _council(BuildContext context) {
    final b = bulletin;
    final ok = b.average >= 10;

    Widget stat(String k, String v, {Color? valueColor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: TextStyle(fontSize: 12, color: context.cMuted)),
            Text(v,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? context.cInk)),
          ]),
        );

    Widget group(String label, List<Widget> children) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: context.cMuted)),
            const SizedBox(height: 6),
            ...children,
          ]),
        );

    return DataPanel(
      title: frozen ? 'Conseil de classe (figé)' : 'Conseil de classe',
      child: LayoutBuilder(builder: (_, constraints) {
        final narrow = constraints.maxWidth < 560;
        final groups = [
          group('Résultats', [
            stat('Moyenne générale',
                '${_n(b.average)} / ${_maxScore.toStringAsFixed(0)}',
                valueColor: ok ? _green : _terra),
            stat('Total / Coef.', '${_n(b.totalPoints)} / ${b.totalCoef}'),
            stat('Rang', '${b.rank ?? '—'} sur ${b.classSize}'),
          ]),
          group('Classe', [
            stat('Moyenne de la classe', _n(b.classAverage)),
            stat('Premier', _n(b.bestAverage)),
            stat('Dernier', _n(b.worstAverage)),
          ]),
          group('Assiduité', [
            stat('Absences', '${b.absences}'),
            stat('Retards', '${b.lates}'),
          ]),
        ];
        final decision = Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (ok ? _green : _terra).withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: (ok ? _green : _terra).withValues(alpha: .3)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(b.decision,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ok ? _green : _terra)),
            const SizedBox(height: 2),
            Text('Mention : ${b.mention}',
                style: TextStyle(fontSize: 12, color: context.cMuted)),
          ]),
        );

        if (narrow) {
          return Column(children: [
            for (final g in groups) ...[g, const SizedBox(height: 10)],
            decision,
          ]);
        }
        return Column(children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final g in groups) ...[
                Expanded(child: g),
                const SizedBox(width: 10),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: decision),
        ]);
      }),
    );
  }
}
