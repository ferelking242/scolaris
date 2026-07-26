import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../admin/presentation/widgets/tuition_account.dart' show coveredUntilLabel;
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/pdf/invoice_pdf.dart';
import '../../../../shared/widgets/online_payment_sheet.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

enum PayStatut { paye, enAttente, enRetard }

class StudentPaymentsPage extends ConsumerWidget {
  const StudentPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authSessionProvider);
    final invoicesAsync = ref.watch(myInvoicesProvider);
    final paymentsAsync = ref.watch(paymentsForStudentProvider(user?.id ?? ''));
    // Le COMPTE de scolarité (solde qui court) — remplace la pile de tranches.
    final acc         = ref.watch(tuitionAccountProvider(user?.id ?? '')).valueOrNull;
    final level       = ref.watch(studentSchoolLevelProvider).valueOrNull
        ?? SchoolLevel.lycee;
    final onlinePay   = ref.watch(onlinePaymentEnabledProvider).valueOrNull ?? false;
    final school      = ref.watch(schoolProvider).valueOrNull;

    final isHigherEd = level == SchoolLevel.universite ||
        level == SchoolLevel.master ||
        level == SchoolLevel.doctorat;
    // Libellés adaptés au type d'école.
    final feesTitle = isHigherEd ? 'Frais universitaires' : 'Tranches de scolarité';
    final headerTitle = isHigherEd ? 'Frais d\'études' : 'Scolarité';
    final year = school?.academicYear ?? '';

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: invoicesAsync.when(
        loading: () => const Center(
            child: Padding(padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator())),
        error: (e, _) => Center(
            child: Padding(padding: const EdgeInsets.all(32),
                child: Text('Erreur : $e',
                    style: const TextStyle(color: _terra)))),
        data: (invoices) {
          // La scolarité est un COMPTE (acc) ; les autres frais restent des
          // factures discrètes (inscription, etc.).
          final others = [...invoices.where((i) => !i.isTuition)]..sort((a, b) {
            final da = a.dueDate, db = b.dueDate;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
          final currency = acc?.currency ??
              (invoices.isNotEmpty ? invoices.first.currency : 'FCFA');

          // Totaux du bandeau : depuis le compte si dispo, sinon repli sur la
          // somme des factures (école sans grille de frais).
          final total = acc?.annual ??
              invoices.fold<double>(0, (s, i) => s + i.amount);
          final paye = acc?.paid ??
              invoices
                  .where((i) => i.status.toLowerCase() == 'paid')
                  .fold<double>(0, (s, i) => s + i.amount);
          final restant = acc?.balance ??
              (total - paye).clamp(0, double.infinity).toDouble();

          // Les factures-compte de scolarité impayées (souvent plusieurs mois
          // en retard) — pas seulement la première, sinon on ne peut régler
          // qu'un mois à la fois.
          final unpaidTuition =
              invoices.where((i) => i.isTuition && !i.isPaid).toList();

          // La facture annuelle de scolarité (une seule par élève) — seule
          // trace imprimable d'un versement cash ou en ligne.
          final tuitionInvoice = invoices.where((i) => i.isTuition).firstOrNull;

          // Autres frais impayés (hors scolarité) — pour le rappel et le CTA.
          final othersUnpaid = others.where(_isUnpaid).toList();

          // Règle une liste de factures en ligne, puis rafraîchit.
          Future<void> pay(List<SbInvoice> list, {double? suggested}) async {
            final ok = await showOnlinePaymentSheet(context, ref, list,
                suggestedAmount: suggested);
            if (ok) ref.invalidate(myInvoicesProvider);
          }

          // Pour la scolarité : pré-remplir le dû à ce jour (sinon une mensualité).
          final tuitionSuggest =
              acc == null ? null : (acc.owedNow > 0.01 ? acc.owedNow : acc.monthly);

          // Rappel : d'abord un retard de scolarité, sinon la prochaine échéance
          // d'un autre frais.
          final scolariteEnRetard = acc != null && acc.owedNow > 0.01;
          final urgentOther = othersUnpaid.isEmpty ? null : othersUnpaid.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCard(
                  name: user?.fullName ?? 'Étudiant',
                  headerTitle: headerTitle,
                  year: year,
                  currency: currency,
                  totalAnnuel: total,
                  totalPaye: paye,
                  restant: restant,
                ),
                const SizedBox(height: 16),

                // ── Rappel : retard de scolarité / prochaine échéance ──────
                if (scolariteEnRetard) ...[
                  _AccountReminder(
                    acc: acc,
                    online: onlinePay && unpaidTuition.isNotEmpty,
                    onPay: unpaidTuition.isEmpty
                        ? null
                        : () => pay(unpaidTuition, suggested: tuitionSuggest),
                  ),
                  const SizedBox(height: 16),
                ] else if (urgentOther != null) ...[
                  _ReminderBanner(
                    invoice: urgentOther,
                    currency: currency,
                    online: onlinePay,
                    onPay: () => pay([urgentOther]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Scolarité : l'échéancier du compte ─────────────────────
                if (acc != null) ...[
                  _SectionTitle(
                    icon: Icons.receipt_long_rounded,
                    label: feesTitle,
                    gradient: const [_terra, _orange],
                  ),
                  const SizedBox(height: 12),
                  _ScheduleCard(acc: acc, currency: currency),
                  if (tuitionInvoice != null) ...[
                    const SizedBox(height: 8),
                    _DownloadRow(
                      label: acc.isUpToDate ? 'Télécharger le reçu' : 'Télécharger la facture',
                      onTap: () => printInvoice(school: school, invoice: tuitionInvoice),
                    ),
                  ],
                  if (onlinePay && unpaidTuition.isNotEmpty && restant > 0.01) ...[
                    const SizedBox(height: 12),
                    _PayCta(
                      online: true,
                      count: unpaidTuition.length,
                      onPay: () => pay(unpaidTuition, suggested: tuitionSuggest),
                    ),
                  ],
                ] else if (invoices.isNotEmpty) ...[
                  // Repli (pas de grille) : ancienne liste de tranches.
                  _SectionTitle(
                    icon: Icons.receipt_long_rounded,
                    label: feesTitle,
                    gradient: const [_terra, _orange],
                  ),
                  const SizedBox(height: 12),
                  for (final inv in others) ...[
                    _TrancheCard(
                      invoice: inv,
                      currency: currency,
                      onPay: (onlinePay && _isUnpaid(inv)) ? () => pay([inv]) : null,
                      onDownload: () => printInvoice(school: school, invoice: inv),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                // ── Autres frais (inscription, etc.) ───────────────────────
                if (acc != null && others.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    icon: Icons.article_outlined,
                    label: 'Autres frais',
                    gradient: const [_gold, _orange],
                  ),
                  const SizedBox(height: 12),
                  for (final inv in others) ...[
                    _TrancheCard(
                      invoice: inv,
                      currency: currency,
                      onPay: (onlinePay && _isUnpaid(inv)) ? () => pay([inv]) : null,
                      onDownload: () => printInvoice(school: school, invoice: inv),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                if (acc == null && invoices.isEmpty) const _EmptyInvoices(),

                // ── Historique ─────────────────────────────────────────────
                const SizedBox(height: 24),
                _SectionTitle(
                  icon: Icons.history_rounded,
                  label: 'Historique des versements',
                  gradient: const [_gold, _orange],
                ),
                const SizedBox(height: 12),
                _HistoriqueCard(
                  payments: paymentsAsync.valueOrNull ?? const <SbPayment>[],
                  currency: currency,
                  studentName: user?.fullName ?? 'Étudiant',
                  school: school,
                ),

                const SizedBox(height: 24),
                _SectionTitle(
                  icon: Icons.info_outline_rounded,
                  label: 'Informations',
                  gradient: const [_green, Color(0xFF2E7D32)],
                ),
                const SizedBox(height: 12),
                _InfoCard(online: onlinePay),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Formatage ──────────────────────────────────────────────────────────────
String _fmtMoney(double n) {
  final s = n.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];
  return '${d.day} ${mois[d.month - 1]} ${d.year}';
}

bool _isUnpaid(SbInvoice i) {
  final s = i.status.toLowerCase();
  return s != 'paid' && s != 'cancelled';
}

String _methodLabel(String? method) => switch (method?.toLowerCase()) {
      'cash' => 'Espèces',
      'mobile_money' || 'mtn' || 'airtel' => 'Mobile Money',
      'bank_transfer' || 'transfer' => 'Virement bancaire',
      'card' => 'Carte bancaire',
      _ => method ?? '—',
    };

// ── Bannière de rappel (prochaine échéance / retard) ────────────────────────
class _ReminderBanner extends StatelessWidget {
  final SbInvoice invoice;
  final String currency;
  final bool online;
  final VoidCallback onPay;
  const _ReminderBanner({
    required this.invoice,
    required this.currency,
    required this.online,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final due = invoice.dueDate;
    final now = DateTime.now();
    final overdue = due != null && due.isBefore(DateTime(now.year, now.month, now.day));
    final days = due == null ? null : due.difference(DateTime(now.year, now.month, now.day)).inDays;
    final color = overdue ? _terra : _gold;

    final String msg;
    if (overdue) {
      msg = 'En retard de ${days!.abs()} jour${days.abs() > 1 ? "s" : ""}';
    } else if (days == 0) {
      msg = 'À régler aujourd\'hui';
    } else if (days != null) {
      msg = 'À régler avant le ${_fmtDate(due)}';
    } else {
      msg = 'À régler';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Row(children: [
        Icon(overdue ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
            color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(invoice.description ?? 'Échéance à venir',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface, fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('$msg · ${_fmtMoney(invoice.amount)} $currency',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
        if (online) ...[
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onPay,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Payer'),
          ),
        ],
      ]),
    );
  }
}

// ── Rappel de compte (retard de scolarité) ─────────────────────────────────
class _AccountReminder extends StatelessWidget {
  final SbTuitionAccount acc;
  final bool online;
  final VoidCallback? onPay;
  const _AccountReminder({required this.acc, required this.online, this.onPay});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _terra.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _terra.withOpacity(.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: _terra, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scolarité en retard',
              style: TextStyle(color: cs.onSurface, fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('À régler maintenant · ${_fmtMoney(acc.owedNow)} ${acc.currency}',
              style: const TextStyle(color: _terra, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
        if (online && onPay != null) ...[
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onPay,
            style: FilledButton.styleFrom(
              backgroundColor: _terra,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Payer'),
          ),
        ],
      ]),
    );
  }
}

// ── Échéancier du compte de scolarité ───────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final SbTuitionAccount acc;
  final String currency;
  const _ScheduleCard({required this.acc, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final covered = acc.periodsCovered; // fractionnaire : 3,5 = 3 mois + moitié
    final today = DateTime.now();
    final periods = acc.periods;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8)],
      ),
      child: Column(children: [
        // En-tête : payé / total.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            Expanded(
              child: Text('Payé ${_fmtMoney(acc.paid)} sur ${_fmtMoney(acc.annual)} $currency',
                  style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            Text('Couvert jusqu\'à ${coveredUntilLabel(acc, acc.paid)}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          ]),
        ),
        const Divider(height: 1),
        for (int i = 0; i < periods.length; i++)
          _MonthRow(
            period: periods[i],
            monthly: acc.monthly,
            currency: currency,
            covered: covered,
            index: i,
            today: today,
            isLast: i == periods.length - 1,
          ),
      ]),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final SbTuitionPeriod period;
  final double monthly;
  final String currency;
  final double covered; // nb de mois couverts (fractionnaire)
  final int index;
  final DateTime today;
  final bool isLast;
  const _MonthRow({
    required this.period,
    required this.monthly,
    required this.currency,
    required this.covered,
    required this.index,
    required this.today,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final due = !period.due.isAfter(today); // échu ?
    final fullyCovered = covered >= index + 1 - 0.001;
    final partlyCovered = !fullyCovered && covered > index + 0.001;

    // Réglé (vert) · Partiel (or) · En retard (terra) · À venir (gris).
    final Color color;
    final String label;
    if (fullyCovered) {
      color = _green;
      label = 'Réglé';
    } else if (partlyCovered) {
      color = _gold;
      label = 'Partiel';
    } else if (due) {
      color = _terra;
      label = 'En retard';
    } else {
      color = cs.onSurfaceVariant;
      label = 'À venir';
    }

    final monthLabel = period.label.replaceFirst('Scolarité — ', '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(monthLabel.isEmpty ? period.code : monthLabel,
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text('${_fmtMoney(monthly)} $currency',
            style: TextStyle(color: cs.onSurface, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(.3)),
          ),
          child: Text(label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Ligne « Télécharger la facture/le reçu » ───────────────────────────────
class _DownloadRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DownloadRow({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.download_rounded, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String name, headerTitle, year, currency;
  final double totalAnnuel, totalPaye, restant;
  const _SummaryCard({
    required this.name, required this.headerTitle, required this.year,
    required this.currency, required this.totalAnnuel,
    required this.totalPaye, required this.restant,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalAnnuel > 0 ? (totalPaye / totalAnnuel) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), Color(0xFF3E1A00), _terra],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _terra.withOpacity(0.4), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15), shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(year.isEmpty ? headerTitle : '$headerTitle $year',
                style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11)),
            Text(name, style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ]),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(.15),
            valueColor: const AlwaysStoppedAnimation<Color>(_gold),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text('${(progress * 100).toStringAsFixed(0)}% payé',
              style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_fmtMoney(restant)} $currency restant',
              style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _StatPill(label: 'Total', value: '${_fmtMoney(totalAnnuel)} $currency', color: Colors.white.withOpacity(.85)),
          const SizedBox(width: 10),
          _StatPill(label: 'Payé', value: '${_fmtMoney(totalPaye)} $currency', color: _gold),
          const SizedBox(width: 10),
          _StatPill(label: 'Restant', value: '${_fmtMoney(restant)} $currency', color: const Color(0xFFFFB74D)),
        ]),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(.12)),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 9,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  ));
}

// ── Tranche Card ──────────────────────────────────────────────────────────
class _TrancheCard extends StatelessWidget {
  final SbInvoice invoice;
  final String currency;
  final VoidCallback? onPay;
  final VoidCallback? onDownload;
  const _TrancheCard({
    required this.invoice,
    required this.currency,
    this.onPay,
    this.onDownload,
  });

  PayStatut get _statut {
    if (invoice.isPaid) return PayStatut.paye;
    // isLate = échéance dépassée impayée ; status=='overdue' n'est jamais écrit.
    if (invoice.isLate) return PayStatut.enRetard;
    return PayStatut.enAttente;
  }

  Color get _statusColor => switch (_statut) {
        PayStatut.paye      => _green,
        PayStatut.enAttente => _gold,
        PayStatut.enRetard  => _terra,
      };

  String get _statusLabel => switch (_statut) {
        PayStatut.paye      => 'Payé',
        PayStatut.enAttente => 'En attente',
        PayStatut.enRetard  => 'En retard',
      };

  IconData get _statusIcon => switch (_statut) {
        PayStatut.paye      => Icons.check_circle_rounded,
        PayStatut.enAttente => Icons.schedule_rounded,
        PayStatut.enRetard  => Icons.warning_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = invoice.description ?? invoice.invoiceNumber ?? 'Frais';
    final dateLabel = _statut == PayStatut.paye
        ? 'Réglé'
        : 'Échéance ${_fmtDate(invoice.dueDate)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withOpacity(.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(_statusIcon, color: _statusColor, size: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
              color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(dateLabel, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          if (invoice.invoiceNumber != null) ...[
            const SizedBox(height: 2),
            Text('Réf: ${invoice.invoiceNumber}', style: TextStyle(
                color: cs.onSurfaceVariant.withOpacity(.7), fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmtMoney(invoice.amount)} $currency', style: TextStyle(
              color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor.withOpacity(.3)),
            ),
            child: Text(_statusLabel, style: TextStyle(
                color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          if (onPay != null) ...[
            const SizedBox(height: 6),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onPay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Payer', style: TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
          if (onDownload != null) ...[
            const SizedBox(height: 6),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onDownload,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_rounded,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(invoice.isPaid ? 'Reçu' : 'Facture',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ── CTA Paiement en ligne (Pro/Max) ────────────────────────────────────────
class _PayCta extends StatelessWidget {
  final bool online;
  final int count;
  final VoidCallback onPay;
  const _PayCta({required this.online, required this.count, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (online) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPay,
          icon: const Icon(Icons.smartphone_rounded, size: 18),
          label: Text(count > 1
              ? 'Tout régler ($count échéances) — Mobile Money'
              : 'Payer en ligne (Mobile Money)'),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }
    // Offre sans paiement en ligne → on oriente vers le règlement manuel.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withOpacity(.25)),
      ),
      child: Row(children: [
        const Icon(Icons.storefront_rounded, color: _gold, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Règlement à la caisse de l\'établissement (espèces, virement).',
              style: TextStyle(color: cs.onSurface, fontSize: 12.5, height: 1.35)),
        ),
      ]),
    );
  }
}

// ── Empty ──────────────────────────────────────────────────────────────────
class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _green.withOpacity(.08), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline_rounded, color: _green, size: 30),
          ),
          const SizedBox(height: 12),
          Text('Aucun frais en attente',
              style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Tes frais de scolarité apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
        ]));
  }
}

// ── Historique Card ───────────────────────────────────────────────────────
class _HistoriqueCard extends StatelessWidget {
  final List<SbPayment> payments;
  final String currency;
  final String studentName;
  final SbSchool? school;
  const _HistoriqueCard({
    required this.payments,
    required this.currency,
    required this.studentName,
    required this.school,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text('Aucun versement enregistré pour le moment.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8)],
      ),
      child: Column(
        children: List.generate(payments.length, (i) {
          final h = payments[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: i < payments.length - 1
                  ? Border(bottom: BorderSide(color: cs.outlineVariant))
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _green.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: _green, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_fmtMoney(h.amount)} $currency', style: TextStyle(
                    color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(_methodLabel(h.paymentMethod),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Text(_fmtDate(h.paymentDate), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 18),
                color: cs.onSurfaceVariant,
                tooltip: 'Télécharger le reçu',
                onPressed: () => printPaymentReceipt(
                  school: school,
                  payment: h,
                  studentName: studentName,
                  description: 'Scolarité',
                  currency: currency,
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final bool online;
  const _InfoCard({required this.online});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final modes = [
      if (online) 'Mobile Money (M-PESA, Airtel, Orange)',
      'Espèces à la caisse',
      'Virement bancaire',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withOpacity(.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded, color: _green, size: 18),
          const SizedBox(width: 8),
          Text('Modes de paiement acceptés',
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        for (final mode in modes) ...[
          Row(children: [
            const Icon(Icons.circle, size: 5, color: _green),
            const SizedBox(width: 8),
            Text(mode, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        Text('Pour tout litige, contactez le bureau de la comptabilité.',
            style: TextStyle(color: cs.onSurfaceVariant.withOpacity(.7), fontSize: 11,
                fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  const _SectionTitle({required this.icon, required this.label, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 16)),
      ),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
          color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w800)),
    ]);
  }
}
