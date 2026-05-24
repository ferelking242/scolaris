// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../data/mock_data.dart';

/// PrintService — déclenche l'impression via le dialogue natif du navigateur.
///
/// Compatible avec toutes les imprimantes reconnues par le système :
/// - WiFi (réseau local / Cloud Print)
/// - Bluetooth
/// - USB / câble
///
/// L'utilisateur voit le dialogue d'impression standard du système (Chrome,
/// Firefox, Edge, Safari) et choisit son imprimante normalement.
class PrintService {
  // ─────────────────────────────────────────────────────────────────────────
  // Reçu de paiement
  // ─────────────────────────────────────────────────────────────────────────

  static void printReceipt({
    required MockInvoice invoice,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Liste d'élèves
  // ─────────────────────────────────────────────────────────────────────────

  static void printStudentList({
    required List<MockStudent> students,
    required String schoolName,
    String? classFilter,
    String? printedBy,
  }) {
    final html_ = _buildStudentListHtml(
      students: students,
      schoolName: schoolName,
      classFilter: classFilter,
      printedBy: printedBy,
    );
    _triggerPrint(html_);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rapport financier simple
  // ─────────────────────────────────────────────────────────────────────────

  static void printFinanceReport({
    required List<MockInvoice> invoices,
    required String schoolName,
    required String period,
    String? printedBy,
  }) {
    final html_ = _buildReportHtml(
      invoices: invoices,
      schoolName: schoolName,
      period: period,
      printedBy: printedBy,
    );
    _triggerPrint(html_);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core : injecter dans un nouvel onglet + window.print()
  // ─────────────────────────────────────────────────────────────────────────

  static void _triggerPrint(String htmlContent) {
    final win = html.window.open('', '_blank');
    if (win == null) return;
    win.document.write(htmlContent);
    win.document.close();
    win.focus();
    // Délai pour que le navigateur charge le contenu avant d'imprimer
    Future.delayed(const Duration(milliseconds: 300), () {
      win.print();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Builders HTML
  // ─────────────────────────────────────────────────────────────────────────

  static String _baseStyle() => '''
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body {
        font-family: 'Segoe UI', Arial, sans-serif;
        font-size: 13px;
        color: #1A0A00;
        background: white;
      }
      .page {
        max-width: 72mm;
        margin: 0 auto;
        padding: 12mm 10mm;
      }
      .school-header {
        text-align: center;
        border-bottom: 2px solid #8B1A00;
        padding-bottom: 10px;
        margin-bottom: 12px;
      }
      .school-name {
        font-size: 16px;
        font-weight: 900;
        color: #8B1A00;
        letter-spacing: -0.3px;
      }
      .school-sub {
        font-size: 10px;
        color: #7A5C44;
        margin-top: 2px;
      }
      .receipt-title {
        background: #8B1A00;
        color: white;
        text-align: center;
        padding: 6px;
        font-size: 14px;
        font-weight: 800;
        letter-spacing: 1px;
        margin-bottom: 12px;
        border-radius: 4px;
      }
      .section-title {
        font-size: 9px;
        font-weight: 800;
        color: #C17F24;
        text-transform: uppercase;
        letter-spacing: 1px;
        margin: 10px 0 6px;
        border-bottom: 1px solid #DDCCBB;
        padding-bottom: 3px;
      }
      .row {
        display: flex;
        justify-content: space-between;
        align-items: baseline;
        padding: 3px 0;
        font-size: 12px;
      }
      .row .label { color: #7A5C44; }
      .row .value { font-weight: 600; color: #1A0A00; }
      .amount-box {
        background: #FFF5EC;
        border: 2px solid #8B1A00;
        border-radius: 6px;
        padding: 10px;
        text-align: center;
        margin: 14px 0;
      }
      .amount-label { font-size: 10px; color: #7A5C44; text-transform: uppercase; letter-spacing: 0.5px; }
      .amount-value { font-size: 22px; font-weight: 900; color: #8B1A00; margin-top: 2px; }
      .status-paid { color: #2D6A4F; font-weight: 800; }
      .status-pending { color: #D4540A; font-weight: 800; }
      .status-overdue { color: #8B1A00; font-weight: 800; }
      .divider { border: none; border-top: 1px dashed #DDCCBB; margin: 10px 0; }
      .footer {
        text-align: center;
        font-size: 9px;
        color: #7A5C44;
        margin-top: 16px;
        border-top: 1px solid #DDCCBB;
        padding-top: 8px;
        line-height: 1.6;
      }
      .signature-box {
        border: 1px solid #DDCCBB;
        border-radius: 4px;
        height: 40px;
        margin-top: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 9px;
        color: #7A5C44;
      }
      table { width: 100%; border-collapse: collapse; font-size: 11px; }
      th {
        background: #3E1A00;
        color: white;
        padding: 5px 6px;
        text-align: left;
        font-size: 9px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }
      td { padding: 5px 6px; border-bottom: 1px solid #F0E8DC; vertical-align: middle; }
      tr:nth-child(even) td { background: #FAF7F3; }
      @media print {
        @page { margin: 0; }
        body { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
      }
    </style>
  ''';

  static String _buildReceiptHtml({
    required MockInvoice invoice,
    required String schoolName,
    String? schoolAddress,
    String? schoolPhone,
    String? schoolEmail,
    String? cashierName,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}h'
        '${now.minute.toString().padLeft(2, '0')}';

    final statusLabel = invoice.status == InvoiceStatus.paid
        ? 'PAYÉ'
        : invoice.status == InvoiceStatus.overdue
            ? 'EN RETARD'
            : 'EN ATTENTE';
    final statusClass = invoice.status == InvoiceStatus.paid
        ? 'status-paid'
        : invoice.status == InvoiceStatus.overdue
            ? 'status-overdue'
            : 'status-pending';

    final dueDateStr =
        '${invoice.due.day.toString().padLeft(2, '0')}/${invoice.due.month.toString().padLeft(2, '0')}/${invoice.due.year}';

    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reçu ${invoice.number}</title>
  ${_baseStyle()}
</head>
<body>
<div class="page">
  <div class="school-header">
    <div class="school-name">$schoolName</div>
    ${schoolAddress != null ? '<div class="school-sub">$schoolAddress</div>' : ''}
    ${schoolPhone != null ? '<div class="school-sub">Tél : $schoolPhone</div>' : ''}
    ${schoolEmail != null ? '<div class="school-sub">$schoolEmail</div>' : ''}
  </div>

  <div class="receipt-title">🧾 REÇU DE PAIEMENT</div>

  <div class="section-title">Référence</div>
  <div class="row"><span class="label">N° Reçu</span><span class="value">${invoice.number}</span></div>
  <div class="row"><span class="label">Date d'impression</span><span class="value">$dateStr à $timeStr</span></div>
  <div class="row"><span class="label">Statut</span><span class="value $statusClass">$statusLabel</span></div>

  <div class="section-title">Élève</div>
  <div class="row"><span class="label">Nom</span><span class="value">${invoice.student}</span></div>

  <div class="section-title">Détail du paiement</div>
  <div class="row"><span class="label">Objet</span><span class="value">${invoice.description}</span></div>
  <div class="row"><span class="label">Échéance</span><span class="value">$dueDateStr</span></div>

  <div class="amount-box">
    <div class="amount-label">Montant</div>
    <div class="amount-value">${invoice.amount.toStringAsFixed(0)} FCFA</div>
  </div>

  <div class="section-title">Encaissement</div>
  <div class="row"><span class="label">Caissier/ière</span><span class="value">${cashierName ?? 'Service financier'}</span></div>

  <hr class="divider">
  <div class="section-title">Signature</div>
  <div class="signature-box">Signature du responsable financier</div>

  <div class="footer">
    Ce reçu est un document officiel.<br>
    Conservez-le pour vos dossiers.<br>
    Imprimé le $dateStr — Scolaris
  </div>
</div>
</body>
</html>
''';
  }

  static String _buildStudentListHtml({
    required List<MockStudent> students,
    required String schoolName,
    String? classFilter,
    String? printedBy,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

    final rows = students.map((s) {
      final pct = (s.attendance * 100).toStringAsFixed(0);
      final avgStr = s.avg.toStringAsFixed(1);
      return '''
        <tr>
          <td>${s.id}</td>
          <td><strong>${s.name}</strong></td>
          <td>${s.classGroup}</td>
          <td>${s.guardian}</td>
          <td>$avgStr/20</td>
          <td>$pct%</td>
        </tr>
      ''';
    }).join();

    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Liste des élèves</title>
  ${_baseStyle()}
  <style>
    .page { max-width: 100%; padding: 15mm 12mm; }
    table { font-size: 11px; }
  </style>
</head>
<body>
<div class="page">
  <div class="school-header">
    <div class="school-name">$schoolName</div>
    <div class="school-sub">Liste des élèves${classFilter != null ? ' — $classFilter' : ''}</div>
  </div>
  <div class="receipt-title">📋 LISTE DES ÉLÈVES</div>
  <div class="row" style="margin-bottom:10px;">
    <span class="label">Date d'impression</span>
    <span class="value">$dateStr</span>
  </div>
  <div class="row" style="margin-bottom:14px;">
    <span class="label">Imprimé par</span>
    <span class="value">${printedBy ?? 'Service'}</span>
  </div>
  <table>
    <thead>
      <tr>
        <th>ID</th>
        <th>Nom complet</th>
        <th>Classe</th>
        <th>Tuteur</th>
        <th>Moy.</th>
        <th>Présence</th>
      </tr>
    </thead>
    <tbody>$rows</tbody>
  </table>
  <div class="footer">
    ${students.length} élève(s) listés — Imprimé le $dateStr — Scolaris
  </div>
</div>
</body>
</html>
''';
  }

  static String _buildReportHtml({
    required List<MockInvoice> invoices,
    required String schoolName,
    required String period,
    String? printedBy,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

    final totalPaid = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold<double>(0, (a, b) => a + b.amount);
    final totalPending = invoices
        .where((i) => i.status == InvoiceStatus.pending)
        .fold<double>(0, (a, b) => a + b.amount);
    final totalOverdue = invoices
        .where((i) => i.status == InvoiceStatus.overdue)
        .fold<double>(0, (a, b) => a + b.amount);

    final rows = invoices.map((i) {
      final statusLabel = i.status == InvoiceStatus.paid
          ? 'PAYÉ'
          : i.status == InvoiceStatus.overdue
              ? 'EN RETARD'
              : 'EN ATTENTE';
      final statusClass = i.status == InvoiceStatus.paid
          ? 'status-paid'
          : i.status == InvoiceStatus.overdue
              ? 'status-overdue'
              : 'status-pending';
      final dueDateStr =
          '${i.due.day.toString().padLeft(2, '0')}/${i.due.month.toString().padLeft(2, '0')}/${i.due.year}';
      return '''
        <tr>
          <td>${i.number}</td>
          <td><strong>${i.student}</strong></td>
          <td>${i.description}</td>
          <td>${i.amount.toStringAsFixed(0)} F</td>
          <td>$dueDateStr</td>
          <td class="$statusClass">$statusLabel</td>
        </tr>
      ''';
    }).join();

    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Rapport financier — $period</title>
  ${_baseStyle()}
  <style>
    .page { max-width: 100%; padding: 15mm 12mm; }
  </style>
</head>
<body>
<div class="page">
  <div class="school-header">
    <div class="school-name">$schoolName</div>
    <div class="school-sub">Rapport financier — $period</div>
  </div>
  <div class="receipt-title">📊 RAPPORT FINANCIER</div>

  <div class="section-title">Résumé</div>
  <div class="row"><span class="label">Total encaissé</span><span class="value status-paid">${totalPaid.toStringAsFixed(0)} FCFA</span></div>
  <div class="row"><span class="label">En attente</span><span class="value status-pending">${totalPending.toStringAsFixed(0)} FCFA</span></div>
  <div class="row"><span class="label">En retard</span><span class="value status-overdue">${totalOverdue.toStringAsFixed(0)} FCFA</span></div>
  <div class="row"><span class="label">Total général</span><span class="value">${(totalPaid + totalPending + totalOverdue).toStringAsFixed(0)} FCFA</span></div>

  <div class="section-title" style="margin-top:16px;">Détail des factures</div>
  <table>
    <thead>
      <tr>
        <th>N°</th>
        <th>Élève</th>
        <th>Objet</th>
        <th>Montant</th>
        <th>Échéance</th>
        <th>Statut</th>
      </tr>
    </thead>
    <tbody>$rows</tbody>
  </table>

  <div class="footer">
    Imprimé par ${printedBy ?? 'Service financier'} le $dateStr — Scolaris
  </div>
</div>
</body>
</html>
''';
  }
}
