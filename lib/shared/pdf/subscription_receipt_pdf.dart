import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/config/school_format.dart';
import '../../data/sources/remote/supabase_db_source.dart';

/// Reçu imprimable d'un versement d'ABONNEMENT (SaaS).
///
/// Design épuré type facture Stripe/SaaS : noir sur blanc, tableau à colonnes
/// (Qté / Prix unitaire / Montant), le crédit apparaît comme une **ligne
/// négative** plutôt qu'en bloc de totaux. Ici l'émetteur est **Scolaris** (le
/// vendeur) et le client est l'**école** — l'inverse d'`invoice_pdf.dart`.
///
/// `Printing.layoutPdf` ouvre la boîte système enregistrer/imprimer : l'admin
/// de l'école télécharge son justificatif.
///
/// ⚠️ Coordonnées Scolaris à compléter (raison sociale/adresse/n° fiscal réels)
///    quand l'entité de facturation sera arrêtée — voir [_Issuer].
Future<void> printSubscriptionReceipt({
  required SbSchool? school,
  required SbSubscriptionPayment payment,
  required String planName,
  String? previousPlanName,
}) async {
  final doc = await buildSubscriptionReceiptPdf(
    school: school,
    payment: payment,
    planName: planName,
    previousPlanName: previousPlanName,
  );
  final ref = payment.reference ?? payment.id.substring(0, 8).toUpperCase();
  await Printing.layoutPdf(onLayout: (_) => doc, name: 'Recu Scolaris $ref');
}

/// Téléchargement DIRECT du reçu (pas d'aperçu/impression) — `Printing.sharePdf`
/// déclenche le téléchargement navigateur sur web, la feuille de partage
/// (Enregistrer dans Fichiers…) sur mobile. C'est ce que « Télécharger le
/// reçu » doit appeler, pas [printSubscriptionReceipt] qui ouvre la boîte
/// système impression/aperçu.
Future<void> downloadSubscriptionReceipt({
  required SbSchool? school,
  required SbSubscriptionPayment payment,
  required String planName,
  String? previousPlanName,
}) async {
  final doc = await buildSubscriptionReceiptPdf(
    school: school,
    payment: payment,
    planName: planName,
    previousPlanName: previousPlanName,
  );
  final ref = payment.reference ?? payment.id.substring(0, 8).toUpperCase();
  await Printing.sharePdf(bytes: doc, filename: 'recu-scolaris-$ref.pdf');
}

Future<Uint8List> buildSubscriptionReceiptPdf({
  required SbSchool? school,
  required SbSubscriptionPayment payment,
  required String planName,
  String? previousPlanName,
}) async {
  final theme = await _theme();
  final pdf = pw.Document();
  pdf.addPage(_receiptPage(
      theme: theme,
      school: school,
      payment: payment,
      planName: planName,
      previousPlanName: previousPlanName));
  return pdf.save();
}

// Police portant les accents (celle par défaut de `pdf` n'a pas « é »).
Future<pw.ThemeData> _theme() async {
  final font = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  return pw.ThemeData.withFont(base: font, bold: bold);
}

// Palette neutre (facture épurée) — une seule touche de marque : le wordmark.
const _black = PdfColor.fromInt(0xFF18181B);
const _body = PdfColor.fromInt(0xFF3F3F46);
const _muted = PdfColor.fromInt(0xFF71717A);
const _line = PdfColor.fromInt(0xFFE4E4E7);
const _brand = PdfColor.fromInt(0xFF8B1A00); // terracotta Scolaris (wordmark seul)

/// Émetteur du reçu (Scolaris). À compléter avec les coordonnées légales réelles.
class _Issuer {
  static const name = 'Scolaris, PBC'; // TODO: raison sociale légale réelle
  static const address = <String>[
    'Espace Numérique de Travail scolaire', // TODO: adresse légale réelle
    'contact@scolaris.app',
  ];
  static const support = 'contact@scolaris.app';

  /// Mention fiscale/légale (TVA, exonération, RCCM…). Laissée vide tant que le
  /// régime réel n'est pas arrêté : on n'imprime PAS de mention fiscale fausse
  /// sur un justificatif financier. Renseigner ici quand le cadre sera fixé.
  static const legalNote = ''; // TODO: mention fiscale réelle (ex. régime TVA)
}

String _methodLabel(String? m) => switch (m) {
      'mobile_money' => 'Mobile Money',
      'card' => 'Carte bancaire',
      'bank' => 'Virement bancaire',
      'cash' => 'Espèces',
      _ => null,
    } ?? '—';

/// Fin de la période couverte par ce versement (mensuel → +1 mois, annuel → +1 an).
DateTime _coverageEnd(DateTime start, bool yearly) => yearly
    ? DateTime(start.year + 1, start.month, start.day)
    : DateTime(start.year, start.month + 1, start.day);

pw.Page _receiptPage({
  required pw.ThemeData theme,
  required SbSchool? school,
  required SbSubscriptionPayment payment,
  required String planName,
  String? previousPlanName,
}) {
  final money = SchoolFormat(currency: payment.currency).money;
  final dfLong = DateFormat('d MMMM yyyy', 'fr');
  final dfShort = DateFormat('d MMM yyyy', 'fr');
  final ref = payment.reference ?? payment.id.substring(0, 8).toUpperCase();

  final start = payment.date;
  final end = _coverageEnd(start, payment.isYearly);
  final coverage = '${dfShort.format(start)} – ${dfShort.format(end)}';
  final periodLabel = payment.isYearly ? 'Abonnement annuel' : 'Abonnement mensuel';
  final hasCredit = payment.creditApplied > 0.01;
  final isPlanChange = payment.isPlanChange && previousPlanName != null;

  final schoolLoc = [
    school?.city,
    school?.country,
    if ((school?.contactEmail ?? '').isNotEmpty) school!.contactEmail,
    if ((school?.contactPhone ?? '').isNotEmpty) school!.contactPhone,
  ].where((e) => (e ?? '').isNotEmpty).map((e) => e!).toList();

  return pw.Page(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(46, 46, 46, 40),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Titre + wordmark ───────────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Reçu',
                style: pw.TextStyle(
                    fontSize: 28, fontWeight: pw.FontWeight.bold, color: _black)),
            pw.Text('Scolaris',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brand)),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── Métadonnées (numéro, dates) ────────────────────────────────────
        _metaRow('Numéro de reçu', ref, valueBold: true),
        _metaRow('Date de paiement', dfLong.format(payment.date)),
        _metaRow('Période couverte', coverage),
        if (isPlanChange)
          _metaRow('Changement d\'offre', '$previousPlanName → $planName'),
        pw.SizedBox(height: 22),

        // ── Émetteur (Scolaris) + client (école) ───────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _party(_Issuer.name, _Issuer.address),
            ),
            pw.Expanded(
              child: _party(
                'Facturé à',
                [school?.name ?? 'Établissement', ...schoolLoc],
                headerIsLabel: true,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 26),

        // ── Montant mis en avant ───────────────────────────────────────────
        pw.Text('${money(payment.amount)} payé le ${dfLong.format(payment.date)}',
            style: pw.TextStyle(
                fontSize: 19, fontWeight: pw.FontWeight.bold, color: _black)),
        pw.SizedBox(height: 8),
        // Bloc « infos » (équivalent adapté des instructions Anthropic).
        pw.Text(
          'Règlement par ${_methodLabel(payment.method)}. Nous privilégions les '
          'paiements électroniques (Mobile Money, carte).',
          style: const pw.TextStyle(fontSize: 9.5, color: _muted, height: 1.4),
        ),
        pw.Text('Pour toute question relative à ce reçu : ${_Issuer.support}',
            style: const pw.TextStyle(fontSize: 9.5, color: _muted, height: 1.4)),
        if (_Issuer.legalNote.isNotEmpty)
          pw.Text(_Issuer.legalNote,
              style: const pw.TextStyle(fontSize: 9.5, color: _muted, height: 1.4)),
        pw.SizedBox(height: 24),

        // ── Tableau des lignes ─────────────────────────────────────────────
        _itemsHeader(),
        pw.Divider(color: _line, thickness: 1, height: 14),
        _itemRow(
          description: 'Offre Scolaris $planName',
          subtitle: '$periodLabel · $coverage',
          qty: '1',
          unit: money(payment.fullPrice),
          amount: money(payment.fullPrice),
        ),
        if (hasCredit) ...[
          pw.Divider(color: _line, thickness: 1, height: 14),
          _itemRow(
            description: 'Crédit / prorata reporté',
            subtitle: isPlanChange
                ? 'Temps restant sur l\'offre $previousPlanName'
                : 'Temps restant de l\'offre précédente',
            qty: '1',
            unit: '',
            amount: money(-payment.creditApplied),
          ),
        ],
        pw.Divider(color: _line, thickness: 1, height: 14),

        // ── Totaux ─────────────────────────────────────────────────────────
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 250,
            child: pw.Column(children: [
              _totalRow('Sous-total', money(payment.amount)),
              _totalRow('Total', money(payment.amount)),
              pw.Divider(color: _line, thickness: 1, height: 12),
              _totalRow('Montant payé', money(payment.amount), bold: true),
            ]),
          ),
        ),

        pw.Spacer(),
        pw.Divider(color: _line, thickness: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Ce reçu atteste du règlement de votre abonnement Scolaris.',
                style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            pw.Text('Page 1 sur 1',
                style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
          ],
        ),
      ],
    ),
  );
}

// Ligne de métadonnée : libellé (gras) à largeur fixe + valeur.
pw.Widget _metaRow(String label, String value, {bool valueBold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: _black)),
        ),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10,
                color: _body,
                fontWeight: valueBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    );

// Bloc émetteur/client : en-tête (gras) + lignes d'adresse.
pw.Widget _party(String header, List<String> lines, {bool headerIsLabel = false}) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(header,
            style: pw.TextStyle(
                fontSize: headerIsLabel ? 10 : 11,
                fontWeight: pw.FontWeight.bold,
                color: _black)),
        pw.SizedBox(height: 3),
        for (final l in lines)
          pw.Text(l, style: const pw.TextStyle(fontSize: 10, color: _body, height: 1.4)),
      ],
    );

// En-tête du tableau des lignes.
pw.Widget _itemsHeader() => pw.Row(children: [
      pw.Expanded(flex: 6, child: _th('Description')),
      pw.Expanded(flex: 1, child: _th('Qté', right: true)),
      pw.Expanded(flex: 3, child: _th('Prix unitaire', right: true)),
      pw.Expanded(flex: 3, child: _th('Montant', right: true)),
    ]);

pw.Widget _th(String s, {bool right = false}) => pw.Text(s,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: const pw.TextStyle(fontSize: 9, color: _muted));

// Une ligne d'article (description + sous-titre, qté, PU, montant).
pw.Widget _itemRow({
  required String description,
  required String subtitle,
  required String qty,
  required String unit,
  required String amount,
}) =>
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(description,
                  style: const pw.TextStyle(fontSize: 10.5, color: _black)),
              if (subtitle.isNotEmpty)
                pw.Text(subtitle,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        ),
        pw.Expanded(
            flex: 1,
            child: pw.Text(qty,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10.5, color: _body))),
        pw.Expanded(
            flex: 3,
            child: pw.Text(unit,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10.5, color: _body))),
        pw.Expanded(
            flex: 3,
            child: pw.Text(amount,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10.5, color: _black))),
      ],
    );

pw.Widget _totalRow(String label, String value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: bold ? 11 : 10,
                  color: bold ? _black : _muted,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: bold ? 11 : 10,
                  color: _black,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
