import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/sources/remote/supabase_db_source.dart';

const _terra = PdfColor.fromInt(0xFF8B1A00);
const _gold = PdfColor.fromInt(0xFFC17F24);
const _white = PdfColors.white;

/// Carte élève au format « badge » (inspirée d'EduNet, sans QR ni photo réelle
/// embarquée — juste des initiales, comme l'avatar déjà utilisé partout dans
/// l'app). Un seul document réutilisé pour imprimer et pour télécharger.
Future<pw.Document> _buildStudentCardPdf({
  required SbUser user,
  required SbStudent? student,
  required SbSchool? school,
  required String guardianName,
  required String guardianPhone,
}) async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: font, bold: bold);

  final initials = user.fullName.trim().isEmpty
      ? '?'
      : user.fullName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();

  final pdf = pw.Document();
  pdf.addPage(pw.Page(
    theme: theme,
    pageFormat: const PdfPageFormat(325, 204, marginAll: 0),
    build: (ctx) => pw.Container(
      width: 325,
      height: 204,
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(colors: [_terra, _gold, _terra]),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CARTE ÉLÈVE',
                style: pw.TextStyle(color: _white, fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
            pw.Text(school?.name ?? 'Établissement',
                style: const pw.TextStyle(color: _white, fontSize: 8)),
          ]),
          pw.Text(school?.academicYear ?? '',
              style: const pw.TextStyle(color: _white, fontSize: 8)),
        ]),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColor.fromInt(0x55FFFFFF), thickness: .6),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 62, height: 78,
              decoration: pw.BoxDecoration(
                color: _white,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Center(
                child: pw.Text(initials,
                    style: pw.TextStyle(color: _terra, fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _field('Nom complet', user.fullName),
                _field('Matricule', student?.matricule ?? '—'),
                _field('Classe', student?.classGroup.isNotEmpty == true ? student!.classGroup : '—'),
                _field('Parent/Tuteur', guardianName.isEmpty ? '—' : guardianName),
                _field('Téléphone', guardianPhone.isEmpty ? '—' : guardianPhone),
              ]),
            ),
          ]),
        ),
        pw.Divider(color: PdfColor.fromInt(0x55FFFFFF), thickness: .6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Cachet de l\'établissement',
              style: const pw.TextStyle(color: _white, fontSize: 6.5)),
          pw.Text('Le Directeur', style: const pw.TextStyle(color: _white, fontSize: 6.5)),
        ]),
      ]),
    ),
  ));
  return pdf;
}

pw.Widget _field(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label.toUpperCase(),
            style: pw.TextStyle(color: PdfColor.fromInt(0xCCFFFFFF), fontSize: 5.5, letterSpacing: .8)),
        pw.Text(value, style: pw.TextStyle(color: _white, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
      ]),
    );

Future<void> printStudentCardPdf({
  required SbUser user,
  required SbStudent? student,
  required SbSchool? school,
  required String guardianName,
  required String guardianPhone,
}) async {
  final pdf = await _buildStudentCardPdf(
      user: user, student: student, school: school,
      guardianName: guardianName, guardianPhone: guardianPhone);
  await Printing.layoutPdf(onLayout: (_) => pdf.save(), name: 'Carte élève — ${user.fullName}');
}

Future<void> downloadStudentCardPdf({
  required SbUser user,
  required SbStudent? student,
  required SbSchool? school,
  required String guardianName,
  required String guardianPhone,
}) async {
  final pdf = await _buildStudentCardPdf(
      user: user, student: student, school: school,
      guardianName: guardianName, guardianPhone: guardianPhone);
  await Printing.sharePdf(bytes: await pdf.save(), filename: 'carte-eleve-${user.fullName}.pdf');
}
