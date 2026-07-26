import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/sources/remote/supabase_db_source.dart';

const _terra = PdfColor.fromInt(0xFF8B1A00);
const _ink = PdfColor.fromInt(0xFF1A0A00);
const _muted = PdfColor.fromInt(0xFF7A5C44);
const _red = PdfColor.fromInt(0xFFDC2626);
const _line = PdfColor.fromInt(0xFFDDCCBB);
const _band = PdfColor.fromInt(0xFFF7F1E8);

/// Rapport d'établissement complet, prêt à imprimer/enregistrer —
/// `Printing.layoutPdf` ouvre la boîte système d'impression/enregistrement,
/// même mécanisme que les reçus de facture (cf. invoice_pdf.dart). C'est ce
/// qui fait un VRAI export, contrairement à un texte CSV à copier-coller.
Future<void> printReportsPdf({
  required SbSchool? school,
  required List<({String name, String level, int count, int capacity})> classRows,
  required ({double collected, double pending, double overdue, double billed}) finances,
  required int studentsCount,
  required int teachersCount,
  required int unassigned,
  // Volets Premium (Max) — null si l'offre ne les débloque pas.
  List<({String period, double billed, double collected})>? trendRows,
  List<MapEntry<String, double>>? lateByClassRows,
  List<({String label, String className, double amount})>? topLateRows,
}) async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: font, bold: bold);
  final fmt = NumberFormat.decimalPattern('fr');
  final df = DateFormat('d MMMM yyyy', 'fr');

  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : pw.SizedBox(height: 8),
    build: (ctx) => [
      // ── En-tête ────────────────────────────────────────────────────────
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(school?.name ?? 'Établissement',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink)),
            if ((school?.city ?? '').isNotEmpty)
              pw.Text(
                  [school?.city, school?.country].where((e) => (e ?? '').isNotEmpty).join(', '),
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(color: _terra, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text('RAPPORT D\'ÉTABLISSEMENT',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Généré le ${df.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ]),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: _line, thickness: 1),
      pw.SizedBox(height: 16),

      // ── Indicateurs clés ───────────────────────────────────────────────
      _sectionTitle('Indicateurs clés'),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        _kpi('Élèves inscrits', '$studentsCount'),
        _kpi('Classes', '${classRows.length}'),
        _kpi('Enseignants', '$teachersCount'),
        _kpi('Sans classe', '$unassigned', color: unassigned > 0 ? _terra : _ink),
      ]),
      pw.SizedBox(height: 18),

      // ── Finances ───────────────────────────────────────────────────────
      _sectionTitle('Finances (scolarité)'),
      pw.SizedBox(height: 8),
      _table(
        headers: const ['Encaissé', 'En attente', 'En retard', 'Total facturé'],
        rows: [[
          '${fmt.format(finances.collected)} F',
          '${fmt.format(finances.pending)} F',
          '${fmt.format(finances.overdue)} F',
          '${fmt.format(finances.billed)} F',
        ]],
      ),
      pw.SizedBox(height: 18),

      // ── Effectifs par classe ──────────────────────────────────────────
      _sectionTitle('Effectifs par classe'),
      pw.SizedBox(height: 8),
      _table(
        headers: const ['Classe', 'Niveau', 'Effectif', 'Capacité'],
        rows: [
          for (final r in classRows) [r.name, r.level, '${r.count}', '${r.capacity}'],
        ],
      ),

      // ── Volets Premium (Max) ──────────────────────────────────────────
      if (trendRows != null && trendRows.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        _sectionTitle('Tendance de recouvrement', premium: true),
        pw.SizedBox(height: 8),
        _table(
          headers: const ['Période', 'Encaissé', 'Facturé', 'Taux'],
          rows: [
            for (final r in trendRows)
              [
                r.period,
                '${fmt.format(r.collected)} F',
                '${fmt.format(r.billed)} F',
                r.billed > 0 ? '${(r.collected / r.billed * 100).toStringAsFixed(0)}%' : '—',
              ],
          ],
        ),
      ],
      if (lateByClassRows != null && lateByClassRows.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        _sectionTitle('Retards par classe', premium: true),
        pw.SizedBox(height: 8),
        _table(
          headers: const ['Classe', 'Montant en retard'],
          rows: [
            for (final r in lateByClassRows) [r.key, '${fmt.format(r.value)} F'],
          ],
          highlightLastCol: true,
        ),
      ],
      if (topLateRows != null && topLateRows.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        _sectionTitle('Top des impayés', premium: true),
        pw.SizedBox(height: 8),
        _table(
          headers: const ['Élève', 'Classe', 'Montant dû'],
          rows: [
            for (final r in topLateRows) [r.label, r.className, '${fmt.format(r.amount)} F'],
          ],
          highlightLastCol: true,
        ),
      ],
    ],
  ));

  await Printing.layoutPdf(
    onLayout: (_) => pdf.save(),
    name: 'Rapport ${school?.name ?? "etablissement"} ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
  );
}

/// Liste des impayés — export dédié pour relancer les familles en retard,
/// utilisable depuis n'importe quelle page de suivi de scolarité (pas
/// réservé à l'offre Max, contrairement au Rapport Premium : c'est une
/// liste de travail, pas une analyse).
Future<void> printLatePayersPdf({
  required SbSchool? school,
  required List<({String name, String classe, String? email, double amount, String? since})> rows,
}) async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: font, bold: bold);
  final fmt = NumberFormat.decimalPattern('fr');
  final df = DateFormat('d MMMM yyyy', 'fr');
  final sorted = rows.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  final total = sorted.fold<double>(0, (a, b) => a + b.amount);

  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(school?.name ?? 'Établissement',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.Text('Liste des impayés',
                style: pw.TextStyle(fontSize: 12, color: _muted)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(color: _red, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text('${sorted.length} élève(s) en retard',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Généré le ${df.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ]),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: _line, thickness: 1),
      pw.SizedBox(height: 16),
      if (sorted.isEmpty)
        pw.Text('Aucun impayé — tout est à jour.',
            style: const pw.TextStyle(fontSize: 11, color: _muted))
      else ...[
        _table(
          headers: const ['Élève', 'Classe', 'Email', 'En retard depuis', 'Montant dû'],
          rows: [
            for (final r in sorted)
              [r.name, r.classe, r.email ?? '—', r.since ?? '—', '${fmt.format(r.amount)} F'],
          ],
          highlightLastCol: true,
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Total dû : ${fmt.format(total)} F',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _red)),
        ),
      ],
    ],
  ));

  await Printing.layoutPdf(
    onLayout: (_) => pdf.save(),
    name: 'Impayes ${school?.name ?? "etablissement"} ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
  );
}

pw.Widget _sectionTitle(String title, {bool premium = false}) => pw.Row(children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink)),
      if (premium) ...[
        pw.SizedBox(width: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF7C3AED), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text('MAX', style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ]);

pw.Widget _kpi(String label, String value, {PdfColor color = _ink}) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: _band, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        ]),
      ),
    );

pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
  bool highlightLastCol = false,
}) {
  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: 0.5),
    columnWidths: {for (var i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth()},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _band),
        children: [
          for (final h in headers)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(children: [
          for (var i = 0; i < row.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(row[i],
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: highlightLastCol && i == row.length - 1 ? _red : _ink,
                      fontWeight: highlightLastCol && i == row.length - 1 ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
        ]),
    ],
  );
}
