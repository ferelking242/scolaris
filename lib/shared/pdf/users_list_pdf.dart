import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/sources/remote/supabase_db_source.dart';

const _ink = PdfColor.fromInt(0xFF1A0A00);
const _muted = PdfColor.fromInt(0xFF7A5C44);
const _terra = PdfColor.fromInt(0xFF8B1A00);
const _line = PdfColor.fromInt(0xFFDDCCBB);
const _band = PdfColor.fromInt(0xFFF7F1E8);

/// Construit le même document pour « Imprimer » et « Exporter » — seule la
/// destination change (`layoutPdf` = boîte système imprimer/enregistrer,
/// `sharePdf` = partage/téléchargement direct du fichier). Reprend la liste
/// EXACTE affichée à l'écran (déjà filtrée par rôle/recherche/statut sorti),
/// comme le fait EduNet avec ses boutons Imprimer/Exporter.
Future<pw.Document> _buildUsersListPdf({
  required String title,
  required List<SbUser> users,
}) async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: font, bold: bold);

  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 2),
            pw.Text('${users.length} personne(s)',
                style: const pw.TextStyle(fontSize: 10, color: _muted)),
            pw.SizedBox(height: 12),
          ])
        : pw.SizedBox(height: 8),
    build: (ctx) => [
      pw.TableHelper.fromTextArray(
        headers: const ['Nom', 'Contact', 'Rôle', 'Statut'],
        data: [
          for (final u in users)
            [
              u.fullName,
              u.email.isNotEmpty ? u.email : (u.phone ?? '—'),
              _roleLabel(u.role),
              u.hasExited ? 'Sorti' : (u.isActive ? 'Actif' : 'Bloqué'),
            ],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: _terra),
        cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
        rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: .5))),
        oddRowDecoration: const pw.BoxDecoration(color: _band),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        cellAlignments: const {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerLeft,
        },
      ),
    ],
  ));
  return pdf;
}

String _roleLabel(String role) {
  switch (role) {
    case 'student': return 'Élève';
    case 'parent': return 'Parent';
    default: return role;
  }
}

/// Bouton « Imprimer » — ouvre la boîte système d'impression/enregistrement.
Future<void> printUsersListPdf({required String title, required List<SbUser> users}) async {
  final pdf = await _buildUsersListPdf(title: title, users: users);
  await Printing.layoutPdf(onLayout: (_) => pdf.save(), name: title);
}

/// Bouton « Exporter » — partage/télécharge directement le PDF (pas de boîte
/// de dialogue imprimante), sans dépendance CSV/Excel supplémentaire.
Future<void> exportUsersListPdf({required String title, required List<SbUser> users}) async {
  final pdf = await _buildUsersListPdf(title: title, users: users);
  await Printing.sharePdf(bytes: await pdf.save(), filename: '$title.pdf');
}
