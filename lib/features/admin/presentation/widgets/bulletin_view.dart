import 'package:flutter/material.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
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

  const BulletinView({
    super.key,
    required this.school,
    required this.student,
    required this.className,
    required this.periodLabel,
    required this.bulletin,
    required this.rules,
    this.frozen = false,
  });

  static const _terra = Color(0xFF8B1A00);
  static const _green = Color(0xFF2D6A4F);

  static String _n(double? v) =>
      v == null ? '—' : v.toStringAsFixed(2).replaceAll('.', ',');
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
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 42,
          columnSpacing: 18,
          headingTextStyle: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800, color: context.cMuted),
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

  Widget _council(BuildContext context) {
    final b = bulletin;
    final ok = b.average >= 10;

    Widget stat(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: TextStyle(fontSize: 12.5, color: context.cMuted)),
            Text(v,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.cInk)),
          ]),
        );

    return DataPanel(
      title: frozen ? 'Conseil de classe (figé)' : 'Conseil de classe',
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
              border:
                  Border.all(color: (ok ? _green : _terra).withValues(alpha: .3)),
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
