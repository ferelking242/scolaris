import 'package:flutter/material.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../pages/bulletin_pdf.dart';

/// La vue d'un bulletin — un DOCUMENT unique (en-tête élève, notes, conseil de
/// classe) plutôt qu'un empilement de cartes séparées : c'est un bulletin
/// qu'on imagine imprimé, pas un tableau de bord.
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
    final b = bulletin;
    final ok = b.average >= 10;
    final accent = ok ? _green : _terra;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── LA feuille : un seul document, sections séparées par des filets
      // fins — pas une pile de cartes grises distinctes.
      Container(
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.cBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(context, accent, ok),
          Divider(height: 1, thickness: 1, color: context.cBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: _sectionLabel(context, Icons.menu_book_rounded, 'Notes de la période'),
          ),
          _table(context),
          const SizedBox(height: 4),
          Divider(height: 1, thickness: 1, color: context.cBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: _sectionLabel(
                context,
                Icons.workspace_premium_rounded,
                frozen ? 'Conseil de classe (figé)' : 'Conseil de classe'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: _council(context, accent, ok),
          ),
        ]),
      ),
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

  Widget _sectionLabel(BuildContext context, IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 14, color: _terra),
          const SizedBox(width: 7),
          Text(text.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                  color: context.cMuted)),
        ],
      );

  /// En-tête du document : identité de l'élève à gauche, verdict en évidence
  /// à droite — les deux infos qu'on cherche en premier sur un bulletin.
  Widget _header(BuildContext context, Color accent, bool ok) {
    final initial = student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: LayoutBuilder(builder: (_, constraints) {
        final narrow = constraints.maxWidth < 460;
        final identity = Row(children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_terra, Color(0xFFB8471F)],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.cInk, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                  '$className · $periodLabel'
                  '${(student.matricule ?? '').isNotEmpty ? ' · ${student.matricule}' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: context.cMuted)),
            ]),
          ),
        ]);

        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: .35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16, color: accent),
            const SizedBox(width: 7),
            Text(bulletin.decision,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: accent)),
          ]),
        );

        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            identity,
            const SizedBox(height: 14),
            badge,
          ]);
        }
        return Row(children: [Expanded(child: identity), badge]);
      }),
    );
  }

  Widget _table(BuildContext context) {
    final labels = rules.devoirLabels;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DataTable(
        headingRowHeight: 38,
        headingRowColor: WidgetStateProperty.all(Colors.transparent),
        dataRowMinHeight: 38,
        dataRowMaxHeight: 44,
        columnSpacing: 20,
        horizontalMargin: 8,
        dividerThickness: 0.6,
        headingTextStyle: TextStyle(
            fontSize: 10.5,
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
    );
  }

  DataRow _row(BuildContext context, BulletinLine l, {required bool zebra}) {
    return DataRow(
      color: zebra
          ? WidgetStateProperty.all(context.cSubtle.withValues(alpha: .4))
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

  /// Le résumé du conseil : des paires libellé/valeur en ligne, séparées par
  /// de simples filets verticaux — comme le pied d'un vrai bulletin papier,
  /// pas des cartes empilées.
  Widget _council(BuildContext context, Color accent, bool ok) {
    final b = bulletin;

    Widget stat(String k, String v, {Color? valueColor}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(k.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                    color: context.cMuted)),
            const SizedBox(height: 4),
            Text(v,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? context.cInk)),
          ],
        );

    final items = [
      stat('Moyenne', '${_n(b.average)} / ${_maxScore.toStringAsFixed(0)}', valueColor: accent),
      stat('Rang', '${b.rank ?? '—'}/${b.classSize}'),
      stat('Moy. classe', _n(b.classAverage)),
      stat('Premier', _n(b.bestAverage)),
      stat('Dernier', _n(b.worstAverage)),
      stat('Absences', '${b.absences}'),
      stat('Retards', '${b.lates}'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 22,
        runSpacing: 14,
        children: items,
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.cBorder)),
        ),
        child: Row(children: [
          Icon(Icons.grade_rounded, size: 15, color: accent),
          const SizedBox(width: 7),
          Text('Mention : ${b.mention}',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cInk)),
          const Spacer(),
          Text('${_n(b.totalPoints)} / ${b.totalCoef} pts',
              style: TextStyle(fontSize: 11.5, color: context.cMuted)),
        ]),
      ),
    ]);
  }
}
