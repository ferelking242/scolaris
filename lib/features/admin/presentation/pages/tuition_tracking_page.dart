import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _gold  = Color(0xFFC17F24);

const _moisAbbr = [
  'janv','févr','mars','avr','mai','juin',
  'juil','août','sept','oct','nov','déc'
];

/// Étiquette courte d'une période ('2025-09' → 'sept' · '2025-T1' → 'T1').
String _periodShort(String p) {
  final parts = p.split('-');
  if (parts.length < 2) return p;
  final tail = parts[1];
  if (tail.startsWith('T')) return tail;
  final m = int.tryParse(tail);
  return (m != null && m >= 1 && m <= 12) ? _moisAbbr[m - 1] : p;
}

enum _Cell { paid, late, pending, none }

/// Suivi de la scolarité : matrice élève × période (qui a payé).
class TuitionTrackingPage extends ConsumerWidget {
  const TuitionTrackingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);

    // Sous-titre calculé pour l'en-tête.
    String? subtitle;
    final inv = invoicesAsync.valueOrNull;
    if (inv != null) {
      final tuition = inv.where((i) => i.isTuition && i.period != null).toList();
      if (tuition.isNotEmpty) {
        final periods = tuition.map((i) => i.period!).toSet();
        final students = tuition.map((i) => i.studentId ?? '—').toSet();
        final pct = (tuition.where((i) => i.isPaid).length / tuition.length * 100).round();
        subtitle =
            '${students.length} élève(s) · ${periods.length} périodes · $pct % réglé';
      } else {
        subtitle = 'Aucune échéance générée';
      }
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          GradientHeader(
            title: 'Suivi scolarité',
            subtitle: invoicesAsync.isLoading ? 'Chargement…' : subtitle,
            icon: Icons.grid_on_rounded,
          ),
          Expanded(
            child: invoicesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _terra)),
              error: (e, _) => Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur : $e',
                          style: const TextStyle(color: muted)))),
              data: (invoices) => _body(context, invoices),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<SbInvoice> invoices) {
    final tuition =
        invoices.where((i) => i.isTuition && i.period != null).toList();

    if (tuition.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 32, 16, 16),
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Aucune échéance',
          description:
              'Génère d\'abord l\'échéancier depuis « Frais de scolarité ».',
        ),
      );
    }

    // Périodes (colonnes), triées.
    final periods = tuition.map((i) => i.period!).toSet().toList()..sort();

    // Élèves (lignes), groupés par id, triés par nom.
    final byStudent = <String, ({String name, Map<String, SbInvoice> byPeriod})>{};
    for (final inv in tuition) {
      final sid = inv.studentId ?? '—';
      final entry = byStudent.putIfAbsent(
          sid, () => (name: inv.studentName ?? '—', byPeriod: {}));
      entry.byPeriod[inv.period!] = inv;
    }
    final students = byStudent.entries.toList()
      ..sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));

    // Stats globales.
    final paidCount = tuition.where((i) => i.isPaid).length;
    final lateCount = tuition.where((i) => i.isLate).length;
    final pendingCount = tuition.length - paidCount - lateCount;
    final pct = (paidCount / tuition.length * 100).round();

    // % payé par période (en-têtes de colonnes).
    final periodPct = <String, int>{
      for (final p in periods)
        p: () {
          final tot = tuition.where((i) => i.period == p).length;
          final pd = tuition.where((i) => i.period == p && i.isPaid).length;
          return tot == 0 ? 0 : (pd / tot * 100).round();
        }()
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        // Stats
        Row(children: [
          Expanded(child: _Stat(label: 'Échéances', value: '${tuition.length}', color: const Color(0xFF6D28D9))),
          const SizedBox(width: 10),
          Expanded(child: _Stat(label: 'Réglées', value: '$paidCount', color: _green)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Stat(label: 'En retard', value: '$lateCount', color: _terra)),
          const SizedBox(width: 10),
          Expanded(child: _Stat(label: 'Taux réglé', value: '$pct %', color: _gold)),
        ]),
        const SizedBox(height: 16),

        // Barre de progression globale
        _ProgressBar(paid: paidCount, late: lateCount, pending: pendingCount),
        const SizedBox(height: 16),

        // Légende
        const Wrap(spacing: 14, runSpacing: 8, children: [
          _LegendDot(color: _green, label: 'Payé'),
          _LegendDot(color: _gold, label: 'En attente'),
          _LegendDot(color: _terra, label: 'En retard'),
          _LegendDot(color: Color(0xFFB8A892), label: 'Aucune'),
        ]),
        const SizedBox(height: 12),

        // Matrice : colonne « Élève » figée + périodes scrollables.
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(
                color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Colonne figée
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _corner(),
                for (int i = 0; i < students.length; i++)
                  _nameCell(students[i].value.name, i),
              ]),
              Container(width: 1, color: border),
              // Périodes scrollables
              Expanded(child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    for (final p in periods) _periodHeader(p, periodPct[p] ?? 0),
                  ]),
                  for (int i = 0; i < students.length; i++)
                    Row(children: [
                      for (final p in periods)
                        _chip(_cellOf(students[i].value.byPeriod[p]), i),
                    ]),
                ]),
              )),
            ]),
          ),
        ),
      ],
    );
  }

  static const _rowH  = 46.0;
  static const _headH = 52.0;
  static const _nameW = 150.0;
  static const _cellW = 56.0;

  Color _zebra(int i) => i.isEven ? Colors.white : const Color(0xFFFBF7F0);

  _Cell _cellOf(SbInvoice? inv) {
    if (inv == null) return _Cell.none;
    if (inv.isPaid) return _Cell.paid;
    if (inv.isLate) return _Cell.late;
    return _Cell.pending;
  }

  Widget _corner() => Container(
        width: _nameW, height: _headH,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(color: Color(0xFFF7F1E8)),
        child: const Text('ÉLÈVE',
            style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
      );

  Widget _nameCell(String name, int i) => Container(
        width: _nameW, height: _rowH,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: _zebra(i),
        child: Text(name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  Widget _periodHeader(String p, int pct) => Container(
        width: _cellW, height: _headH,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0xFFF7F1E8)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_periodShort(p),
              style: const TextStyle(color: ink, fontSize: 10.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('$pct%',
              style: TextStyle(
                  color: pct >= 100 ? _green : (pct == 0 ? muted : _gold),
                  fontSize: 9, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _chip(_Cell cell, int i) {
    final (color, icon) = switch (cell) {
      _Cell.paid    => (_green, Icons.check_rounded),
      _Cell.late    => (_terra, Icons.priority_high_rounded),
      _Cell.pending => (_gold, Icons.schedule_rounded),
      _Cell.none    => (const Color(0xFFB8A892), Icons.remove_rounded),
    };
    return Container(
      width: _cellW, height: _rowH,
      alignment: Alignment.center,
      color: _zebra(i),
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: cell == _Cell.none ? .08 : .15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Barre de progression empilée : payé / en attente / en retard.
class _ProgressBar extends StatelessWidget {
  final int paid, late, pending;
  const _ProgressBar({required this.paid, required this.late, required this.pending});
  @override
  Widget build(BuildContext context) {
    final hasData = paid + late + pending > 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Row(children: [
        if (paid > 0) Expanded(flex: paid, child: Container(height: 10, color: _green)),
        if (pending > 0) Expanded(flex: pending, child: Container(height: 10, color: _gold)),
        if (late > 0) Expanded(flex: late, child: Container(height: 10, color: _terra)),
        // garde-fou si tout est à zéro (improbable ici) → barre neutre
        if (!hasData) Expanded(child: Container(height: 10, color: border)),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: muted, fontSize: 11.5)),
      ]);
}
