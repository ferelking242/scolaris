// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../data/supabase_db_types.dart';

class PrintService {
  static void printReceipt({
    required SbInvoiceForPrint invoice,
    required String schoolName,
    String? schoolAddress,
    String? schoolPhone,
    String? schoolEmail,
    String? cashierName,
  }) {
    final html_ = _buildReceiptHtml(
      invoice: invoice,
      schoolName: schoolName,
      schoolAddress: schoolAddress,
      schoolPhone: schoolPhone,
      schoolEmail: schoolEmail,
      cashierName: cashierName,
    );
    _triggerPrint(html_);
  }

  static void printStudentList({
    required String className,
    required List<Map<String, String>> students,
    String? schoolName,
    String? teacherName,
  }) {
    final rows = students.map((s) => '''
      <tr>
        <td>${s['matricule'] ?? ''}</td>
        <td>${s['name'] ?? ''}</td>
        <td>${s['class'] ?? ''}</td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
      </tr>
    ''').join();

    final html_ = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Liste — $className</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; font-size: 12px; }
    h2 { color: #8B1A00; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: left; }
    th { background: #f5eee6; color: #8B1A00; font-weight: bold; }
    @media print { button { display: none; } }
  </style>
</head>
<body>
  <h2>${schoolName ?? 'École Scolaris'}</h2>
  <p><strong>Classe :</strong> $className${teacherName != null ? ' &nbsp;|&nbsp; <strong>Professeur :</strong> $teacherName' : ''}</p>
  <table>
    <thead>
      <tr><th>Matricule</th><th>Nom complet</th><th>Classe</th><th>Signature</th><th>Observations</th></tr>
    </thead>
    <tbody>$rows</tbody>
  </table>
</body>
</html>''';
    _triggerPrint(html_);
  }

  static String _buildReceiptHtml({
    required SbInvoiceForPrint invoice,
    required String schoolName,
    String? schoolAddress,
    String? schoolPhone,
    String? schoolEmail,
    String? cashierName,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Reçu — ${invoice.invoiceNumber}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; font-size: 12px; }
    .header { text-align: center; border-bottom: 2px solid #8B1A00; padding-bottom: 12px; margin-bottom: 16px; }
    .school { font-size: 18px; font-weight: bold; color: #8B1A00; }
    .label { color: #7A5C44; }
    .amount { font-size: 22px; font-weight: bold; color: #8B1A00; }
    table { width: 100%; margin-top: 12px; }
    td { padding: 4px 0; }
    .status-paid { color: #16A34A; font-weight: bold; }
    .status-pending { color: #EA580C; font-weight: bold; }
    @media print { button { display: none; } }
  </style>
</head>
<body>
  <div class="header">
    <div class="school">$schoolName</div>
    ${schoolAddress != null ? '<div>$schoolAddress</div>' : ''}
    ${schoolPhone != null ? '<div>Tél : $schoolPhone</div>' : ''}
  </div>
  <h3>REÇU DE PAIEMENT</h3>
  <table>
    <tr><td class="label">N° Facture :</td><td><strong>${invoice.invoiceNumber}</strong></td></tr>
    <tr><td class="label">Élève :</td><td>${invoice.studentName}</td></tr>
    <tr><td class="label">Description :</td><td>${invoice.description}</td></tr>
    <tr><td class="label">Montant :</td><td class="amount">${invoice.amountFormatted} ${invoice.currency}</td></tr>
    <tr><td class="label">Statut :</td><td class="${invoice.isPaid ? 'status-paid' : 'status-pending'}">${invoice.isPaid ? 'PAYÉ' : 'EN ATTENTE'}</td></tr>
    ${cashierName != null ? '<tr><td class="label">Caissier :</td><td>$cashierName</td></tr>' : ''}
  </table>
</body>
</html>''';
  }

  static void _triggerPrint(String htmlContent) {
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final win = html.window.open(url, '_blank');
    if (win != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        win.print();
        html.Url.revokeObjectUrl(url);
      });
    }
  }
}
