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

/// Les 4 modèles disponibles — SOURCE UNIQUE pour la galerie de l'admin
/// (`report_cards_page.dart`) : un nom d'affichage et une description, pour ne
/// pas dupliquer ces libellés entre le PDF et l'UI.
const bulletinTemplates = <String, ({String label, String description})>{
  'standard': (
    label: 'Standard (CSBFE)',
    description: 'Le bulletin classique : devoirs, M.C, compo, conseil de classe.',
  ),
  'detailed': (
    label: 'Détaillé (Emma & Bénie)',
    description: 'Tableau fourni avec profs en clair et synthèse annuelle.',
  ),
  'compact': (
    label: 'Synthèse compacte',
    description: 'Une page dense, sans détail des devoirs — idéal au primaire.',
  ),
  'modern': (
    label: 'Moderne coloré',
    description: 'Mise en couleur avec la teinte de l\'école, moyenne en badge.',
  ),
};

/// Parse `school.accentColor` (hex `#RRGGBB` ou `RRGGBB`) en [PdfColor].
/// `null`/invalide → une teinte terracotta par défaut, cohérente avec la
/// marque de l'app (cf. CLAUDE.md, accents de marque constants).
PdfColor _accentPdfColor(SbSchool? school) {
  final hex = school?.accentColor;
  if (hex == null || hex.isEmpty) return const PdfColor.fromInt(0xFF8B1A00);
  try {
    final clean = hex.replaceFirst('#', '');
    return PdfColor.fromInt(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const PdfColor.fromInt(0xFF8B1A00);
  }
}

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
  String? classId,
  String? academicYear,
  String? periodCode,
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
    classId: classId,
    academicYear: academicYear,
    periodCode: periodCode,
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
  String? classId,
  String? academicYear,
  String? periodCode,
  String? bulletinNumber,
}) async {
  final theme = await _theme();
  final pdf = pw.Document();
  final template = school?.bulletinTemplate ?? 'standard';
  if (template == 'detailed') {
    // La synthèse annuelle a besoin des périodes PRÉCÉDENTES — un appel réseau
    // par période, donc AVANT de construire la page (celle-ci est synchrone).
    final annual = await _annualSummary(
      school: school,
      studentId: student.id,
      classId: classId,
      academicYear: academicYear,
      currentPeriodCode: periodCode,
      bulletin: bulletin,
    );
    pdf.addPage(_detailedBulletinPage(
      theme: theme, school: school, student: student, className: className,
      periodLabel: periodLabel, bulletin: bulletin, rules: rules,
      decision: decision, bulletinNumber: bulletinNumber, annual: annual));
  } else if (template == 'compact') {
    pdf.addPage(_compactBulletinPage(
      theme: theme, school: school, student: student, className: className,
      periodLabel: periodLabel, bulletin: bulletin, rules: rules,
      decision: decision));
  } else if (template == 'modern') {
    pdf.addPage(_modernBulletinPage(
      theme: theme, school: school, student: student, className: className,
      periodLabel: periodLabel, bulletin: bulletin, rules: rules,
      decision: decision, councilComment: councilComment));
  } else {
    pdf.addPage(_bulletinPage(
      theme: theme, school: school, student: student, className: className,
      periodLabel: periodLabel, bulletin: bulletin, rules: rules,
      decision: decision, councilComment: councilComment));
  }
  return pdf.save();
}

/// Un élève à imprimer dans un lot : son bulletin et son identité.
class BulletinToPrint {
  final SbStudent student;
  final String className;
  final Bulletin bulletin;
  /// Classe de l'élève — ne sert qu'au modèle détaillé (synthèse annuelle).
  final String? classId;
  const BulletinToPrint(
      {required this.student, required this.className, required this.bulletin,
      this.classId});
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
  String? academicYear,
  String? periodCode,
}) async {
  if (items.isEmpty) return;
  final theme = await _theme();
  final pdf = pw.Document();
  final template = school?.bulletinTemplate ?? 'standard';
  for (final it in items) {
    if (template == 'detailed') {
      final annual = await _annualSummary(
        school: school,
        studentId: it.student.id,
        classId: it.classId,
        academicYear: academicYear,
        currentPeriodCode: periodCode,
        bulletin: it.bulletin,
      );
      pdf.addPage(_detailedBulletinPage(
        theme: theme, school: school, student: it.student,
        className: it.className, periodLabel: periodLabel,
        bulletin: it.bulletin, rules: rules, annual: annual));
    } else if (template == 'compact') {
      pdf.addPage(_compactBulletinPage(
        theme: theme, school: school, student: it.student,
        className: it.className, periodLabel: periodLabel,
        bulletin: it.bulletin, rules: rules));
    } else if (template == 'modern') {
      pdf.addPage(_modernBulletinPage(
        theme: theme, school: school, student: it.student,
        className: it.className, periodLabel: periodLabel,
        bulletin: it.bulletin, rules: rules));
    } else {
      pdf.addPage(_bulletinPage(
        theme: theme, school: school, student: it.student,
        className: it.className, periodLabel: periodLabel,
        bulletin: it.bulletin, rules: rules));
    }
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

// ═════════════════════════════════════════════════════════════════════════
// MODÈLE DÉTAILLÉ — « Groupe Scolaire Emma et Bénie »
// ═════════════════════════════════════════════════════════════════════════
//
// Un second papier, à côté du premier — pas à sa place. Certaines écoles
// impriment un tableau plus fourni (devoirs nommés, professeur en clair,
// synthèse annuelle) : plutôt que de complexifier `_bulletinPage` avec des
// branches partout, on lui donne un jumeau qui réutilise les mêmes briques
// (thème, échelle, couleurs) sans toucher à l'original.

/// Couleurs propres au modèle détaillé — le bandeau pêche du titre et le
/// bandeau vert de la composition, comme sur le papier d'origine. Restent
/// des couleurs D'IMPRESSION (constantes), pas du thème de l'app : cf. [_ink].
const _peach = PdfColor.fromInt(0xFFF4D9B0);
const _paleGreen = PdfColor.fromInt(0xFFCDE8CB);

/// La moyenne annuelle d'un élève et son rang dans la classe, calculés à
/// partir des bulletins déjà archivés des périodes précédentes — UNIQUEMENT
/// pour la DERNIÈRE période de l'année (cf. [Bulletin.isFinalPeriod]).
class _AnnualSummary {
  /// Moyenne de chaque période disponible, dans l'ordre (`null` = pas encore
  /// de bulletin archivé pour cette période — ne compte pas dans la moyenne).
  final List<double?> periodAverages;
  final double annualAverage;
  final int? rank;
  final int? classSize;
  const _AnnualSummary({
    required this.periodAverages,
    required this.annualAverage,
    this.rank,
    this.classSize,
  });
}

/// Construit la synthèse annuelle — ou `null` si elle ne peut pas être
/// calculée (période non finale, classe/année inconnues, ou périodes
/// introuvables). Ne JAMAIS planter l'impression pour ça : le bloc annuel est
/// un bonus, pas une condition d'impression.
Future<_AnnualSummary?> _annualSummary({
  required SbSchool? school,
  required String studentId,
  required String? classId,
  required String? academicYear,
  required String? currentPeriodCode,
  required Bulletin bulletin,
}) async {
  if (!bulletin.isFinalPeriod) return null;
  if (classId == null || academicYear == null || academicYear.isEmpty) {
    return null;
  }
  // Le cycle de la classe (pour la périodicité — un lycée est en trimestres,
  // le primaire peut être mensuel) : on cherche le NIVEAU de la classe pour
  // résoudre le bon format, sinon on retombe sur le format par défaut.
  final periods = school?.format.periods ?? const ['T1', 'T2', 'T3'];
  if (periods.isEmpty) return null;
  final resolvedCurrent = currentPeriodCode ?? periods.last;

  try {
    // Une requête par période — la classe entière, pour pouvoir classer TOUS
    // les élèves qui ont au moins une période renseignée (pas seulement cet
    // élève : le rang annuel n'a de sens que comparé aux autres).
    final byPeriod = <String, List<SbReportCard>>{};
    for (final p in periods) {
      byPeriod[p] = await SupabaseDbSource.getReportCardsForClass(
          classId, academicYear, p);
    }

    // Moyennes de CET élève, période par période (jusqu'à la période courante
    // incluse — les périodes futures n'existent pas encore).
    final upTo = periods.indexOf(resolvedCurrent);
    final ordered = upTo >= 0 ? periods.sublist(0, upTo + 1) : periods;
    final myAverages = <double?>[
      for (final p in ordered)
        byPeriod[p]
            ?.where((c) => c.studentId == studentId)
            .map((c) => c.generalAverage)
            .firstOrNull,
    ];
    // La période courante n'a pas forcément encore de bulletin ARCHIVÉ (on
    // imprime souvent avant de sauvegarder) : on utilise alors la moyenne du
    // bulletin qu'on est en train d'imprimer.
    if (myAverages.isNotEmpty && myAverages.last == null) {
      myAverages[myAverages.length - 1] = bulletin.average;
    }
    final present = myAverages.whereType<double>().toList();
    if (present.isEmpty) return null;
    final annualAverage = present.reduce((a, b) => a + b) / present.length;

    // Classement annuel : tous les élèves de la classe ayant au moins une
    // période, moyennés sur les périodes qu'ILS ont (même logique que
    // buildBulletins — cf. bulletin_math.dart, rang par position après tri).
    final allStudentIds = <String>{
      for (final p in ordered) ...byPeriod[p]!.map((c) => c.studentId),
    };
    final classAverages = <String, double>{};
    for (final sid in allStudentIds) {
      final vals = [
        for (final p in ordered)
          byPeriod[p]!
              .where((c) => c.studentId == sid)
              .map((c) => c.generalAverage)
              .firstOrNull,
      ].whereType<double>().toList();
      if (vals.isNotEmpty) {
        classAverages[sid] = vals.reduce((a, b) => a + b) / vals.length;
      }
    }
    // Cet élève n'a peut-être pas de ligne archivée pour la période courante :
    // on force sa propre moyenne annuelle déjà calculée ci-dessus.
    classAverages[studentId] = annualAverage;
    final ranked = classAverages.keys.toList()
      ..sort((a, b) => classAverages[b]!.compareTo(classAverages[a]!));
    final rank = ranked.indexOf(studentId) + 1;

    return _AnnualSummary(
      periodAverages: myAverages,
      annualAverage: _r2Annual(annualAverage),
      rank: rank > 0 ? rank : null,
      classSize: ranked.length,
    );
  } catch (_) {
    // Un souci réseau ne doit jamais empêcher d'imprimer LE reste du bulletin.
    return null;
  }
}

double _r2Annual(double v) => (v * 100).round() / 100;

/// La page du modèle détaillé.
pw.Page _detailedBulletinPage({
  required pw.ThemeData theme,
  required SbSchool? school,
  required SbStudent student,
  required String className,
  required String periodLabel,
  required Bulletin bulletin,
  required BulletinRules rules,
  String? decision,
  String? bulletinNumber,
  _AnnualSummary? annual,
}) {
  final maxScore = school
          ?.formatForCycle(SchoolLevel.fromClassName(className)?.name)
          .maxScore ??
      20;
  final k = maxScore / 20;
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 20),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _detailedHeader(school, className, periodLabel, bulletinNumber, student),
        pw.SizedBox(height: 10),
        _detailedTable(bulletin, rules, maxScore, k),
        pw.SizedBox(height: 8),
        _detailedFooter(bulletin, decision, school, annual, maxScore, k),
      ],
    ),
  );
}

// ── En-tête du modèle détaillé ───────────────────────────────────────────────
pw.Widget _detailedHeader(SbSchool? school, String className, String periodLabel,
    String? bulletinNumber, SbStudent student) {
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
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.Text('DIRECTION GENERALE',
                  style: const pw.TextStyle(fontSize: 8, color: _grey)),
              pw.Text('DIRECTION DES ETUDES',
                  style: const pw.TextStyle(fontSize: 8, color: _grey)),
              if (school?.city != null)
                pw.Text('Tél : —  · ${school!.city}',
                    style: const pw.TextStyle(fontSize: 8, color: _grey)),
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
            pw.SizedBox(height: 6),
            pw.Text('Classe : $className',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 10),
    // Bandeau du numéro — pêche, comme sur le papier d'origine.
    pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: const pw.BoxDecoration(color: _peach),
      child: pw.Text('BULLETIN DE NOTES N° : ${bulletinNumber ?? ''}',
          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
    ),
    // Bandeau de la composition — vert.
    pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(color: _paleGreen),
      child: pw.Text('Composition du : ${periodLabel.toUpperCase()}',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
    ),
    pw.SizedBox(height: 8),
    pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Text('NOM ET PRENOM : ${student.fullName.toUpperCase()}',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
    ),
  ]);
}

// ── Le tableau du modèle détaillé ────────────────────────────────────────────
pw.Widget _detailedTable(Bulletin b, BulletinRules rules, double maxScore, double k) {
  String s(double? v) => _n(v == null ? null : v * k);

  // Les 3 devoirs ont un nom FIXE dans ce modèle (papier d'origine) ; pour tout
  // autre nombre de devoirs, on retombe sur les libellés génériques de l'école
  // plutôt que de planter.
  final devoirHeaders = rules.devoirs == 3
      ? const ['Devoir de Classe', 'Devoir de Maison', 'Devoir Départ.']
      : rules.devoirLabels;

  pw.Widget cell(String t, {bool head = false, pw.Alignment? align, double size = 7.5}) =>
      pw.Container(
        alignment: align ?? pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        color: head ? _head : null,
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: head ? 7 : size,
                fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  final nDevoirCols = devoirHeaders.length;
  // N° | Matières | devoirs… | Compo | Coef | Pondérations | Profs | Appréciations | Signature
  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: .5),
    columnWidths: {
      0: const pw.FlexColumnWidth(.5), // N°
      1: const pw.FlexColumnWidth(2.6), // Matières
      for (var i = 0; i < nDevoirCols; i++) 2 + i: const pw.FlexColumnWidth(1),
      2 + nDevoirCols: const pw.FlexColumnWidth(1), // Compo
      3 + nDevoirCols: const pw.FlexColumnWidth(.7), // Coef
      4 + nDevoirCols: const pw.FlexColumnWidth(1), // Pondérations
      5 + nDevoirCols: const pw.FlexColumnWidth(1.6), // Profs
      6 + nDevoirCols: const pw.FlexColumnWidth(1.6), // Appréciations
      7 + nDevoirCols: const pw.FlexColumnWidth(1.6), // Signature
    },
    children: [
      pw.TableRow(children: [
        cell('N°', head: true),
        cell('Matières', head: true, align: pw.Alignment.centerLeft),
        for (final d in devoirHeaders) cell(d, head: true),
        cell('Compo', head: true),
        cell('Coef', head: true),
        cell('Pondérations', head: true),
        cell('Noms des Profs', head: true),
        cell('Appréciations', head: true),
        cell('Signature des\nprofesseurs', head: true),
      ]),
      for (var i = 0; i < b.lines.length; i++)
        pw.TableRow(children: [
          cell('${i + 1}'),
          cell(b.lines[i].subject, align: pw.Alignment.centerLeft, size: 8),
          for (var d = 0; d < nDevoirCols; d++)
            cell(s(d < b.lines[i].devoirs.length ? b.lines[i].devoirs[d] : null)),
          cell(s(b.lines[i].compo)),
          cell('${b.lines[i].coef}'),
          cell(s(b.lines[i].total)),
          cell(b.lines[i].teacherName ?? '', size: 7),
          cell(b.lines[i].appreciation, size: 7),
          cell(''),
        ]),
      // Total général : Σ Coef et Σ Pondérations.
      pw.TableRow(children: [
        cell(''),
        cell('Total Général', head: true, align: pw.Alignment.centerLeft),
        for (var i = 0; i < nDevoirCols; i++) cell(''),
        cell(''),
        cell('${b.totalCoef}', head: true),
        cell(s(b.totalPoints), head: true),
        cell(''),
        cell(''),
        cell(''),
      ]),
      // Moyenne trimestrielle — ligne SÉPARÉE (pas fusionnée avec le total).
      pw.TableRow(children: [
        cell(''),
        cell('Moyenne Trimestrielle', head: true, align: pw.Alignment.centerLeft),
        for (var i = 0; i < nDevoirCols; i++) cell(''),
        cell(''),
        cell(''),
        cell(s(b.average), head: true),
        cell(''),
        cell(''),
        cell(''),
      ]),
    ],
  );
}

// ── Bas de page du modèle détaillé ───────────────────────────────────────────
pw.Widget _detailedFooter(Bulletin b, String? decision, SbSchool? school,
    _AnnualSummary? annual, double maxScore, double k) {
  String s(double? v) => _n(v == null ? null : v * k);
  final today = DateFormat('d MMMM yyyy', 'fr').format(DateTime.now());

  pw.Widget signatureBox(String title) => pw.Expanded(
        child: pw.Container(
          height: 70,
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      );

  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
    // ── Synthèse annuelle — uniquement à la dernière période. ────────────────
    if (b.isFinalPeriod && annual != null) ...[
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('SYNTHÈSE ANNUELLE',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Row(children: [
            for (var i = 0; i < 3; i++)
              pw.Expanded(
                child: pw.Text(
                  'Moyenne ${i == 0 ? "1er" : i == 1 ? "2e" : "3e"} Tr : '
                  '${i < annual.periodAverages.length ? s(annual.periodAverages[i]) : '—'}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(
              child: pw.Text(
                'TOTAL : '
                '${s(annual.periodAverages.whereType<double>().fold<double>(0.0, (a, b2) => a + b2))} '
                '../3',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Expanded(
              child: pw.Text('Moyenne annuelle : ${s(annual.annualAverage)}',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              child: pw.Text(
                  'Classement Annuel ${_rg(annual.rank)} Sur ${annual.classSize ?? ''}',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ]),
          pw.SizedBox(height: 4),
          pw.Text(
              'Décision du conseil de fin d\'année : ${decision ?? b.decision}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      pw.SizedBox(height: 8),
    ],
    pw.Text('Fait à ${school?.city ?? ''}, le $today',
        style: const pw.TextStyle(fontSize: 8, color: _grey)),
    pw.SizedBox(height: 6),
    pw.Row(children: [
      signatureBox('Directeur des Études'),
      pw.SizedBox(width: 8),
      signatureBox('Appréciation du Directeur Général'),
    ]),
  ]);
}

// ═════════════════════════════════════════════════════════════════════════
// MODÈLE COMPACT — « Synthèse compacte », une page dense sans détail des devoirs
// ═════════════════════════════════════════════════════════════════════════
//
// Pensé pour un bulletin mensuel de primaire : pas de M.C/Compo détaillé, pas
// de conseil sur trois colonnes — juste l'essentiel, sur une fraction de page.

pw.Page _compactBulletinPage({
  required pw.ThemeData theme,
  required SbSchool? school,
  required SbStudent student,
  required String className,
  required String periodLabel,
  required Bulletin bulletin,
  required BulletinRules rules,
  String? decision,
}) {
  final year = school?.academicYear ?? '';
  final maxScore = school
          ?.formatForCycle(SchoolLevel.fromClassName(className)?.name)
          .maxScore ??
      20;
  final k = maxScore / 20;
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _compactHeader(school, student, className, periodLabel, year),
        pw.SizedBox(height: 10),
        _compactTable(bulletin, maxScore, k),
        pw.SizedBox(height: 10),
        _compactSummary(bulletin, decision, maxScore, k),
      ],
    ),
  );
}

/// Bandeau unique : école + période sur une ligne, identité de l'élève sur
/// l'autre — pas de boîte séparée, tout est plat et dense.
pw.Widget _compactHeader(SbSchool? school, SbStudent student, String className,
    String periodLabel, String year) {
  return pw.Column(children: [
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(school?.name.toUpperCase() ?? 'ÉTABLISSEMENT',
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
        pw.Text(
            'BULLETIN — ${periodLabel.toUpperCase()}'
            '${year.isNotEmpty ? ' · $year' : ''}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    ),
    pw.SizedBox(height: 4),
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(color: _head),
      child: pw.Text(
          '${student.fullName} · ${student.matricule ?? '—'} · Classe $className',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ),
  ]);
}

/// Le tableau réduit : Matière | Coef | Moyenne | Rang | Appréciation.
pw.Widget _compactTable(Bulletin b, double maxScore, double k) {
  String s(double? v) => _n(v == null ? null : v * k);
  final sur = 'sur ${maxScore.toStringAsFixed(0)}';
  pw.Widget cell(String t, {bool head = false, pw.Alignment? align, double size = 8.5}) =>
      pw.Container(
        alignment: align ?? pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        color: head ? _head : null,
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: head ? 8 : size,
                fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: .5),
    columnWidths: const {
      0: pw.FlexColumnWidth(3.4),
      1: pw.FlexColumnWidth(.9),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(.9),
      4: pw.FlexColumnWidth(2.6),
    },
    children: [
      pw.TableRow(children: [
        cell('Matières', head: true, align: pw.Alignment.centerLeft),
        cell('Coef', head: true),
        cell('Moyenne\n$sur', head: true),
        cell('Rang', head: true),
        cell('Appréciation', head: true),
      ]),
      for (final l in b.lines)
        pw.TableRow(children: [
          cell(l.subject, align: pw.Alignment.centerLeft),
          cell('${l.coef}'),
          cell(s(l.average)),
          cell(_rg(l.rank)),
          cell(l.appreciation, size: 8),
        ]),
    ],
  );
}

/// Une seule ligne de synthèse : moyenne générale, rang, mention, décision.
pw.Widget _compactSummary(Bulletin b, String? decision, double maxScore, double k) {
  String s(double? v) => _n(v == null ? null : v * k);
  pw.Widget item(String label, String value) => pw.Expanded(
        child: pw.Column(children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    decoration: pw.BoxDecoration(
        color: _head, border: pw.Border.all(color: _line)),
    child: pw.Row(children: [
      item('Moyenne générale', '${s(b.average)} / ${maxScore.toStringAsFixed(0)}'),
      item('Rang', '${_rg(b.rank)} / ${b.classSize}'),
      item('Mention', b.mention),
      item('Décision', decision ?? b.decision),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// MODÈLE MODERNE — « Moderne coloré », habillé de la teinte de l'école
// ═════════════════════════════════════════════════════════════════════════
//
// Même colonnes que le modèle standard, mais bandeaux et en-tête de tableau
// prennent la couleur d'accent de l'école (cf. [_accentPdfColor]) — et la
// moyenne générale devient un badge, comme sur l'écran (cf. bulletin_view.dart).

pw.Page _modernBulletinPage({
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
  final accent = _accentPdfColor(school);
  final devoirLabels = rules.devoirLabels;
  final year = school?.academicYear ?? '';
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
        _modernHeader(school, student, className, periodLabel, year, accent),
        pw.SizedBox(height: 12),
        _modernTable(bulletin, devoirLabels, maxScore, k, accent),
        pw.SizedBox(height: 12),
        _modernSummary(bulletin, decision, councilComment, school, maxScore, k, accent),
      ],
    ),
  );
}

/// Bandeau coloré (accent de l'école) portant le nom de l'établissement et la
/// période, puis un bloc identité aux coins arrondis.
pw.Widget _modernHeader(SbSchool? school, SbStudent student, String className,
    String periodLabel, String year, PdfColor accent) {
  return pw.Column(children: [
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(school?.name.toUpperCase() ?? 'ÉTABLISSEMENT',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            if (school?.city != null)
              pw.Text(school!.city!,
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('BULLETIN DE NOTES',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text(
                '${periodLabel.toUpperCase()}${year.isNotEmpty ? ' · $year' : ''}',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
          ]),
        ],
      ),
    ),
    pw.SizedBox(height: 10),
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _head,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Text(
          '${student.fullName} · ${student.matricule ?? '—'} · Classe $className',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
    ),
  ]);
}

/// Même colonnes que le tableau standard, en-tête et lignes alternées teintées.
pw.Widget _modernTable(
    Bulletin b, List<String> devoirLabels, double maxScore, double k, PdfColor accent) {
  String s(double? v) => _n(v == null ? null : v * k);
  final sur = 'sur ${maxScore.toStringAsFixed(0)}';
  // Teinte pâle (mélange à 90% blanc) pour l'alternance de lignes du tableau.
  final accentTint = PdfColor(
    accent.red + (1 - accent.red) * .9,
    accent.green + (1 - accent.green) * .9,
    accent.blue + (1 - accent.blue) * .9,
  );
  pw.Widget cell(String t,
          {bool head = false, pw.Alignment? align, double size = 8,
          PdfColor? bg}) =>
      pw.Container(
        alignment: align ?? pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        color: head ? accent : bg,
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: head ? 7.5 : size,
                color: head ? PdfColors.white : _ink,
                fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: .5),
    columnWidths: {
      0: const pw.FlexColumnWidth(3.2),
      for (var i = 0; i < devoirLabels.length; i++)
        i + 1: const pw.FlexColumnWidth(1),
      devoirLabels.length + 1: const pw.FlexColumnWidth(1),
      devoirLabels.length + 2: const pw.FlexColumnWidth(1),
      devoirLabels.length + 3: const pw.FlexColumnWidth(.7),
      devoirLabels.length + 4: const pw.FlexColumnWidth(1),
      devoirLabels.length + 5: const pw.FlexColumnWidth(1),
      devoirLabels.length + 6: const pw.FlexColumnWidth(.8),
      devoirLabels.length + 7: const pw.FlexColumnWidth(1.8),
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
      for (var i = 0; i < b.lines.length; i++)
        pw.TableRow(children: [
          for (final w in [
            cell(b.lines[i].subject, align: pw.Alignment.centerLeft, size: 8.5,
                bg: i.isOdd ? accentTint : null),
            for (final d in b.lines[i].devoirs)
              cell(s(d), bg: i.isOdd ? accentTint : null),
            cell(s(b.lines[i].mc), bg: i.isOdd ? accentTint : null),
            cell(s(b.lines[i].compo), bg: i.isOdd ? accentTint : null),
            cell('${b.lines[i].coef}', bg: i.isOdd ? accentTint : null),
            cell(s(b.lines[i].total), bg: i.isOdd ? accentTint : null),
            cell(s(b.lines[i].average), bg: i.isOdd ? accentTint : null),
            cell(_rg(b.lines[i].rank), bg: i.isOdd ? accentTint : null),
            cell(b.lines[i].appreciation, size: 7.5, bg: i.isOdd ? accentTint : null),
          ])
            w,
        ]),
    ],
  );
}

/// Le conseil de classe, avec une grosse pastille colorée pour la moyenne
/// générale — même esprit que le badge de `bulletin_view.dart` à l'écran.
pw.Widget _modernSummary(Bulletin b, String? decision, String? comment,
    SbSchool? school, double maxScore, double k, PdfColor accent) {
  String s(double? v) => _n(v == null ? null : v * k);
  final today = DateFormat('d MMMM yyyy', 'fr').format(DateTime.now());

  pw.Widget box(String title, List<pw.Widget> children, {int flex = 1}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Container(
          height: 130,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
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

  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    box('DISCIPLINE', [
      line('Absences', '${b.absences}'),
      line('Retards', '${b.lates}'),
    ]),
    pw.SizedBox(width: 6),
    // Le badge : un cercle coloré, la moyenne au centre — la grosse pastille.
    pw.Expanded(
      flex: 2,
      child: pw.Container(
        height: 130,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(children: [
          pw.Text('MOYENNE GÉNÉRALE',
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 6),
          pw.Container(
            width: 62,
            height: 62,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(31)),
            ),
            child: pw.Text(s(b.average),
                style: pw.TextStyle(
                    fontSize: 15, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
          pw.SizedBox(height: 6),
          pw.Text('${_rg(b.rank)} / ${b.classSize} · ${b.mention}',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ]),
      ),
    ),
    pw.SizedBox(width: 6),
    box('DÉCISION DU CONSEIL', [
      pw.Center(
        child: pw.Text(decision ?? b.decision,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
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
