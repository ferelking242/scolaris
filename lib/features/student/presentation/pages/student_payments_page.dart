import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart';
import '../../../../shared/widgets/online_payment_sheet.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFEDD8BE);

enum PayStatut { paye, enAttente, enRetard }

class StudentPaymentsPage extends ConsumerWidget {
  const StudentPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authSessionProvider);
    final invoicesAsync = ref.watch(myInvoicesProvider);
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
      color: _bg,
      child: invoicesAsync.when(
        loading: () => const Center(
            child: Padding(padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator())),
        error: (e, _) => Center(
            child: Padding(padding: const EdgeInsets.all(32),
                child: Text('Erreur : $e',
                    style: const TextStyle(color: _terra)))),
        data: (invoices) {
          final currency = invoices.isNotEmpty ? invoices.first.currency : 'FCFA';
          final total = invoices.fold<double>(0, (s, i) => s + i.amount);
          final paye  = invoices
              .where((i) => i.status.toLowerCase() == 'paid')
              .fold<double>(0, (s, i) => s + i.amount);
          final restant = (total - paye).clamp(0, double.infinity).toDouble();

          // Échéancier : trié par date d'échéance (puis non datées à la fin).
          final sorted = [...invoices]..sort((a, b) {
            final da = a.dueDate, db = b.dueDate;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
          final unpaid = sorted.where((i) {
            final s = i.status.toLowerCase();
            return s != 'paid' && s != 'cancelled';
          }).toList();
          final hasUnpaid = unpaid.isNotEmpty;
          // Échéance la plus urgente (en retard d'abord, sinon la plus proche).
          final urgent = unpaid.isEmpty ? null : unpaid.first;

          // Règle une liste de factures en ligne, puis rafraîchit.
          Future<void> pay(List<SbInvoice> list) async {
            final ok = await showOnlinePaymentSheet(context, ref, list);
            if (ok) ref.invalidate(myInvoicesProvider);
          }

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

                // ── Rappel : prochaine échéance / retard ───────────────────
                if (urgent != null) ...[
                  _ReminderBanner(
                    invoice: urgent,
                    currency: currency,
                    online: onlinePay,
                    onPay: () => pay([urgent]),
                  ),
                  const SizedBox(height: 16),
                ],

                if (invoices.isEmpty)
                  const _EmptyInvoices()
                else ...[
                  _SectionTitle(
                    icon: Icons.receipt_long_rounded,
                    label: feesTitle,
                    gradient: const [_terra, _orange],
                  ),
                  const SizedBox(height: 12),
                  for (final inv in sorted) ...[
                    _TrancheCard(
                      invoice: inv,
                      currency: currency,
                      onPay: (onlinePay && _isUnpaid(inv)) ? () => pay([inv]) : null,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Tout régler en une fois ────────────────────────────
                  if (hasUnpaid) ...[
                    const SizedBox(height: 8),
                    _PayCta(
                      online: onlinePay,
                      count: unpaid.length,
                      onPay: () => pay(unpaid),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _SectionTitle(
                    icon: Icons.history_rounded,
                    label: 'Historique des paiements',
                    gradient: const [_gold, _orange],
                  ),
                  const SizedBox(height: 12),
                  _HistoriqueCard(
                    paid: invoices
                        .where((i) => i.status.toLowerCase() == 'paid')
                        .toList(),
                    currency: currency,
                  ),
                ],

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
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(children: [
        Icon(overdue ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
            color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(invoice.description ?? 'Échéance à venir',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
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
          BoxShadow(color: _terra.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _white.withValues(alpha: .15), shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.account_balance_wallet_rounded, color: _white, size: 22)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(year.isEmpty ? headerTitle : '$headerTitle $year',
                style: TextStyle(color: _white.withValues(alpha: .7), fontSize: 11)),
            Text(name, style: const TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ]),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _white.withValues(alpha: .15),
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
              style: TextStyle(color: _white.withValues(alpha: .7), fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _StatPill(label: 'Total', value: '${_fmtMoney(totalAnnuel)} $currency', color: _white.withValues(alpha: .85)),
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
      color: _white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _white.withValues(alpha: .12)),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(color: _white.withValues(alpha: .55), fontSize: 9,
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
  const _TrancheCard({required this.invoice, required this.currency, this.onPay});

  PayStatut get _statut {
    switch (invoice.status.toLowerCase()) {
      case 'paid':    return PayStatut.paye;
      case 'overdue': return PayStatut.enRetard;
      default:        return PayStatut.enAttente;
    }
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
    final label = invoice.description ?? invoice.invoiceNumber ?? 'Frais';
    final dateLabel = _statut == PayStatut.paye
        ? 'Réglé'
        : 'Échéance ${_fmtDate(invoice.dueDate)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: .2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(_statusIcon, color: _statusColor, size: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
              color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(dateLabel, style: const TextStyle(color: _muted, fontSize: 12)),
          if (invoice.invoiceNumber != null) ...[
            const SizedBox(height: 2),
            Text('Réf: ${invoice.invoiceNumber}', style: TextStyle(
                color: _muted.withValues(alpha: .7), fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmtMoney(invoice.amount)} $currency', style: const TextStyle(
              color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor.withValues(alpha: .3)),
            ),
            child: Text(_statusLabel, style: TextStyle(
                color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          if (onPay != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onPay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Payer', style: TextStyle(
                    color: _white, fontSize: 11, fontWeight: FontWeight.w700)),
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
        color: _gold.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: .25)),
      ),
      child: Row(children: [
        const Icon(Icons.storefront_rounded, color: _gold, size: 20),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Règlement à la caisse de l\'établissement (espèces, virement).',
              style: TextStyle(color: _ink, fontSize: 12.5, height: 1.35)),
        ),
      ]),
    );
  }
}

// ── Empty ──────────────────────────────────────────────────────────────────
class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEE5D8)),
        ),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: .08), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline_rounded, color: _green, size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Aucun frais en attente',
              style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Tes frais de scolarité apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5)),
        ]),
      );
}

// ── Historique Card ───────────────────────────────────────────────────────
class _HistoriqueCard extends StatelessWidget {
  final List<SbInvoice> paid;
  final String currency;
  const _HistoriqueCard({required this.paid, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (paid.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEE5D8)),
        ),
        child: const Text('Aucun paiement enregistré pour le moment.',
            style: TextStyle(color: _muted, fontSize: 12.5)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 8)],
      ),
      child: Column(
        children: List.generate(paid.length, (i) {
          final h = paid[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: i < paid.length - 1
                  ? const Border(bottom: BorderSide(color: Color(0xFFEEE5D8)))
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: _green, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_fmtMoney(h.amount)} $currency', style: const TextStyle(
                    color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(h.description ?? h.invoiceNumber ?? 'Paiement',
                    style: const TextStyle(color: _muted, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Text(_fmtDate(h.dueDate), style: const TextStyle(color: _muted, fontSize: 11)),
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
    final modes = [
      if (online) 'Mobile Money (M-PESA, Airtel, Orange)',
      'Espèces à la caisse',
      'Virement bancaire',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withValues(alpha: .2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.info_outline_rounded, color: _green, size: 18),
          SizedBox(width: 8),
          Text('Modes de paiement acceptés',
              style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        for (final mode in modes) ...[
          Row(children: [
            const Icon(Icons.circle, size: 5, color: _green),
            const SizedBox(width: 8),
            Text(mode, style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        Text('Pour tout litige, contactez le bureau de la comptabilité.',
            style: TextStyle(color: _muted.withValues(alpha: .7), fontSize: 11,
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
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(child: Icon(icon, color: _white, size: 16)),
    ),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(
        color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
  ]);
}
