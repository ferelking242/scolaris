/// Le bulletin **papier** : A4, imprimable, tel que l'école le délivre.
///
/// Ce n'est pas une capture d'écran de l'app. C'est le document officiel que le
/// parent emporte et que le proviseur signe — même structure que celui du
/// Complexe Scolaire Bilingue Félix Éboué : en-tête, tableau des matières avec
/// le détail des devoirs, moyennes essentielles, conseil de classe, visa.
///
/// `printing` ouvre la boîte de dialogue d'impression du système (Windows,
/// Android, iOS, web) : le bulletin part directement à l'imprimante, ou se
/// sauvegarde en PDF. Rien à installer côté école.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../shared/data/features_catalog.dart';

/// Le document « papier » reste en noir sur blanc, volontairement : il sera
/// photocopié, tamponné, rangé dans un classeur. Les couleurs de l'app n'ont
/// rien à y faire.
const _ink = PdfColors.black;
const _grey = PdfColors.grey700;
const _line = PdfColors.grey400;
const _head = PdfColors.grey200;

String _n(double? v) => v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

/// Le rang, à la congolaise : 1ᵉʳ, 2ᵉ, 3ᵉ…
String _rg(int? r) => r == null ? '' : (r == 1 ? '1er' : '${r}e');

/// Imprime (ou exporte) le bulletin d'un élève.
///
/// [logo] : les octets du logo de l'école, s'il en a un. On ne le télécharge pas
/// ici : un appel réseau au moment d'imprimer, c'est une impression qui échoue
/// quand la connexion tombe.
Future<void> printBulletin({
  required SbSchool? school,
  required SbStudent student,
  required String className,
  required String periodLabel,
  required Bulletin bulletin,
  required BulletinRules rules,
  String? decision,
  String? councilComment,
}) async {
  final doc = await buildBulletinPdf(
    school: school,
    student: student,
    className: className,
    periodLabel: periodLabel,
    bulletin: bulletin,
    rules: rules,
    decision: decision,
    councilComment: councilComment,
  );
  await Printing.layoutPdf(
    onLayout: (_) => doc,
    name: 'Bulletin ${student.fullName} — $periodLabel',
  );
}

Future<Uint8List> buildBulletinPdf({
  required SbSchool? school,
  required SbStudent student,
  required String className,
  required String periodLabel,
  required Bulletin bulletin,
  required BulletinRules rules,
  String? decision,
  String? councilComment,
}) async {
  final theme = await _theme();
  final pdf = pw.Document();
  pdf.addPage(_bulletinPage(
    theme: theme, school: school, student: student, className: className,
    periodLabel: periodLabel, bulletin: bulletin, rules: rules,
    decision: decision, councilComment: councilComment));
  return pdf.save();
}

/// Un élève à imprimer dans un lot : son bulletin et son identité.
class BulletinToPrint {
  final SbStudent student;
  final String className;
  final Bulletin bulletin;
  const BulletinToPrint(
      {required this.student, required this.className, required this.bulletin});
}

/// **Tous les bulletins d'une classe en un seul document** — une page par élève.
///
/// L'impression groupée : au lieu d'ouvrir trente fois la boîte d'impression, on
/// bâtit un PDF unique et on l'imprime d'un geste. La police n'est chargée
/// qu'une fois, partagée par toutes les pages.
Future<void> printClassBulletins({
  required SbSchool? school,
  required String periodLabel,
  required BulletinRules rules,
  required List<BulletinToPrint> items,
}) async {
  if (items.isEmpty) return;
  final theme = await _theme();
  final pdf = pw.Document();
  for (final it in items) {
    pdf.addPage(_bulletinPage(
      theme: theme, school: school, student: it.student,
      className: it.className, periodLabel: periodLabel,
      bulletin: it.bulletin, rules: rules));
  }
  final bytes = await pdf.save();
  await Printing.layoutPdf(
    onLayout: (_) => bytes,
    name: 'Bulletins ${items.first.className} — $periodLabel',
  );
}

/// Une police qui porte les accents. Celle par défaut de `pdf` n'a pas « é » ni
/// « É » : « Éducation Civique » deviendrait « ducation Civique ».
Future<pw.ThemeData> _theme() async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  return pw.ThemeData.withFont(base: font, bold: bold);
}

/// La page d'un bulletin. Le même rendu pour l'impression unique et groupée —
/// un bulletin doit se ressembler partout.
pw.Page _bulletinPage({
  required pw.ThemeData theme,
  required SbSchool? school,
  required SbStudent student,
  required String className,
  required String periodLabel,
  required Bulletin bulletin,
  required BulletinRules rules,
  String? decision,
  String? councilComment,
}) {
  final devoirLabels = rules.devoirLabels;
  final year = school?.academicYear ?? '';
  // Barème d'affichage = celui du CYCLE de la classe. Le calcul reste sur 20 ;
  // `k` convertit à l'affichage (0,5 → /10, 5 → /100, 1 → /20 inchangé).
  final maxScore = school
          ?.formatForCycle(SchoolLevel.fromClassName(className)?.name)
          .maxScore ??
      20;
  final k = maxScore / 20;
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(school, periodLabel, year),
        pw.SizedBox(height: 14),
        _identity(student, className),
        pw.SizedBox(height: 10),
        _table(bulletin, devoirLabels, maxScore, k),
        pw.SizedBox(height: 12),
        _council(bulletin, decision, councilComment, school, maxScore, k),
      ],
    ),
  );
}

// ── En-tête : l'école à gauche, la République à droite ───────────────────────
pw.Widget _header(SbSchool? school, String periodLabel, String year) {
  return pw.Column(children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(school?.name.toUpperCase() ?? 'ÉTABLISSEMENT',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink)),
              if (school?.city != null)
                pw.Text(school!.city!,
                    style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
              if (school?.code != null)
                pw.Text('Code : ${school!.code}',
                    style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('République du Congo',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text('Unité – Travail – Progrès',
                style: pw.TextStyle(
                    fontSize: 8.5, color: _grey, fontStyle: pw.FontStyle.italic)),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 12),
    pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
      child: pw.Column(children: [
        pw.Text('BULLETIN DE NOTES — ${periodLabel.toUpperCase()}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        if (year.isNotEmpty)
          pw.Text('Année scolaire : $year',
              style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ]),
    ),
  ]);
}

// ── L'élève ──────────────────────────────────────────────────────────────────
pw.Widget _identity(SbStudent student, String className) {
  pw.Widget row(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(children: [
          pw.SizedBox(
              width: 110,
              child: pw.Text(k,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold))),
          pw.Text(': $v', style: const pw.TextStyle(fontSize: 9)),
        ]),
      );

  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      row('Matricule', student.matricule ?? '—'),
      row('Nom et prénom', student.fullName),
      row('Classe', className),
    ]),
  );
}

// ── Le tableau des matières ──────────────────────────────────────────────────
pw.Widget _table(Bulletin b, List<String> devoirLabels, double maxScore, double k) {
  // Une NOTE, ramenée du calcul interne (/20) au barème du cycle.
  String s(double? v) => _n(v == null ? null : v * k);
  final sur = 'sur ${maxScore.toStringAsFixed(0)}';
  pw.Widget cell(String t, {bool head = false, pw.Alignment? align, double size = 8}) =>
      pw.Container(
        alignment: align ?? pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        color: head ? _head : null,
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: head ? 7.5 : size,
                fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: .5),
    columnWidths: {
      0: const pw.FlexColumnWidth(3.2), // Matière
      for (var i = 0; i < devoirLabels.length; i++)
        i + 1: const pw.FlexColumnWidth(1),
      devoirLabels.length + 1: const pw.FlexColumnWidth(1), // M.C
      devoirLabels.length + 2: const pw.FlexColumnWidth(1), // Compo
      devoirLabels.length + 3: const pw.FlexColumnWidth(.7), // Coef
      devoirLabels.length + 4: const pw.FlexColumnWidth(1), // Total
      devoirLabels.length + 5: const pw.FlexColumnWidth(1), // Moy
      devoirLabels.length + 6: const pw.FlexColumnWidth(.8), // RG
      devoirLabels.length + 7: const pw.FlexColumnWidth(1.8), // Observations
    },
    children: [
      pw.TableRow(children: [
        cell('Matières', head: true, align: pw.Alignment.centerLeft),
        for (final d in devoirLabels) cell('$d\n$sur', head: true),
        cell('M.C\n$sur', head: true),
        cell('Compo\n$sur', head: true),
        cell('Coef.', head: true),
        cell('Total', head: true),
        cell('Moy\n$sur', head: true),
        cell('RG', head: true),
        cell('Observations', head: true),
      ]),
      for (final l in b.lines)
        pw.TableRow(children: [
          cell(l.subject, align: pw.Alignment.centerLeft, size: 8.5),
          for (final d in l.devoirs) cell(s(d)),
          cell(s(l.mc)),
          cell(s(l.compo)),
          cell('${l.coef}'),
          cell(s(l.total)),
          cell(s(l.average)),
          cell(_rg(l.rank)),
          cell(l.appreciation, size: 7.5),
        ]),
      // La ligne de synthèse — « MOYENNES ESSENTIELLES » du bulletin papier.
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _head),
        children: [
          cell('RÉSULTAT DU TRIMESTRE',
              head: true, align: pw.Alignment.centerLeft),
          for (var i = 0; i < devoirLabels.length + 1; i++) cell(''),
          cell('Total', head: true),
          cell('${b.totalCoef}', head: true),
          cell(s(b.totalPoints), head: true),
          cell(s(b.average), head: true),
          cell(_rg(b.rank), head: true),
          cell(b.mention, head: true),
        ],
      ),
    ],
  );
}

// ── Le conseil de classe ─────────────────────────────────────────────────────
pw.Widget _council(
    Bulletin b, String? decision, String? comment, SbSchool? school,
    double maxScore, double k) {
  // Une NOTE, ramenée du calcul interne (/20) au barème du cycle.
  String s(double? v) => _n(v == null ? null : v * k);
  pw.Widget box(String title, List<pw.Widget> children, {int flex = 1}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Container(
          height: 130,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ...children,
            ],
          ),
        ),
      );

  pw.Widget line(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(k, style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
          pw.Text(v,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  final today = DateFormat('d MMMM yyyy', 'fr').format(DateTime.now());

  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    box('DISCIPLINE', [
      line('Absences', '${b.absences}'),
      line('Retards', '${b.lates}'),
    ]),
    pw.SizedBox(width: 6),
    box('RÉSULTAT', [
      line('Rang', '${_rg(b.rank)} / ${b.classSize}'),
      line('Moyenne', '${s(b.average)} / ${maxScore.toStringAsFixed(0)}'),
      line('Moy. classe', s(b.classAverage)),
      line('Premier', s(b.bestAverage)),
      line('Dernier', s(b.worstAverage)),
    ], flex: 2),
    pw.SizedBox(width: 6),
    box('DÉCISION DU CONSEIL', [
      pw.Center(
        child: pw.Text(decision ?? b.decision,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Text('Mention : ${b.mention}',
            style: const pw.TextStyle(fontSize: 9)),
      ),
      if (comment != null && comment.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Center(
            child: pw.Text(comment,
                style: pw.TextStyle(
                    fontSize: 9, fontStyle: pw.FontStyle.italic))),
      ],
      pw.Spacer(),
      pw.Text('${school?.city ?? ''}, le $today',
          style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      pw.SizedBox(height: 2),
      pw.Text('Visa du Chef d\'établissement',
          style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
    ], flex: 2),
  ]);
}
