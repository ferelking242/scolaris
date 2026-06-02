import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/auth_providers.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFEDD8BE);

class StudentPaymentsPage extends ConsumerWidget {
  const StudentPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);

    const tranches = [
      _Tranche(
        label: '1ère Tranche',
        montant: 75000,
        statut: PayStatut.paye,
        date: '15 Sep 2025',
        recu: 'SCO-2025-001',
      ),
      _Tranche(
        label: '2ème Tranche',
        montant: 75000,
        statut: PayStatut.paye,
        date: '12 Jan 2026',
        recu: 'SCO-2026-042',
      ),
      _Tranche(
        label: '3ème Tranche',
        montant: 75000,
        statut: PayStatut.enAttente,
        date: 'Avant le 15 Avr 2026',
        recu: null,
      ),
    ];

    const totalAnnuel = 225000;
    const totalPaye   = 150000;
    const restant     = totalAnnuel - totalPaye;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Carte résumé ──────────────────────────────────────────
            _SummaryCard(
              name: user?.fullName ?? 'Étudiant',
              totalAnnuel: totalAnnuel,
              totalPaye: totalPaye,
              restant: restant,
            ),
            const SizedBox(height: 24),

            // ── Section titre ─────────────────────────────────────────
            _SectionTitle(
              icon: Icons.receipt_long_rounded,
              label: 'Tranches de scolarité',
              gradient: const [_terra, _orange],
            ),
            const SizedBox(height: 12),

            // ── Tranches ──────────────────────────────────────────────
            for (final t in tranches) ...[
              _TrancheCard(tranche: t),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 24),

            // ── Historique ────────────────────────────────────────────
            _SectionTitle(
              icon: Icons.history_rounded,
              label: 'Historique des paiements',
              gradient: const [_gold, _orange],
            ),
            const SizedBox(height: 12),
            _HistoriqueCard(),

            const SizedBox(height: 24),

            // ── Infos utiles ──────────────────────────────────────────
            _SectionTitle(
              icon: Icons.info_outline_rounded,
              label: 'Informations',
              gradient: const [_green, Color(0xFF2E7D32)],
            ),
            const SizedBox(height: 12),
            _InfoCard(),
          ],
        ),
      ),
    );
  }
}

// ── Enums & data ──────────────────────────────────────────────────────────
enum PayStatut { paye, enAttente, enRetard }

class _Tranche {
  final String label;
  final int montant;
  final PayStatut statut;
  final String date;
  final String? recu;
  const _Tranche({
    required this.label, required this.montant, required this.statut,
    required this.date, required this.recu,
  });
}

// ── Summary Card ──────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String name;
  final int totalAnnuel, totalPaye, restant;
  const _SummaryCard({
    required this.name, required this.totalAnnuel,
    required this.totalPaye, required this.restant,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalPaye / totalAnnuel;
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
              color: _white.withOpacity(.15), shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.account_balance_wallet_rounded, color: _white, size: 22)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scolarité 2025-2026',
                style: TextStyle(color: _white.withOpacity(.7), fontSize: 11)),
            Text(name, style: const TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ]),
        const SizedBox(height: 20),

        // Barre de progression
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _white.withOpacity(.15),
            valueColor: const AlwaysStoppedAnimation<Color>(_gold),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text('${(progress * 100).toStringAsFixed(0)}% payé',
              style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_fmt(restant)} FCFA restant',
              style: TextStyle(color: _white.withOpacity(.7), fontSize: 11)),
        ]),
        const SizedBox(height: 16),

        // Stats row
        Row(children: [
          _StatPill(label: 'Total annuel', value: '${_fmt(totalAnnuel)} FCFA', color: _white.withOpacity(.85)),
          const SizedBox(width: 10),
          _StatPill(label: 'Payé', value: '${_fmt(totalPaye)} FCFA', color: _gold),
          const SizedBox(width: 10),
          _StatPill(label: 'Restant', value: '${_fmt(restant)} FCFA', color: const Color(0xFFFFB74D)),
        ]),
      ]),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
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
      color: _white.withOpacity(.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _white.withOpacity(.12)),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(color: _white.withOpacity(.55), fontSize: 9,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  ));
}

// ── Tranche Card ──────────────────────────────────────────────────────────
class _TrancheCard extends StatelessWidget {
  final _Tranche tranche;
  const _TrancheCard({required this.tranche});

  Color get _statusColor {
    switch (tranche.statut) {
      case PayStatut.paye:       return _green;
      case PayStatut.enAttente:  return _gold;
      case PayStatut.enRetard:   return _terra;
    }
  }

  String get _statusLabel {
    switch (tranche.statut) {
      case PayStatut.paye:       return 'Payé';
      case PayStatut.enAttente:  return 'En attente';
      case PayStatut.enRetard:   return 'En retard';
    }
  }

  IconData get _statusIcon {
    switch (tranche.statut) {
      case PayStatut.paye:       return Icons.check_circle_rounded;
      case PayStatut.enAttente:  return Icons.schedule_rounded;
      case PayStatut.enRetard:   return Icons.warning_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
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
          Text(tranche.label, style: const TextStyle(
              color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(tranche.date, style: TextStyle(color: _muted, fontSize: 12)),
          if (tranche.recu != null) ...[
            const SizedBox(height: 2),
            Text('Reçu: ${tranche.recu}', style: TextStyle(
                color: _muted.withOpacity(.7), fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('75 000 FCFA', style: const TextStyle(
              color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
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
        ]),
      ]),
    );
  }
}

// ── Historique Card ───────────────────────────────────────────────────────
class _HistoriqueCard extends StatelessWidget {
  static const _history = [
    (date: '12 Jan 2026', montant: '75 000 FCFA', mode: 'Mobile Money', ref: 'TXN-20260112'),
    (date: '15 Sep 2025', montant: '75 000 FCFA', mode: 'Espèces', ref: 'TXN-20250915'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8)],
      ),
      child: Column(
        children: List.generate(_history.length, (i) {
          final h = _history[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: i < _history.length - 1
                  ? Border(bottom: BorderSide(color: const Color(0xFFEEE5D8)))
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _green.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle_outline_rounded, color: _green, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.montant, style: const TextStyle(
                    color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${h.mode} · ${h.ref}',
                    style: TextStyle(color: _muted, fontSize: 11)),
              ])),
              Text(h.date, style: TextStyle(color: _muted, fontSize: 11)),
            ]),
          );
        }),
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withOpacity(.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, color: _green, size: 18),
          const SizedBox(width: 8),
          const Text('Modes de paiement acceptés',
              style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        for (final mode in ['Mobile Money (M-PESA, Airtel)', 'Espèces à la caisse', 'Virement bancaire']) ...[
          Row(children: [
            Icon(Icons.circle, size: 5, color: _green),
            const SizedBox(width: 8),
            Text(mode, style: TextStyle(color: _muted, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        Text('Pour tout litige, contactez le bureau de la comptabilité.',
            style: TextStyle(color: _muted.withOpacity(.7), fontSize: 11,
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
