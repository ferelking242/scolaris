import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/config/school_format.dart';
import '../../data/sources/remote/supabase_db_source.dart';

/// Justificatif imprimable d'UNE facture, côté famille (élève/parent).
///
/// « REÇU » si la facture est soldée, sinon « FACTURE » (avec le reste dû).
/// `Printing.layoutPdf` ouvre la boîte système enregistrer/imprimer : c'est ce
/// qui permet à un parent de **télécharger** son justificatif.
Future<void> printInvoice({
  required SbSchool? school,
  required SbInvoice invoice,
}) async {
  final doc = await buildInvoicePdf(school: school, invoice: invoice);
  final ref = invoice.invoiceNumber ?? invoice.id.substring(0, 8).toUpperCase();
  await Printing.layoutPdf(
    onLayout: (_) => doc,
    name: '${invoice.isPaid ? "Recu" : "Facture"} $ref',
  );
}

/// Reçu imprimable d'UN versement précis (table `payments`) — distinct de la
/// facture annuelle globale, qui ne montre que le cumul encaissé à date. Un
/// parent qui veut la preuve du paiement du 15 mars, précisément, a besoin de
/// CE document, pas de l'état cumulé de la facture.
Future<void> printPaymentReceipt({
  required SbSchool? school,
  required SbPayment payment,
  required String studentName,
  String? description,
  required String currency,
}) async {
  final theme = await _theme();
  final pdf = pw.Document();
  final money = SchoolFormat(currency: currency).money;
  final df = DateFormat('d MMMM yyyy', 'fr');
  final ref = payment.reference ?? payment.id.substring(0, 8).toUpperCase();

  pdf.addPage(pw.Page(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(school?.name ?? 'Établissement',
                  style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _ink)),
              if ((school?.city ?? '').isNotEmpty)
                pw.Text([school?.city, school?.country].where((e) => (e ?? '').isNotEmpty).join(', '),
                    style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ]),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(color: _green, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text('REÇU DE VERSEMENT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _line, thickness: 1),
        pw.SizedBox(height: 18),
        _kv('Réglé par', studentName),
        pw.SizedBox(height: 8),
        _kv('Date du versement', df.format(payment.paymentDate ?? DateTime.now())),
        pw.SizedBox(height: 8),
        _kv('Motif', description ?? 'Scolarité'),
        pw.SizedBox(height: 8),
        _kv('Mode de paiement', _methodLabel(payment.paymentMethod)),
        pw.SizedBox(height: 8),
        _kv('Référence', ref),
        pw.SizedBox(height: 22),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF0FDF4),
            border: pw.Border.all(color: _green),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Montant versé',
                  style: pw.TextStyle(fontSize: 12, color: _muted, fontWeight: pw.FontWeight.bold)),
              pw.Text(money(payment.amount),
                  style: pw.TextStyle(fontSize: 18, color: _green, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.Spacer(),
        pw.Divider(color: _line, thickness: 1),
        pw.Text('Ce reçu atteste du règlement de ce versement précis. Merci.',
            style: const pw.TextStyle(fontSize: 9, color: _muted)),
      ],
    ),
  ));

  await Printing.layoutPdf(
    onLayout: (_) => pdf.save(),
    name: 'Recu $ref',
  );
}

String _methodLabel(String? method) => switch (method?.toLowerCase()) {
      'cash' => 'Espèces',
      'mobile_money' || 'mtn' || 'airtel' => 'Mobile Money',
      'bank_transfer' || 'transfer' => 'Virement bancaire',
      'card' => 'Carte bancaire',
      _ => method ?? '—',
    };

Future<Uint8List> buildInvoicePdf({
  required SbSchool? school,
  required SbInvoice invoice,
}) async {
  final theme = await _theme();
  final pdf = pw.Document();
  pdf.addPage(_invoicePage(theme: theme, school: school, invoice: invoice));
  return pdf.save();
}

// Police portant les accents (celle par défaut de `pdf` n'a pas « é »).
Future<pw.ThemeData> _theme() async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  return pw.ThemeData.withFont(base: font, bold: bold);
}

const _terra = PdfColor.fromInt(0xFF8B1A00);
const _ink = PdfColor.fromInt(0xFF1A0A00);
const _muted = PdfColor.fromInt(0xFF7A5C44);
const _green = PdfColor.fromInt(0xFF16A34A);
const _line = PdfColor.fromInt(0xFFDDCCBB);

pw.Page _invoicePage({
  required pw.ThemeData theme,
  required SbSchool? school,
  required SbInvoice invoice,
}) {
  final money = SchoolFormat(currency: invoice.currency).money;
  final df = DateFormat('d MMMM yyyy', 'fr');
  final isReceipt = invoice.isPaid;
  final ref = invoice.invoiceNumber ?? invoice.id.substring(0, 8).toUpperCase();

  final statusLabel = invoice.isPaid
      ? 'Payée'
      : invoice.isPartiallyPaid
          ? 'Partiellement réglée'
          : invoice.isLate
              ? 'En retard'
              : 'En attente';
  final statusColor = invoice.isPaid
      ? _green
      : invoice.isLate
          ? _terra
          : const PdfColor.fromInt(0xFFEA580C);

  return pw.Page(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── En-tête : école + type de document ────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(school?.name ?? 'Établissement',
                    style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink)),
                if ((school?.city ?? '').isNotEmpty)
                  pw.Text(
                      [school?.city, school?.country]
                          .where((e) => (e ?? '').isNotEmpty)
                          .join(', '),
                      style: const pw.TextStyle(fontSize: 10, color: _muted)),
                if ((school?.academicYear ?? '').isNotEmpty)
                  pw.Text('Année ${school!.academicYear}',
                      style: const pw.TextStyle(fontSize: 10, color: _muted)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: _terra,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(isReceipt ? 'REÇU' : 'FACTURE',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _line, thickness: 1),
        pw.SizedBox(height: 14),

        // ── Références ─────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Facturé à', invoice.studentName ?? '—'),
                if ((invoice.period ?? '').isNotEmpty)
                  _kv('Période', invoice.period!),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _kv('N°', ref, alignEnd: true),
                if (invoice.dueDate != null)
                  _kv('Échéance', df.format(invoice.dueDate!), alignEnd: true),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),

        // ── Ligne de facturation ───────────────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(children: [
            pw.Container(
              color: const PdfColor.fromInt(0xFFF7F1E8),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: pw.Row(children: [
                pw.Expanded(
                    flex: 4,
                    child: pw.Text('Désignation',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _muted))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('Montant',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _muted))),
              ]),
            ),
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: pw.Row(children: [
                pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                        invoice.description ?? invoice.categoryLabel,
                        style: const pw.TextStyle(fontSize: 11, color: _ink))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(money(invoice.amount),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 11, color: _ink))),
              ]),
            ),
          ]),
        ),
        pw.SizedBox(height: 12),

        // ── Totaux ─────────────────────────────────────────────────────────
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 240,
            child: pw.Column(children: [
              _total('Total', money(invoice.amount)),
              if (invoice.amountPaid > 0.01)
                _total('Déjà réglé', money(invoice.amountPaid), color: _green),
              if (!invoice.isPaid)
                _total('Reste dû', money(invoice.balance),
                    color: _terra, bold: true),
            ]),
          ),
        ),
        pw.SizedBox(height: 18),

        // ── Statut ─────────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColor(statusColor.red, statusColor.green,
                statusColor.blue, 0.12),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text('Statut : $statusLabel',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: statusColor)),
        ),

        pw.Spacer(),
        pw.Divider(color: _line, thickness: 1),
        pw.Text(
          isReceipt
              ? 'Ce reçu atteste du règlement de la somme indiquée. Merci.'
              : 'Document non contractuel — à présenter lors du règlement.',
          style: const pw.TextStyle(fontSize: 9, color: _muted),
        ),
      ],
    ),
  );
}

pw.Widget _kv(String k, String v, {bool alignEnd = false}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Column(
        crossAxisAlignment:
            alignEnd ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(k, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
          pw.Text(v,
              style: pw.TextStyle(
                  fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _ink)),
        ],
      ),
    );

pw.Widget _total(String label, String value,
        {PdfColor color = _ink, bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 11,
                  color: _muted,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: bold ? 13 : 11,
                  color: color,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
